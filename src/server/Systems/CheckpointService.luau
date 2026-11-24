--[[
	CheckpointService
	-----------------
	* Cria o ponto de nascimento no primeiro checkpoint.
	* Detecta (no servidor) quando o jogador toca um checkpoint e avança o
	  progresso. O visual "ativado" é feito no cliente, por jogador.
	* Fornece o CFrame de renascimento de cada checkpoint.
]]

local Players = game:GetService("Players")
local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Config = require(Shared.Config)

local CheckpointService = {}

local checkpoints = {} -- [index] = { model, trigger, data, spawnCFrame }
local listeners = {}

function CheckpointService.count(): number
	return #checkpoints
end

function CheckpointService.get(index: number)
	return checkpoints[index]
end

function CheckpointService.spawnCFrame(index: number): CFrame
	local cp = checkpoints[math.clamp(index, 1, #checkpoints)]
	return cp.spawnCFrame
end

-- Registra uma função chamada quando um jogador alcança um checkpoint novo
function CheckpointService.onReached(fn)
	table.insert(listeners, fn)
end

local function handleTouch(index: number, hit: BasePart)
	local character = hit.Parent
	if not character then
		return
	end
	local player = Players:GetPlayerFromCharacter(character)
	if not player then
		return
	end
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if not humanoid or humanoid.Health <= 0 then
		return
	end
	local current = player:GetAttribute(Config.Attr.Checkpoint) or 1
	if index <= current then
		return
	end
	player:SetAttribute(Config.Attr.Checkpoint, index)
	for _, fn in listeners do
		task.spawn(fn, player, index, checkpoints[index].data)
	end
end

function CheckpointService.init(triggers)
	for index, entry in triggers do
		local data = entry.data
		checkpoints[index] = {
			model = entry.model,
			trigger = entry.trigger,
			data = data,
			spawnCFrame = entry.model:GetAttribute("SpawnCFrame"),
		}
		entry.trigger.Touched:Connect(function(hit)
			handleTouch(index, hit)
		end)
	end

	-- ponto de nascimento no primeiro checkpoint
	local first = checkpoints[1]
	local spawn = Instance.new("SpawnLocation")
	spawn.Name = "Inicio"
	spawn.Anchored = true
	spawn.Neutral = true
	spawn.Duration = 0
	spawn.Size = Vector3.new(6, 1, 6)
	spawn.CFrame = CFrame.new(first.data.position + Vector3.new(0, 0.2, 0)) * first.spawnCFrame.Rotation
	spawn.Transparency = 1
	spawn.CanCollide = false
	spawn.CanTouch = false
	spawn.CanQuery = false
	spawn.Parent = first.model
end

return CheckpointService
