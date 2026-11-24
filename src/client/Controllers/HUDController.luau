--[[
	HUDController (cliente)
	-----------------------
	Interface simples e bonita:
	  * cartão (canto superior esquerdo): região atual, altura real, checkpoint
	  * cronômetro (topo, centro) com recorde da sessão
	  * medidor vertical de subida (direita) com as 5 regiões, posição atual
	    e altura máxima alcançada
	  * avisos: checkpoint alcançado, nova região, anúncios
	  * tela de chegada com tempo, recorde e botão para recomeçar

	Escala automaticamente pelo tamanho da tela (UIScale) e respeita as
	áreas seguras do celular (ScreenInsets), longe do analógico e do pulo.
]]

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Regions = require(Shared.Regions)
local Remotes = require(Shared.Remotes)

local HUDController = {}
local player = Players.LocalPlayer
local A = Config.Attr

local TITLE_FONT = Enum.Font.FredokaOne
local BODY_FONT = Enum.Font.GothamMedium
local BOLD_FONT = Enum.Font.GothamBold

local CARD_BG = Color3.fromRGB(255, 248, 250)
local INK = Color3.fromRGB(78, 58, 72)
local INK_SOFT = Color3.fromRGB(132, 108, 124)

-- ===================================================================
-- Pequenos construtores de GUI
-- ===================================================================

local function new(className: string, props, children)
	local obj = Instance.new(className)
	for k, v in props do
		if k ~= "Parent" then
			(obj :: any)[k] = v
		end
	end
	for _, child in children or {} do
		child.Parent = obj
	end
	if props.Parent then
		obj.Parent = props.Parent
	end
	return obj
end

local function corner(radius: number)
	return new("UICorner", { CornerRadius = UDim.new(0, radius) })
end

local function stroke(color: Color3, thickness: number, transparency: number?)
	return new("UIStroke", { Color = color, Thickness = thickness, Transparency = transparency or 0, ApplyStrokeMode = Enum.ApplyStrokeMode.Border })
end

local function label(props)
	props.BackgroundTransparency = 1
	props.TextColor3 = props.TextColor3 or INK
	props.Font = props.Font or BODY_FONT
	props.TextXAlignment = props.TextXAlignment or Enum.TextXAlignment.Left
	return new("TextLabel", props)
end

function HUDController.formatTime(seconds: number): string
	if seconds < 0 then
		seconds = 0
	end
	local m = math.floor(seconds / 60)
	local s = seconds - m * 60
	return string.format("%d:%05.2f", m, s)
end

-- ===================================================================
-- Construção
-- ===================================================================

local ui = {}

local function build()
	local gui = new("ScreenGui", {
		Name = "HUD",
		ResetOnSpawn = false,
		IgnoreGuiInset = false,
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
		ScreenInsets = Enum.ScreenInsets.CoreUISafeInsets,
	})
	ui.gui = gui
	ui.scale = new("UIScale", { Parent = gui })

	-- Cartão de informações -------------------------------------------
	local card = new("Frame", {
		Name = "InfoCard",
		Position = UDim2.new(0, 12, 0, 10),
		Size = UDim2.fromOffset(280, 104),
		BackgroundColor3 = CARD_BG,
		BackgroundTransparency = 0.12,
		Parent = gui,
	}, { corner(14), stroke(Color3.fromRGB(246, 196, 214), 2, 0.2) })
	ui.accent = new("Frame", {
		Name = "Accent",
		Position = UDim2.fromOffset(12, 16),
		Size = UDim2.fromOffset(12, 12),
		BackgroundColor3 = Regions[1].Accent,
		Parent = card,
	}, { corner(6) })
	ui.region = label({ Name = "Region", Position = UDim2.fromOffset(32, 7), Size = UDim2.new(1, -40, 0, 30), Font = TITLE_FONT, TextSize = 22, Text = Regions[1].Name, TextTruncate = Enum.TextTruncate.AtEnd, Parent = card })
	ui.height = label({ Name = "Height", Position = UDim2.fromOffset(14, 38), Size = UDim2.new(1, -28, 0, 26), Font = BOLD_FONT, TextSize = 20, Text = "Altura: 0 m", Parent = card })
	ui.checkpoint = label({ Name = "Checkpoint", Position = UDim2.fromOffset(14, 66), Size = UDim2.new(1, -28, 0, 22), TextSize = 15, TextColor3 = INK_SOFT, Text = "Checkpoint 1", TextTruncate = Enum.TextTruncate.AtEnd, Parent = card })
	ui.card = card

	-- Cronômetro -------------------------------------------------------
	local timer = new("Frame", {
		Name = "Timer",
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 10),
		Size = UDim2.fromOffset(190, 54),
		BackgroundColor3 = CARD_BG,
		BackgroundTransparency = 0.12,
		Parent = gui,
	}, { corner(27), stroke(Color3.fromRGB(246, 196, 214), 2, 0.2) })
	ui.time = label({ Name = "Time", Size = UDim2.new(1, 0, 0, 34), Position = UDim2.fromOffset(0, 3), Font = TITLE_FONT, TextSize = 28, Text = "0:00.00", TextXAlignment = Enum.TextXAlignment.Center, Parent = timer })
	ui.best = label({ Name = "Best", Size = UDim2.new(1, 0, 0, 16), Position = UDim2.fromOffset(0, 34), TextSize = 13, TextColor3 = INK_SOFT, Text = "Recorde: --", TextXAlignment = Enum.TextXAlignment.Center, Parent = timer })

	-- Medidor vertical de subida ----------------------------------------
	local meter = new("Frame", {
		Name = "ClimbMeter",
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, -14, 0.42, 0),
		Size = UDim2.new(0, 64, 0.5, 0),
		BackgroundTransparency = 1,
		Parent = gui,
	})
	local track = new("Frame", {
		Name = "Track",
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, 0, 0, 0),
		Size = UDim2.new(0, 14, 1, 0),
		BackgroundColor3 = CARD_BG,
		BackgroundTransparency = 0.2,
		ClipsDescendants = false,
		Parent = meter,
	}, { corner(7), stroke(Color3.fromRGB(246, 196, 214), 2, 0.2) })
	ui.track = track
	ui.fill = new("Frame", {
		Name = "Fill",
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.new(0, 0, 1, 0),
		Size = UDim2.new(1, 0, 0, 0),
		BackgroundColor3 = Regions[1].Accent,
		Parent = track,
	}, { corner(7) })
	ui.maxTick = new("Frame", {
		Name = "MaxTick",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.new(0.5, 0, 1, 0),
		Size = UDim2.new(1, 8, 0, 3),
		BackgroundColor3 = Color3.fromRGB(255, 214, 150),
		Parent = track,
	}, { corner(2) })
	ui.marker = new("Frame", {
		Name = "Marker",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.new(0.5, 0, 1, 0),
		Size = UDim2.fromOffset(24, 24),
		BackgroundColor3 = Color3.fromRGB(255, 255, 255),
		ZIndex = 3,
		Parent = track,
	}, { corner(12), stroke(Color3.fromRGB(236, 132, 172), 3) })
	ui.percent = label({ Name = "Percent", AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, 6, 1, 6), Size = UDim2.fromOffset(70, 20), Font = BOLD_FONT, TextSize = 15, Text = "0%", TextXAlignment = Enum.TextXAlignment.Right, TextStrokeTransparency = 0.6, TextStrokeColor3 = Color3.fromRGB(255, 255, 255), Parent = meter })
	ui.regionTicks = {}
	ui.meter = meter

	-- Avisos -----------------------------------------------------------
	ui.toast = new("TextLabel", {
		Name = "Toast",
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 74),
		Size = UDim2.fromOffset(360, 40),
		BackgroundColor3 = Color3.fromRGB(255, 150, 190),
		BackgroundTransparency = 1,
		TextTransparency = 1,
		TextColor3 = Color3.fromRGB(255, 255, 255),
		Font = BOLD_FONT,
		TextSize = 18,
		Text = "",
		Parent = gui,
	}, { corner(20) })
	ui.banner = new("Frame", {
		Name = "RegionBanner",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.new(0.5, 0, 0.3, 0),
		Size = UDim2.fromOffset(560, 110),
		BackgroundTransparency = 1,
		Parent = gui,
	})
	ui.bannerTitle = label({ Name = "Title", Size = UDim2.new(1, 0, 0, 64), Font = TITLE_FONT, TextSize = 50, TextColor3 = Color3.fromRGB(255, 255, 255), TextStrokeColor3 = Color3.fromRGB(150, 90, 120), TextStrokeTransparency = 1, TextTransparency = 1, TextXAlignment = Enum.TextXAlignment.Center, Text = "", Parent = ui.banner })
	ui.bannerSub = label({ Name = "Subtitle", Position = UDim2.fromOffset(0, 62), Size = UDim2.new(1, 0, 0, 30), Font = BOLD_FONT, TextSize = 22, TextColor3 = Color3.fromRGB(255, 255, 255), TextStrokeColor3 = Color3.fromRGB(150, 90, 120), TextStrokeTransparency = 1, TextTransparency = 1, TextXAlignment = Enum.TextXAlignment.Center, Text = "", Parent = ui.banner })
	ui.feed = new("Frame", {
		Name = "Feed",
		Position = UDim2.new(0, 12, 0, 122),
		Size = UDim2.fromOffset(300, 120),
		BackgroundTransparency = 1,
		Parent = gui,
	}, { new("UIListLayout", { Padding = UDim.new(0, 4), SortOrder = Enum.SortOrder.LayoutOrder }) })

	-- Tela de transição (queda) ------------------------------------------
	ui.fade = new("Frame", {
		Name = "Fade",
		Size = UDim2.fromScale(1, 1),
		Position = UDim2.fromScale(0, 0),
		BackgroundColor3 = Color3.fromRGB(255, 236, 244),
		BackgroundTransparency = 1,
		ZIndex = 20,
		Parent = gui,
	})

	-- Tela de chegada --------------------------------------------------
	local finish = new("Frame", {
		Name = "Finish",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(380, 250),
		BackgroundColor3 = CARD_BG,
		BackgroundTransparency = 0.04,
		Visible = false,
		ZIndex = 10,
		Parent = gui,
	}, { corner(22), stroke(Color3.fromRGB(240, 160, 196), 3) })
	label({ Name = "Title", Size = UDim2.new(1, 0, 0, 50), Position = UDim2.fromOffset(0, 14), Font = TITLE_FONT, TextSize = 34, Text = "🌸 Você chegou ao topo! 🌸", TextXAlignment = Enum.TextXAlignment.Center, ZIndex = 11, Parent = finish })
	ui.finishTime = label({ Name = "Time", Size = UDim2.new(1, 0, 0, 44), Position = UDim2.fromOffset(0, 70), Font = TITLE_FONT, TextSize = 40, Text = "0:00.00", TextColor3 = Color3.fromRGB(226, 110, 156), TextXAlignment = Enum.TextXAlignment.Center, ZIndex = 11, Parent = finish })
	ui.finishBest = label({ Name = "Best", Size = UDim2.new(1, 0, 0, 24), Position = UDim2.fromOffset(0, 118), Font = BOLD_FONT, TextSize = 17, TextColor3 = INK_SOFT, Text = "", TextXAlignment = Enum.TextXAlignment.Center, ZIndex = 11, Parent = finish })
	ui.restart = new("TextButton", {
		Name = "Restart",
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.28, 0, 0, 164),
		Size = UDim2.fromOffset(160, 52),
		BackgroundColor3 = Color3.fromRGB(240, 140, 180),
		Font = BOLD_FONT,
		TextSize = 18,
		TextColor3 = Color3.fromRGB(255, 255, 255),
		Text = "Recomeçar",
		ZIndex = 11,
		Parent = finish,
	}, { corner(16) })
	ui.stay = new("TextButton", {
		Name = "Stay",
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.72, 0, 0, 164),
		Size = UDim2.fromOffset(160, 52),
		BackgroundColor3 = Color3.fromRGB(150, 196, 230),
		Font = BOLD_FONT,
		TextSize = 18,
		TextColor3 = Color3.fromRGB(255, 255, 255),
		Text = "Ver a paisagem",
		ZIndex = 11,
		Parent = finish,
	}, { corner(16) })
	ui.finish = finish

	gui.Parent = player:WaitForChild("PlayerGui")
	return gui
end

-- ===================================================================
-- Comportamento
-- ===================================================================

local info
local function courseNumbers()
	local startY = info:GetAttribute("StartY") or 0
	local summitY = info:GetAttribute("SummitY") or 300
	return startY, summitY
end

local function buildRegionTicks()
	local startY, summitY = courseNumbers()
	local count = info:GetAttribute("RegionCount") or #Regions
	for i = 1, count do
		local y = info:GetAttribute("Region" .. i .. "Start") or startY
		local frac = math.clamp((y - startY) / (summitY - startY), 0, 1)
		local tick = new("Frame", {
			Name = "Region" .. i,
			AnchorPoint = Vector2.new(1, 0.5),
			Position = UDim2.new(0, -4, 1 - frac, 0),
			Size = UDim2.fromOffset(10, 10),
			BackgroundColor3 = Regions[i] and Regions[i].Accent or Color3.new(1, 1, 1),
			Parent = ui.track,
		}, { corner(5), stroke(Color3.fromRGB(255, 255, 255), 2) })
		ui.regionTicks[i] = tick
	end
end

local function updateScale()
	local camera = workspace.CurrentCamera
	if not camera then
		return
	end
	local vp = camera.ViewportSize
	local s = math.min(vp.X / 1100, vp.Y / 680)
	ui.scale.Scale = math.clamp(s, 0.62, 1.15)
	-- telas muito estreitas (celular em pé): esconde o recorde do cronômetro
	ui.best.Visible = vp.X >= 520
end

local toastToken = 0
function HUDController.toast(text: string, color: Color3?)
	toastToken += 1
	local token = toastToken
	ui.toast.Text = text
	ui.toast.BackgroundColor3 = color or Color3.fromRGB(240, 140, 180)
	local fadeIn = TweenInfo.new(0.25)
	TweenService:Create(ui.toast, fadeIn, { BackgroundTransparency = 0.1, TextTransparency = 0 }):Play()
	task.delay(2.6, function()
		if token == toastToken then
			TweenService:Create(ui.toast, TweenInfo.new(0.6), { BackgroundTransparency = 1, TextTransparency = 1 }):Play()
		end
	end)
end

local bannerToken = 0
function HUDController.regionBanner(index: number)
	local region = Regions[index]
	if not region then
		return
	end
	bannerToken += 1
	local token = bannerToken
	ui.bannerTitle.Text = region.Name
	ui.bannerSub.Text = string.format("Região %d de %d — %s", index, #Regions, region.Subtitle)
	ui.bannerTitle.TextStrokeColor3 = region.Accent:Lerp(Color3.new(0, 0, 0), 0.35)
	ui.bannerSub.TextStrokeColor3 = ui.bannerTitle.TextStrokeColor3
	local show = TweenInfo.new(0.8, Enum.EasingStyle.Sine)
	for _, l in { ui.bannerTitle, ui.bannerSub } do
		TweenService:Create(l, show, { TextTransparency = 0, TextStrokeTransparency = 0.4 }):Play()
	end
	task.delay(3.4, function()
		if token == bannerToken then
			for _, l in { ui.bannerTitle, ui.bannerSub } do
				TweenService:Create(l, TweenInfo.new(1.2), { TextTransparency = 1, TextStrokeTransparency = 1 }):Play()
			end
		end
	end)
	ui.region.Text = region.Name
	ui.accent.BackgroundColor3 = region.Accent
	ui.fill.BackgroundColor3 = region.Accent
end

function HUDController.announce(text: string)
	local item = label({
		Size = UDim2.new(1, 0, 0, 22),
		TextSize = 14,
		Font = BOLD_FONT,
		TextColor3 = Color3.fromRGB(255, 255, 255),
		TextStrokeTransparency = 0.5,
		TextStrokeColor3 = Color3.fromRGB(120, 70, 100),
		Text = text,
		TextTruncate = Enum.TextTruncate.AtEnd,
		Parent = ui.feed,
	})
	task.delay(7, function()
		TweenService:Create(item, TweenInfo.new(1), { TextTransparency = 1, TextStrokeTransparency = 1 }):Play()
		task.delay(1.1, function()
			item:Destroy()
		end)
	end)
end

local function updateCheckpointText()
	local index = player:GetAttribute(A.Checkpoint) or 1
	local total = info:GetAttribute("CheckpointCount") or 1
	local name = info:GetAttribute("Checkpoint" .. index .. "Label") or ""
	ui.checkpoint.Text = string.format("Checkpoint %d/%d · %s", index, total, name)
end

local function updateBest()
	local best = player:GetAttribute(A.BestTime) or 0
	ui.best.Text = best > 0 and ("Recorde: " .. HUDController.formatTime(best)) or "Recorde: --"
end

local function showFinish(elapsed: number, best: number, newRecord: boolean)
	ui.finishTime.Text = HUDController.formatTime(elapsed)
	ui.finishBest.Text = newRecord and "✨ Novo recorde da sessão! ✨" or ("Recorde: " .. HUDController.formatTime(best))
	ui.finish.Visible = true
	ui.finish.Size = UDim2.fromOffset(320, 210)
	TweenService:Create(ui.finish, TweenInfo.new(0.35, Enum.EasingStyle.Back), { Size = UDim2.fromOffset(380, 250) }):Play()
end

local function fadeFlash()
	ui.fade.BackgroundTransparency = 1
	TweenService:Create(ui.fade, TweenInfo.new(0.15), { BackgroundTransparency = 0.15 }):Play()
	task.delay(0.35, function()
		TweenService:Create(ui.fade, TweenInfo.new(0.5), { BackgroundTransparency = 1 }):Play()
	end)
end

-- Laço de atualização (texto 10x por segundo; marcador suave todo frame)
local function startLoop(regionAt)
	local markerFrac = 0
	local textClock = 0
	local lastRegion = 0
	RunService.RenderStepped:Connect(function(dt)
		local character = player.Character
		local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
		local startY, summitY = courseNumbers()
		local y = root and root.Position.Y or startY
		local frac = math.clamp((y - startY) / (summitY - startY), 0, 1)
		markerFrac += (frac - markerFrac) * math.min(1, dt * 8)
		ui.marker.Position = UDim2.new(0.5, 0, 1 - markerFrac, 0)
		ui.fill.Size = UDim2.new(1, 0, markerFrac, 0)

		textClock += dt
		if textClock < 0.1 then
			return
		end
		textClock = 0
		ui.height.Text = string.format("Altura: %d m", math.max(0, math.floor(y - startY)))
		ui.percent.Text = string.format("%d%%", math.floor(frac * 100 + 0.5))
		local maxY = player:GetAttribute(A.MaxHeight) or 0
		ui.maxTick.Position = UDim2.new(0.5, 0, 1 - math.clamp((maxY - startY) / (summitY - startY), 0, 1), 0)

		local start = player:GetAttribute(A.RunStart)
		local finished = player:GetAttribute(A.RunFinish) or 0
		if finished > 0 then
			ui.time.Text = HUDController.formatTime(finished)
		elseif start then
			ui.time.Text = HUDController.formatTime(workspace:GetServerTimeNow() - start)
		end

		if root then
			local region = regionAt(y)
			if region ~= lastRegion then
				if lastRegion ~= 0 then
					HUDController.regionBanner(region)
				else
					ui.region.Text = Regions[region].Name
					ui.accent.BackgroundColor3 = Regions[region].Accent
					ui.fill.BackgroundColor3 = Regions[region].Accent
				end
				lastRegion = region
			end
		end
	end)
end

function HUDController.start(regionAt)
	info = ReplicatedStorage:WaitForChild("CourseInfo")
	build()
	buildRegionTicks()
	updateScale()
	updateCheckpointText()
	updateBest()
	local camera = workspace.CurrentCamera
	if camera then
		camera:GetPropertyChangedSignal("ViewportSize"):Connect(updateScale)
	end
	player:GetAttributeChangedSignal(A.Checkpoint):Connect(updateCheckpointText)
	player:GetAttributeChangedSignal(A.BestTime):Connect(updateBest)

	local remotes = Remotes.get()
	remotes.CheckpointReached.OnClientEvent:Connect(function(index: number, labelText: string?, isFinish: boolean?)
		if not isFinish then
			HUDController.toast(string.format("✿ Checkpoint %d: %s", index, labelText or ""))
		end
	end)
	remotes.FallReset.OnClientEvent:Connect(function(reason: string)
		fadeFlash()
		if reason == "water" then
			HUDController.toast("A correnteza te levou de volta ao checkpoint", Color3.fromRGB(120, 176, 220))
		elseif reason == "restart" then
			ui.finish.Visible = false
			HUDController.toast("Uma nova subida começa!", Color3.fromRGB(150, 200, 140))
		end
	end)
	remotes.RunFinished.OnClientEvent:Connect(showFinish)
	remotes.Announcement.OnClientEvent:Connect(HUDController.announce)
	ui.restart.Activated:Connect(function()
		ui.finish.Visible = false
		remotes.RequestRestart:FireServer()
	end)
	ui.stay.Activated:Connect(function()
		ui.finish.Visible = false
	end)
	startLoop(regionAt)
end

HUDController.ui = ui
return HUDController
