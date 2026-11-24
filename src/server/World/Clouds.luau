--[[
	Clouds
	------
	Nuvens fofas feitas de várias bolas de tamanhos diferentes.

	A superfície pisável é SEMPRE um colisor invisível exato (dados do
	layout). As bolas só decoram: o topo delas fica um pouco acima do
	colisor (o pé "afunda" de leve na nuvem) e elas nunca passam muito da
	borda do colisor, para o jogador não achar que dá para pisar onde não dá.

	Também cria as poucas nuvens grandes que flutuam ao longe no céu.
]]

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Config = require(Shared.Config)
local Builder = require(script.Parent.Builder)

local Clouds = {}
local M = Enum.Material

-- Paletas: corpo, sombra (por baixo) e brilho (por cima)
Clouds.Palettes = {
	cloud = {
		body = Color3.fromRGB(250, 250, 255),
		shade = Color3.fromRGB(226, 228, 246),
		light = Color3.fromRGB(255, 255, 255),
	},
	sunsetcloud = {
		body = Color3.fromRGB(255, 226, 206),
		shade = Color3.fromRGB(250, 188, 200),
		light = Color3.fromRGB(255, 242, 216),
	},
	cloudstone = {
		body = Color3.fromRGB(246, 246, 252),
		shade = Color3.fromRGB(222, 224, 240),
		light = Color3.fromRGB(255, 255, 255),
	},
}

function Clouds.palette(style: string?)
	return Clouds.Palettes[style or "cloud"] or Clouds.Palettes.cloud
end

local function puff(parent: Instance, position: Vector3, radius: number, color: Color3, rng: Random, name: string?)
	local ball = Builder.ball(position, radius, {
		Color = Builder.vary(color, rng, 0.015),
		Material = M.SmoothPlastic,
		Name = name or "Puff",
		Parent = parent,
	})
	ball.CastShadow = false
	return ball
end

--[[
	Nuvem pisável sobre um retângulo w x l cujo topo passa por `cf`.
	Retorna a lista de bolas (para animar junto com plataformas frágeis).
]]
function Clouds.platform(cf: CFrame, w: number, l: number, rng: Random, parent: Instance, style: string?)
	local pal = Clouds.palette(style)
	local list = {}
	local half = math.min(w, l) / 2
	local r = math.clamp(half * 0.62, 1.1, 3.2)
	-- anel de bolas: a borda externa coincide com a borda do colisor (+0.35)
	local around = math.clamp(math.floor((w + l) / 3.2), 4, 14)
	local ax = math.max(0, w / 2 - r + 0.35)
	local az = math.max(0, l / 2 - r + 0.35)
	for i = 1, around do
		local a = (i / around) * math.pi * 2 + rng:NextNumber(-0.15, 0.15)
		local rr = r * rng:NextNumber(0.85, 1.05)
		local p = cf * CFrame.new(math.cos(a) * ax, -rr + 0.4, math.sin(a) * az)
		table.insert(list, puff(parent, p.Position, rr, pal.body, rng))
	end
	-- miolo
	local core = math.max(r, half * 0.8)
	table.insert(list, puff(parent, (cf * CFrame.new(0, -core + 0.35, 0)).Position, core, pal.body, rng))
	-- barriga sombreada por baixo
	for i = 1, 3 do
		local a = (i / 3) * math.pi * 2 + rng:NextNumber(0, 1)
		local rr = r * rng:NextNumber(0.8, 1.1)
		local p = cf * CFrame.new(math.cos(a) * ax * 0.55, -rr - r * 0.7, math.sin(a) * az * 0.55)
		table.insert(list, puff(parent, p.Position, rr, pal.shade, rng, "Shade"))
	end
	-- tufos de brilho em cima
	for _ = 1, 2 do
		local p = cf * CFrame.new(rng:NextNumber(-ax, ax) * 0.6, -r * 0.35 + 0.45, rng:NextNumber(-az, az) * 0.6)
		table.insert(list, puff(parent, p.Position, r * 0.5, pal.light, rng, "Light"))
	end
	return list
end

--[[
	Ilha de nuvem grande (checkpoint das fases no céu): várias camadas de
	bolas, com bordas onduladas e uma "barriga" que pende para baixo.
]]
function Clouds.island(cf: CFrame, w: number, l: number, rng: Random, parent: Instance, style: string?)
	local pal = Clouds.palette(style)
	local cell = 4.2
	local nx = math.max(1, math.floor(w / cell))
	local nz = math.max(1, math.floor(l / cell))
	local r = cell * 0.72
	for ix = 0, nx - 1 do
		for iz = 0, nz - 1 do
			local x = -w / 2 + (ix + 0.5) * (w / nx)
			local z = -l / 2 + (iz + 0.5) * (l / nz)
			local edge = ix == 0 or iz == 0 or ix == nx - 1 or iz == nz - 1
			local rr = r * rng:NextNumber(0.9, 1.08)
			-- na borda a bola recua para não "vazar" além do colisor
			local sx = edge and (x - math.sign(x) * math.max(0, math.abs(x) + rr - w / 2 - 0.4)) or x
			local sz = edge and (z - math.sign(z) * math.max(0, math.abs(z) + rr - l / 2 - 0.4)) or z
			puff(parent, (cf * CFrame.new(sx, -rr + 0.35, sz)).Position, rr, pal.body, rng)
		end
	end
	-- barriga em degraus
	local layers = 3
	for k = 1, layers do
		local shrink = 1 - k * 0.22
		local n = math.max(3, math.floor((w + l) / 7 * shrink))
		for i = 1, n do
			local a = (i / n) * math.pi * 2 + rng:NextNumber(-0.2, 0.2)
			local rr = r * rng:NextNumber(1, 1.35) * (1 - k * 0.12)
			local p = cf * CFrame.new(math.cos(a) * w * 0.36 * shrink, -r * 0.8 - k * r * 0.9, math.sin(a) * l * 0.36 * shrink)
			puff(parent, p.Position, rr, k == 1 and pal.body or pal.shade, rng, "Shade")
		end
	end
	-- tufos de brilho pela borda
	for i = 1, math.floor((w + l) / 5) do
		local a = (i / math.floor((w + l) / 5)) * math.pi * 2
		local p = cf * CFrame.new(math.cos(a) * (w / 2 - 1.6), 0.1, math.sin(a) * (l / 2 - 1.6))
		puff(parent, p.Position, rng:NextNumber(0.9, 1.4), pal.light, rng, "Light")
	end
end

--[[
	Nuvem decorativa gigante, flutuando ao longe (o céu tem poucas nuvens).
]]
function Clouds.sky(center: Vector3, scale: number, rng: Random, parent: Instance, style: string?)
	local pal = Clouds.palette(style)
	local model = Builder.model("NuvemDoCeu", parent)
	local length = scale * rng:NextNumber(2.6, 3.4)
	local count = rng:NextInteger(6, 9)
	local heading = rng:NextNumber(0, math.pi * 2)
	local dir = Vector3.new(math.cos(heading), 0, math.sin(heading))
	for i = 1, count do
		local t = (i - 0.5) / count - 0.5
		local bump = 1 - math.abs(t) * 1.3
		local rr = scale * rng:NextNumber(0.55, 0.8) * (0.55 + bump * 0.6)
		local p = center + dir * (t * length) + Vector3.new(rng:NextNumber(-0.2, 0.2) * scale, rr * 0.35 * bump, rng:NextNumber(-0.25, 0.25) * scale)
		puff(model, p, rr, pal.body, rng)
	end
	-- base mais achatada e sombreada
	for i = 1, 3 do
		local t = (i - 2) * 0.28
		puff(model, center + dir * (t * length) - Vector3.new(0, scale * 0.35, 0), scale * 0.5, pal.shade, rng, "Shade")
	end
	return model
end

return Clouds
