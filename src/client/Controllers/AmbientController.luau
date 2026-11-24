--[[
	AmbientController (cliente)
	---------------------------
	Efeitos de ambiente que dependem de onde o jogador está:
	  * atmosfera (névoa e cor do céu) muda suavemente por região
	  * pétalas de cerejeira caindo (Jardim, Vila, Jardim Celestial)
	  * vaga-lumes / luzes (Floresta das Nuvens, Jardim Celestial)

	Usa só DOIS emissores de partículas que acompanham a câmera — muito
	mais leve do que espalhar emissores pelo mapa. Em celulares e em
	qualidade gráfica baixa a quantidade de partículas é reduzida.
]]

local Lighting = game:GetService("Lighting")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Regions = require(Shared.Regions)
local Config = require(Shared.Config)

local AmbientController = {}
local player = Players.LocalPlayer

AmbientController.currentRegion = 0
local listeners = {}

-- 0..1: quanto de efeito o aparelho aguenta
local function qualityFactor(): number
	local factor = 1
	local ok, level = pcall(function()
		return UserSettings():GetService("UserGameSettings").SavedQualityLevel.Value
	end)
	if ok and typeof(level) == "number" and level > 0 then
		factor = math.clamp(level / 7, 0.3, 1)
	end
	if UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled then
		factor *= 0.55
	end
	return factor
end

local function makeEmitterHost()
	local host = Instance.new("Part")
	host.Name = "AmbientParticles"
	host.Anchored = true
	host.CanCollide = false
	host.CanTouch = false
	host.CanQuery = false
	host.Transparency = 1
	host.Size = Vector3.new(110, 1, 110)
	host.Parent = workspace.CurrentCamera
	return host
end

local function petals(host: BasePart, rate: number)
	local e = Instance.new("ParticleEmitter")
	e.Name = "Petals"
	e.Texture = "rbxasset://textures/particles/sparkles_main.dds"
	e.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, Config.Palette.BlossomLight),
		ColorSequenceKeypoint.new(1, Config.Palette.Blossom),
	})
	e.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.32), NumberSequenceKeypoint.new(1, 0.22) })
	e.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.1, 0.1), NumberSequenceKeypoint.new(0.85, 0.2), NumberSequenceKeypoint.new(1, 1) })
	e.Lifetime = NumberRange.new(9, 13)
	e.Rate = rate
	e.Speed = NumberRange.new(1.5, 3)
	e.EmissionDirection = Enum.NormalId.Bottom
	e.SpreadAngle = Vector2.new(35, 35)
	e.Acceleration = Vector3.new(1.2, -1.2, 0.6)
	e.Rotation = NumberRange.new(0, 360)
	e.RotSpeed = NumberRange.new(-120, 120)
	e.Drag = 0.6
	e.LightEmission = 0.15
	e.Parent = host
	return e
end

local function fireflies(host: BasePart, rate: number)
	local e = Instance.new("ParticleEmitter")
	e.Name = "Fireflies"
	e.Texture = "rbxasset://textures/particles/sparkles_main.dds"
	e.Color = ColorSequence.new(Color3.fromRGB(236, 255, 196), Color3.fromRGB(196, 230, 255))
	e.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0), NumberSequenceKeypoint.new(0.3, 0.35), NumberSequenceKeypoint.new(1, 0) })
	e.Lifetime = NumberRange.new(4, 7)
	e.Rate = rate
	e.Speed = NumberRange.new(0.4, 1.2)
	e.SpreadAngle = Vector2.new(180, 180)
	e.LightEmission = 1
	e.Parent = host
	return e
end

-- Índice da região pela altura real (os limites vêm do servidor)
function AmbientController.regionAt(y: number): number
	local info = ReplicatedStorage:FindFirstChild("CourseInfo")
	if not info then
		return 1
	end
	local count = info:GetAttribute("RegionCount") or #Regions
	local region = 1
	for i = 2, count do
		local start = info:GetAttribute("Region" .. i .. "Start")
		if start and y >= start - 1 then
			region = i
		end
	end
	return region
end

function AmbientController.onRegionChanged(fn)
	table.insert(listeners, fn)
end

function AmbientController.start()
	local factor = qualityFactor()
	local petalHost = makeEmitterHost()
	local fireflyHost = makeEmitterHost()
	fireflyHost.Size = Vector3.new(70, 30, 70)
	local petalEmitter = petals(petalHost, math.floor(26 * factor))
	local fireflyEmitter = fireflies(fireflyHost, math.floor(14 * factor))
	fireflyEmitter.Enabled = false

	local atmosphere = Lighting:FindFirstChildOfClass("Atmosphere")
	local tweenInfo = TweenInfo.new(4, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut)

	local function apply(index: number)
		local region = Regions[index]
		if not region then
			return
		end
		petalEmitter.Enabled = region.Petals
		fireflyEmitter.Enabled = region.Fireflies
		atmosphere = atmosphere or Lighting:FindFirstChildOfClass("Atmosphere")
		if atmosphere then
			TweenService:Create(atmosphere, tweenInfo, {
				Density = region.Atmosphere.Density,
				Haze = region.Atmosphere.Haze,
				Color = region.Atmosphere.Color,
				Decay = region.Atmosphere.Decay,
			}):Play()
		end
		for _, fn in listeners do
			task.spawn(fn, index, region)
		end
	end

	local accumulator = 0
	RunService.Heartbeat:Connect(function(dt)
		local camera = workspace.CurrentCamera
		if not camera then
			return
		end
		local camPos = camera.CFrame.Position
		petalHost.CFrame = CFrame.new(camPos + Vector3.new(0, 28, 0))
		fireflyHost.CFrame = CFrame.new(camPos)
		accumulator += dt
		if accumulator < 0.5 then
			return
		end
		accumulator = 0
		local character = player.Character
		local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
		if root then
			local index = AmbientController.regionAt(root.Position.Y)
			if index ~= AmbientController.currentRegion then
				AmbientController.currentRegion = index
				apply(index)
			end
		end
	end)
end

return AmbientController
