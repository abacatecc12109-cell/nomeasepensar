--[[
	Decorator
	---------
	Dá vida ao mundo: espalha vegetação por tema de região, ergue casas da
	vila, árvores gigantes, cachoeiras, templo, pagode e enfeita o chão em
	volta da montanha.

	Toda colocação passa pelo Clearance: nada encosta no percurso.
]]

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Config = require(Shared.Config)
local Builder = require(script.Parent.Builder)
local Nature = require(script.Parent.Nature)
local Structures = require(script.Parent.Structures)
local Water = require(script.Parent.Water)

local Decorator = {}
local P = Config.Palette

-- Densidade: itens por 100 studs² e pesos de cada tipo
local THEMES = {
	meadow = { density = 1.25, items = { cherry = 18, bush = 14, flowers = 40, rock = 6, mushroom = 4, lantern = 2 } },
	garden = { density = 1.3, items = { cherry = 22, bush = 14, flowers = 40, rock = 5, mushroom = 4, lantern = 2 } },
	hill = { density = 1.1, items = { cherry = 20, bush = 16, flowers = 30, rock = 10, mushroom = 6 } },
	grove = { density = 1.2, items = { cherry = 16, green = 10, bush = 16, flowers = 30, rock = 6, mushroom = 8 } },
	cliffbase = { density = 1.0, items = { green = 10, bush = 20, flowers = 20, rock = 14 } },
	orchard = { density = 1.2, items = { cherry = 30, bush = 10, flowers = 34, lantern = 3, rock = 4 } },
	village = { density = 0.55, items = { cherry = 10, bush = 18, flowers = 40, lantern = 6, rock = 2 } },
	village_high = { density = 0.8, items = { cherry = 18, bush = 16, flowers = 40, lantern = 4 } },
	village_ledge = { density = 0.9, items = { cherry = 16, bush = 18, flowers = 30, rock = 6 } },
	cliff_ledge = { density = 0.9, items = { green = 20, bush = 24, flowers = 16, rock = 16 } },
	cliff_mid = { density = 0.9, items = { green = 20, cherry = 6, bush = 24, flowers = 16, rock = 14 } },
	cliff_terrace = { density = 0.9, items = { green = 22, bush = 22, flowers = 14, rock = 16 } },
	cliff_high = { density = 0.9, items = { green = 20, cherry = 8, bush = 22, flowers = 18, rock = 12 } },
	cliff_top = { density = 0.9, items = { green = 22, bush = 22, flowers = 16, rock = 12 } },
	cliff_crown = { density = 0.9, items = { green = 22, bush = 22, flowers = 16, rock = 12 } },
	forest_floor = { density = 1.0, items = { green = 14, bush = 26, mushroom = 22, glowmushroom = 10, rock = 14, flowers = 8 } },
	celestial = { density = 1.0, items = { bigcherry = 14, glowflowers = 30, flowers = 22, bush = 10, lantern = 5 } },
	sanctuary = { density = 1.0, items = { bigcherry = 12, glowflowers = 34, flowers = 18, lantern = 6 } },
	summit = { density = 0.9, items = { cherry = 10, glowflowers = 36, flowers = 20, lantern = 4 } },
	massif = { density = 0.45, items = { cherry = 16, green = 16, bush = 20, flowers = 24, rock = 10 } },
}

local FOOTPRINT = {
	cherry = { r = 5.5, h = 16 },
	bigcherry = { r = 9, h = 30 },
	green = { r = 5, h = 16 },
	bush = { r = 2.4, h = 4 },
	flowers = { r = 1.3, h = 1.5 },
	glowflowers = { r = 1.3, h = 1.5 },
	rock = { r = 2.2, h = 3 },
	mushroom = { r = 1, h = 2 },
	glowmushroom = { r = 1.4, h = 3 },
	lantern = { r = 1, h = 5 },
}

local function pickWeighted(items, rng: Random): string
	local total = 0
	for _, w in items do
		total += w
	end
	local roll = rng:NextNumber(0, total)
	for name, w in items do
		roll -= w
		if roll <= 0 then
			return name
		end
	end
	return next(items)
end

local function spawnItem(kind: string, pos: Vector3, rng: Random, parent: Instance)
	if kind == "cherry" then
		Nature.cherryTree(pos, rng:NextNumber(0.85, 1.3), rng, parent)
	elseif kind == "bigcherry" then
		Nature.cherryTree(pos, rng:NextNumber(1.8, 2.5), rng, parent)
	elseif kind == "green" then
		Nature.greenTree(pos, rng:NextNumber(0.9, 1.35), rng, parent)
	elseif kind == "bush" then
		Nature.bush(pos, rng:NextNumber(0.8, 1.3), rng, parent)
	elseif kind == "flowers" then
		Nature.flowers(pos, rng, parent, false)
	elseif kind == "glowflowers" then
		Nature.flowers(pos, rng, parent, true)
	elseif kind == "rock" then
		Nature.rock(pos, rng:NextNumber(0.8, 1.6), rng, parent, rng:NextNumber() < 0.6)
	elseif kind == "mushroom" then
		Nature.mushroom(pos, rng:NextNumber(1, 2.2), rng, parent, false)
	elseif kind == "glowmushroom" then
		Nature.mushroom(pos, rng:NextNumber(2, 3.4), rng, parent, true)
	elseif kind == "lantern" then
		Structures.lantern(pos, parent, rng:NextNumber() < 0.25)
	end
end

local function tryPlace(kind: string, pos: Vector3, rng: Random, parent: Instance, clearance): boolean
	local fp = FOOTPRINT[kind] or { r = 2, h = 3 }
	if not clearance:isFreeAt(pos, fp.r, fp.h) then
		return false
	end
	spawnItem(kind, pos, rng, parent)
	clearance:reserve(pos - Vector3.new(fp.r * 0.7, 0, fp.r * 0.7), pos + Vector3.new(fp.r * 0.7, fp.h, fp.r * 0.7), "deco")
	return true
end

-- Espalha itens dentro de um retângulo orientado (grade com variação)
function Decorator.scatterRect(rect, themeName: string, rng: Random, parent: Instance, clearance)
	local theme = THEMES[themeName]
	if not theme then
		return 0
	end
	local cell = math.sqrt(100 / theme.density)
	local f = Vector3.new(math.sin(rect.yaw), 0, math.cos(rect.yaw))
	local r = Vector3.new(-math.cos(rect.yaw), 0, math.sin(rect.yaw))
	local placed = 0
	local margin = 2.5
	local nx = math.floor((rect.width - margin * 2) / cell)
	local nz = math.floor((rect.length - margin * 2) / cell)
	for ix = 0, nx do
		for iz = 0, nz do
			local side = -rect.width / 2 + margin + (ix + rng:NextNumber(0.1, 0.9)) * cell
			local along = -rect.length / 2 + margin + (iz + rng:NextNumber(0.1, 0.9)) * cell
			if math.abs(side) < rect.width / 2 - margin and math.abs(along) < rect.length / 2 - margin then
				local pos = Vector3.new(rect.center.X, rect.top, rect.center.Z) + r * side + f * along
				local kind = pickWeighted(theme.items, rng)
				if tryPlace(kind, pos, rng, parent, clearance) then
					placed += 1
				end
			end
		end
	end
	return placed
end

-- Casas decorativas nas laterais da vila (de frente para a rua)
local function villageHouses(zone, rng: Random, parent: Instance, clearance)
	local f = Vector3.new(math.sin(zone.yaw), 0, math.cos(zone.yaw))
	local r = Vector3.new(-math.cos(zone.yaw), 0, math.sin(zone.yaw))
	local colors = { P.RoofRed, P.RoofTeal, P.RoofPlum, Color3.fromRGB(196, 132, 84) }
	local count = 0
	for _, side in { -1, 1 } do
		local along = -zone.length / 2 + 12
		while along < zone.length / 2 - 10 do
			local w = rng:NextNumber(9, 12)
			local l = rng:NextNumber(9, 11)
			local h = rng:NextNumber(7, 10)
			local lateral = side * (zone.width / 2 - l / 2 - rng:NextNumber(3, 6))
			local pos = Vector3.new(zone.center.X, zone.top, zone.center.Z) + r * lateral + f * along
			local half = math.max(w, l) / 2 + 1
			if clearance:isFree(pos - Vector3.new(half, 0, half), pos + Vector3.new(half, h + 7, half)) then
				-- porta virada para a rua (centro da zona)
				local facing = -r * side
				local cf = CFrame.lookAt(pos, pos - facing)
				Structures.house(cf, w, l, h, rng, parent, colors[rng:NextInteger(1, #colors)])
				clearance:reserve(pos - Vector3.new(half, 0, half), pos + Vector3.new(half, h + 7, half), "house")
				-- canteiro na frente
				local bedPos = pos + facing * (l / 2 + 2.2)
				if clearance:isFreeAt(bedPos, 2.5, 2) then
					Structures.flowerBed(CFrame.lookAt(bedPos, bedPos + facing), 5, 2, rng, parent)
					clearance:reserve(bedPos - Vector3.new(2.5, 0, 2.5), bedPos + Vector3.new(2.5, 2, 2.5), "bed")
				end
				count += 1
			end
			along += w + rng:NextNumber(4, 8)
		end
	end
	return count
end

-- Lanternas de papel ao longo dos caminhos da vila
local function pathLanterns(zone, rng: Random, parent: Instance, clearance)
	for i = 1, #zone.path - 1 do
		local a, b = zone.path[i], zone.path[i + 1]
		local seg = Vector3.new(b.X - a.X, 0, b.Z - a.Z)
		local len = seg.Magnitude
		if len > 8 then
			local dir = seg.Unit
			local right = Vector3.new(-dir.Z, 0, dir.X)
			local t = 6
			local side = 1
			while t < len - 4 do
				local p = a + dir * t + right * (side * 5)
				if clearance:isFreeAt(p, 0.8, 5) then
					Builder.deco({ Size = Vector3.new(0.35, 4.2, 0.35), CFrame = CFrame.new(p + Vector3.new(0, 2.1, 0)), Color = P.WoodDark, Material = Enum.Material.Wood, Name = "LanternPost", Parent = parent })
					Structures.paperLantern(p + Vector3.new(0, 4.6, 0), parent, rng:NextNumber() < 0.2)
				end
				t += 13
				side = -side
			end
		end
	end
end

-- Chão em volta da montanha (florestas e prados ao redor)
local function decorateGround(layout, center: Vector3, rng: Random, parent: Instance, clearance)
	local blocked = {}
	for _, z in layout.zones do
		if z.surface == "terrain" and z.top > 0.5 then
			table.insert(blocked, z)
		end
	end
	for _, w in layout.walls do
		table.insert(blocked, w)
	end
	local water = {}
	for _, prop in layout.props do
		if prop.type == "stream" or prop.type == "lake" or prop.type == "ravine" then
			table.insert(water, prop.data)
		end
	end
	local function insideRect(rect, p: Vector3, margin: number): boolean
		local f = Vector3.new(math.sin(rect.yaw), 0, math.cos(rect.yaw))
		local r = Vector3.new(-math.cos(rect.yaw), 0, math.sin(rect.yaw))
		local rel = Vector3.new(p.X - rect.center.X, 0, p.Z - rect.center.Z)
		return math.abs(rel:Dot(f)) < rect.length / 2 + margin and math.abs(rel:Dot(r)) < rect.width / 2 + margin
	end
	local placed = 0
	-- bosques: aglomerados de árvores (mais natural do que espalhar uniforme)
	for _ = 1, 34 do
		local angle = rng:NextNumber(0, math.pi * 2)
		local dist = rng:NextNumber(260, 620)
		local groveCenter = center + Vector3.new(math.cos(angle) * dist, 0, math.sin(angle) * dist)
		local cherryGrove = rng:NextNumber() < 0.55
		for _ = 1, rng:NextInteger(4, 8) do
			local p = groveCenter + Vector3.new(rng:NextNumber(-26, 26), 0, rng:NextNumber(-26, 26))
			local ok = true
			for _, rect in blocked do
				if insideRect(rect, p, 6) then
					ok = false
					break
				end
			end
			for _, wd in water do
				if ok and insideRect(wd, p, 4) then
					ok = false
				end
			end
			if ok then
				local kind = cherryGrove and "cherry" or ((rng:NextNumber() < 0.7) and "green" or "cherry")
				if tryPlace(kind, p, rng, parent, clearance) then
					placed += 1
				end
				-- arbustos e flores ao redor de cada árvore
				for _ = 1, 2 do
					local q = p + Vector3.new(rng:NextNumber(-8, 8), 0, rng:NextNumber(-8, 8))
					tryPlace((rng:NextNumber() < 0.5) and "bush" or "flowers", q, rng, parent, clearance)
				end
			end
		end
	end
	-- flores soltas pelo prado mais perto do percurso
	for _ = 1, 160 do
		local angle = rng:NextNumber(0, math.pi * 2)
		local dist = rng:NextNumber(120, 420)
		local p = center + Vector3.new(math.cos(angle) * dist, 0, math.sin(angle) * dist)
		local ok = true
		for _, rect in blocked do
			if insideRect(rect, p, 4) then
				ok = false
				break
			end
		end
		for _, wd in water do
			if ok and insideRect(wd, p, 2) then
				ok = false
			end
		end
		if ok then
			tryPlace((rng:NextNumber() < 0.75) and "flowers" or "rock", p, rng, parent, clearance)
		end
	end
	return placed
end

-- Árvores gigantes decorativas no chão da floresta
local function forestGiants(zone, rng: Random, parent: Instance, clearance)
	local f = Vector3.new(math.sin(zone.yaw), 0, math.cos(zone.yaw))
	local r = Vector3.new(-math.cos(zone.yaw), 0, math.sin(zone.yaw))
	for _ = 1, 10 do
		local p = Vector3.new(zone.center.X, zone.top - 2, zone.center.Z) + r * rng:NextNumber(-zone.width / 2 + 8, zone.width / 2 - 8) + f * rng:NextNumber(-zone.length / 2 + 8, zone.length / 2 - 8)
		local radius = rng:NextNumber(4, 6.5)
		local height = rng:NextNumber(90, 130)
		local half = Vector3.new(radius + 2, 0, radius + 2)
		if clearance:isFree(p - half, p + half + Vector3.new(0, height, 0)) then
			Nature.giantTree({ center = p, radius = radius, height = height, canopy = true, name = "ArvoreDaNevoa" }, rng, parent, clearance)
			clearance:reserve(p - half, p + half + Vector3.new(0, height, 0), "giant")
		end
	end
end

function Decorator.build(layout, root: Instance, rng: Random, clearance, worldInfo)
	local regionFolders = {}
	local function folderFor(region: number)
		local f = regionFolders[region]
		if not f then
			f = Builder.folder(string.format("Regiao%d", region), root)
			regionFolders[region] = f
		end
		return f
	end

	-- 1) marcos (props) primeiro: ocupam espaço antes da vegetação
	for _, prop in layout.props do
		local d = prop.data
		local parent = folderFor(prop.region)
		if prop.type == "gianttree" then
			Nature.giantTree(d, rng, parent, clearance)
		elseif prop.type == "waterfall" then
			Water.waterfall(d, parent)
			if d.pool then
				local f = Vector3.new(math.sin(d.yaw), 0, math.cos(d.yaw))
				local r = d.width / 2 + 2
				local c = d.top - Vector3.new(0, d.drop, 0) + f * r
				clearance:reserve(c - Vector3.new(r, 2, r), c + Vector3.new(r, 4, r), "pool")
			end
		elseif prop.type == "bench" then
			Structures.bench(d.position, d.yaw + math.rad(90), parent)
			clearance:reserve(d.position - Vector3.new(3, 0, 3), d.position + Vector3.new(3, 3, 3), "bench")
		elseif prop.type == "well" then
			Structures.well(d.position, parent)
			clearance:reserve(d.position - Vector3.new(3.5, 0, 3.5), d.position + Vector3.new(3.5, 8, 3.5), "well")
		elseif prop.type == "gazebo" then
			Structures.gazebo(d.position, d.yaw, parent)
			clearance:reserve(d.position - Vector3.new(7, 0, 7), d.position + Vector3.new(7, 12, 7), "gazebo")
		elseif prop.type == "windmill" then
			Structures.windmill(d.position, d.yaw + math.rad(90), parent)
			clearance:reserve(d.position - Vector3.new(6, 0, 6), d.position + Vector3.new(6, 26, 6), "windmill")
		elseif prop.type == "temple" then
			Structures.temple(d.position, d.yaw, rng, parent)
			clearance:reserve(d.position - Vector3.new(13, 0, 13), d.position + Vector3.new(13, 18, 13), "temple")
		elseif prop.type == "pagoda" then
			Structures.pagoda(d.position, d.yaw, parent)
		elseif prop.type == "pond" then
			Water.lilies(d.center, d.radius - 1, rng, parent, 5)
			clearance:reserve(d.center - Vector3.new(d.radius, 2, d.radius), d.center + Vector3.new(d.radius, 3, d.radius), "pond")
		elseif prop.type == "river" or prop.type == "stream" then
			local ext = math.max(d.width, d.length) / 2 + 1.5
			if math.max(d.width, d.length) < 60 then
				clearance:reserve(d.center - Vector3.new(ext, 2, ext), d.center + Vector3.new(ext, 3, ext), "river")
			end
			for i = 1, 4 do
				local f = Vector3.new(math.sin(d.yaw), 0, math.cos(d.yaw))
				local r = Vector3.new(-math.cos(d.yaw), 0, math.sin(d.yaw))
				local side = (i % 2 == 0) and 1 or -1
				local p = d.center + Vector3.new(0, 0.6, 0) + r * side * (d.width / 2 + 1) + f * rng:NextNumber(-d.length / 2, d.length / 2)
				if math.max(d.width, d.length) < 60 and clearance:isFreeAt(p, 1, 3) then
					Nature.reeds(p, rng, parent)
				end
			end
		elseif prop.type == "lake" then
			local reach = math.min(d.width, d.length) / 2 - 2
			if d.decorative then
				Water.lilies(d.center, reach, rng, parent, 10)
			end
			local halfW, halfL = d.width / 2, d.length / 2
			local ext = math.max(halfW, halfL)
			clearance:reserve(d.center - Vector3.new(ext, 2, ext), d.center + Vector3.new(ext, 2, ext), "lake")
		end
	end

	-- 2) vila: casas nas laterais e lanternas nas ruas
	for _, zone in layout.zones do
		if zone.theme == "village" or zone.theme == "village_high" then
			villageHouses(zone, rng, folderFor(zone.region), clearance)
			pathLanterns(zone, rng, folderFor(zone.region), clearance)
		elseif zone.theme == "forest_floor" then
			forestGiants(zone, rng, folderFor(zone.region), clearance)
		end
	end

	-- 3) vegetação por tema em cada platô
	local total = 0
	for _, zone in layout.zones do
		if zone.surface == "terrain" then
			total += Decorator.scatterRect(zone, zone.theme, rng, folderFor(zone.region), clearance)
		end
	end
	-- topos dos maciços (visíveis de longe)
	for _, wall in layout.walls do
		if wall.theme == "massif" then
			total += Decorator.scatterRect(wall, "massif", rng, folderFor(wall.region), clearance)
		end
	end

	-- 4) chão em volta da montanha
	local groundFolder = Builder.folder("Arredores", root)
	total += decorateGround(layout, worldInfo.center, rng, groundFolder, clearance)
	return total
end

return Decorator
