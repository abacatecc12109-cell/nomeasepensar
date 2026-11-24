--[[
	MinigameController (cliente)
	----------------------------
	Minigames das ilhas do céu. A ilha vem marcada pelo servidor (tag "Minigame")
	e a ponte de saída (tag "MiniGate") só fica sólida depois que ESTE jogador
	vence. Tudo é montado localmente na ilha atual e apagado ao sair.

	Cada minigame recebe `g` (estado) e devolve uma função step(dt, pos, entrou):
	  pos    = posição do jogador na ilha (x lateral, z avanço), ou nil se está fora
	  g.k    = dificuldade 0..1
]]

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Config = require(Shared.Config)

local MinigameController = {}
local player = Players.LocalPlayer
local rng = Random.new()

local COLORS = {
	{ "VERMELHO", Color3.fromRGB(232, 92, 92) },
	{ "AZUL", Color3.fromRGB(92, 140, 236) },
	{ "VERDE", Color3.fromRGB(98, 196, 110) },
	{ "AMARELO", Color3.fromRGB(246, 212, 92) },
	{ "ROXO", Color3.fromRGB(172, 112, 226) },
	{ "LARANJA", Color3.fromRGB(244, 152, 72) },
	{ "ROSA", Color3.fromRGB(248, 150, 196) },
	{ "BRANCO", Color3.fromRGB(246, 246, 250) },
}
local OFF = Color3.fromRGB(150, 156, 176)
local GOOD = Color3.fromRGB(110, 220, 130)
local BAD = Color3.fromRGB(236, 84, 84)
local WARN = Color3.fromRGB(255, 170, 60)

local function dim(c: Color3): Color3
	return c:Lerp(Color3.fromRGB(60, 60, 80), 0.55)
end

local function shuffle(list)
	for i = #list, 2, -1 do
		local j = rng:NextInteger(1, i)
		list[i], list[j] = list[j], list[i]
	end
	return list
end

-- ===================================================================
-- Peças locais
-- ===================================================================

local function block(g, x, y, z, size: Vector3, color: Color3, transparency: number?): BasePart
	local p = Instance.new("Part")
	p.Anchored = true
	p.CanCollide = false
	p.CanTouch = false
	p.CanQuery = false
	p.CastShadow = false
	p.Material = Enum.Material.SmoothPlastic
	p.Size = size
	p.Color = color
	p.Transparency = transparency or 0
	p.CFrame = g.cf * CFrame.new(x, y, z)
	p.Parent = g.folder
	return p
end

local function text(part: BasePart, str: string)
	local gui = Instance.new("BillboardGui")
	gui.Size = UDim2.fromOffset(90, 44)
	gui.StudsOffset = Vector3.new(0, 1.6, 0)
	gui.AlwaysOnTop = true
	gui.MaxDistance = 80
	local l = Instance.new("TextLabel")
	l.Name = "Text"
	l.BackgroundTransparency = 1
	l.Size = UDim2.fromScale(1, 1)
	l.Font = Enum.Font.GothamBold
	l.TextScaled = true
	l.TextColor3 = Color3.fromRGB(255, 255, 255)
	l.TextStrokeTransparency = 0.2
	l.Text = str
	l.Parent = gui
	gui.Parent = part
	return l
end

-- ladrilho pisável (só detecção); { part, x, z, h }
local function tile(g, x, z, w, color, str)
	local t = { part = block(g, x, 0.12, z, Vector3.new(w - 0.3, 0.24, w - 0.3), color), x = x, z = z, h = w / 2, color = color }
	if str then
		t.label = text(t.part, str)
	end
	table.insert(g.tiles, t)
	return t
end

local function grid(g, n, w, color, zc)
	local out = {}
	for iz = 1, n do
		for ix = 1, n do
			table.insert(out, tile(g, (ix - (n + 1) / 2) * w, (zc or 2) + (iz - (n + 1) / 2) * w, w, color))
		end
	end
	return out
end

local function ring(g, n, radius, w, color)
	local out = {}
	for i = 1, n do
		local a = i / n * math.pi * 2
		table.insert(out, tile(g, math.sin(a) * radius, 2 + math.cos(a) * radius, w, color))
	end
	return out
end

local function randomSpot(r)
	return rng:NextNumber(-r, r), 2 + rng:NextNumber(-r, r)
end

-- ===================================================================
-- Minigames
-- ===================================================================

local games = {}
MinigameController.Games = games

-- 1) Repita a sequência de cores
function games.memoria(g)
	local pads = ring(g, 4 + math.floor(g.k * 2.9), 7, 5, OFF)
	for i, t in pads do
		t.color = COLORS[i][2]
		t.part.Color = dim(t.color)
	end
	local seq = {}
	for i = 1, 3 + math.floor(g.k * 4) do
		seq[i] = rng:NextInteger(1, #pads)
		if seq[i] == seq[i - 1] then
			seq[i] = seq[i] % #pads + 1
		end
	end
	local on = 0.75 - g.k * 0.3
	local clock, at = -1, 1
	local lit = {}
	return function(dt, _, entered)
		clock += dt
		local show = clock < #seq * on
		local now = show and clock >= 0 and seq[math.floor(clock / on) + 1]
		local flash = show and (clock % on) < on * 0.75
		for i, t in pads do
			lit[i] = math.max(0, (lit[i] or 0) - dt)
			t.part.Color = ((now == i and flash) or lit[i] > 0) and t.color or dim(t.color)
		end
		if show then
			g.say("Memorize a sequência! Não pise ainda")
			return
		end
		g.say(string.format("Repita a sequência: %d/%d", at - 1, #seq))
		if entered then
			local i = table.find(pads, entered)
			lit[i] = 0.35
			if i == seq[at] then
				at += 1
				if at > #seq then
					g.win()
				end
			else
				g.fail("Cor errada!")
			end
		end
	end
end

-- 2) O chão some, menos a cor anunciada
function games.cores(g)
	local n = 5
	local tiles = grid(g, n, 4.4, OFF)
	local kinds = 4 + math.floor(g.k * 4)
	local rounds = 3 + math.floor(g.k * 3)
	local round, clock, target, hold = 0, 0, 1, 0
	local function nextRound()
		round += 1
		target = rng:NextInteger(1, kinds)
		for i, t in tiles do
			t.id = rng:NextInteger(1, kinds)
			t.part.Color = COLORS[t.id][2]
			t.part.Transparency = 0
		end
		local t = tiles[rng:NextInteger(1, #tiles)]
		t.id = target
		t.part.Color = COLORS[target][2]
		clock = 4.2 - g.k * 2
		hold = 1
	end
	nextRound()
	return function(dt, pos, _, on)
		if clock > 0 then
			clock -= dt
			g.say(string.format("Corra para o %s!  %.1f  (%d/%d)", COLORS[target][1], math.max(0, clock), round, rounds))
			if clock <= 0 then
				for _, t in tiles do
					if t.id ~= target then
						t.part.Transparency = 0.9
					end
				end
				if not pos or not on or on.id ~= target then
					g.fail("Cor errada!")
				end
			end
		else
			hold -= dt
			if hold <= 0 then
				if round >= rounds then
					g.win()
				else
					nextRound()
				end
			end
		end
	end
end

-- 3) Colete as estrelas a tempo
function games.coletar(g)
	local n = 6 + math.floor(g.k * 6)
	local time = n * (1.9 - g.k * 0.6)
	local stars = {}
	for i = 1, n do
		local x, z = randomSpot(9)
		local p = block(g, x, 2, z, Vector3.new(1.4, 1.4, 1.4), COLORS[4][2])
		p.Material = Enum.Material.Neon
		stars[i] = { part = p, x = x, z = z }
	end
	local left, spin = n, 0
	return function(dt, pos)
		time -= dt
		spin += dt * 3
		g.say(string.format("Pegue as estrelas! Faltam %d  ·  %.1f s", left, math.max(0, time)))
		for _, s in stars do
			if not s.got then
				s.part.CFrame = g.cf * CFrame.new(s.x, 2, s.z) * CFrame.Angles(spin, spin, 0)
				if pos and math.abs(pos.X - s.x) < 2 and math.abs(pos.Z - s.z) < 2 then
					s.got = true
					s.part.Transparency = 1
					left -= 1
				end
			end
		end
		if left == 0 then
			g.win()
		elseif time <= 0 then
			g.fail("Acabou o tempo!")
		end
	end
end

-- 4) Pule o laser giratório
function games.laser(g)
	local arms = g.k > 0.6 and 2 or 1
	local bars = {}
	for i = 1, arms do
		bars[i] = block(g, 0, 1, 2, Vector3.new(22, 0.6, 0.6), BAD)
		bars[i].Material = Enum.Material.Neon
	end
	local angle, time = 0, 10 + g.k * 8
	local speed = 1.1 + g.k * 0.8
	return function(dt, pos)
		time -= dt
		angle += dt * speed
		g.say(string.format("Pule o laser! %.1f s", math.max(0, time)))
		for i, b in bars do
			local a = angle + (i - 1) * math.pi / 2
			b.CFrame = g.cf * CFrame.new(0, 1, 2) * CFrame.Angles(0, a, 0)
			if pos and pos.Y < 4.2 then
				local rx, rz = pos.X, pos.Z - 2
				local across = math.abs(rx * math.sin(a) + rz * math.cos(a))
				if across < 0.9 and math.sqrt(rx * rx + rz * rz) > 1.2 then
					return g.fail("O laser te pegou!")
				end
			end
		end
		if not pos then
			return g.fail("Fique na ilha!")
		end
		if time <= 0 then
			g.win()
		end
	end
end

-- 5) Caminho invisível: descubra os ladrilhos seguros
function games.caminho(g)
	local cols, rows = 3 + math.floor(g.k * 2.9), 5
	local w = 4
	local safe, tiles = {}, {}
	local c = rng:NextInteger(1, cols)
	for r = 1, rows do
		safe[r] = c
		tiles[r] = {}
		for i = 1, cols do
			local t = tile(g, (i - (cols + 1) / 2) * w, -5 + (r - 1) * w, w, OFF)
			t.row, t.col = r, i
			tiles[r][i] = t
		end
		c = math.clamp(c + rng:NextInteger(-1, 1), 1, cols)
	end
	local at = 0
	return function(_, _, entered)
		g.say(string.format("Ache o caminho seguro, uma fileira por vez! %d/%d", at, rows))
		if entered then
			if entered.row == at + 1 then
				if entered.col == safe[entered.row] then
					at += 1
					entered.part.Color = GOOD
					if at >= rows then
						g.win()
					end
				else
					entered.part.Color = BAD
					at = 0
					g.warn("Errado! Volte ao começo")
					for r = 1, rows do
						for _, t in tiles[r] do
							if t.part.Color ~= BAD then
								t.part.Color = OFF
							end
						end
					end
					g.sendBack()
				end
			elseif entered.row > at + 1 then
				g.warn("Não pule fileiras!")
				g.sendBack()
			end
		end
	end
end

-- 6) Contas
function games.conta(g)
	local pads = {}
	for i = 1, 3 do
		pads[i] = tile(g, (i - 2) * 7, 5, 5, COLORS[i + 1][2], "")
	end
	local need, done, answer, question, time = 3 + math.floor(g.k * 2), 0, 0, "", 0
	local function ask()
		local a, b = rng:NextInteger(2, 9 + math.floor(g.k * 20)), rng:NextInteger(2, 9 + math.floor(g.k * 12))
		local op = rng:NextInteger(1, g.k > 0.35 and 3 or 2)
		if op == 1 then
			answer, question = a + b, a .. " + " .. b
		elseif op == 2 then
			a, b = math.max(a, b), math.min(a, b)
			answer, question = a - b, a .. " - " .. b
		else
			a, b = rng:NextInteger(2, 9), rng:NextInteger(2, 9)
			answer, question = a * b, a .. " x " .. b
		end
		local opts = shuffle({ answer, answer + rng:NextInteger(1, 3), answer - rng:NextInteger(1, 3) })
		for i, t in pads do
			t.value = opts[i]
			t.label.Text = tostring(opts[i])
		end
		time = 13 - g.k * 5
	end
	ask()
	return function(dt, _, entered)
		time -= dt
		g.say(string.format("Quanto é %s ?   %.0f s   (%d/%d)", question, math.max(0, time), done, need))
		if entered then
			if entered.value == answer then
				done += 1
				if done >= need then
					return g.win()
				end
				g.sendBack()
				ask()
			else
				return g.fail("Conta errada!")
			end
		end
		if time <= 0 then
			g.fail("Acabou o tempo!")
		end
	end
end

-- 7) Reação: pise no ladrilho aceso
function games.reacao(g)
	local tiles = grid(g, 4, 5, OFF)
	local need, done, cur, time = 6 + math.floor(g.k * 6), 0, nil, 0
	local function light()
		if cur then
			cur.part.Color = OFF
		end
		local prev = cur
		repeat
			cur = tiles[rng:NextInteger(1, #tiles)]
		until cur ~= prev
		cur.part.Color = WARN
		time = 2.9 - g.k * 1
	end
	light()
	return function(dt, _, _, on)
		time -= dt
		g.say(string.format("Pise no aceso! %d/%d  ·  %.1f s", done, need, math.max(0, time)))
		if on == cur then
			done += 1
			if done >= need then
				return g.win()
			end
			light()
		elseif time <= 0 then
			g.fail("Devagar demais!")
		end
	end
end

-- 8) Números em ordem
function games.numeros(g)
	local n = 5 + math.floor(g.k * 5)
	local tiles = ring(g, n, 8.5, 3.6, COLORS[2][2])
	local order = {}
	for i = 1, n do
		order[i] = i
	end
	shuffle(order)
	for i, t in tiles do
		t.value = order[i]
		t.label = text(t.part, tostring(order[i]))
	end
	local at, time = 1, n * (3.4 - g.k)
	return function(dt, _, entered)
		time -= dt
		g.say(string.format("Pise em ordem: agora o %d  ·  %.1f s", at, math.max(0, time)))
		if entered and entered.value == at then
			entered.part.Color = GOOD
			at += 1
			if at > n then
				return g.win()
			end
		elseif entered and entered.value > at then
			return g.fail("Fora de ordem!")
		end
		if time <= 0 then
			g.fail("Acabou o tempo!")
		end
	end
end

-- 9) Chuva de meteoros
function games.meteoros(g)
	local time, spawnIn, list = 12 + g.k * 8, 0.5, {}
	return function(dt, pos)
		time -= dt
		spawnIn -= dt
		g.say(string.format("Desvie dos meteoros! %.1f s", math.max(0, time)))
		if not pos then
			return g.fail("Fique na ilha!")
		end
		if spawnIn <= 0 then
			spawnIn = 0.6 - g.k * 0.3
			local x, z = randomSpot(10)
			if rng:NextNumber() < 0.35 then
				x, z = pos.X, pos.Z
			end
			table.insert(list, { x = x, z = z, t = 1.4 - g.k * 0.3, mark = block(g, x, 0.1, z, Vector3.new(5, 0.15, 5), BAD, 0.5), rock = block(g, x, 30, z, Vector3.new(3, 3, 3), Color3.fromRGB(120, 80, 70)) })
		end
		for i = #list, 1, -1 do
			local m = list[i]
			m.t -= dt
			m.rock.CFrame = g.cf * CFrame.new(m.x, math.max(0, m.t) * 22 + 1, m.z) * CFrame.Angles(m.t * 4, m.t * 3, 0)
			if m.t <= 0 then
				m.mark:Destroy()
				m.rock:Destroy()
				table.remove(list, i)
				if math.abs(pos.X - m.x) < 2.6 and math.abs(pos.Z - m.z) < 2.6 then
					return g.fail("Meteoro!")
				end
			end
		end
		if time <= 0 then
			g.win()
		end
	end
end

-- 10) Fique dentro do holofote que anda
function games.holofote(g)
	local spot = block(g, 0, 0.12, 2, Vector3.new(7 - g.k * 2.5, 0.2, 7 - g.k * 2.5), COLORS[4][2], 0.2)
	local half = spot.Size.X / 2
	local x, z, tx, tz = 0, 2, randomSpot(8)
	local need, got = 8 + g.k * 6, 0
	return function(dt, pos)
		local d = Vector2.new(tx - x, tz - z)
		if d.Magnitude < 0.5 then
			tx, tz = randomSpot(8)
		else
			local s = math.min(d.Magnitude, dt * (4 + g.k * 6)) / d.Magnitude
			x += d.X * s
			z += d.Y * s
		end
		spot.CFrame = g.cf * CFrame.new(x, 0.12, z)
		local inside = pos and math.abs(pos.X - x) < half and math.abs(pos.Z - z) < half
		got = math.max(0, got + (inside and dt or -dt * 0.6))
		spot.Color = inside and GOOD or COLORS[4][2]
		g.say(string.format("Fique no holofote! %.1f/%.0f s", got, need))
		if got >= need then
			g.win()
		end
	end
end

-- 11) Apague as luzes (cada passo inverte os vizinhos)
function games.luzes(g)
	local n = 3
	local tiles = grid(g, n, 6, OFF)
	local state = {}
	for i = 1, n * n do
		state[i] = false
	end
	local function flip(i)
		local r, c = math.floor((i - 1) / n), (i - 1) % n
		for _, d in { { 0, 0 }, { 1, 0 }, { -1, 0 }, { 0, 1 }, { 0, -1 } } do
			local rr, cc = r + d[1], c + d[2]
			if rr >= 0 and rr < n and cc >= 0 and cc < n then
				local j = rr * n + cc + 1
				state[j] = not state[j]
			end
		end
	end
	-- embaralha só com jogadas válidas: sempre tem solução
	local picks = {}
	for i = 1, n * n do
		picks[i] = i
	end
	shuffle(picks)
	for i = 1, 2 + math.floor(g.k * 3) do
		flip(picks[i])
	end
	return function(_, _, entered)
		g.say("Apague todas as luzes! Cada passo inverte os vizinhos (pule para não pisar)")
		if entered then
			flip(table.find(tiles, entered))
		end
		local any = false
		for i, t in tiles do
			t.part.Color = state[i] and COLORS[4][2] or OFF
			any = any or state[i]
		end
		if not any then
			g.win()
		end
	end
end

-- 12) Pares de cores escondidas
function games.pares(g)
	local pairsN = 3 + math.floor(g.k * 3.9)
	local ids = {}
	for i = 1, pairsN do
		table.insert(ids, i)
		table.insert(ids, i)
	end
	shuffle(ids)
	local tiles = ring(g, #ids, 8.8, math.min(4, 46 / #ids), OFF)
	for i, t in tiles do
		t.id = ids[i]
	end
	local first, wait, hide, found, tries = nil, 0, nil, 0, math.floor(pairsN * 3.5)
	return function(dt, _, entered)
		g.say(string.format("Ache os pares: %d/%d  ·  erros restantes: %d", found, pairsN, tries))
		if hide then
			wait -= dt
			if wait <= 0 then
				for _, t in hide do
					t.part.Color = OFF
				end
				hide = nil
			end
			return
		end
		if entered and not entered.found and entered ~= first then
			entered.part.Color = COLORS[entered.id][2]
			if not first then
				first = entered
			elseif first.id == entered.id then
				first.found, entered.found = true, true
				first = nil
				found += 1
				if found == pairsN then
					g.win()
				end
			else
				hide, wait = { first, entered }, 0.9
				first = nil
				tries -= 1
				if tries < 0 then
					g.fail("Muitos erros!")
				end
			end
		end
	end
end

-- 13) Área segura encolhendo
function games.encolhe(g)
	local safe = block(g, 0, 0.1, 2, Vector3.new(20, 0.2, 20), GOOD, 0.3)
	local round, rounds, clock, size, x, z = 0, 3 + math.floor(g.k * 3), 0, 20, 0, 2
	return function(dt, pos)
		clock -= dt
		if clock <= 0 then
			if round > 0 and (not pos or math.abs(pos.X - x) > size / 2 or math.abs(pos.Z - z) > size / 2) then
				return g.fail("Fora da área segura!")
			end
			round += 1
			if round > rounds then
				return g.win()
			end
			size = math.max(3, 9 - round * 1.2 - g.k * 1.5)
			x, z = randomSpot(9)
			safe.Size = Vector3.new(size, 0.2, size)
			safe.CFrame = g.cf * CFrame.new(x, 0.1, z)
			clock = 2.8 - g.k * 1
		end
		g.say(string.format("Entre no verde! %.1f s  (%d/%d)", clock, round, rounds))
	end
end

-- 14) Verdadeiro ou falso
local QUIZ = {
	{ "O Sol é uma estrela", true }, { "A Lua tem luz própria", false }, { "Uma aranha tem 8 patas", true },
	{ "O Brasil fica na Europa", false }, { "A água ferve a 100 °C no nível do mar", true }, { "Baleia é um peixe", false },
	{ "Um triângulo tem 4 lados", false }, { "O maior oceano é o Pacífico", true }, { "O morcego é um mamífero", true },
	{ "Um ano bissexto tem 366 dias", true }, { "Marte é o maior planeta", false }, { "A capital do Brasil é Brasília", true },
	{ "O polvo tem 3 corações", true }, { "Um século tem 10 anos", false }, { "Saturno tem anéis", true },
	{ "O ouro é um metal", true }, { "Pinguins voam", false }, { "7 x 8 = 54", false }, { "9 x 9 = 81", true },
	{ "O deserto do Saara fica na África", true }, { "A Terra gira em torno da Lua", false }, { "O gelo flutua na água", true },
}
function games.quiz(g)
	local yes = tile(g, -6, 5, 7, GOOD, "SIM")
	tile(g, 6, 5, 7, BAD, "NÃO")
	local list = shuffle(table.clone(QUIZ))
	local need, at, time = 3 + math.floor(g.k * 4), 1, 14
	return function(dt, _, entered)
		time -= dt
		g.say(string.format("%s?   %.0f s  (%d/%d)", list[at][1], math.max(0, time), at - 1, need))
		if entered then
			if (entered == yes) ~= list[at][2] then
				return g.fail("Resposta errada!")
			end
			at += 1
			time = 14 - g.k * 5
			if at > need then
				return g.win()
			end
			g.sendBack()
		elseif time <= 0 then
			g.fail("Acabou o tempo!")
		end
	end
end

-- 15) Ache o ladrilho diferente
function games.diferente(g)
	local tiles = grid(g, 4 + (g.k > 0.5 and 1 or 0), g.k > 0.5 and 4.2 or 5, OFF)
	local need, done, odd, time = 3 + math.floor(g.k * 3), 0, nil, 0
	local function deal()
		local c = COLORS[rng:NextInteger(1, 7)][2]
		odd = tiles[rng:NextInteger(1, #tiles)]
		for _, t in tiles do
			t.part.Color = t == odd and c:Lerp(Color3.fromRGB(255, 255, 255), 0.42 - g.k * 0.24) or c
		end
		time = 9 - g.k * 3
	end
	deal()
	return function(dt, _, _, on)
		time -= dt
		g.say(string.format("Vá até o diferente e fique nele! %.1f s  (%d/%d)", math.max(0, time), done, need))
		if time <= 0 then
			if on == odd then
				done += 1
				if done >= need then
					return g.win()
				end
				deal()
			else
				g.fail("Não era esse!")
			end
		end
	end
end

-- 16) Semáforo
function games.semaforo(g)
	block(g, 0, 0.1, 10, Vector3.new(22, 0.2, 3), GOOD, 0.2)
	local lamp = block(g, 0, 8, 12, Vector3.new(4, 4, 1), GOOD)
	lamp.Material = Enum.Material.Neon
	local green, clock, last, laps, back = true, 1.5, nil, 1 + math.floor(g.k * 2.9), false
	local need = laps
	block(g, 0, 0.1, -9, Vector3.new(22, 0.2, 3), COLORS[2][2], 0.2)
	local grace = 0
	return function(dt, pos)
		clock -= dt
		grace -= dt
		if clock <= 0 then
			green = not green
			clock = green and rng:NextNumber(0.5, 1.2) or rng:NextNumber(0.8, 1.8)
			grace = 0.45 - g.k * 0.15
			lamp.Color = green and GOOD or BAD
		end
		g.say((green and "VERDE: ande!" or "VERMELHO: parado!") .. string.format("  voltas: %d  (%s)", need, back and "volte ao azul" or "vá ao verde"))
		if pos then
			if last and not green and grace <= 0 and Vector2.new(pos.X - last.X, pos.Z - last.Z).Magnitude > dt * 5 then
				last = nil
				return g.fail("Você se mexeu no vermelho!")
			end
			if not back and pos.Z > 8.7 then
				need -= 1
				back = true
				if need <= 0 then
					return g.win()
				end
			elseif back and pos.Z < -7.6 then
				back = false
			end
		end
		last = pos
	end
end

-- 17) Ritmo: esteja no ar quando o anel fechar
function games.ritmo(g)
	local mark = block(g, 0, 0.1, 2, Vector3.new(20, 0.2, 20), COLORS[5][2], 0.4)
	local beat = 1.9 - g.k * 0.6
	local need, done, clock, miss = 6 + math.floor(g.k * 6), 0, beat, 2
	return function(dt, pos)
		clock -= dt
		local f = math.max(0.05, clock / beat)
		mark.Size = Vector3.new(20 * f + 1, 0.2, 20 * f + 1)
		mark.Color = clock < 0.35 and WARN or COLORS[5][2]
		g.say(string.format("PULE quando o quadrado fechar! %d/%d  ·  vidas: %d", done, need, miss + 1))
		if clock <= 0 then
			clock += beat
			if pos and pos.Y > 4.4 then
				done += 1
				if done >= need then
					g.win()
				end
			else
				miss -= 1
				if miss < 0 then
					g.fail("Fora do ritmo!")
				end
			end
		end
	end
end

-- 18) Paredes que varrem a ilha: passe pelo buraco
function games.paredes(g)
	local waves, speed = 4 + math.floor(g.k * 5), 9 + g.k * 8
	local gap = 6 - g.k * 2
	local at, z, hole = 0, 99, 0
	local left = block(g, 0, 3, 40, Vector3.new(1, 6, 1), COLORS[6][2], 0.15)
	local right = block(g, 0, 3, 40, Vector3.new(1, 6, 1), COLORS[6][2], 0.15)
	local function wave()
		at += 1
		z = 16
		hole = rng:NextNumber(-8, 8)
		local l, r = hole - gap / 2 + 13, 13 - hole - gap / 2
		left.Size = Vector3.new(l, 6, 1)
		right.Size = Vector3.new(r, 6, 1)
	end
	return function(dt, pos)
		if not pos then
			return g.fail("Fique na ilha!")
		end
		if at == 0 then
			wave()
		end
		z -= dt * speed
		left.CFrame = g.cf * CFrame.new(-13 + left.Size.X / 2, 3, z)
		right.CFrame = g.cf * CFrame.new(13 - right.Size.X / 2, 3, z)
		g.say(string.format("Passe pelo buraco da parede! %d/%d", at, waves))
		if math.abs(pos.Z - z) < 1.2 and math.abs(pos.X - hole) > gap / 2 + 0.2 then
			return g.fail("A parede te pegou!")
		end
		if z < -14 then
			if at >= waves then
				g.win()
			else
				wave()
			end
		end
	end
end

-- ===================================================================
-- Sessão
-- ===================================================================

local arenas, gates = {}, {}
local solved = {}
local active = nil
local gui, sayLabel

local function buildGui()
	local playerGui = player:WaitForChild("PlayerGui")
	gui = Instance.new("ScreenGui")
	gui.Name = "Minigame"
	gui.ResetOnSpawn = false
	sayLabel = Instance.new("TextLabel")
	sayLabel.Name = "Say"
	sayLabel.AnchorPoint = Vector2.new(0.5, 0)
	sayLabel.Position = UDim2.new(0.5, 0, 0.16, 0)
	sayLabel.Size = UDim2.new(0.6, 0, 0, 46)
	sayLabel.BackgroundColor3 = Color3.fromRGB(44, 38, 66)
	sayLabel.BackgroundTransparency = 0.25
	sayLabel.Font = Enum.Font.GothamBold
	sayLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
	sayLabel.TextScaled = true
	sayLabel.Text = ""
	sayLabel.Visible = false
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(0, 12)
	c.Parent = sayLabel
	sayLabel.Parent = gui
	gui.Parent = playerGui
end

local function isOpen(index: number): boolean
	return solved[index] == true or (player:GetAttribute(Config.Attr.Checkpoint) or 1) > index
end

local function applyGate(model)
	local s = gates[model]
	if not s then
		return
	end
	local open = isOpen(s.index)
	for _, p in model:GetDescendants() do
		if p:IsA("BasePart") then
			local o = s.parts[p]
			if not o then
				o = { collide = p.CanCollide, transparency = p.Transparency }
				s.parts[p] = o
			end
			p.CanCollide = open and o.collide
			p.Transparency = open and o.transparency or math.max(o.transparency, 0.85)
		end
	end
end

local function refreshGates()
	for model in gates do
		applyGate(model)
	end
end

local function stop()
	if active then
		active.folder:Destroy()
		active = nil
	end
	if sayLabel then
		sayLabel.Visible = false
	end
end

local function begin(g)
	for _, c in g.folder:GetChildren() do
		c:Destroy()
	end
	g.tiles = {}
	g.last = nil
	g.over = false
	g.step = games[g.kind](g)
end

local function say(str: string, color: Color3?)
	if sayLabel then
		sayLabel.Visible = true
		sayLabel.Text = str
		sayLabel.TextColor3 = color or Color3.fromRGB(255, 255, 255)
	end
end

local function newGame(kind: string, level: number, cf: CFrame, index: number)
	local folder = Instance.new("Folder")
	folder.Name = "MinigameLocal"
	folder.Parent = workspace
	local g = { kind = kind, k = math.clamp((level - 1) / 63, 0, 1), cf = cf, index = index, folder = folder, tiles = {}, wait = 2.2, hold = 0 }
	function g.say(str)
		if g.hold <= 0 then
			say(str)
		end
	end
	function g.warn(str)
		g.hold = 1
		say(str, BAD)
	end
	function g.fail(str)
		if g.over then
			return
		end
		g.over = true
		g.wait = 2
		g.warn(str .. " Tente de novo...")
		g.sendBack()
	end
	function g.win()
		if g.over then
			return
		end
		g.over = true
		g.won = true
		solved[index] = true
		for _, c in folder:GetChildren() do
			c:Destroy()
		end
		g.hold = 3
		say("Venceu! A ponte abriu", GOOD)
		refreshGates()
		task.delay(3, function()
			if active == g then
				stop()
			end
		end)
	end
	function g.sendBack()
		local character = player.Character
		local root = character and character:FindFirstChild("HumanoidRootPart")
		if root then
			root.AssemblyLinearVelocity = Vector3.zero
			character:PivotTo(cf * CFrame.new(0, 3.2, -10) * CFrame.Angles(0, math.pi, 0))
		end
	end
	return g
end
MinigameController.newGame = newGame
MinigameController.begin = begin

-- um quadro de um jogo, com a posição do jogador (nil = fora da ilha)
local function tick(g, dt: number, world: Vector3?)
	g.hold = math.max(0, g.hold - dt)
	if g.won then
		return
	end
	local pos = world and g.cf:PointToObjectSpace(world)
	if pos and (math.abs(pos.X) > 13.5 or math.abs(pos.Z) > 13.5 or pos.Y < -2 or pos.Y > 16) then
		pos = nil
	end
	if g.wait > 0 then
		g.wait -= dt
		if g.wait <= 0 then
			begin(g)
		elseif g.hold <= 0 then
			say(string.format("Desafio em %d...", math.ceil(g.wait)))
		end
		return
	end
	local on = nil
	if pos and pos.Y < 4 then
		for _, t in g.tiles do
			if math.abs(pos.X - t.x) < t.h and math.abs(pos.Z - t.z) < t.h then
				on = t
				break
			end
		end
	end
	local entered = (on and on ~= g.last) and on or nil
	g.last = on
	g.step(dt, pos, entered, on)
end
MinigameController.tick = tick

local function update(dt: number)
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	local index = player:GetAttribute(Config.Attr.Checkpoint) or 1
	local arena = arenas[index]
	local world = root and root.Position
	if active and active.index ~= index then
		stop()
	end
	if not active and arena and world and not isOpen(index) then
		local cf = arena:GetAttribute("MiniCFrame")
		if (world - cf.Position).Magnitude < 24 then
			active = newGame(arena:GetAttribute("MiniKind"), arena:GetAttribute("MiniLevel"), cf, index)
		end
	end
	if active then
		if not world or (world - active.cf.Position).Magnitude > 40 then
			stop()
		else
			tick(active, dt, world)
		end
	end
end

function MinigameController.start()
	buildGui()
	local function addArena(m)
		arenas[m:GetAttribute("MiniIndex")] = m
	end
	local function addGate(m)
		gates[m] = { index = m:GetAttribute("MiniIndex"), parts = {} }
		applyGate(m)
		m.DescendantAdded:Connect(function()
			task.defer(applyGate, m)
		end)
	end
	for _, m in CollectionService:GetTagged("Minigame") do
		addArena(m)
	end
	for _, m in CollectionService:GetTagged("MiniGate") do
		addGate(m)
	end
	CollectionService:GetInstanceAddedSignal("Minigame"):Connect(addArena)
	CollectionService:GetInstanceAddedSignal("MiniGate"):Connect(addGate)
	CollectionService:GetInstanceRemovedSignal("MiniGate"):Connect(function(m)
		gates[m] = nil
	end)
	player:GetAttributeChangedSignal(Config.Attr.Checkpoint):Connect(function()
		-- recomeçou a subida: os desafios valem de novo
		local index = player:GetAttribute(Config.Attr.Checkpoint) or 1
		if index == 1 then
			table.clear(solved)
		end
		refreshGates()
	end)
	RunService.Heartbeat:Connect(update)
end

return MinigameController