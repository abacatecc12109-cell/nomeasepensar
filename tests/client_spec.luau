--!nocheck
-- Teste do cliente: servidor + cliente na simulação, quadros simulados.

local ServerScriptService = game:GetService("ServerScriptService")
local StarterPlayer = game:GetService("StarterPlayer")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local CollectionService = game:GetService("CollectionService")
local UserInputService = game:GetService("UserInputService")

runScript(ServerScriptService.Server.Main)
for _ = 1, 5000 do -- a construção faz pausas
	Roblox.step(0.1)
	local info = game:GetService("ReplicatedStorage"):FindFirstChild("CourseInfo")
	if info and info:GetAttribute("Ready") then
		break
	end
end
Roblox.step(0.1)
local player = Roblox.addPlayer("Cliente", 7)
Roblox.step(0.1)
Players.__props.LocalPlayer = player
Roblox.isServer = false

local function frames(n, dt)
	for _ = 1, n do
		Roblox.step(dt)
		RunService.PreSimulation:Fire(dt)
		RunService.Heartbeat:Fire(dt)
		RunService.RenderStepped:Fire(dt)
	end
end

describe("cliente", function()
	it("inicia todos os controladores", function()
		local co = runScript(StarterPlayer.StarterPlayerScripts.Client.Main)
		Roblox.step(0.1)
		expect(coroutine.status(co) == "dead", "o script do cliente não terminou de iniciar")
		expect(player.PlayerGui:FindFirstChild("HUD"), "HUD não criada")
	end)

	it("todos os minigames rodam sem erro", function()
		local MC = require(StarterPlayer.StarterPlayerScripts.Client.Controllers.MinigameController)
		local n = 0
		for kind in MC.Games do
			n += 1
			for _, level in { 1, 32, 63 } do
				local cf = CFrame.new(0, 900, 0)
				local g = MC.newGame(kind, level, cf, 9000 + n)
				for i = 1, 400 do
					MC.tick(g, 1 / 15, cf * Vector3.new(math.sin(i / 9) * 8, (i % 20 < 8) and 5 or 3, 2 + math.cos(i / 7) * 8))
				end
				g.folder:Destroy()
			end
		end
		expect(n == 18, "deveriam ser 18 minigames: " .. n)
		local used = {}
		for _, m in CollectionService:GetTagged("Minigame") do
			expect(MC.Games[m:GetAttribute("MiniKind")], "minigame inexistente")
			used[m:GetAttribute("MiniKind")] = true
		end
		for kind in MC.Games do
			expect(used[kind], string.format("minigame nunca usado: %s (%d ilhas)", kind, #CollectionService:GetTagged("Minigame")))
		end
		expect(#CollectionService:GetTagged("Minigame") == #CollectionService:GetTagged("MiniGate"), "ilha sem ponte")
	end)

	it("move as plataformas e passa a velocidade ao jogador", function()
		local m = CollectionService:GetTagged("MovingPlatform")[1]
		local root = player.Character.HumanoidRootPart
		player.Character:PivotTo(CFrame.new(m:GetAttribute("PointA") + Vector3.new(0, 4, 0)))
		local before = m.PrimaryPart.Position
		frames(90, 1 / 30)
		local after = m.PrimaryPart.Position
		expect((after - before).Magnitude > 0.5, "a plataforma não se moveu")
		local a, b = m:GetAttribute("PointA"), m:GetAttribute("PointB")
		local travel = (b - a).Magnitude
		expect((after - a).Magnitude <= travel + 0.01, "plataforma saiu do trajeto")
		local v = m.PrimaryPart.AssemblyLinearVelocity.Magnitude
		expect(v < travel * 2, "velocidade irreal: " .. v)
	end)

	it("tábua frágil cai e volta", function()
		local plank = CollectionService:GetTagged("CollapsingPlank")[1]
		local home = plank.CFrame
		local old = Roblox.methods.Raycast
		Roblox.methods.Raycast = function()
			return { Instance = plank, Position = plank.Position }
		end
		frames(2, 1 / 30)
		Roblox.methods.Raycast = old
		frames(20, 1 / 30) -- passa o atraso (0.45s)
		expect(plank.CanCollide == false, "a tábua não caiu")
		frames(120, 1 / 30) -- passa o tempo de volta (3.5s)
		expect(plank.CanCollide == true and (plank.Position - home.Position).Magnitude < 0.01, "a tábua não voltou")
	end)

	it("tronco balançando empurra o jogador", function()
		local log = CollectionService:GetTagged("SwingingLog")[1]
		local pivot = log:GetAttribute("Pivot")
		local root = player.Character.HumanoidRootPart
		local hit = false
		for _ = 1, 200 do
			local center = (log.PrimaryPart.Position)
			player.Character:PivotTo(CFrame.new(center))
			root.AssemblyLinearVelocity = Vector3.zero
			frames(1, 1 / 30)
			if root.AssemblyLinearVelocity.Magnitude > 20 then
				hit = true
				break
			end
		end
		expect(hit, "o tronco não empurrou ninguém")
	end)

	it("HUD mostra altura, região e checkpoint", function()
		local ui = player.PlayerGui.HUD
		local cp = CollectionService:GetTagged("Checkpoint")
		player.Character:PivotTo(CFrame.new(0, 120, 0))
		frames(6, 1 / 30)
		local text = ui.InfoCard.Height.Text
		expect(string.find(text, "Altura: 1%d%d m") ~= nil, "altura errada: " .. text)
		expect(ui.InfoCard.Region.Text == "Penhascos Verdes", "região errada: " .. ui.InfoCard.Region.Text)
		expect(string.find(ui.InfoCard.Checkpoint.Text, "Checkpoint 1/80") ~= nil, ui.InfoCard.Checkpoint.Text)
		expect(string.find(ui.Timer.Time.Text, "^%d+:%d%d%.%d%d$") ~= nil, "cronômetro: " .. ui.Timer.Time.Text)
	end)

	it("tela de chegada aparece e o botão reinicia", function()
		local ui = player.PlayerGui.HUD
		ReplicatedStorage.Remotes.RunFinished.OnClientEvent:Fire(125.4, 125.4, true)
		expect(ui.Finish.Visible, "tela de chegada não apareceu")
		expect(ui.Finish.Time.Text == "2:05.40", ui.Finish.Time.Text)
		Roblox.localPlayer = player
		ui.Finish.Restart.Activated:Fire()
		expect(not ui.Finish.Visible, "tela não fechou")
	end)

	it("checkpoint atual (só a estrela) fica rosa e brilhando", function()
		player:SetAttribute("Checkpoint", 2)
		frames(1, 1 / 30)
		local m
		for _, c in CollectionService:GetTagged("Checkpoint") do
			if c:GetAttribute("CheckpointIndex") == 2 then
				m = c
			end
		end
		expect(m.Crystal.Glow.Brightness > 0, "sem brilho")
		expect(m.Crystal.Color == Color3.fromRGB(255, 150, 190), "não mudou de cor")
		expect(m:FindFirstChild("Banner") == nil and m:FindFirstChild("Ring") == nil, "checkpoint deveria ter só a estrela")
	end)

	it("céu em degradê amarelo → laranja → rosa e um sol", function()
		local sky = require(StarterPlayer.StarterPlayerScripts.Client.Controllers.SkyController)
		local horizon, middle, top = sky.colorAt(1), sky.colorAt(22), sky.colorAt(70)
		-- amarelo: muito vermelho e verde, pouco azul
		expect(horizon.R > 0.95 and horizon.G > 0.85 and horizon.B < 0.6, "horizonte deveria ser amarelo")
		-- laranja: verde médio
		expect(middle.R > 0.95 and middle.G > 0.55 and middle.G < 0.75 and middle.B < 0.5, "meio deveria ser laranja")
		-- rosa claro: azul alto
		expect(top.R > 0.95 and top.B > 0.78 and top.G > 0.75, "topo deveria ser rosa claro")
		expect(sky.dome and #sky.dome:GetChildren() > 100, "cúpula do céu não foi montada")
		frames(2, 1 / 30)
		local cam = workspace.CurrentCamera.CFrame.Position
		local sun = sky.sun.PrimaryPart.Position
		expect((sun - cam).Magnitude > 1000, "sol perto demais")
		expect(sun.Y > cam.Y, "sol abaixo do horizonte")
		local Lighting = game:GetService("Lighting")
		expect(Lighting.Sky.CelestialBodiesShown == false, "o céu padrão não deveria mostrar outro sol")
		expect(workspace.Terrain.Clouds.Cover < 0.05, "nuvens volumétricas deveriam estar desligadas (poucas nuvens)")
		local n = #workspace.Mundo.Cenario.Ceu:GetChildren()
		expect(n >= 4 and n <= 12, "deveria ter poucas nuvens no céu: " .. n)
	end)

	it("ambientação sonora troca com a região", function()
		local sound = require(StarterPlayer.StarterPlayerScripts.Client.Controllers.SoundController)
		local SoundService = game:GetService("SoundService")
		expect(SoundService:FindFirstChild("Ambiente"), "sem SoundGroup")
		expect(sound.music and sound.music.SoundId ~= "", "sem trilha")
		sound.setRegion(6)
		expect(sound.currentRegion() == 6, "não trocou de região")
		local playing = 0
		for _, s in SoundService.SomDeFundo:GetChildren() do
			if string.find(s.Name, "Regiao6") then
				playing += 1
				expect(string.find(s.SoundId, "^rbxassetid://%d+$") ~= nil, "id de som inválido: " .. s.SoundId)
			end
		end
		expect(playing == 2, "região 6 deveria ter 2 loops: " .. playing)
		-- cachoeiras ganham som 3D
		local sheet = CollectionService:GetTagged("Waterfall")[1]
		expect(sheet:FindFirstChild("Agua"), "cachoeira sem som")
		-- botão de som
		sound.button.Activated:Fire()
		expect(sound.muted and SoundService.Ambiente.Volume == 0, "não silenciou")
		sound.button.Activated:Fire()
		expect(not sound.muted and SoundService.Ambiente.Volume == 1, "não voltou o som")
	end)

	it("pássaros e borboletas dão vida à paisagem", function()
		local life = require(StarterPlayer.StarterPlayerScripts.Client.Controllers.LifeController)
		expect(#life.flocks >= 3, "poucos bandos")
		local b = life.flocks[1].birds[1]
		local before = b.body.Position
		frames(10, 1 / 30)
		expect(#life.butterflies > 0, "sem borboletas")
		expect(b.body.Position ~= nil, "pássaro sem posição")
		local _ = before
	end)

	it("escala a interface em tela de celular", function()
		local cam = workspace.CurrentCamera
		local hud = require(StarterPlayer.StarterPlayerScripts.Client.Controllers.HUDController)
		-- celular deitado (844x390)
		cam.ViewportSize = Vector2.new(844, 390)
		local scale = hud.ui.scale.Scale
		expect(math.abs(scale - 0.62) < 0.01, "escala no celular deitado: " .. scale)
		-- celular em pé (390x844): esconde o recorde para caber
		cam.ViewportSize = Vector2.new(390, 844)
		expect(hud.ui.best.Visible == false, "recorde deveria sumir em tela estreita")
		-- monitor grande
		cam.ViewportSize = Vector2.new(1920, 1080)
		expect(hud.ui.scale.Scale > 1, "escala no monitor: " .. hud.ui.scale.Scale)
		expect(hud.ui.best.Visible, "recorde deveria aparecer no PC")
	end)
end)
