--[[
	Structures
	----------
	Construções de pedra e madeira: casas, torre do sino, moinho, poço,
	banco, gazebo, templo, pagode, lanternas, cercas e canteiros.

	Todas recebem um CFrame no CHÃO (centro da base, olhando para a frente).
]]

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Config = require(Shared.Config)
local Builder = require(script.Parent.Builder)

local Structures = {}
local P = Config.Palette
local M = Enum.Material

local lightBudget = 40 -- luzes dinâmicas custam caro no celular
Structures.lightsUsed = 0

local function light(parent: BasePart, range: number, brightness: number)
	if Structures.lightsUsed >= lightBudget then
		return
	end
	Structures.lightsUsed += 1
	local l = Instance.new("PointLight")
	l.Color = P.Lantern
	l.Range = range
	l.Brightness = brightness
	l.Shadows = false
	l.Parent = parent
end

-- Telhado de duas águas (2 cunhas + cumeeira).
-- A face alta de uma WedgePart fica no +Z local; giramos para que ela
-- encoste no centro (cumeeira).
local function gableRoof(model: Model, cf: CFrame, w: number, l: number, h: number, color: Color3)
	local half = w / 2 + 0.6
	Builder.wedge({
		Size = Vector3.new(l + 1.2, h, half),
		CFrame = cf * CFrame.new(-half / 2, h / 2, 0) * CFrame.Angles(0, math.rad(90), 0),
		Color = color,
		Material = M.Slate,
		Name = "Roof",
		Parent = model,
	})
	Builder.wedge({
		Size = Vector3.new(l + 1.2, h, half),
		CFrame = cf * CFrame.new(half / 2, h / 2, 0) * CFrame.Angles(0, math.rad(-90), 0),
		Color = color,
		Material = M.Slate,
		Name = "Roof",
		Parent = model,
	})
	Builder.deco({
		Size = Vector3.new(0.6, 0.6, l + 1.6),
		CFrame = cf * CFrame.new(0, h, 0),
		Color = P.WoodDark,
		Material = M.Wood,
		Name = "Ridge",
		Parent = model,
	})
end

-- Paredes com vigas de madeira, porta, janelas e floreiras
local function walls(model: Model, cf: CFrame, w: number, l: number, h: number, rng: Random)
	Builder.solid({
		Size = Vector3.new(w, h, l),
		CFrame = cf * CFrame.new(0, h / 2, 0),
		Color = Builder.vary(P.Plaster, rng, 0.02),
		Material = M.SmoothPlastic,
		Name = "Walls",
		Parent = model,
	})
	-- vigas nos cantos
	for _, sx in { -1, 1 } do
		for _, sz in { -1, 1 } do
			Builder.deco({
				Size = Vector3.new(0.7, h, 0.7),
				CFrame = cf * CFrame.new(sx * (w / 2 - 0.1), h / 2, sz * (l / 2 - 0.1)),
				Color = P.WoodDark,
				Material = M.Wood,
				Name = "Beam",
				Parent = model,
			})
		end
	end
	-- faixa de madeira entre andares
	if h > 8 then
		for _, y in { h * 0.5 } do
			Builder.deco({
				Size = Vector3.new(w + 0.3, 0.5, l + 0.3),
				CFrame = cf * CFrame.new(0, y, 0),
				Color = P.WoodDark,
				Material = M.Wood,
				Name = "Band",
				Parent = model,
			})
		end
	end
	-- porta (fachada da frente = -Z local)
	Builder.deco({
		Size = Vector3.new(2.4, 4, 0.3),
		CFrame = cf * CFrame.new(0, 2, -l / 2 - 0.1),
		Color = P.Wood,
		Material = M.Wood,
		Name = "Door",
		Parent = model,
	})
	-- janelas com floreiras nas laterais
	local rows = math.max(1, math.floor(h / 6))
	for row = 1, rows do
		local y = math.min(h - 2, 2 + row * (h - 2) / (rows + 0.6))
		for _, side in { -1, 1 } do
			local wcf = cf * CFrame.new(side * (w / 2 + 0.1), y, 0) * CFrame.Angles(0, math.rad(90 * side), 0)
			Builder.deco({ Size = Vector3.new(2, 2, 0.3), CFrame = wcf, Color = Color3.fromRGB(150, 196, 214), Material = M.Glass, Transparency = 0.2, Name = "Window", Parent = model })
			Builder.deco({ Size = Vector3.new(2.4, 0.6, 0.7), CFrame = wcf * CFrame.new(0, -1.3, -0.3), Color = P.WoodDark, Material = M.Wood, Name = "Planter", Parent = model })
			for k = -1, 1 do
				Builder.deco({
					Shape = Enum.PartType.Ball,
					Size = Vector3.new(0.6, 0.6, 0.6),
					CFrame = wcf * CFrame.new(k * 0.7, -0.85, -0.3),
					Color = P.FlowerColors[rng:NextInteger(1, #P.FlowerColors)],
					CastShadow = false,
					Name = "Flower",
					Parent = model,
				})
			end
		end
	end
end

-- Casa decorativa com telhado de duas águas
function Structures.house(cf: CFrame, w: number, l: number, h: number, rng: Random, parent: Instance, roofColor: Color3?)
	local model = Builder.model("Casa", parent)
	walls(model, cf, w, l, h, rng)
	gableRoof(model, cf * CFrame.new(0, h, 0), w, l, math.min(w * 0.45, 6), roofColor or P.RoofRed)
	-- chaminé
	if rng:NextNumber() < 0.6 then
		Builder.deco({ Size = Vector3.new(1.2, 4, 1.2), CFrame = cf * CFrame.new(w * 0.22, h + 3, l * 0.2), Color = P.RockLight, Material = M.Brick, Name = "Chimney", Parent = model })
	end
	return model
end

-- Corpo de casa sob um telhado-terraço do percurso (o piso é o colisor da peça)
function Structures.terraceHouse(topCF: CFrame, w: number, l: number, groundY: number, floorThickness: number, rng: Random, parent: Instance, roofColor: Color3?)
	local model = Builder.model("CasaTerraco", parent)
	local topY = topCF.Position.Y - floorThickness
	local h = topY - groundY
	local groundCF = CFrame.new(topCF.Position.X, groundY, topCF.Position.Z) * topCF.Rotation
	if h > 1 then
		walls(model, groundCF, w - 0.6, l - 0.6, h, rng)
	end
	-- beiral colorido em volta do terraço
	Builder.deco({
		Size = Vector3.new(w + 0.8, 0.8, l + 0.8),
		CFrame = topCF * CFrame.new(0, -floorThickness - 0.4, 0),
		Color = roofColor or P.RoofRed,
		Material = M.Slate,
		Name = "Eave",
		Parent = model,
	})
	-- grade baixa nas laterais (frente e trás ficam livres para o percurso)
	for _, side in { -1, 1 } do
		Builder.deco({
			Size = Vector3.new(0.3, 1.2, l - 1),
			CFrame = topCF * CFrame.new(side * (w / 2 - 0.2), 0.6, 0),
			Color = P.WoodDark,
			Material = M.Wood,
			Name = "Rail",
			Parent = model,
		})
	end
	-- vasos de flores nos cantos
	for _, sx in { -1, 1 } do
		for _, sz in { -1, 1 } do
			local pcf = topCF * CFrame.new(sx * (w / 2 - 0.9), 0.4, sz * (l / 2 - 0.9))
			Builder.deco({ Size = Vector3.new(1, 0.8, 1), CFrame = pcf, Color = Color3.fromRGB(180, 110, 80), Material = M.Brick, Name = "Pot", Parent = model })
			Builder.ball(pcf.Position + Vector3.new(0, 0.7, 0), 0.6, { Color = P.FlowerColors[rng:NextInteger(1, #P.FlowerColors)], Name = "Flower", Parent = model })
		end
	end
	return model
end

-- Corpo de torre (pedra embaixo, madeira em cima)
function Structures.towerBody(topCF: CFrame, w: number, l: number, groundY: number, floorThickness: number, rng: Random, parent: Instance, withRoof: boolean)
	local model = Builder.model("Torre", parent)
	local topY = topCF.Position.Y - floorThickness
	local h = topY - groundY
	local groundCF = CFrame.new(topCF.Position.X, groundY, topCF.Position.Z) * topCF.Rotation
	local stoneH = math.min(h, math.max(6, h * 0.45))
	Builder.solid({ Size = Vector3.new(w, stoneH, l), CFrame = groundCF * CFrame.new(0, stoneH / 2, 0), Color = P.RockLight, Material = M.Cobblestone, Name = "Stone", Parent = model })
	if h - stoneH > 0.5 then
		Builder.solid({ Size = Vector3.new(w - 0.8, h - stoneH, l - 0.8), CFrame = groundCF * CFrame.new(0, stoneH + (h - stoneH) / 2, 0), Color = P.Plaster, Name = "Upper", Parent = model })
		for _, sx in { -1, 1 } do
			for _, sz in { -1, 1 } do
				Builder.deco({ Size = Vector3.new(0.8, h - stoneH, 0.8), CFrame = groundCF * CFrame.new(sx * (w / 2 - 0.5), stoneH + (h - stoneH) / 2, sz * (l / 2 - 0.5)), Color = P.WoodDark, Material = M.Wood, Name = "Beam", Parent = model })
			end
		end
	end
	if withRoof then
		-- postes nos cantos e telhado alto com sino
		local postH = 8
		for _, sx in { -1, 1 } do
			for _, sz in { -1, 1 } do
				Builder.solid({ Size = Vector3.new(0.8, postH, 0.8), CFrame = topCF * CFrame.new(sx * (w / 2 - 0.5), postH / 2, sz * (l / 2 - 0.5)), Color = P.WoodDark, Material = M.Wood, Name = "Post", Parent = model })
			end
		end
		local roofCF = topCF * CFrame.new(0, postH, 0)
		gableRoof(model, roofCF, w, l, 5, P.RoofTeal)
		local bell = Builder.deco({ Shape = Enum.PartType.Ball, Size = Vector3.new(2, 2.2, 2), CFrame = roofCF * CFrame.new(0, -1.6, 0), Color = Color3.fromRGB(210, 170, 90), Material = M.Metal, Name = "Bell", Parent = model })
		light(bell, 14, 0.8)
	end
	return model
end

-- Lanterna de pedra (estilo jardim)
function Structures.lantern(position: Vector3, parent: Instance, withLight: boolean?)
	local model = Builder.model("Lanterna", parent)
	Builder.deco({ Size = Vector3.new(1.4, 0.5, 1.4), CFrame = CFrame.new(position + Vector3.new(0, 0.25, 0)), Color = P.RockLight, Material = M.Slate, Name = "Base", Parent = model })
	Builder.deco({ Size = Vector3.new(0.6, 2.4, 0.6), CFrame = CFrame.new(position + Vector3.new(0, 1.7, 0)), Color = P.RockLight, Material = M.Slate, Name = "Pillar", Parent = model })
	local lamp = Builder.deco({ Size = Vector3.new(1.2, 1, 1.2), CFrame = CFrame.new(position + Vector3.new(0, 3.4, 0)), Color = P.Lantern, Material = M.Neon, Name = "Lamp", Parent = model })
	Builder.wedge({ Size = Vector3.new(1.8, 0.7, 0.9), CFrame = CFrame.new(position + Vector3.new(0, 4.25, 0.45)) * CFrame.Angles(0, math.pi, 0), Color = P.RockDark, Material = M.Slate, CanCollide = false, Name = "Cap", Parent = model })
	Builder.wedge({ Size = Vector3.new(1.8, 0.7, 0.9), CFrame = CFrame.new(position + Vector3.new(0, 4.25, -0.45)), Color = P.RockDark, Material = M.Slate, CanCollide = false, Name = "Cap", Parent = model })
	if withLight then
		light(lamp, 12, 0.7)
	end
	return model
end

-- Lanterna de papel pendurada (vila e floresta)
function Structures.paperLantern(position: Vector3, parent: Instance, withLight: boolean?)
	local lamp = Builder.deco({
		Shape = Enum.PartType.Ball,
		Size = Vector3.new(1.3, 1.6, 1.3),
		CFrame = CFrame.new(position),
		Color = Color3.fromRGB(255, 196, 160),
		Material = M.Neon,
		Name = "PaperLantern",
		Parent = parent,
	})
	if withLight then
		light(lamp, 10, 0.6)
	end
	return lamp
end

function Structures.fence(a: Vector3, b: Vector3, parent: Instance)
	local dir = (b - a)
	local n = math.max(1, math.floor(dir.Magnitude / 4))
	for i = 0, n do
		local p = a:Lerp(b, i / n)
		Builder.deco({ Size = Vector3.new(0.4, 2, 0.4), CFrame = CFrame.new(p + Vector3.new(0, 1, 0)), Color = P.WoodLight, Material = M.Wood, Name = "FencePost", Parent = parent })
	end
	for _, y in { 0.8, 1.6 } do
		Builder.cylinder(a + Vector3.new(0, y, 0), b + Vector3.new(0, y, 0), 0.12, { Color = P.WoodLight, Material = M.Wood, Name = "FenceRail", Parent = parent })
	end
end

function Structures.well(position: Vector3, parent: Instance)
	local model = Builder.model("Poco", parent)
	Builder.cylinder(position, position + Vector3.new(0, 2.2, 0), 2.2, { Color = P.RockLight, Material = M.Cobblestone, Name = "Wall", Parent = model }, false)
	Builder.cylinder(position + Vector3.new(0, 2.2, 0), position + Vector3.new(0, 2.3, 0), 1.8, { Color = P.Water, Material = M.Glass, Transparency = 0.3, Name = "Water", Parent = model })
	for _, s in { -1, 1 } do
		Builder.deco({ Size = Vector3.new(0.4, 4.5, 0.4), CFrame = CFrame.new(position + Vector3.new(s * 1.9, 3.4, 0)), Color = P.WoodDark, Material = M.Wood, Name = "Post", Parent = model })
	end
	local roofCF = CFrame.new(position + Vector3.new(0, 5.6, 0))
	gableRoof(model, roofCF, 4.6, 3.2, 1.6, P.RoofRed)
	return model
end

function Structures.bench(position: Vector3, yaw: number, parent: Instance)
	local cf = CFrame.new(position) * CFrame.Angles(0, yaw, 0)
	local model = Builder.model("Banco", parent)
	Builder.solid({ Size = Vector3.new(4, 0.4, 1.4), CFrame = cf * CFrame.new(0, 1.2, 0), Color = P.Wood, Material = M.Wood, Name = "Seat", Parent = model })
	Builder.deco({ Size = Vector3.new(4, 1.2, 0.3), CFrame = cf * CFrame.new(0, 2, 0.6), Color = P.Wood, Material = M.Wood, Name = "Back", Parent = model })
	for _, s in { -1, 1 } do
		Builder.deco({ Size = Vector3.new(0.4, 1.1, 1.2), CFrame = cf * CFrame.new(s * 1.6, 0.55, 0), Color = P.WoodDark, Material = M.Wood, Name = "Leg", Parent = model })
	end
	return model
end

-- Gazebo de madeira com telhado
function Structures.gazebo(position: Vector3, yaw: number, parent: Instance)
	local cf = CFrame.new(position) * CFrame.Angles(0, yaw, 0)
	local model = Builder.model("Gazebo", parent)
	Builder.solid({ Size = Vector3.new(10, 0.6, 10), CFrame = cf * CFrame.new(0, 0.3, 0), Color = P.WoodLight, Material = M.WoodPlanks, Name = "Floor", Parent = model })
	for _, sx in { -1, 1 } do
		for _, sz in { -1, 1 } do
			Builder.solid({ Size = Vector3.new(0.7, 7, 0.7), CFrame = cf * CFrame.new(sx * 4.4, 3.8, sz * 4.4), Color = P.WoodDark, Material = M.Wood, Name = "Post", Parent = model })
		end
	end
	gableRoof(model, cf * CFrame.new(0, 7.3, 0), 10, 10, 3.5, P.RoofPlum)
	local lamp = Structures.paperLantern((cf * CFrame.new(0, 6, 0)).Position, model, true)
	lamp.Name = "Lamp"
	return model
end

-- Moinho de vento (as pás giram no cliente)
function Structures.windmill(position: Vector3, yaw: number, parent: Instance)
	local cf = CFrame.new(position) * CFrame.Angles(0, yaw, 0)
	local model = Builder.model("Moinho", parent)
	Builder.solid({ Size = Vector3.new(8, 14, 8), CFrame = cf * CFrame.new(0, 7, 0), Color = P.Plaster, Name = "Body", Parent = model })
	Builder.solid({ Size = Vector3.new(7, 6, 7), CFrame = cf * CFrame.new(0, 17, 0), Color = P.WoodLight, Material = M.WoodPlanks, Name = "Top", Parent = model })
	gableRoof(model, cf * CFrame.new(0, 20, 0), 7, 7, 3.5, P.RoofRed)
	local hub = Builder.deco({ Shape = Enum.PartType.Ball, Size = Vector3.new(1.6, 1.6, 1.6), CFrame = cf * CFrame.new(0, 17, -4.4), Color = P.WoodDark, Material = M.Wood, Name = "Hub", Parent = model })
	local blades = Builder.model("Blades", model)
	for i = 0, 3 do
		local a = math.rad(i * 90)
		local bcf = hub.CFrame * CFrame.Angles(0, 0, a) * CFrame.new(0, 5, -0.4)
		Builder.deco({ Size = Vector3.new(1.6, 9, 0.2), CFrame = bcf, Color = P.Plaster, Name = "Sail", Parent = blades })
		Builder.deco({ Size = Vector3.new(0.3, 10, 0.3), CFrame = bcf * CFrame.new(-0.9, 0, 0), Color = P.WoodDark, Material = M.Wood, Name = "Spar", Parent = blades })
	end
	blades.WorldPivot = hub.CFrame
	blades:SetAttribute("SpinAxis", "Z")
	blades:SetAttribute("SpinSpeed", 0.6)
	blades:AddTag("Spin")
	return model
end

-- Templo de pedra e madeira (jardim celestial)
function Structures.temple(position: Vector3, yaw: number, rng: Random, parent: Instance)
	local cf = CFrame.new(position) * CFrame.Angles(0, yaw, 0)
	local model = Builder.model("Templo", parent)
	Builder.solid({ Size = Vector3.new(22, 1.6, 16), CFrame = cf * CFrame.new(0, 0.8, 0), Color = Color3.fromRGB(226, 222, 214), Material = M.Marble, Name = "Plinth", Parent = model })
	for _, sx in { -1, -0.33, 0.33, 1 } do
		for _, sz in { -1, 1 } do
			Builder.solid({ Size = Vector3.new(1, 9, 1), CFrame = cf * CFrame.new(sx * 9.5, 6.1, sz * 6.5), Color = Color3.fromRGB(190, 90, 84), Material = M.Wood, Name = "Column", Parent = model })
		end
	end
	Builder.deco({ Size = Vector3.new(23, 1, 17), CFrame = cf * CFrame.new(0, 11, 0), Color = P.WoodDark, Material = M.Wood, Name = "Beam", Parent = model })
	gableRoof(model, cf * CFrame.new(0, 11.5, 0), 22, 18, 5, P.RoofTeal)
	Builder.deco({ Size = Vector3.new(6, 3.5, 4), CFrame = cf * CFrame.new(0, 3.35, 0), Color = Color3.fromRGB(236, 226, 206), Material = M.Marble, Name = "Altar", Parent = model })
	local orb = Builder.ball((cf * CFrame.new(0, 6.2, 0)).Position, 1.1, { Color = P.Glow, Material = M.Neon, Name = "Orb", Parent = model })
	light(orb, 16, 1)
	return model
end

-- Pagode do mirante (chegada): andares de telhados sobre o topo
function Structures.pagoda(position: Vector3, yaw: number, parent: Instance)
	local cf = CFrame.new(position) * CFrame.Angles(0, yaw, 0)
	local model = Builder.model("Pagode", parent)
	-- postes nos cantos de um quadrado largo (o centro fica livre)
	local half = 9
	for _, sx in { -1, 1 } do
		for _, sz in { -1, 1 } do
			Builder.solid({ Size = Vector3.new(1.2, 10, 1.2), CFrame = cf * CFrame.new(sx * half, 5, sz * half), Color = Color3.fromRGB(190, 90, 84), Material = M.Wood, Name = "Post", Parent = model })
		end
	end
	local y = 10
	for tier = 1, 3 do
		local w = 22 - tier * 4
		gableRoof(model, cf * CFrame.new(0, y, 0), w, w, 3, tier % 2 == 1 and P.RoofTeal or P.RoofPlum)
		y += 4.5
		if tier < 3 then
			Builder.deco({ Size = Vector3.new(w - 5, 1.5, w - 5), CFrame = cf * CFrame.new(0, y - 1, 0), Color = Color3.fromRGB(190, 90, 84), Material = M.Wood, Name = "Tier", Parent = model })
		end
	end
	local spire = Builder.deco({ Size = Vector3.new(0.6, 6, 0.6), CFrame = cf * CFrame.new(0, y + 2, 0), Color = Color3.fromRGB(220, 180, 90), Material = M.Metal, Name = "Spire", Parent = model })
	Builder.ball(spire.Position + Vector3.new(0, 3.4, 0), 0.9, { Color = Color3.fromRGB(255, 220, 140), Material = M.Neon, Name = "Jewel", Parent = model })
	for _, sx in { -1, 1 } do
		for _, sz in { -1, 1 } do
			local lamp = Structures.paperLantern((cf * CFrame.new(sx * (half - 1.5), 8.5, sz * (half - 1.5))).Position, model, sx == sz)
			lamp.Name = "Lamp"
		end
	end
	return model
end

-- Canteiro de flores retangular com borda de madeira
function Structures.flowerBed(cf: CFrame, w: number, l: number, rng: Random, parent: Instance)
	local model = Builder.model("Canteiro", parent)
	Builder.deco({ Size = Vector3.new(w, 0.6, l), CFrame = cf * CFrame.new(0, 0.3, 0), Color = P.Ground, Material = M.Ground, Name = "Soil", Parent = model })
	for _, s in { -1, 1 } do
		Builder.deco({ Size = Vector3.new(w + 0.4, 0.8, 0.3), CFrame = cf * CFrame.new(0, 0.4, s * l / 2), Color = P.WoodLight, Material = M.Wood, Name = "Edge", Parent = model })
		Builder.deco({ Size = Vector3.new(0.3, 0.8, l), CFrame = cf * CFrame.new(s * w / 2, 0.4, 0), Color = P.WoodLight, Material = M.Wood, Name = "Edge", Parent = model })
	end
	local count = math.floor(w * l / 3)
	for _ = 1, count do
		local p = cf * CFrame.new(rng:NextNumber(-w / 2 + 0.5, w / 2 - 0.5), 0.9, rng:NextNumber(-l / 2 + 0.5, l / 2 - 0.5))
		Builder.ball(p.Position, rng:NextNumber(0.3, 0.45), { Color = P.FlowerColors[rng:NextInteger(1, #P.FlowerColors)], CastShadow = false, Name = "Flower", Parent = model })
	end
	return model
end

return Structures
