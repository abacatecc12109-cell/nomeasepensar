--!nocheck
-- Testes do percurso: justiça dos saltos, conexões, sobreposições e checkpoints.

local ServerScriptService = game:GetService("ServerScriptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Config = require(ReplicatedStorage.Shared.Config)
local Fairness = require(ReplicatedStorage.Shared.Fairness)
local CourseLayout = require(ServerScriptService.Server.Course.CourseLayout)
local CourseDefinition = require(ServerScriptService.Server.Course.CourseDefinition)

local layout = CourseDefinition.build()
local fwdOf, rightOf = CourseLayout.forwardOf, CourseLayout.rightOf

-- Retângulo orientado no plano XZ (com curso de movimento das plataformas)
local function rectOf(e)
	local c = Vector3.new(e.center.X, 0, e.center.Z)
	local hw, hl = e.width / 2, e.length / 2
	if e.kind == "mover" then
		if e.axis == "forward" then
			c = c + fwdOf(e.yaw) * (e.travel / 2)
			hl += e.travel / 2
		elseif e.axis == "lateral" then
			hw += e.travel / 2
		end
	end
	return { c = c, f = fwdOf(e.yaw), r = rightOf(e.yaw), hw = hw, hl = hl }
end

local function corners(rect)
	local out = {}
	for _, s in { { 1, 1 }, { 1, -1 }, { -1, 1 }, { -1, -1 } } do
		table.insert(out, rect.c + rect.f * (rect.hl * s[1]) + rect.r * (rect.hw * s[2]))
	end
	return out
end

-- Teste de eixo separador; margin > 0 encolhe (tolera encostar)
local function overlaps(a, b, margin)
	local ca, cb = corners(a), corners(b)
	for _, axis in { a.f, a.r, b.f, b.r } do
		local amin, amax, bmin, bmax = math.huge, -math.huge, math.huge, -math.huge
		for _, p in ca do
			local d = p:Dot(axis)
			amin, amax = math.min(amin, d), math.max(amax, d)
		end
		for _, p in cb do
			local d = p:Dot(axis)
			bmin, bmax = math.min(bmin, d), math.max(bmax, d)
		end
		if amax - margin <= bmin or bmax - margin <= amin then
			return false
		end
	end
	return true
end

local function surfaceRange(e)
	if e.kind == "zone" or e.kind == "wall" then
		return e.top, e.top
	end
	local lo = math.min(e.entry.Y, e.exit.Y)
	local hi = math.max(e.entry.Y, e.exit.Y)
	if e.kind == "mover" and e.axis == "vertical" then
		hi = e.centerB.Y
	end
	return lo, hi
end

local function bottomOf(e)
	local _, mn = nil, nil
	local minV = CourseLayout.bounds(e)
	return minV.Y
end

describe("layout", function()
	it("não registra erros de construção (saltos justos, áreas válidas)", function()
		if #layout.errors > 0 then
			error(table.concat(layout.errors, "\n      "))
		end
	end)

	it("tem as 7 regiões em ordem crescente", function()
		local last = 1
		for _, e in layout.elements do
			expect(e.region >= last, "região voltou de " .. last .. " para " .. e.region .. " no elemento " .. e.id)
			last = e.region
		end
		expect(last == 7, "a última região deveria ser 7, é " .. last)
	end)

	it("cada salto respeita a física do personagem", function()
		local worst = 0
		for _, e in layout.elements do
			if e.connect == "jump" then
				local ok, why = Fairness.check(e.gap, e.rise)
				expect(ok, string.format("elemento %d (%s): %s", e.id, e.kind, tostring(why)))
				worst = math.max(worst, e.gap / math.max(0.01, Fairness.maxReach(e.rise)))
			end
		end
		log(string.format("salto mais exigente usa %.0f%% do alcance máximo", worst * 100))
	end)

	it("plataformas têm largura e comprimento mínimos", function()
		for _, e in layout.pieces do
			expect(e.width >= Config.Difficulty.MinPlatformWidth, "peça " .. e.id .. " estreita demais")
		end
	end)
end)

describe("geometria", function()
	it("nenhuma zona de terreno enterra peças do percurso", function()
		local problems = {}
		local solids = {}
		for _, z in layout.zones do
			if z.surface ~= "deck" then
				table.insert(solids, z)
			end
		end
		for _, w in layout.walls do
			table.insert(solids, w)
		end
		for _, s in solids do
			local rs = rectOf(s)
			for _, p in layout.pieces do
				if p.id ~= s.owner and math.abs(p.id - (s.id or -100)) > 1 then
					local lo = surfaceRange(p)
					if lo < s.top - 0.3 and overlaps(rs, rectOf(p), 0.3) then
						table.insert(problems, string.format("%s '%s' (topo %.1f) cobre peça %d %s (y %.1f)", s.kind, tostring(s.theme or "parede"), s.top, p.id, p.kind, lo))
					end
				end
			end
		end
		if #problems > 0 then
			error(#problems .. " conflito(s):\n      " .. table.concat(problems, "\n      "))
		end
	end)

	it("peças não se atravessam e sempre há espaço para a cabeça", function()
		local HEAD = 5.5
		local problems = {}
		local list = {}
		for _, e in layout.elements do
			if e.kind ~= "zone" or e.surface == "deck" then
				table.insert(list, e)
			end
		end
		for i = 1, #list do
			local a = list[i]
			local ra = rectOf(a)
			local aLo, aHi = surfaceRange(a)
			local aBottom = bottomOf(a)
			for j = i + 1, #list do
				local b = list[j]
				if math.abs(a.id - b.id) > 1 then
					local bLo, bHi = surfaceRange(b)
					local bBottom = bottomOf(b)
					-- intervalos verticais ocupados (corpo + espaço livre acima)
					if aBottom < bHi + HEAD and bBottom < aHi + HEAD then
						if overlaps(ra, rectOf(b), 0.2) then
							table.insert(problems, string.format("peças %d (%s, y %.1f) e %d (%s, y %.1f) se sobrepõem", a.id, a.kind, aHi, b.id, b.kind, bHi))
						end
					end
				end
			end
		end
		if #problems > 0 then
			error(#problems .. " conflito(s):\n      " .. table.concat(problems, "\n      ", 1, math.min(#problems, 25)))
		end
	end)

	it("árvores gigantes não atravessam o percurso", function()
		local problems = {}
		for _, prop in layout.props do
			if prop.type == "gianttree" then
				local d = prop.data
				local c = Vector3.new(d.center.X, 0, d.center.Z)
				for _, p in layout.elements do
					if p.kind ~= "zone" or p.surface == "deck" then
						local rect = rectOf(p)
						local rel = c - rect.c
						local along = math.clamp(rel:Dot(rect.f), -rect.hl, rect.hl)
						local side = math.clamp(rel:Dot(rect.r), -rect.hw, rect.hw)
						local nearest = rect.c + rect.f * along + rect.r * side
						if (nearest - c).Magnitude < d.radius - 0.1 then
							local lo = surfaceRange(p)
							if lo > d.center.Y and lo < d.center.Y + d.height then
								table.insert(problems, string.format("tronco '%s' atravessa peça %d (%s)", d.name, p.id, p.kind))
							end
						end
					end
				end
				expect(d.radius > 3, "tronco fino demais: " .. d.radius)
			end
		end
		if #problems > 0 then
			error(table.concat(problems, "\n      "))
		end
	end)
end)

describe("checkpoints", function()
	it("toda região tem pelo menos um checkpoint", function()
		local per = {}
		for _, cp in layout.checkpoints do
			per[cp.region] = (per[cp.region] or 0) + 1
		end
		for r = 1, 7 do
			expect((per[r] or 0) >= 1, "região " .. r .. " sem checkpoint")
		end
	end)

	it("o último checkpoint é a chegada e as alturas sobem", function()
		local cps = layout.checkpoints
		expect(cps[#cps].finish, "último checkpoint deveria ser a chegada")
		for i = 2, #cps do
			expect(cps[i].position.Y >= cps[i - 1].position.Y - 0.01, "checkpoint " .. i .. " mais baixo que o anterior")
		end
	end)

	it("o percurso nunca desce até a zona de reinício por queda", function()
		local cps = layout.checkpoints
		local ci = 0
		for _, e in layout.elements do
			while cps[ci + 1] and cps[ci + 1].elementId and cps[ci + 1].elementId <= e.id do
				ci += 1
			end
			if ci > 0 then
				local lo = surfaceRange(e)
				local limit = cps[ci].position.Y - Config.FallResetDepth + 3
				expect(lo >= limit, string.format("elemento %d (y %.1f) está abaixo do limite de queda do checkpoint %d (%.1f)", e.id, lo, ci, limit))
			end
		end
	end)
end)

describe("resumo", function()
	it("imprime o mapa", function()
		local s = layout:summary()
		log(string.format("%d elementos (%d zonas, %d peças), %d checkpoints, altura %.0f → %.0f", s.elements, s.zones, s.pieces, s.checkpoints, s.minY, s.maxY))
		local mnx, mxx, mnz, mxz = math.huge, -math.huge, math.huge, -math.huge
		for _, e in layout.elements do
			local a, b = CourseLayout.bounds(e)
			mnx, mxx = math.min(mnx, a.X), math.max(mxx, b.X)
			mnz, mxz = math.min(mnz, a.Z), math.max(mxz, b.Z)
		end
		log(string.format("extensão X %.0f..%.0f  Z %.0f..%.0f", mnx, mxx, mnz, mxz))
		if __verbose ~= false then
			for _, e in layout.elements do
				local lo, hi = surfaceRange(e)
				log(string.format("#%-3d R%d %-10s %-12s c=(%6.0f,%6.0f) y=%5.1f..%5.1f %s gap=%.1f rise=%.1f", e.id, e.region, e.kind, tostring(e.theme or e.style), e.center.X, e.center.Z, lo, hi, e.connect, e.gap or 0, e.rise or 0))
			end
		end
	end)
end)
