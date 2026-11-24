--[[
	ProgressService
	---------------
	Progresso do jogador durante a sessão:
	  * checkpoint atual, tempo de corrida, recorde e altura máxima
	  * renascer no último checkpoint (morte, queda ou água abaixo do percurso)
	  * chegada, anúncio e reinício da subida
	O progresso fica salvo na memória do servidor por UserId: se o jogador
	sair e voltar ao mesmo servidor, continua de onde parou.
]]

local Players = game:GetService("Players")
local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Config = require(Shared.Config)
local Remotes = require(Shared.Remotes)

local ProgressService = {}

local A = Config.Attr
local CHECK_INTERVAL = 0.25

local remotes
local checkpointService
local session = {} -- [userId] = { checkpoint, runStart, finishTime, best, maxHeight }
local lastRestart = {}
local resetting = {}

local function now(): number
	return workspace:GetServerTimeNow()
end

local function formatTime(seconds: number): string
	local m = math.floor(seconds / 60)
	local s = seconds - m * 60
	return string.format("%d:%05.2f", m, s)
end
ProgressService.formatTime = formatTime

local function save(player: Player)
	local data = session[player.UserId]
	if not data then
		return
	end
	data.checkpoint = player:GetAttribute(A.Checkpoint) or 1
	data.runStart = player:GetAttribute(A.RunStart)
	data.finishTime = player:GetAttribute(A.RunFinish) or 0
	data.best = player:GetAttribute(A.BestTime) or 0
	data.maxHeight = player:GetAttribute(A.MaxHeight) or 0
end

local function leaderstats(player: Player)
	local stats = Instance.new("Folder")
	stats.Name = "leaderstats"
	local stage = Instance.new("IntValue")
	stage.Name = "Etapa"
	stage.Value = player:GetAttribute(A.Checkpoint) or 1
	stage.Parent = stats
	local record = Instance.new("StringValue")
	record.Name = "Recorde"
	local best = player:GetAttribute(A.BestTime) or 0
	record.Value = best > 0 and formatTime(best) or "--"
	record.Parent = stats
	stats.Parent = player
	player:GetAttributeChangedSignal(A.Checkpoint):Connect(function()
		stage.Value = player:GetAttribute(A.Checkpoint) or 1
	end)
	player:GetAttributeChangedSignal(A.BestTime):Connect(function()
		local b = player:GetAttribute(A.BestTime) or 0
		record.Value = b > 0 and formatTime(b) or "--"
	end)
end

-- Coloca o personagem em pé no checkpoint atual
local function placeAtCheckpoint(player: Player, character: Model)
	local root = character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not root then
		return
	end
	local index = player:GetAttribute(A.Checkpoint) or 1
	local cf = checkpointService.spawnCFrame(index)
	pcall(function()
		player:RequestStreamAroundAsync(cf.Position, 3)
	end)
	root.AssemblyLinearVelocity = Vector3.zero
	root.AssemblyAngularVelocity = Vector3.zero
	character:PivotTo(cf)
end

function ProgressService.resetToCheckpoint(player: Player, reason: string)
	local character = player.Character
	if not character or resetting[player] then
		return
	end
	resetting[player] = true
	remotes.FallReset:FireClient(player, reason)
	task.delay(0.18, function()
		if player.Parent and player.Character == character then
			placeAtCheckpoint(player, character)
		end
		resetting[player] = nil
	end)
end

local function onCharacter(player: Player, character: Model)
	local humanoid = character:WaitForChild("Humanoid", 10) :: Humanoid?
	character:WaitForChild("HumanoidRootPart", 10)
	if humanoid then
		humanoid.MaxSlopeAngle = Config.Physics.MaxSlopeAngle
	end
	task.defer(function()
		if player.Character == character then
			placeAtCheckpoint(player, character)
		end
	end)
	if player:GetAttribute(A.RunStart) == nil then
		player:SetAttribute(A.RunStart, now())
	end
end

local function onPlayerAdded(player: Player)
	local data = session[player.UserId]
	if not data then
		data = { checkpoint = 1, runStart = nil, finishTime = 0, best = 0, maxHeight = 0 }
		session[player.UserId] = data
	end
	player:SetAttribute(A.Checkpoint, data.checkpoint)
	player:SetAttribute(A.RunFinish, data.finishTime)
	player:SetAttribute(A.BestTime, data.best)
	player:SetAttribute(A.MaxHeight, data.maxHeight)
	if data.runStart then
		player:SetAttribute(A.RunStart, data.runStart)
	end
	leaderstats(player)
	player.CharacterAdded:Connect(function(character)
		onCharacter(player, character)
	end)
	if player.Character then
		onCharacter(player, player.Character)
	end
	if ProgressService.worldReady then
		player:LoadCharacter()
	end
end

local function onReached(player: Player, index: number, data)
	remotes.CheckpointReached:FireClient(player, index, data.label, data.finish)
	if data.finish and (player:GetAttribute(A.RunFinish) or 0) == 0 then
		local start = player:GetAttribute(A.RunStart) or now()
		local elapsed = now() - start
		local best = player:GetAttribute(A.BestTime) or 0
		local newRecord = best == 0 or elapsed < best
		player:SetAttribute(A.RunFinish, elapsed)
		if newRecord then
			player:SetAttribute(A.BestTime, elapsed)
		end
		remotes.RunFinished:FireClient(player, elapsed, newRecord and elapsed or best, newRecord)
		remotes.Announcement:FireAllClients(string.format("🌸 %s chegou ao Mirante do Céu em %s!", player.DisplayName, formatTime(elapsed)))
	end
	save(player)
end

local function onRestart(player: Player)
	local t = os.clock()
	if lastRestart[player] and t - lastRestart[player] < 3 then
		return
	end
	lastRestart[player] = t
	player:SetAttribute(A.Checkpoint, 1)
	player:SetAttribute(A.RunFinish, 0)
	player:SetAttribute(A.RunStart, now())
	save(player)
	if player.Character then
		ProgressService.resetToCheckpoint(player, "restart")
	end
end

-- Verificação leve (4x por segundo): queda abaixo do checkpoint, água e altura máxima
local function monitor()
	while true do
		task.wait(CHECK_INTERVAL)
		for _, player in Players:GetPlayers() do
			local character = player.Character
			local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
			local humanoid = character and character:FindFirstChildOfClass("Humanoid")
			if root and humanoid and humanoid.Health > 0 and not resetting[player] then
				local index = player:GetAttribute(A.Checkpoint) or 1
				local cp = checkpointService.get(index)
				local y = root.Position.Y
				if cp then
					local cpY = cp.data.position.Y
					if y < cpY - Config.FallResetDepth then
						ProgressService.resetToCheckpoint(player, "fall")
					elseif humanoid:GetState() == Enum.HumanoidStateType.Swimming and y < cpY - 4 then
						ProgressService.resetToCheckpoint(player, "water")
					end
				end
				if y > (player:GetAttribute(A.MaxHeight) or 0) + 1 then
					player:SetAttribute(A.MaxHeight, math.floor(y))
				end
			end
		end
	end
end

function ProgressService.init(cpService)
	checkpointService = cpService
	remotes = Remotes.get()
	cpService.onReached(onReached)
	remotes.RequestRestart.OnServerEvent:Connect(onRestart)
	Players.PlayerAdded:Connect(onPlayerAdded)
	Players.PlayerRemoving:Connect(function(player)
		save(player)
		lastRestart[player] = nil
		resetting[player] = nil
	end)
	for _, player in Players:GetPlayers() do
		task.spawn(onPlayerAdded, player)
	end
	task.spawn(monitor)
end

-- Chamado quando o mundo terminou de ser construído
function ProgressService.markReady()
	ProgressService.worldReady = true
	Players.CharacterAutoLoads = true
	for _, player in Players:GetPlayers() do
		if not player.Character then
			player:LoadCharacter()
		end
	end
end

return ProgressService
