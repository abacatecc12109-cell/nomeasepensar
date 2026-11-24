--[[
	TerrainBuilder
	--------------
	Esculpe o Terrain do Roblox a partir do layout:
	  * chão gramado do mundo e colinas no horizonte
	  * colinas suaves, serras e picos recortados no horizonte
	  * platôs (zonas) com corpo de rocha, topo de grama e encostas naturais
	    (veja Mountains)
	  * paredões das trilhas e o maciço central
	  * riacho, ravina com rio, lagos e laguinhos (água transparente)

	Terrain é muito mais leve que milhares de peças, por isso é a base do mundo.
]]

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Config = require(Shared.Config)

local Builder = require(script.Parent.Builder)

local Mountains = require(script.Parent.Mountains)

local TerrainBuilder = {}

local M = Enum.Material

-- Material do topo e do corpo de cada tema de zona
local THEMES = {
	meadow = { top = M.Grass, body = M.Rock },
	garden = { top = M.Grass, body = M.Rock },
	hill = { top = M.Grass, body = M.Rock },
	grove = { top = M.Grass, body = M.Rock },
	cliffbase = { top = M.Grass, body = M.Rock },
	orchard = { top = M.Grass, body = M.Rock },
	village = { top = M.Grass, body = M.Rock },
	village_high = { top = M.Grass, body = M.Rock },
	village_ledge = { top = M.Grass, body = M.Slate },
	cliff_ledge = { top = M.Grass, body = M.Slate },
	cliff_mid = { top = M.Grass, body = M.Slate },
	cliff_terrace = { top = M.Grass, body = M.Slate },
	cliff_high = { top = M.Grass, body = M.Slate },
	cliff_top = { top = M.Grass, body = M.Slate },
	cliff_crown = { top = M.Grass, body = M.Slate },
	forest_floor = { top = M.LeafyGrass, body = M.Slate },
	celestial = { top = M.LeafyGrass, body = M.Limestone },
	sanctuary = { top = M.LeafyGrass, body = M.Limestone },
	summit = { top = M.LeafyGrass, body = M.Limestone },
	massif = { top = M.LeafyGrass, body = M.Limestone },
	cliffwall = { top = M.Grass, body = M.Slate },
}

local function themeOf(name: string?)
	local t = THEMES[name or ""] or { top = M.Grass, body = M.Rock }
	if not t.alt then
		t.alt = (t.body == M.Rock) and M.Slate or M.Rock
	end
	return t
end

local function frame(center: Vector3, yaw: number): CFrame
	return CFrame.new(center) * CFrame.Angles(0, yaw, 0)
end

function TerrainBuilder.configure(terrain: Terrain)
	local P = Config.Palette
	terrain:SetMaterialColor(M.Grass, P.Grass)
	terrain:SetMaterialColor(M.LeafyGrass, Color3.fromRGB(110, 172, 104))
	terrain:SetMaterialColor(M.Rock, P.Rock)
	terrain:SetMaterialColor(M.Slate, Color3.fromRGB(112, 116, 112))
	terrain:SetMaterialColor(M.Limestone, Color3.fromRGB(206, 198, 186))
	terrain:SetMaterialColor(M.Ground, P.Ground)
	terrain:SetMaterialColor(M.Mud, Color3.fromRGB(96, 80, 66))
	terrain:SetMaterialColor(M.Sand, P.Sand)
	terrain:SetMaterialColor(M.Sandstone, Color3.fromRGB(196, 170, 140))
	terrain.WaterColor = P.Water
	terrain.WaterTransparency = 0.78
	terrain.WaterReflectance = 0.35
	terrain.WaterWaveSize = 0.08
	terrain.WaterWaveSpeed = 6
end

-- Altura do chão (colinas suaves) num ponto: usada pela decoração para
-- plantar árvores e flores em cima das colinas, e não enterradas nelas.
local mounds = {}
function TerrainBuilder.groundHeight(x: number, z: number): number
	local best = Mountains.heightAt(x, z)
	for _, m in mounds do
		local dx, dz = x - m.c.X, z - m.c.Z
		local d2 = dx * dx + dz * dz
		if d2 < m.r * m.r then
			best = math.max(best, m.c.Y + math.sqrt(m.r * m.r - d2))
		end
	end
	return best
end

-- Chão do mundo, colinas suaves, serras e picos distantes no horizonte.
function TerrainBuilder.buildGround(terrain: Terrain, rng: Random, center: Vector3, clearance, blocked)
	Builder.pace()
	terrain:FillCylinder(CFrame.new(center.X, -12, center.Z), 24, 1150, M.Grass)
	Builder.pace()
	terrain:FillCylinder(CFrame.new(center.X, -30, center.Z), 12, 1150, M.Rock)

	-- manchas de capim e terra no chão (o prado não fica liso e igual)
	for _ = 1, 40 do
		local a = rng:NextNumber(0, math.pi * 2)
		local d = rng:NextNumber(300, 1000)
		local p = Vector3.new(center.X + math.cos(a) * d, -0.4, center.Z + math.sin(a) * d)
		Builder.pace()
		terrain:FillCylinder(CFrame.new(p), 0.8, rng:NextNumber(14, 40), (rng:NextNumber() < 0.7) and M.LeafyGrass or M.Ground)
	end

	-- colinas suaves e arredondadas em volta da montanha
	table.clear(mounds)
	for _ = 1, 46 do
		local a = rng:NextNumber(0, math.pi * 2)
		local d = rng:NextNumber(330, 760)
		local r = rng:NextNumber(36, 80)
		local c = Vector3.new(center.X + math.cos(a) * d, -r * rng:NextNumber(0.72, 0.86), center.Z + math.sin(a) * d)
		local top = c.Y + r
		local ok = clearance:isFree(Vector3.new(c.X - r, -2, c.Z - r), Vector3.new(c.X + r, top + 2, c.Z + r))
		if ok and blocked then
			ok = not blocked(Vector3.new(c.X, 0, c.Z), r + 8)
		end
		if ok then
			Builder.pace()
			terrain:FillBall(c - Vector3.new(0, 3, 0), r, M.Rock)
			Builder.pace()
			terrain:FillBall(c, r, M.Grass)
			table.insert(mounds, { c = c, r = r })
		end
	end

	-- cordilheira no horizonte
	Mountains.horizon(terrain, center, 760, 1150)
end

-- Platô: corpo de rocha + camada de grama no topo + encostas naturais.
function TerrainBuilder.buildMesa(terrain: Terrain, rng: Random, clearance, rect, themeName: string?)
	local theme = themeOf(themeName)
	local top, bottom = rect.top, rect.bottom
	local height = top - bottom
	local cf = frame(Vector3.new(rect.center.X, bottom + (height - 4) / 2, rect.center.Z), rect.yaw)
	if height > 4 then
		Builder.pace()
		terrain:FillBlock(cf, Vector3.new(rect.width, height - 4, rect.length), theme.body)
	end
	Builder.pace()
	terrain:FillBlock(frame(Vector3.new(rect.center.X, top - 2, rect.center.Z), rect.yaw), Vector3.new(rect.width, 4, rect.length), theme.top)
end

-- Canal de água: escava e enche com água (riacho, rio da ravina, lago)
function TerrainBuilder.carveWater(terrain: Terrain, center: Vector3, yaw: number, width: number, length: number, depth: number, bank: number?)
	local surface = center.Y
	local bankTop = bank or (surface + 1.2)
	local carveH = bankTop - (surface - depth) + 4
	Builder.pace()
	terrain:FillBlock(frame(Vector3.new(center.X, surface - depth + carveH / 2, center.Z), yaw), Vector3.new(width, carveH, length), M.Air)
	-- leito de areia/lodo
	Builder.pace()
	terrain:FillBlock(frame(Vector3.new(center.X, surface - depth - 1, center.Z), yaw), Vector3.new(width + 2, 3, length + 2), M.Sand)
	Builder.pace()
	terrain:FillBlock(frame(Vector3.new(center.X, surface - depth / 2, center.Z), yaw), Vector3.new(width, depth, length), M.Water)
end

function TerrainBuilder.carvePond(terrain: Terrain, center: Vector3, radius: number, depth: number)
	local cf = CFrame.new(center.X, center.Y - depth / 2 + 1, center.Z)
	Builder.pace()
	terrain:FillCylinder(cf, depth + 2, radius, M.Air)
	Builder.pace()
	terrain:FillCylinder(CFrame.new(center.X, center.Y - depth - 0.5, center.Z), 2, radius + 1, M.Sand)
	Builder.pace()
	terrain:FillCylinder(CFrame.new(center.X, center.Y - depth / 2 - 0.6, center.Z), depth - 0.6, radius, M.Water)
end

--[[
	Constrói todo o terreno do layout.
	Retorna informações úteis (centro do mundo) para os outros construtores.
]]
function TerrainBuilder.build(layout, clearance, rng: Random)
	local terrain = workspace.Terrain
	TerrainBuilder.configure(terrain)

	-- centro aproximado do mundo (para o chão e o horizonte)
	local sum, n = Vector3.zero, 0
	for _, z in layout.zones do
		sum += Vector3.new(z.center.X, 0, z.center.Z)
		n += 1
	end
	local center = n > 0 and sum / n or Vector3.zero
	-- colinas não podem nascer em cima de platôs, paredões ou água
	local rects = {}
	for _, z in layout.zones do
		if z.surface == "terrain" then
			table.insert(rects, z)
		end
	end
	for _, w in layout.walls do
		table.insert(rects, w)
	end
	for _, prop in layout.props do
		local d = prop.data
		if (prop.type == "stream" or prop.type == "lake" or prop.type == "ravine" or prop.type == "river") and d.width and d.length then
			table.insert(rects, { center = d.center, yaw = d.yaw or 0, width = d.width, length = d.length })
		end
	end
	local function blocked(p: Vector3, margin: number): boolean
		for _, rect in rects do
			local f = Vector3.new(math.sin(rect.yaw), 0, math.cos(rect.yaw))
			local r = Vector3.new(-math.cos(rect.yaw), 0, math.sin(rect.yaw))
			local rel = Vector3.new(p.X - rect.center.X, 0, p.Z - rect.center.Z)
			if math.abs(rel:Dot(f)) < rect.length / 2 + margin and math.abs(rel:Dot(r)) < rect.width / 2 + margin then
				return true
			end
		end
		return false
	end
	TerrainBuilder.buildGround(terrain, rng, center, clearance, blocked)

	-- maciços e paredões primeiro (as zonas ficam por cima)
	for _, wall in layout.walls do
		TerrainBuilder.buildMesa(terrain, rng, clearance, wall, wall.theme or "cliffwall")
	end
	for _, zone in layout.zones do
		if zone.surface == "terrain" and zone.top > 0.5 then
			TerrainBuilder.buildMesa(terrain, rng, clearance, zone, zone.theme)
		end
	end

	-- encostas naturais (depois de todos os platôs): não cobrem zonas, água nem cachoeiras
	local others = {}
	local function protect(rect, cap)
		table.insert(others, { rect = rect, dist = Mountains.distFn(rect), cap = cap })
	end
	for _, zone in layout.zones do
		protect(zone, zone.top - 1)
	end
	for _, prop in layout.props do
		local d = prop.data
		if d.width and d.length and d.center then
			protect({ center = d.center, yaw = d.yaw or 0, width = d.width + 6, length = d.length + 6 }, d.center.Y - 1)
		elseif prop.type == "pond" then
			protect({ center = d.center, yaw = 0, width = d.radius * 2 + 4, length = d.radius * 2 + 4 }, d.center.Y - 1)
		elseif prop.type == "waterfall" then
			local f = Vector3.new(math.sin(d.yaw), 0, math.cos(d.yaw))
			protect({ center = d.top + f * 14, yaw = d.yaw, width = d.width + 6, length = 30 }, d.top.Y - d.drop - 1)
		end
	end
	for _, wall in layout.walls do
		Mountains.slopes(terrain, clearance, wall, themeOf(wall.theme or "cliffwall"), others)
	end
	for _, zone in layout.zones do
		if zone.surface == "terrain" and zone.top > 0.5 then
			Mountains.slopes(terrain, clearance, zone, themeOf(zone.theme), others)
		end
	end

	-- água e escavações (depois dos platôs)
	for _, prop in layout.props do
		local d = prop.data
		if prop.type == "stream" or prop.type == "river" then
			TerrainBuilder.carveWater(terrain, d.center, d.yaw, d.width, d.length, d.depth or 4, d.bank)
		elseif prop.type == "lake" then
			TerrainBuilder.carveWater(terrain, d.center, d.yaw, d.width, d.length, d.depth or 6, d.bank)
		elseif prop.type == "ravine" then
			-- ravina: abre o chão e coloca um rio no fundo
			local c = d.center
			Builder.pace()
			terrain:FillBlock(frame(Vector3.new(c.X, c.Y - d.depth / 2 + 2, c.Z), d.yaw), Vector3.new(d.width, d.depth + 4, d.length), M.Air)
			Builder.pace()
			terrain:FillBlock(frame(Vector3.new(c.X, c.Y - d.depth - 1, c.Z), d.yaw), Vector3.new(d.width + 4, 4, d.length + 4), M.Mud)
			Builder.pace()
			terrain:FillBlock(frame(Vector3.new(c.X, c.Y - d.depth + 1.5, c.Z), d.yaw), Vector3.new(d.width * 0.45, 3, d.length + 4), M.Water)
		elseif prop.type == "pond" then
			TerrainBuilder.carvePond(terrain, d.center, d.radius, d.depth or 3)
		elseif prop.type == "waterfall" and d.pool then
			-- poço no pé da cachoeira, encostado no paredão
			local f = Vector3.new(math.sin(d.yaw), 0, math.cos(d.yaw))
			local r = d.width / 2 + 1.5
			TerrainBuilder.carvePond(terrain, d.top - Vector3.new(0, d.drop, 0) + f * (r + 0.5), r, 2.5)
		end
	end

	return { center = center, groundHeight = TerrainBuilder.groundHeight }
end

return TerrainBuilder
