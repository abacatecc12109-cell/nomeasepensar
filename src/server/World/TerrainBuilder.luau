--[[
	TerrainBuilder
	--------------
	Esculpe o Terrain do Roblox a partir do layout:
	  * chão gramado do mundo e colinas no horizonte
	  * platôs (zonas) com corpo de rocha, topo de grama e bordas irregulares
	  * paredões das trilhas e o maciço central
	  * riacho, ravina com rio, lagos e laguinhos (água transparente)

	Terrain é muito mais leve que milhares de peças, por isso é a base do mundo.
]]

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Config = require(Shared.Config)

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
	return THEMES[name or ""] or { top = M.Grass, body = M.Rock }
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
	terrain.Decoration = true -- grama animada (leve, feita pela engine)
end

-- Chão do mundo e colinas distantes que formam o horizonte.
function TerrainBuilder.buildGround(terrain: Terrain, rng: Random, center: Vector3)
	terrain:FillCylinder(CFrame.new(center.X, -12, center.Z) * CFrame.Angles(0, 0, 0), 24, 1150, M.Grass)
	terrain:FillCylinder(CFrame.new(center.X, -30, center.Z), 12, 1150, M.Rock)

	-- Colinas ao redor (horizonte), alternando grama e rocha
	for i = 1, 28 do
		local angle = (i / 28) * math.pi * 2 + rng:NextNumber(-0.08, 0.08)
		local dist = rng:NextNumber(780, 980)
		local radius = rng:NextNumber(110, 210)
		local p = Vector3.new(center.X + math.cos(angle) * dist, rng:NextNumber(-radius * 0.65, -radius * 0.35), center.Z + math.sin(angle) * dist)
		terrain:FillBall(p - Vector3.new(0, 12, 0), radius, M.Rock)
		terrain:FillBall(p, radius * 0.97, M.Grass)
	end
	-- Picos distantes mais altos atrás da montanha
	for i = 1, 7 do
		local angle = (i / 7) * math.pi * 2 + 0.4
		local dist = rng:NextNumber(1050, 1150)
		local p = Vector3.new(center.X + math.cos(angle) * dist, rng:NextNumber(40, 120), center.Z + math.sin(angle) * dist)
		terrain:FillBall(p, rng:NextNumber(140, 220), M.Slate)
	end
end

-- Bordas irregulares: pedras redondas encaixadas nas laterais do platô.
local function roughEdges(terrain: Terrain, rng: Random, clearance, rect, top: number, bottom: number, material)
	local f = Vector3.new(math.sin(rect.yaw), 0, math.cos(rect.yaw))
	local r = Vector3.new(-math.cos(rect.yaw), 0, math.sin(rect.yaw))
	local height = top - bottom
	local perimeter = 2 * (rect.width + rect.length)
	local count = math.clamp(math.floor(perimeter / 11), 6, 60)
	for i = 1, count do
		local t = (i - 0.5) / count * perimeter
		local along, side
		if t < rect.length then
			along, side = t - rect.length / 2, rect.width / 2
		elseif t < rect.length + rect.width then
			along, side = rect.length / 2, rect.width / 2 - (t - rect.length)
		elseif t < 2 * rect.length + rect.width then
			along, side = rect.length / 2 - (t - rect.length - rect.width), -rect.width / 2
		else
			along, side = -rect.length / 2, -rect.width / 2 + (t - 2 * rect.length - rect.width)
		end
		local radius = rng:NextNumber(4, 9)
		local depth = rng:NextNumber(2, math.max(3, math.min(height * 0.6, 30)))
		local c = rect.center + f * along + r * side
		local p = Vector3.new(c.X, top - 1.5 - radius * 0.35 - depth, c.Z)
		if p.Y - radius > bottom - 10 then
			local half = Vector3.new(radius + 1, radius + 1, radius + 1)
			if clearance:isFree(p - half, p + half + Vector3.new(0, 7, 0)) then
				terrain:FillBall(p, radius, material)
			end
		end
	end
end

-- Platô: corpo de rocha + camada de grama no topo + bordas irregulares.
function TerrainBuilder.buildMesa(terrain: Terrain, rng: Random, clearance, rect, themeName: string?)
	local theme = themeOf(themeName)
	local top, bottom = rect.top, rect.bottom
	local height = top - bottom
	local cf = frame(Vector3.new(rect.center.X, bottom + (height - 4) / 2, rect.center.Z), rect.yaw)
	if height > 4 then
		terrain:FillBlock(cf, Vector3.new(rect.width, height - 4, rect.length), theme.body)
	end
	terrain:FillBlock(frame(Vector3.new(rect.center.X, top - 2, rect.center.Z), rect.yaw), Vector3.new(rect.width, 4, rect.length), theme.top)
	if height > 10 then
		roughEdges(terrain, rng, clearance, rect, top, bottom, theme.body)
	end
end

-- Canal de água: escava e enche com água (riacho, rio da ravina, lago)
function TerrainBuilder.carveWater(terrain: Terrain, center: Vector3, yaw: number, width: number, length: number, depth: number, bank: number?)
	local surface = center.Y
	local bankTop = bank or (surface + 1.2)
	local carveH = bankTop - (surface - depth) + 4
	terrain:FillBlock(frame(Vector3.new(center.X, surface - depth + carveH / 2, center.Z), yaw), Vector3.new(width, carveH, length), M.Air)
	-- leito de areia/lodo
	terrain:FillBlock(frame(Vector3.new(center.X, surface - depth - 1, center.Z), yaw), Vector3.new(width + 2, 3, length + 2), M.Sand)
	terrain:FillBlock(frame(Vector3.new(center.X, surface - depth / 2, center.Z), yaw), Vector3.new(width, depth, length), M.Water)
end

function TerrainBuilder.carvePond(terrain: Terrain, center: Vector3, radius: number, depth: number)
	local cf = CFrame.new(center.X, center.Y - depth / 2 + 1, center.Z)
	terrain:FillCylinder(cf, depth + 2, radius, M.Air)
	terrain:FillCylinder(CFrame.new(center.X, center.Y - depth - 0.5, center.Z), 2, radius + 1, M.Sand)
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
	TerrainBuilder.buildGround(terrain, rng, center)

	-- maciços e paredões primeiro (as zonas ficam por cima)
	for _, wall in layout.walls do
		TerrainBuilder.buildMesa(terrain, rng, clearance, wall, wall.theme or "cliffwall")
	end
	for _, zone in layout.zones do
		if zone.surface == "terrain" and zone.top > 0.5 then
			TerrainBuilder.buildMesa(terrain, rng, clearance, zone, zone.theme)
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
			terrain:FillBlock(frame(Vector3.new(c.X, c.Y - d.depth / 2 + 2, c.Z), d.yaw), Vector3.new(d.width, d.depth + 4, d.length), M.Air)
			terrain:FillBlock(frame(Vector3.new(c.X, c.Y - d.depth - 1, c.Z), d.yaw), Vector3.new(d.width + 4, 4, d.length + 4), M.Mud)
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

	return { center = center }
end

return TerrainBuilder
