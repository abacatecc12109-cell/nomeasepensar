--[[
	ObstacleController (cliente)
	----------------------------
	Anima os obstáculos localmente, o que deixa tudo suave e justo:

	* Plataformas móveis: posição calculada pelo relógio do servidor
	  (todos os jogadores veem a mesma fase). A velocidade da plataforma é
	  aplicada à peça, então o personagem é carregado junto.
	* Tábuas que desabam / pedras que caem: por jogador. Tremem ao serem
	  pisadas (aviso), caem e voltam alguns segundos depois.
	* Troncos balançando: pêndulos; um tronco empurra o jogador para o lado.
	* Cachoeira com rajadas: a água engrossa ANTES da rajada (aviso visual),
	  depois empurra quem estiver na trilha.
	* Pás do moinho giram.

	Tudo lida com StreamingEnabled: objetos que entram/saem do streaming são
	registrados/removidos pelos sinais do CollectionService.
]]

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Config = require(Shared.Config)

local Tags = Config.Tags
local ObstacleController = {}

local player = Players.LocalPlayer
local UPDATE_RADIUS = 450 -- só anima o que está perto (economia no celular)

local movers = {}
local logs = {}
local gusts = {}
local spinners = {}
local fragile = {} -- [part] = estado
local shaking = {}

-- ===================================================================
-- Curvas de movimento
-- ===================================================================

local function ease(x: number): number
	return (1 - math.cos(math.pi * math.clamp(x, 0, 1))) / 2
end

-- Vai e volta com pausas nas pontas (tempo para subir/descer com calma)
function ObstacleController.alpha(t: number, period: number, phase: number): number
	local u = (t / period + phase) % 1
	if u < 0.15 then
		return 0
	elseif u < 0.5 then
		return ease((u - 0.15) / 0.35)
	elseif u < 0.65 then
		return 1
	end
	return 1 - ease((u - 0.65) / 0.35)
end

-- ===================================================================
-- Registro (com suporte a streaming)
-- ===================================================================

local function track(tag: string, onAdd, onRemove)
	for _, inst in CollectionService:GetTagged(tag) do
		task.spawn(onAdd, inst)
	end
	CollectionService:GetInstanceAddedSignal(tag):Connect(onAdd)
	CollectionService:GetInstanceRemovedSignal(tag):Connect(onRemove)
end

local function addMover(model: Model)
	local primary = model.PrimaryPart
	if not primary then
		return
	end
	movers[model] = {
		primary = primary,
		a = model:GetAttribute("PointA"),
		b = model:GetAttribute("PointB"),
		period = model:GetAttribute("Period") or 6,
		phase = model:GetAttribute("Phase") or 0,
		rot = primary.CFrame.Rotation,
		offset = primary.CFrame:ToObjectSpace(model:GetPivot()),
		last = primary.Position,
	}
end

local function addLog(model: Model)
	local pivot = model:GetAttribute("Pivot")
	if typeof(pivot) ~= "CFrame" then
		return
	end
	logs[model] = {
		pivot = pivot,
		rope = model:GetAttribute("RopeLength") or 6.5,
		half = (model:GetAttribute("LogLength") or 3.6) / 2,
		radius = model:GetAttribute("Radius") or 1.1,
		amp = model:GetAttribute("Amplitude") or math.rad(70),
		period = model:GetAttribute("Period") or 3.4,
		phase = model:GetAttribute("Phase") or 0,
		base = pivot:ToObjectSpace(model:GetPivot()),
	}
end

local function addGust(zone: BasePart)
	local model = zone.Parent
	gusts[zone] = {
		period = zone:GetAttribute("Period") or 4.4,
		gustTime = zone:GetAttribute("GustTime") or 1.4,
		phase = zone:GetAttribute("Phase") or 0,
		push = zone:GetAttribute("Push") or Vector3.xAxis,
		splash = model and model:FindFirstChild("Splash"),
		sheet = model and model:FindFirstChild("Sheet"),
		mist = zone:FindFirstChild("Mist", true),
		lastCycle = -1,
	}
end

local function addSpinner(model: Model)
	spinners[model] = {
		base = model:GetPivot(),
		speed = model:GetAttribute("SpinSpeed") or 0.5,
	}
end

local function addFragile(part: BasePart)
	fragile[part] = {
		home = part.CFrame,
		transparency = part.Transparency,
		delay = part:GetAttribute("Delay") or 0.5,
		respawn = part:GetAttribute("Respawn") or 3.5,
		busy = false,
	}
end

local function remover(list)
	return function(inst)
		list[inst] = nil
	end
end

-- ===================================================================
-- Tábuas e pedras frágeis
-- ===================================================================

local function collapse(part: BasePart)
	local state = fragile[part]
	if not state or state.busy then
		return
	end
	state.busy = true
	shaking[part] = state
	task.delay(state.delay, function()
		shaking[part] = nil
		if not part.Parent then
			return
		end
		part.CanCollide = false
		local start = os.clock()
		local conn
		conn = RunService.Heartbeat:Connect(function()
			local k = math.min((os.clock() - start) / 0.9, 1)
			part.CFrame = state.home * CFrame.new(0, -k * k * 24, 0) * CFrame.Angles(k * 0.6, 0, k * 0.4)
			part.Transparency = state.transparency + (1 - state.transparency) * k
			if k >= 1 then
				conn:Disconnect()
			end
		end)
		task.delay(state.respawn, function()
			if conn.Connected then
				conn:Disconnect()
			end
			if part.Parent then
				part.CFrame = state.home
				part.Transparency = state.transparency
				part.CanCollide = true
			end
			state.busy = false
		end)
	end)
end

local rayParams = RaycastParams.new()
rayParams.FilterType = Enum.RaycastFilterType.Exclude

-- ===================================================================
-- Laço principal (antes da física: as plataformas carregam o jogador)
-- ===================================================================

local knockCooldown = 0

local function knock(humanoid: Humanoid, root: BasePart, direction: Vector3, strength: number)
	if os.clock() < knockCooldown then
		return
	end
	knockCooldown = os.clock() + 0.9
	humanoid:ChangeState(Enum.HumanoidStateType.Jumping)
	root.AssemblyLinearVelocity = Vector3.new(direction.X * strength, 26, direction.Z * strength)
end

local function step(dt: number)
	local t = workspace:GetServerTimeNow()
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local camera = workspace.CurrentCamera
	local focus = root and root.Position or (camera and camera.CFrame.Position) or Vector3.zero

	-- plataformas móveis
	for model, m in movers do
		if (m.a - focus).Magnitude < UPDATE_RADIUS then
			local pos = m.a:Lerp(m.b, ObstacleController.alpha(t, m.period, m.phase))
			local cf = CFrame.new(pos) * m.rot
			model:PivotTo(cf * m.offset)
			if dt > 0 then
				m.primary.AssemblyLinearVelocity = (pos - m.last) / dt
			end
			m.last = pos
		end
	end

	-- troncos balançando
	for model, l in logs do
		if (l.pivot.Position - focus).Magnitude < UPDATE_RADIUS then
			local w = 2 * math.pi / l.period
			local angle = l.amp * math.sin(w * (t + l.phase))
			local swung = l.pivot * CFrame.Angles(0, 0, angle)
			model:PivotTo(swung * l.base)
			if root and humanoid and humanoid.Health > 0 then
				local center = (swung * CFrame.new(0, -l.rope, 0)).Position
				local axis = l.pivot.LookVector
				local rel = root.Position - center
				local along = math.clamp(rel:Dot(axis), -l.half, l.half)
				local closest = center + axis * along
				if (root.Position - closest).Magnitude < l.radius + 1.7 then
					local swingDir = math.cos(w * (t + l.phase)) >= 0 and 1 or -1
					local side = (swung.RightVector * swingDir)
					knock(humanoid, root, Vector3.new(side.X, 0, side.Z).Unit, 48)
				end
			end
		end
	end

	-- rajadas da cachoeira
	for zone, g in gusts do
		local u = (t + g.phase) % g.period
		local gustStart = g.period - g.gustTime
		local warning = u > gustStart - 0.9 and u <= gustStart
		local active = u > gustStart
		if g.splash then
			g.splash.Transparency = active and 0.35 or (warning and 0.7 or 0.92)
		end
		if g.mist then
			g.mist.Rate = active and 24 or (warning and 10 or 4)
		end
		if active and root and humanoid and humanoid.Health > 0 then
			local cycle = math.floor((t + g.phase) / g.period)
			local localPos = zone.CFrame:PointToObjectSpace(root.Position)
			local half = zone.Size / 2
			if math.abs(localPos.X) <= half.X and math.abs(localPos.Y) <= half.Y and math.abs(localPos.Z) <= half.Z and g.lastCycle ~= cycle then
				g.lastCycle = cycle
				knock(humanoid, root, g.push, 40)
			end
		end
	end

	-- pás do moinho
	for model, s in spinners do
		if (s.base.Position - focus).Magnitude < UPDATE_RADIUS then
			model:PivotTo(s.base * CFrame.Angles(0, 0, t * s.speed))
		end
	end

	-- tremor das peças frágeis (aviso antes de cair)
	for part, state in shaking do
		part.CFrame = state.home * CFrame.new(math.random() * 0.16 - 0.08, 0, math.random() * 0.16 - 0.08)
	end

	-- o que está sob os pés?
	if root and character then
		rayParams.FilterDescendantsInstances = { character }
		local hit = workspace:Raycast(root.Position, Vector3.new(0, -4.6, 0), rayParams)
		if hit and fragile[hit.Instance] then
			collapse(hit.Instance)
		end
	end
end

function ObstacleController.start()
	track(Tags.MovingPlatform, addMover, remover(movers))
	track(Tags.SwingingLog, addLog, remover(logs))
	track(Tags.WaterfallGust, addGust, remover(gusts))
	track("Spin", addSpinner, remover(spinners))
	track(Tags.CollapsingPlank, addFragile, remover(fragile))
	track(Tags.FallingStone, addFragile, remover(fragile))
	RunService.PreSimulation:Connect(step)
end

return ObstacleController
