--!nocheck
-- Teste de integração: executa o script real do servidor na simulação,
-- constrói o mundo inteiro e simula um jogador subindo até o topo.

local ServerScriptService = game:GetService("ServerScriptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local CollectionService = game:GetService("CollectionService")
local Config = require(ReplicatedStorage.Shared.Config)

local mainScript = ServerScriptService.Server.Main

describe("servidor", function()
	it("constrói o mundo sem erros", function()
		local co = runScript(mainScript)
		-- a construção faz pausas: avança até o mundo ficar pronto
		for _ = 1, 5000 do
			local info = ReplicatedStorage:FindFirstChild("CourseInfo")
			if info and info:GetAttribute("Ready") then
				break
			end
			Roblox.step(0.1)
		end
		Roblox.step(0.1)
		expect(coroutine.status(co) == "dead" or coroutine.status(co) == "suspended", "script do servidor travou")
		expect(workspace:FindFirstChild("Mundo"), "pasta Mundo não foi criada")
		log(string.format("%d partes criadas, %d chamadas de Terrain", Roblox.stats.parts, Roblox.stats.terrainCalls))
		for _, w in Roblox.warnings or {} do
			log("aviso: " .. w)
		end
		expect(#(Roblox.warnings or {}) == 0, "o servidor emitiu avisos")
	end)

	it("respeita o orçamento de partes para celular", function()
		-- partes por pasta (ajuda a achar o que pesa)
		for _, folder in workspace.Mundo:GetChildren() do
			for _, sub in folder:GetChildren() do
				local n = 0
				for _, d in sub:GetDescendants() do
					if d:IsA("BasePart") then
						n += 1
					end
				end
				if n > 300 then
					log(string.format("%s/%s: %d partes", folder.Name, sub.Name, n))
				end
			end
		end
		expect(Roblox.stats.parts < 16000, "partes demais: " .. Roblox.stats.parts)
	end)

	it("publica as informações do percurso", function()
		local info = ReplicatedStorage:FindFirstChild("CourseInfo")
		expect(info and info:GetAttribute("Ready"), "CourseInfo ausente")
		expect(info:GetAttribute("RegionCount") == 7, "deveria ter 7 regiões")
		expect(info:GetAttribute("CheckpointCount") == 80, "deveria ter 80 fases")
		for i = 2, 7 do
			expect(info:GetAttribute("Region" .. i .. "Start") > info:GetAttribute("Region" .. (i - 1) .. "Start"), "regiões fora de ordem")
		end
		log(string.format("topo a %.0f studs, %d checkpoints", info:GetAttribute("SummitY"), info:GetAttribute("CheckpointCount")))
	end)

	it("marca obstáculos dinâmicos para o cliente", function()
		for _, tag in { "MovingPlatform", "CollapsingPlank", "FallingStone", "SwingingLog", "WaterfallGust", "Checkpoint", "Spin" } do
			local n = #CollectionService:GetTagged(tag)
			log(tag .. ": " .. n)
			expect(n > 0, "nenhum objeto com a tag " .. tag)
		end
		for _, m in CollectionService:GetTagged("MovingPlatform") do
			expect(m.PrimaryPart and m:GetAttribute("PointA") and m:GetAttribute("PointB") and m:GetAttribute("Period"), "plataforma móvel incompleta")
		end
		for _, m in CollectionService:GetTagged("SwingingLog") do
			expect(typeof(m:GetAttribute("Pivot")) == "CFrame", "tronco sem pivô")
		end
	end)

	it("as escaladas têm treliças", function()
		local n = 0
		for _, d in workspace.Mundo:GetDescendants() do
			if d.ClassName == "TrussPart" then
				n += 1
			end
		end
		expect(n >= 10, "poucas treliças: " .. n)
	end)
end)

describe("jogador", function()
	local player
	local checkpoints = {}
	for _, m in CollectionService:GetTagged("Checkpoint") do
		checkpoints[m:GetAttribute("CheckpointIndex")] = m
	end

	it("nasce no primeiro checkpoint", function()
		player = Roblox.addPlayer("Tester", 1)
		Roblox.step(0.1)
		expect(player:GetAttribute("Checkpoint") == 1, "checkpoint inicial errado")
		expect(player:FindFirstChild("leaderstats"), "sem leaderstats")
		local root = player.Character.HumanoidRootPart
		local cp1 = checkpoints[1]:GetAttribute("SpawnCFrame").Position
		expect((root.Position - cp1).Magnitude < 1, "não nasceu no checkpoint 1")
	end)

	it("avança ao tocar checkpoints, em ordem", function()
		local root = player.Character.HumanoidRootPart
		checkpoints[3].Trigger.Touched:Fire(root)
		expect(player:GetAttribute("Checkpoint") == 3, "não avançou para 3")
		checkpoints[2].Trigger.Touched:Fire(root)
		expect(player:GetAttribute("Checkpoint") == 3, "voltou para um checkpoint anterior")
		expect(player.leaderstats.Etapa.Value == 3, "leaderstats não atualizou")
	end)

	it("volta ao checkpoint ao cair", function()
		local root = player.Character.HumanoidRootPart
		local cp = checkpoints[3]:GetAttribute("SpawnCFrame").Position
		player.Character:PivotTo(CFrame.new(cp - Vector3.new(0, Config.FallResetDepth + 5, 0)))
		Roblox.step(0.3)
		Roblox.step(0.3)
		expect((root.Position - cp).Magnitude < 1, "não voltou ao checkpoint após a queda")
	end)

	it("renasce no checkpoint depois de morrer", function()
		Roblox.spawnCharacter(player)
		Roblox.step(0.1)
		local cp = checkpoints[3]:GetAttribute("SpawnCFrame").Position
		expect((player.Character.HumanoidRootPart.Position - cp).Magnitude < 1, "renasceu no lugar errado")
	end)

	it("registra a chegada e o recorde", function()
		Roblox.step(42)
		local root = player.Character.HumanoidRootPart
		local last = #checkpoints
		checkpoints[last].Trigger.Touched:Fire(root)
		expect(player:GetAttribute("Checkpoint") == last, "não marcou a chegada")
		local t = player:GetAttribute("RunFinish")
		expect(t and t > 40, "tempo final não registrado: " .. tostring(t))
		expect(player:GetAttribute("BestTime") == t, "recorde não registrado")
		log("tempo simulado: " .. string.format("%.1f", t))
	end)

	it("reinicia a subida quando pede", function()
		Roblox.localPlayer = player
		ReplicatedStorage.Remotes.RequestRestart:FireServer()
		Roblox.step(0.3)
		expect(player:GetAttribute("Checkpoint") == 1, "não voltou ao início")
		expect(player:GetAttribute("RunFinish") == 0, "tempo não zerou")
		expect(player:GetAttribute("BestTime") > 0, "perdeu o recorde")
	end)

	it("mantém o progresso ao sair e voltar no mesmo servidor", function()
		checkpoints[4].Trigger.Touched:Fire(player.Character.HumanoidRootPart)
		Players.PlayerRemoving:Fire(player)
		local again = Roblox.addPlayer("Tester", 1)
		Roblox.step(0.1)
		expect(again:GetAttribute("Checkpoint") == 4, "progresso da sessão perdido")
	end)
end)
