--[[
	SoundController (cliente)
	-------------------------
	Ambientação sonora do jogo:
	  * fundo de cada região (dois loops misturados: pássaros, vento nas
	    folhas, riacho, insetos da floresta, sinos de vento, brilho mágico
	    nas nuvens) com troca suave quando o jogador muda de região;
	  * trilha calma bem baixinha, tocando em sequência;
	  * som 3D nas cachoeiras (fica mais alto quando se chega perto);
	  * efeitos: checkpoint, nova região, chegada, queda, tábua rangendo e
	    nuvem se desfazendo;
	  * botão para ligar/desligar o som (canto superior direito).

	Os números dos áudios ficam em Config.Sounds.
]]

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local SoundService = game:GetService("SoundService")
local TweenService = game:GetService("TweenService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Remotes = require(Shared.Remotes)

local SoundController = {}
local S = Config.Sounds
local player = Players.LocalPlayer

local FADE = TweenInfo.new(3, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut)

local group: SoundGroup
local ambienceFolder: Folder
local layers = {} -- [regionIndex] = { Sound, ... }
local currentRegion = 0
SoundController.muted = false

local function makeSound(entry, parent: Instance, looped: boolean, name: string): Sound
	local sound = Instance.new("Sound")
	sound.Name = name
	sound.SoundId = entry[1]
	sound.Volume = entry[2]
	sound.Looped = looped
	sound.SoundGroup = group
	sound:SetAttribute("BaseVolume", entry[2])
	sound.Parent = parent
	return sound
end

-- Toca um efeito curto (2D, ou 3D se `at` for uma peça)
function SoundController.play(entry, at: Instance?)
	if not entry then
		return
	end
	local sound = makeSound(entry, at or SoundService, false, "Efeito")
	if at then
		sound.RollOffMinDistance = 8
		sound.RollOffMaxDistance = 90
	end
	sound:Play()
	task.delay(8, function()
		sound:Destroy()
	end)
	return sound
end

local function regionLayers(index: number)
	local list = layers[index]
	if list then
		return list
	end
	list = {}
	for i, entry in S.Ambience[index] or {} do
		local sound = makeSound(entry, ambienceFolder, true, string.format("Regiao%d_%d", index, i))
		sound.Volume = 0
		table.insert(list, sound)
	end
	layers[index] = list
	return list
end

-- Troca suave do som de fundo para a região `index`
function SoundController.setRegion(index: number)
	if index == currentRegion then
		return
	end
	local previous = currentRegion
	local old = layers[previous]
	if old then
		for _, sound in old do
			TweenService:Create(sound, FADE, { Volume = 0 }):Play()
			task.delay(3.2, function()
				-- só para se o jogador não voltou para aquela região
				if currentRegion ~= previous then
					sound:Stop()
				end
			end)
		end
	end
	if currentRegion ~= 0 then
		SoundController.play(S.NewRegion)
	end
	currentRegion = index
	for _, sound in regionLayers(index) do
		if not sound.IsPlaying then
			sound:Play()
		end
		TweenService:Create(sound, FADE, { Volume = sound:GetAttribute("BaseVolume") or 0.3 }):Play()
	end
end

function SoundController.currentRegion(): number
	return currentRegion
end

-- Trilha em sequência
local function startMusic()
	if not S.Music or #S.Music == 0 then
		return
	end
	local music = Instance.new("Sound")
	music.Name = "Trilha"
	music.Looped = false
	music.SoundGroup = group
	music.Parent = SoundService
	SoundController.music = music
	local track = 0
	local function nextTrack()
		track = track % #S.Music + 1
		music.SoundId = S.Music[track][1]
		music.Volume = S.Music[track][2]
		music.TimePosition = 0
		music:Play()
	end
	pcall(function()
		music.Ended:Connect(nextTrack)
	end)
	nextTrack()
end

-- Cachoeiras: loop 3D preso na lâmina d'água
local function addWaterfall(sheet: Instance)
	if not sheet:IsA("BasePart") or sheet:FindFirstChild("Agua") then
		return
	end
	local sound = makeSound(S.Waterfall, sheet, true, "Agua")
	sound.RollOffMode = Enum.RollOffMode.InverseTapered
	sound.RollOffMinDistance = 14
	sound.RollOffMaxDistance = 150
	sound:Play()
end

-- Botão de som (liga/desliga)
local function buildToggle()
	local gui = Instance.new("ScreenGui")
	gui.Name = "Som"
	gui.ResetOnSpawn = false
	gui.ScreenInsets = Enum.ScreenInsets.CoreUISafeInsets
	gui.DisplayOrder = 5
	local button = Instance.new("TextButton")
	button.Name = "Toggle"
	button.AnchorPoint = Vector2.new(1, 0)
	button.Position = UDim2.new(1, -12, 0, 10)
	button.Size = UDim2.fromOffset(44, 44)
	button.BackgroundColor3 = Color3.fromRGB(255, 248, 250)
	button.BackgroundTransparency = 0.08
	button.Text = "🔊"
	button.TextSize = 22
	button.Font = Enum.Font.GothamBold
	button.AutoButtonColor = true
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(1, 0)
	c.Parent = button
	local stroke = Instance.new("UIStroke")
	stroke.Color = Color3.fromRGB(240, 170, 150)
	stroke.Thickness = 2
	stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	stroke.Parent = button
	button.Parent = gui
	button.Activated:Connect(function()
		SoundController.setMuted(not SoundController.muted)
	end)
	gui.Parent = player:WaitForChild("PlayerGui")
	SoundController.button = button
end

function SoundController.setMuted(muted: boolean)
	SoundController.muted = muted
	group.Volume = muted and 0 or 1
	if SoundController.button then
		SoundController.button.Text = muted and "🔇" or "🔊"
	end
end

function SoundController.start(ambient, obstacles)
	group = Instance.new("SoundGroup")
	group.Name = "Ambiente"
	group.Volume = 1
	group.Parent = SoundService
	ambienceFolder = Instance.new("Folder")
	ambienceFolder.Name = "SomDeFundo"
	ambienceFolder.Parent = SoundService

	buildToggle()
	startMusic()

	-- som de fundo acompanha a região (AmbientController detecta pela altura)
	if ambient then
		ambient.onRegionChanged(function(index: number)
			SoundController.setRegion(index)
		end)
		if ambient.currentRegion and ambient.currentRegion > 0 then
			SoundController.setRegion(ambient.currentRegion)
		end
	end
	if currentRegion == 0 then
		SoundController.setRegion(1)
	end

	for _, sheet in CollectionService:GetTagged(Config.Tags.Waterfall) do
		addWaterfall(sheet)
	end
	CollectionService:GetInstanceAddedSignal(Config.Tags.Waterfall):Connect(addWaterfall)

	-- tábuas rangem, nuvens fazem "puf" ao se desfazer
	if obstacles and obstacles.collapseListeners then
		table.insert(obstacles.collapseListeners, function(part: BasePart)
			local cloud = part:FindFirstChild("Puff", true) ~= nil
			SoundController.play(cloud and S.CloudPuff or S.PlankCreak, part)
		end)
	end

	local remotes = Remotes.get()
	remotes.CheckpointReached.OnClientEvent:Connect(function(_index: number, _label: string?, isFinish: boolean?)
		SoundController.play(isFinish and S.Finish or S.Checkpoint)
	end)
	remotes.FallReset.OnClientEvent:Connect(function()
		SoundController.play(S.FallReset)
	end)
end

return SoundController
