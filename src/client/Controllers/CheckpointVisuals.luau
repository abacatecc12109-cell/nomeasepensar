--[[
	CheckpointVisuals (cliente)
	---------------------------
	Muda o visual dos checkpoints conforme o progresso DESTE jogador:
	  * ainda não alcançado: estrela clara, apagada
	  * já ativado: estrela rosa
	  * atual: estrela brilhando, girando, com partículas e luz
	O checkpoint é só a estrela (sem faixa, anel ou pilar).
]]

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Config = require(Shared.Config)

local CheckpointVisuals = {}
local P = Config.Palette
local player = Players.LocalPlayer

local models = {} -- [index] = model
local currentCrystal: BasePart? = nil
local crystalHome: CFrame? = nil

local function paint(model: Model, state: string)
	local crystal = model:FindFirstChild("Crystal") :: BasePart?
	local color = state == "idle" and P.CheckpointIdle or P.CheckpointActive
	if crystal then
		crystal.Color = color
		local glow = crystal:FindFirstChild("Glow") :: PointLight?
		if glow then
			glow.Brightness = state == "current" and 1.4 or 0
		end
		local sparkle = crystal:FindFirstChild("Sparkle", true) :: ParticleEmitter?
		if sparkle then
			sparkle.Enabled = state == "current"
		end
	end
end

local function refresh()
	local current = player:GetAttribute(Config.Attr.Checkpoint) or 1
	if currentCrystal and crystalHome then
		currentCrystal.CFrame = crystalHome
	end
	currentCrystal, crystalHome = nil, nil
	for index, model in models do
		if model.Parent then
			local state = index < current and "done" or (index == current and "current" or "idle")
			paint(model, state)
			if state == "current" then
				local crystal = model:FindFirstChild("Crystal") :: BasePart?
				if crystal then
					currentCrystal = crystal
					crystalHome = crystal.CFrame
				end
			end
		end
	end
end
CheckpointVisuals.refresh = refresh

local function add(model: Model)
	local index = model:GetAttribute(Config.Attr.CheckpointIndex)
	if index then
		models[index] = model
		refresh()
	end
end

function CheckpointVisuals.start()
	for _, m in CollectionService:GetTagged(Config.Tags.Checkpoint) do
		add(m)
	end
	CollectionService:GetInstanceAddedSignal(Config.Tags.Checkpoint):Connect(add)
	CollectionService:GetInstanceRemovedSignal(Config.Tags.Checkpoint):Connect(function(m)
		local index = m:GetAttribute(Config.Attr.CheckpointIndex)
		if index and models[index] == m then
			models[index] = nil
		end
	end)
	player:GetAttributeChangedSignal(Config.Attr.Checkpoint):Connect(refresh)
	-- cristal atual girando e flutuando de leve
	RunService.RenderStepped:Connect(function()
		if currentCrystal and crystalHome and currentCrystal.Parent then
			local t = os.clock()
			currentCrystal.CFrame = crystalHome * CFrame.new(0, math.sin(t * 2) * 0.25, 0) * CFrame.Angles(0, t * 1.4, 0)
		end
	end)
end

return CheckpointVisuals
