--[[
	Pieces
	------
	Transforma cada elemento do layout em peças do Roblox.

	Regra de ouro: a superfície pisável SEMPRE corresponde exatamente aos
	dados do layout (largura, comprimento, altura). Quando o visual é
	irregular (troncos redondos, cogumelos, pedras), usamos um colisor
	invisível exato e o visual vira decoração sem colisão.

	Obstáculos dinâmicos recebem Tags + Atributos; quem os anima é o cliente
	(ObstacleController), o que deixa o movimento suave e por jogador.
]]

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Config = require(Shared.Config)
local World = script.Parent.Parent.World
local Builder = require(World.Builder)
local Structures = require(World.Structures)
local Clouds = require(World.Clouds)

local Pieces = {}
local P = Config.Palette
local M = Enum.Material
local Tags = Config.Tags

-- ===================================================================
-- Utilidades
-- ===================================================================

-- Frame inclinado que passa pela entrada e saída (superfície de cima)
local function slopeFrame(e): (CFrame, number)
	local length = (e.exit - e.entry).Magnitude
	if length < 0.01 then
		return Builder.frameOf(e.center, e.yaw), e.length
	end
	return CFrame.lookAt((e.entry + e.exit) / 2, e.exit), length
end

-- Caixa sólida cujo topo passa pelo frame dado
local function topBox(cf: CFrame, w: number, thickness: number, l: number, props)
	props.Size = Vector3.new(w, thickness, l)
	props.CFrame = cf * CFrame.new(0, -thickness / 2, 0)
	return Builder.solid(props)
end

local function topCollider(cf: CFrame, w: number, thickness: number, l: number, parent: Instance)
	return Builder.collider({
		Size = Vector3.new(w, thickness, l),
		CFrame = cf * CFrame.new(0, -thickness / 2, 0),
		Parent = parent,
	})
end

-- Paredes invisíveis baixas nas laterais (pontes seguras)
local function sideGuards(cf: CFrame, w: number, l: number, height: number, parent: Instance)
	for _, s in { -1, 1 } do
		local g = Builder.collider({
			Size = Vector3.new(0.4, height, l),
			CFrame = cf * CFrame.new(s * (w / 2 + 0.2), height / 2, 0),
			Name = "Guard",
			Parent = parent,
		})
		g.CanQuery = false
	end
end

local function verticalCylinder(position: Vector3, height: number, radius: number, props, solid: boolean)
	local a = position
	local b = position + Vector3.new(0, height, 0)
	return Builder.cylinder(a, b, radius, props, not solid)
end

-- ===================================================================
-- Plataformas (pads)
-- ===================================================================

local padStyles = {}

function padStyles.riverstone(e, cf, parent, rng)
	local s = topBox(cf, e.width, 4, e.length, { Color = Builder.vary(P.RockLight, rng, 0.04), Material = M.Slate, Name = "Stone", Parent = parent })
	-- musgo e seixos ao redor (decorativos, abaixo do topo)
	Builder.deco({ Size = Vector3.new(e.width * 0.7, 0.2, e.length * 0.5), CFrame = cf * CFrame.new(rng:NextNumber(-0.5, 0.5), 0.05, 0), Color = P.Moss, Material = M.Grass, Name = "Moss", Parent = parent })
	for i = 1, 3 do
		local a = (i / 3) * math.pi * 2
		Builder.deco({
			Size = Vector3.new(1.6, 1.2, 1.4),
			CFrame = cf * CFrame.new(math.cos(a) * (e.width / 2 + 0.4), -1.4, math.sin(a) * (e.length / 2 + 0.4)) * CFrame.Angles(0.3, a, 0.2),
			Color = P.Rock,
			Material = M.Slate,
			Name = "Pebble",
			Parent = parent,
		})
	end
	return s
end

function padStyles.stump(e, cf, parent, rng)
	local ground = e.support or (cf.Position.Y - 3)
	local height = cf.Position.Y - ground
	local top = cf.Position
	-- tronco cortado (colisor cilíndrico do tamanho exato da plataforma)
	verticalCylinder(Vector3.new(top.X, ground - 0.5, top.Z), height + 0.5, e.width / 2, { Color = P.Bark, Material = M.Wood, Name = "Stump", Parent = parent }, true)
	verticalCylinder(Vector3.new(top.X, top.Y - 0.05, top.Z), 0.1, e.width / 2 - 0.35, { Color = P.WoodLight, Material = M.Wood, Name = "Rings", Parent = parent }, false)
	-- raízes
	for i = 1, 4 do
		local a = (i / 4) * math.pi * 2 + rng:NextNumber(-0.3, 0.3)
		local dir = Vector3.new(math.cos(a), 0, math.sin(a))
		local from = Vector3.new(top.X, ground + 1.2, top.Z) + dir * (e.width / 2 - 0.3)
		Builder.cylinder(from, from + dir * 2.4 + Vector3.new(0, -1.4, 0), 0.45, { Color = P.Bark, Material = M.Wood, Name = "Root", Parent = parent })
	end
end

function padStyles.boulder(e, cf, parent, rng)
	local ground = e.support or (cf.Position.Y - 6)
	local height = cf.Position.Y - ground + 1
	local body = Builder.solid({
		Size = Vector3.new(e.width, height, e.length),
		CFrame = cf * CFrame.new(0, -height / 2, 0),
		Color = Builder.vary(P.Rock, rng, 0.04),
		Material = M.Slate,
		Name = "Boulder",
		Parent = parent,
	})
	-- volumes irregulares nas laterais (abaixo do topo)
	for i = 1, 4 do
		local a = (i / 4) * math.pi * 2 + 0.4
		local s = rng:NextNumber(2.4, 3.6)
		Builder.deco({
			Size = Vector3.new(s, math.min(height * 0.7, s * 1.6), s),
			CFrame = cf * CFrame.new(math.cos(a) * e.width * 0.42, -math.min(height * 0.35, s * 0.8) - 1, math.sin(a) * e.length * 0.42) * CFrame.Angles(0.2, a, -0.15),
			Color = Builder.vary(P.RockDark, rng, 0.04),
			Material = M.Slate,
			Name = "Chunk",
			Parent = parent,
		})
	end
	Builder.deco({ Size = Vector3.new(e.width * 0.8, 0.2, e.length * 0.6), CFrame = cf * CFrame.new(0, 0.05, rng:NextNumber(-0.5, 0.5)), Color = P.Moss, Material = M.Grass, CastShadow = false, Name = "Moss", Parent = parent })
	return body
end

padStyles.cliffrock = padStyles.boulder

function padStyles.pillar(e, cf, parent, rng)
	local ground = e.support or (cf.Position.Y - 30)
	local height = cf.Position.Y - ground
	Builder.solid({
		Size = Vector3.new(e.width, height, e.length),
		CFrame = cf * CFrame.new(0, -height / 2, 0),
		Color = Builder.vary(Color3.fromRGB(118, 120, 116), rng, 0.04),
		Material = M.Slate,
		Name = "Pillar",
		Parent = parent,
	})
	-- base mais larga e faixas de rocha (quebra a forma reta)
	for i = 1, 3 do
		local y = -height * (0.25 + i * 0.2)
		local grow = 1 + i * 0.6
		Builder.deco({
			Size = Vector3.new(e.width + grow, height * 0.22, e.length + grow * 0.8),
			CFrame = cf * CFrame.new(0, y, 0) * CFrame.Angles(0, rng:NextNumber(-0.3, 0.3), 0),
			Color = Builder.vary(P.RockDark, rng, 0.03),
			Material = M.Slate,
			Name = "Strata",
			Parent = parent,
		})
	end
	Builder.deco({ Size = Vector3.new(e.width - 0.6, 0.25, e.length - 0.6), CFrame = cf * CFrame.new(0, 0.05, 0), Color = P.Moss, Material = M.Grass, CastShadow = false, Name = "Moss", Parent = parent })
	-- tufo de grama pendurado
	Builder.deco({ Size = Vector3.new(0.4, 2.5, e.length * 0.6), CFrame = cf * CFrame.new(e.width / 2 + 0.15, -1.2, 0), Color = P.Leaf, Material = M.Grass, CastShadow = false, Name = "Hang", Parent = parent })
end

function padStyles.crate(e, cf, parent, rng)
	local ground = e.support or (cf.Position.Y - 3)
	local height = cf.Position.Y - ground
	Builder.solid({ Size = Vector3.new(e.width, height, e.length), CFrame = cf * CFrame.new(0, -height / 2, 0), Color = Builder.vary(P.WoodLight, rng, 0.03), Material = M.WoodPlanks, Name = "Crate", Parent = parent })
	for _, sx in { -1, 1 } do
		for _, sz in { -1, 1 } do
			Builder.deco({ Size = Vector3.new(0.35, height, 0.35), CFrame = cf * CFrame.new(sx * (e.width / 2 - 0.1), -height / 2, sz * (e.length / 2 - 0.1)), Color = P.WoodDark, Material = M.Wood, Name = "Edge", Parent = parent })
		end
	end
end

function padStyles.roof(e, cf, parent, rng)
	local floor = topBox(cf, e.width, 0.8, e.length, { Color = P.WoodLight, Material = M.WoodPlanks, Name = "Terrace", Parent = parent })
	local colorName = e.params and e.params.house and e.params.house.color or "RoofRed"
	Structures.terraceHouse(cf, e.width, e.length, e.support or (cf.Position.Y - 8), 0.8, rng, parent, P[colorName])
	return floor
end

function padStyles.towerbase(e, cf, parent, rng)
	local floor = topBox(cf, e.width, 0.8, e.length, { Color = P.WoodLight, Material = M.WoodPlanks, Name = "Deck", Parent = parent })
	Structures.towerBody(cf, e.width, e.length, e.support or (cf.Position.Y - 8), 0.8, rng, parent, false)
	return floor
end

function padStyles.towertop(e, cf, parent, rng)
	local floor = topBox(cf, e.width, 0.8, e.length, { Color = P.WoodLight, Material = M.WoodPlanks, Name = "Lookout", Parent = parent })
	Structures.towerBody(cf, e.width, e.length, e.support or (cf.Position.Y - 8), 0.8, rng, parent, true)
	return floor
end

function padStyles.fungus(e, cf, parent, rng)
	-- cogumelo-prateleira: colisor cilíndrico achatado + chapéu decorativo
	local top = cf.Position
	verticalCylinder(top - Vector3.new(0, 1, 0), 1, e.width / 2, { Color = Color3.fromRGB(232, 200, 160), Material = M.SmoothPlastic, Name = "Shelf", Parent = parent }, true)
	Builder.deco({
		Shape = Enum.PartType.Ball,
		Size = Vector3.new(e.width + 0.6, 2.6, e.length + 0.6),
		CFrame = CFrame.new(top - Vector3.new(0, 1.55, 0)),
		Color = Builder.vary(P.Fungus, rng, 0.05),
		Material = M.SmoothPlastic,
		Name = "Cap",
		Parent = parent,
	})
	-- pintinhas luminosas
	for i = 1, 3 do
		local a = (i / 3) * math.pi * 2 + rng:NextNumber(0, 1)
		Builder.ball(top + Vector3.new(math.cos(a) * e.width * 0.3, -0.05, math.sin(a) * e.length * 0.3), 0.3, { Color = Color3.fromRGB(255, 240, 220), Material = M.Neon, Name = "Spot", Parent = parent })
	end
end

function padStyles.deck(e, cf, parent, rng)
	local floor = topBox(cf, e.width, 1, e.length, { Color = P.Wood, Material = M.WoodPlanks, Name = "Deck", Parent = parent })
	-- vigas e cordas que "penduram" a plataforma
	for _, sx in { -1, 1 } do
		Builder.deco({ Size = Vector3.new(0.6, 0.6, e.length + 1), CFrame = cf * CFrame.new(sx * (e.width / 2 - 0.5), -1.2, 0), Color = P.WoodDark, Material = M.Wood, Name = "Joist", Parent = parent })
		for _, sz in { -1, 1 } do
			local base = (cf * CFrame.new(sx * (e.width / 2 - 0.3), 0, sz * (e.length / 2 - 0.3))).Position
			Builder.cylinder(base, base + Vector3.new(0, 14, 0), 0.1, { Color = Color3.fromRGB(196, 170, 120), Material = M.Fabric, Name = "Rope", Parent = parent })
		end
	end
	Structures.paperLantern((cf * CFrame.new(e.width / 2 - 0.6, 2.5, 0)).Position, parent, rng:NextNumber() < 0.3)
	return floor
end

function padStyles.marble(e, cf, parent, rng)
	return topBox(cf, e.width, 2, e.length, { Color = Color3.fromRGB(236, 232, 226), Material = M.Marble, Name = "Marble", Parent = parent })
end

padStyles.stone = function(e, cf, parent, rng)
	return topBox(cf, e.width, 2, e.length, { Color = Builder.vary(P.RockLight, rng, 0.04), Material = M.Slate, Name = "Stone", Parent = parent })
end

-- Nuvem fofa (colisor invisível exato + bolas)
function padStyles.cloud(e, cf, parent, rng)
	local c = topCollider(cf, e.width, 1.6, e.length, parent)
	c.Name = "CloudTop"
	Clouds.platform(cf, e.width, e.length, rng, parent, e.style)
	return c
end
padStyles.sunsetcloud = padStyles.cloud

-- Pedra-estrela dourada (plataforma pequena, de precisão)
function padStyles.star(e, cf, parent, rng)
	local c = topCollider(cf, e.width, 1, e.length, parent)
	c.Name = "StarTop"
	local gold = Color3.fromRGB(255, 214, 128)
	for k = 0, 1 do
		Builder.deco({
			Size = Vector3.new(e.width * 0.92, 0.9, e.length * 0.92),
			CFrame = cf * CFrame.new(0, -0.45, 0) * CFrame.Angles(0, math.rad(45 * k), 0),
			Color = k == 0 and gold or Color3.fromRGB(255, 232, 170),
			Material = M.Neon,
			CastShadow = false,
			Name = "StarPoint",
			Parent = parent,
		})
	end
	Builder.ball((cf * CFrame.new(0, -1.3, 0)).Position, e.width * 0.32, { Color = Color3.fromRGB(255, 196, 150), Material = M.Neon, Name = "StarCore", Parent = parent })
	return c
end

function Pieces.pad(e, parent: Instance, rng: Random)
	local cf = Builder.frameOf(e.center, e.yaw)
	local style = padStyles[e.style] or padStyles.stone
	style(e, cf, parent, rng)
end

-- ===================================================================
-- Vigas, troncos, galhos, raízes
-- ===================================================================

function Pieces.beam(e, parent: Instance, rng: Random)
	local cf, length = slopeFrame(e)
	if e.style == "plank" then
		topBox(cf, e.width, 0.5, length, { Color = P.WoodLight, Material = M.WoodPlanks, Name = "Plank", Parent = parent })
		return
	end
	if e.style == "rainbow" then
		-- arco-íris: faixas coloridas lado a lado sobre um colisor único
		topCollider(cf, e.width, 0.6, length, parent)
		local bands = {
			Color3.fromRGB(255, 150, 150),
			Color3.fromRGB(255, 196, 140),
			Color3.fromRGB(255, 236, 150),
			Color3.fromRGB(170, 226, 160),
			Color3.fromRGB(150, 200, 246),
			Color3.fromRGB(196, 170, 240),
		}
		local bw = e.width / #bands
		for i, color in bands do
			Builder.deco({
				Size = Vector3.new(bw, 0.5, length),
				CFrame = cf * CFrame.new(-e.width / 2 + (i - 0.5) * bw, -0.25, 0),
				Color = color,
				Material = M.SmoothPlastic,
				Transparency = 0.1,
				CastShadow = false,
				Name = "Band",
				Parent = parent,
			})
		end
		-- tufos de nuvem segurando as pontas
		for _, z in { -length / 2, length / 2 } do
			local p = cf * CFrame.new(0, -1.6, z)
			Builder.ball(p.Position, 1.5, { Color = Color3.fromRGB(252, 250, 255), Name = "Puff", Parent = parent })
		end
		return
	end
	topCollider(cf, e.width, 0.8, length, parent)
	local r = e.width / 2
	local color = (e.style == "root") and P.BarkDark or P.Bark
	local a = (cf * CFrame.new(0, -r, length / 2 + 0.4)).Position
	local b = (cf * CFrame.new(0, -r, -length / 2 - 0.4)).Position
	Builder.cylinder(a, b, r, { Color = Builder.vary(color, rng, 0.03), Material = M.Wood, Name = "Log", Parent = parent })
	-- musgo por cima (fino, não muda a altura do colisor)
	Builder.deco({ Size = Vector3.new(e.width * 0.55, 0.12, length * 0.5), CFrame = cf * CFrame.new(0, 0.02, rng:NextNumber(-length * 0.2, length * 0.2)), Color = P.Moss, Material = M.Grass, CastShadow = false, Name = "Moss", Parent = parent })
	if e.style == "branch" or e.style == "root" then
		for i = 1, 3 do
			local t = rng:NextNumber(-0.4, 0.4)
			local side = (i % 2 == 0) and 1 or -1
			local from = (cf * CFrame.new(side * r * 0.8, -r, t * length)).Position
			local to = from + (cf.RightVector * side * 2.2) + Vector3.new(0, 1.2, 0)
			Builder.cylinder(from, to, 0.25, { Color = color, Material = M.Wood, Name = "Twig", Parent = parent })
			Builder.ball(to, 0.9, { Color = P.Leaf, Name = "Leaves", Parent = parent })
		end
	end
end

-- ===================================================================
-- Pontes
-- ===================================================================

local function bridgePosts(cf: CFrame, w: number, length: number, parent: Instance, height: number)
	local tops = {}
	for _, sz in { -1, 1 } do
		for _, sx in { -1, 1 } do
			local p = cf * CFrame.new(sx * (w / 2 + 0.3), height / 2 - 0.6, sz * (length / 2 - 0.2))
			Builder.deco({ Size = Vector3.new(0.6, height + 1.2, 0.6), CFrame = p, Color = P.WoodDark, Material = M.Wood, Name = "Post", Parent = parent })
			tops[sx .. ":" .. sz] = (p * CFrame.new(0, height / 2, 0)).Position
		end
	end
	return tops
end

local function sagRope(a: Vector3, b: Vector3, sag: number, parent: Instance)
	local mid = (a + b) / 2 - Vector3.new(0, sag, 0)
	Builder.cylinder(a, mid, 0.12, { Color = Color3.fromRGB(196, 170, 120), Material = M.Fabric, Name = "Rope", Parent = parent })
	Builder.cylinder(mid, b, 0.12, { Color = Color3.fromRGB(196, 170, 120), Material = M.Fabric, Name = "Rope", Parent = parent })
end

function Pieces.bridge(e, parent: Instance, rng: Random)
	local cf, length = slopeFrame(e)
	if e.style == "stonebridge" then
		topBox(cf, e.width, 1.6, length, { Color = P.RockLight, Material = M.Cobblestone, Name = "Deck", Parent = parent })
		for _, s in { -1, 1 } do
			Builder.solid({ Size = Vector3.new(0.8, 1.6, length), CFrame = cf * CFrame.new(s * (e.width / 2 + 0.4), 0.8, 0), Color = Color3.fromRGB(226, 222, 214), Material = M.Marble, Name = "Balustrade", Parent = parent })
		end
		-- arco por baixo
		for i = 1, 3 do
			local t = (i - 2) * length * 0.3
			Builder.deco({ Size = Vector3.new(e.width, 3 + math.abs(i - 2) * 3, 3), CFrame = cf * CFrame.new(0, -3 - math.abs(i - 2) * 1.5, t), Color = P.RockLight, Material = M.Cobblestone, Name = "Arch", Parent = parent })
		end
		return
	end
	-- ponte de corda/madeira: colisor único + tábuas decorativas
	topCollider(cf, e.width, 0.6, length, parent)
	sideGuards(cf, e.width, length, 2.2, parent)
	local count = math.floor(length / 1.15)
	for i = 0, count - 1 do
		local z = -length / 2 + (i + 0.5) * (length / count)
		Builder.deco({
			Size = Vector3.new(e.width, 0.35, length / count - 0.18),
			CFrame = cf * CFrame.new(0, -0.18, z) * CFrame.Angles(0, rng:NextNumber(-0.03, 0.03), 0),
			Color = Builder.vary(P.Wood, rng, 0.04),
			Material = M.WoodPlanks,
			CastShadow = true,
			Name = "Board",
			Parent = parent,
		})
	end
	local tops = bridgePosts(cf, e.width, length, parent, 2.6)
	sagRope(tops["-1:-1"], tops["-1:1"], 0.9, parent)
	sagRope(tops["1:-1"], tops["1:1"], 0.9, parent)
end

-- ===================================================================
-- Trilha na encosta e cachoeira com rajadas
-- ===================================================================

function Pieces.ledge(e, parent: Instance, rng: Random)
	local cf, length = slopeFrame(e)
	topBox(cf, e.width, 3, length, { Color = Builder.vary(Color3.fromRGB(122, 122, 116), rng, 0.03), Material = M.Slate, Name = "Ledge", Parent = parent })
	-- borda externa irregular e grama
	local outward = -(e.wallSide or 1)
	for i = 1, math.floor(length / 5) do
		local z = -length / 2 + (i - 0.5) * 5
		Builder.deco({
			Size = Vector3.new(1.6, rng:NextNumber(2.5, 4.5), 4.6),
			CFrame = cf * CFrame.new(outward * (e.width / 2 - 0.2), -2.6, z) * CFrame.Angles(0, 0, outward * 0.25),
			Color = P.RockDark,
			Material = M.Slate,
			Name = "Edge",
			Parent = parent,
		})
	end
	Builder.deco({ Size = Vector3.new(0.6, 0.15, length * 0.9), CFrame = cf * CFrame.new(-outward * (e.width / 2 - 0.4), 0.03, 0), Color = P.Moss, Material = M.Grass, CastShadow = false, Name = "Moss", Parent = parent })
end

function Pieces.waterfall(e, parent: Instance, rng: Random)
	Pieces.ledge(e, parent, rng)
	local cf, length = slopeFrame(e)
	local outward = -(e.wallSide or 1)
	local sectionLength = math.min(10, length - 4)
	local wallTop = math.max(e.entry.Y, e.exit.Y) + 24
	local ledgeTop = cf.Position.Y
	local bottom = -40
	local fallHeight = wallTop - bottom
	local model = Builder.model("Cachoeira", parent)

	-- lâmina principal: cai na frente da trilha (o jogador passa por trás)
	local edge = (cf * CFrame.new(outward * (e.width / 2 + 0.6), 0, 0)).Position
	local sheet = Builder.deco({
		Size = Vector3.new(0.8, fallHeight, sectionLength + 2),
		CFrame = CFrame.new(Vector3.new(edge.X, wallTop - fallHeight / 2, edge.Z)) * cf.Rotation,
		Color = P.Water,
		Material = M.Glass,
		Transparency = 0.45,
		Name = "Sheet",
		Parent = model,
	})
	sheet:AddTag(Tags.Waterfall)
	-- jato que atravessa a trilha durante a rajada (fica quase invisível no resto)
	local splash = Builder.deco({
		Size = Vector3.new(e.width + 1, wallTop - ledgeTop, sectionLength),
		CFrame = CFrame.new(Vector3.new(cf.Position.X, (wallTop + ledgeTop) / 2, cf.Position.Z)) * cf.Rotation,
		Color = P.WaterFoam,
		Material = M.Glass,
		Transparency = 0.92,
		Name = "Splash",
		Parent = model,
	})
	-- zona da rajada (o cliente empurra o jogador para fora durante a rajada)
	local zone = Builder.deco({
		Size = Vector3.new(e.width + 1, 8, sectionLength),
		CFrame = cf * CFrame.new(0, 3.5, 0),
		Transparency = 1,
		Name = "GustZone",
		Parent = model,
	})
	zone:SetAttribute("Period", e.period)
	zone:SetAttribute("GustTime", e.gustTime)
	zone:SetAttribute("Phase", rng:NextNumber(0, e.period))
	zone:SetAttribute("Push", cf.RightVector * outward)
	zone:AddTag(Tags.WaterfallGust)
	-- névoa e respingos
	local att = Instance.new("Attachment")
	att.Parent = zone
	local mist = Instance.new("ParticleEmitter")
	mist.Name = "Mist"
	mist.Texture = "rbxasset://textures/particles/smoke_main.dds"
	mist.Color = ColorSequence.new(P.WaterFoam)
	mist.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.6), NumberSequenceKeypoint.new(1, 1) })
	mist.Size = NumberSequence.new(3, 6)
	mist.Lifetime = NumberRange.new(1.2, 2)
	mist.Rate = 4
	mist.Speed = NumberRange.new(2, 4)
	mist.SpreadAngle = Vector2.new(60, 60)
	mist.LightEmission = 0.2
	mist.Parent = att
	-- poço no fundo não é necessário: a água cai no abismo entre as rochas
end

-- ===================================================================
-- Escadas
-- ===================================================================

function Pieces.stairs(e, parent: Instance, rng: Random)
	local f = Vector3.new(math.sin(e.yaw), 0, math.cos(e.yaw))
	local rot = CFrame.lookAt(Vector3.zero, f).Rotation
	local material = e.style == "marble" and M.Marble or M.Cobblestone
	local color = e.style == "marble" and Color3.fromRGB(232, 228, 220) or P.RockLight
	for i = 1, e.steps do
		local topY = e.entry.Y + i * e.stepRise
		local height = i * e.stepRise + 1
		local zc = e.entry + f * ((i - 0.5) * e.stepRun)
		Builder.solid({
			Size = Vector3.new(e.width, height, e.stepRun),
			CFrame = CFrame.new(Vector3.new(zc.X, topY - height / 2, zc.Z)) * rot,
			Color = Builder.vary(color, rng, 0.02),
			Material = material,
			Name = "Step",
			Parent = parent,
		})
	end
	-- muretas laterais (decorativas, fora da largura pisável)
	local cf, length = slopeFrame(e)
	for _, s in { -1, 1 } do
		Builder.deco({
			Size = Vector3.new(0.8, 1.4, length),
			CFrame = cf * CFrame.new(s * (e.width / 2 + 0.4), 0.4, 0),
			Color = e.style == "marble" and Color3.fromRGB(214, 206, 196) or P.Rock,
			Material = material,
			Name = "Balustrade",
			Parent = parent,
		})
	end
	Structures.lantern(e.exit + Vector3.new(0, 0, 0) + (cf.RightVector * (e.width / 2 + 1.6)), parent, true)
end

-- ===================================================================
-- Obstáculos dinâmicos
-- ===================================================================

function Pieces.collapse(e, parent: Instance, rng: Random)
	local cf, length = slopeFrame(e)
	local n = e.planks
	local plankLen = length / n
	if e.style == "cloud" or e.style == "sunsetcloud" then
		-- ponte de nuvens: cada pedaço some ao ser pisado
		for i = 0, n - 1 do
			local z = -length / 2 + (i + 0.5) * plankLen
			local pcf = cf * CFrame.new(0, 0, z)
			local plank = Builder.collider({ Size = Vector3.new(e.width, 0.8, plankLen), CFrame = pcf * CFrame.new(0, -0.4, 0), Name = "Plank", Parent = parent })
			Clouds.platform(pcf, e.width, plankLen, rng, plank, e.style)
			plank:SetAttribute("Delay", 0.45)
			plank:SetAttribute("Respawn", 3.5)
			plank:AddTag(Tags.CollapsingPlank)
		end
		return
	end
	for i = 0, n - 1 do
		local z = -length / 2 + (i + 0.5) * plankLen
		local plank = Builder.solid({
			Size = Vector3.new(e.width, 0.6, plankLen),
			CFrame = cf * CFrame.new(0, -0.3, z),
			Color = Builder.vary(e.style == "branch" and P.Bark or P.Wood, rng, 0.05),
			Material = e.style == "branch" and M.Wood or M.WoodPlanks,
			Name = "Plank",
			Parent = parent,
		})
		plank:SetAttribute("Delay", 0.45)
		plank:SetAttribute("Respawn", 3.5)
		plank:AddTag(Tags.CollapsingPlank)
	end
	local tops = bridgePosts(cf, e.width, length, parent, 2.4)
	sagRope(tops["-1:-1"], tops["-1:1"], 1.4, parent)
	sagRope(tops["1:-1"], tops["1:1"], 1.4, parent)
end

function Pieces.fallstone(e, parent: Instance, rng: Random)
	local cf = Builder.frameOf(e.center, e.yaw)
	if e.style == "cloud" or e.style == "sunsetcloud" then
		-- nuvem que se desfaz: o colisor invisível leva as bolas junto
		local cloud = topCollider(cf, e.width, 1.6, e.length, parent)
		cloud.Name = "LooseCloud"
		Clouds.platform(cf, e.width, e.length, rng, cloud, e.style)
		cloud:SetAttribute("Delay", e.fallDelay or 0.55)
		cloud:SetAttribute("Respawn", 3.5)
		cloud:AddTag(Tags.FallingStone)
		return
	end
	local marble = e.style == "marble"
	local stone = topBox(cf, e.width, 2.2, e.length, {
		Color = marble and Color3.fromRGB(236, 230, 224) or Builder.vary(Color3.fromRGB(150, 140, 128), rng, 0.04),
		Material = marble and M.Marble or M.Slate,
		Name = "LooseStone",
		Parent = parent,
	})
	stone:SetAttribute("Delay", e.fallDelay or 0.55)
	stone:SetAttribute("Respawn", 3.5)
	stone:AddTag(Tags.FallingStone)
end

local moverStyles = {
	raft = function(model, cf, e, rng)
		for i = -2, 2 do
			Builder.cylinder((cf * CFrame.new(i * 1.15, -0.6, e.length / 2)).Position, (cf * CFrame.new(i * 1.15, -0.6, -e.length / 2)).Position, 0.6, { Color = Builder.vary(P.Wood, rng, 0.05), Material = M.Wood, Name = "Log", Parent = model })
		end
	end,
	lift = function(model, cf, e)
		for _, sx in { -1, 1 } do
			for _, sz in { -1, 1 } do
				local base = (cf * CFrame.new(sx * (e.width / 2 - 0.3), 0, sz * (e.length / 2 - 0.3))).Position
				Builder.cylinder(base, base + Vector3.new(0, 7, 0), 0.12, { Color = Color3.fromRGB(196, 170, 120), Material = M.Fabric, Name = "Rope", Parent = model })
			end
		end
		Builder.deco({ Size = Vector3.new(e.width + 0.4, 0.6, 0.6), CFrame = cf * CFrame.new(0, 7, 0), Color = P.WoodDark, Material = M.Wood, Name = "Bar", Parent = model })
	end,
	basket = function(model, cf, e)
		for _, s in { -1, 1 } do
			Builder.deco({ Size = Vector3.new(0.3, 1, e.length), CFrame = cf * CFrame.new(s * (e.width / 2 - 0.15), 0.5, 0), Color = Color3.fromRGB(176, 140, 92), Material = M.Fabric, Name = "Rim", Parent = model })
			local base = (cf * CFrame.new(s * (e.width / 2 - 0.2), 0.5, 0)).Position
			Builder.cylinder(base, base + Vector3.new(0, 9, 0), 0.14, { Color = P.LeafDeep, Material = M.Grass, Name = "Vine", Parent = model })
		end
	end,
	cloudstone = function(model, cf, e, rng)
		Clouds.platform(cf, e.width, e.length, rng, model, "cloudstone")
	end,
	cloud = function(model, cf, e, rng)
		Clouds.platform(cf, e.width, e.length, rng, model, "cloud")
	end,
	sunsetcloud = function(model, cf, e, rng)
		Clouds.platform(cf, e.width, e.length, rng, model, "sunsetcloud")
	end,
	petal = function(model, cf, e)
		Builder.deco({ Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.3, e.width + 1.4, e.length + 1.4), CFrame = cf * CFrame.new(0, -1.6, 0) * CFrame.Angles(0, 0, math.rad(90)), Color = P.BlossomLight, Name = "Petal", Parent = model })
	end,
}

function Pieces.mover(e, parent: Instance, rng: Random)
	local model = Builder.model("MovingPlatform", parent)
	local rot = Builder.frameOf(Vector3.zero, e.yaw).Rotation
	local topA = e.center
	local cf = CFrame.new(topA) * rot
	local materials = {
		raft = { P.Wood, M.WoodPlanks },
		lift = { P.WoodLight, M.WoodPlanks },
		basket = { Color3.fromRGB(190, 150, 100), M.Fabric },
		cloudstone = { Color3.fromRGB(240, 238, 244), M.Marble },
		petal = { P.Blossom, M.SmoothPlastic },
		stone = { P.RockLight, M.Slate },
	}
	local look = materials[e.style] or materials.stone
	local platform = topBox(cf, e.width, e.thickness, e.length, { Color = look[1], Material = look[2], Name = "Platform", Parent = model })
	if Clouds.Palettes[e.style] then
		-- nuvens: a plataforma vira só colisor; o visual são as bolas
		platform.Transparency = 1
		platform.CastShadow = false
	end
	local deco = moverStyles[e.style]
	if deco then
		deco(model, cf, e, rng)
	end
	model.PrimaryPart = platform
	-- extremos do movimento (posições do PrimaryPart)
	local offset = platform.Position - topA
	local a, b
	if e.axis == "lateral" then
		local right = cf.RightVector
		a = topA + offset - right * (e.travel / 2)
		b = topA + offset + right * (e.travel / 2)
	else
		a = topA + offset
		b = e.centerB + offset
	end
	model:SetAttribute("PointA", a)
	model:SetAttribute("PointB", b)
	model:SetAttribute("Period", e.period)
	model:SetAttribute("Phase", e.axis == "lateral" and 0.25 or 0)
	model:SetAttribute("Axis", e.axis)
	model.ModelStreamingMode = Enum.ModelStreamingMode.Atomic
	model:AddTag(Tags.MovingPlatform)
end

function Pieces.swing(e, parent: Instance, rng: Random)
	local cf, length = slopeFrame(e)
	-- passarela (galho largo e achatado)
	topBox(cf, e.width, 1.2, length, { Color = P.Bark, Material = M.Wood, Name = "Walkway", Parent = parent })
	Builder.deco({ Size = Vector3.new(e.width * 0.5, 0.12, length * 0.7), CFrame = cf * CFrame.new(0, 0.02, 0), Color = P.Moss, Material = M.Grass, CastShadow = false, Name = "Moss", Parent = parent })
	local pivotHeight = 9
	local ropeLength = 6.5
	for i = 1, e.logs do
		local z = -length / 2 + i * length / (e.logs + 1)
		-- arco de galhos que segura o tronco
		for _, s in { -1, 1 } do
			Builder.solid({ Size = Vector3.new(0.9, pivotHeight + 1.2, 0.9), CFrame = cf * CFrame.new(s * (e.width / 2 + 0.9), pivotHeight / 2 - 1.2, z), Color = P.BarkDark, Material = M.Wood, Name = "Post", Parent = parent })
		end
		Builder.deco({ Size = Vector3.new(e.width + 3, 0.9, 0.9), CFrame = cf * CFrame.new(0, pivotHeight, z), Color = P.BarkDark, Material = M.Wood, Name = "Crossbar", Parent = parent })
		-- o tronco pendurado (modelo animado no cliente)
		local pivot = cf * CFrame.new(0, pivotHeight, z)
		local log = Builder.model("SwingingLog", parent)
		local logPart = Builder.cylinder((pivot * CFrame.new(0, -ropeLength, 1.8)).Position, (pivot * CFrame.new(0, -ropeLength, -1.8)).Position, 1.1, {
			Color = P.Wood,
			Material = M.Wood,
			Name = "Log",
			Parent = log,
		})
		Builder.deco({ Size = Vector3.new(0.25, ropeLength, 0.25), CFrame = pivot * CFrame.new(0, -ropeLength / 2, 0), Color = Color3.fromRGB(196, 170, 120), Material = M.Fabric, Name = "Rope", Parent = log })
		log.PrimaryPart = logPart
		log.WorldPivot = pivot
		log:SetAttribute("Pivot", pivot)
		log:SetAttribute("RopeLength", ropeLength)
		log:SetAttribute("LogLength", 3.6)
		log:SetAttribute("Radius", 1.1)
		log:SetAttribute("Amplitude", math.rad(70))
		log:SetAttribute("Period", e.period)
		log:SetAttribute("Phase", (i - 1) * e.period / e.logs)
		log.ModelStreamingMode = Enum.ModelStreamingMode.Atomic
		log:AddTag(Tags.SwingingLog)
	end
end

-- ===================================================================
-- Escaladas
-- ===================================================================

function Pieces.climb(c, parent: Instance, rng: Random)
	local f = Vector3.new(math.sin(c.yaw), 0, math.cos(c.yaw))
	local right = Vector3.new(-math.cos(c.yaw), 0, math.sin(c.yaw))
	local rot = CFrame.lookAt(Vector3.zero, f).Rotation
	local columns = math.max(1, math.floor(c.width / 2))
	local height = math.ceil(c.height / 2) * 2
	for i = 1, columns do
		local lateral = (i - (columns + 1) / 2) * 2
		local truss = Instance.new("TrussPart")
		truss.Anchored = true
		truss.Size = Vector3.new(2, height, 2)
		truss.CFrame = CFrame.new(c.base - f * 1.6 + right * lateral + Vector3.new(0, c.height - height / 2, 0)) * rot
		truss.Transparency = 1
		truss.CastShadow = false
		truss.Name = "Climb"
		truss.Parent = parent
		Builder.stats.parts += 1
	end
	local face = c.base - f * 2.5
	-- painel atrás das vinhas: mostra de longe onde dá para subir
	Builder.deco({
		Size = Vector3.new(c.width + 1.4, c.height, 0.5),
		CFrame = CFrame.new(c.base - f * 0.35 + Vector3.new(0, c.height / 2, 0)) * rot,
		Color = (c.style == "ladder") and P.WoodDark or P.LeafDeep,
		Material = (c.style == "ladder") and M.WoodPlanks or M.LeafyGrass,
		Name = "ClimbPanel",
		Parent = parent,
	})
	if c.style == "ladder" then
		for _, s in { -1, 1 } do
			local p = face + right * (s * c.width / 2)
			Builder.cylinder(p, p + Vector3.new(0, c.height + 1, 0), 0.22, { Color = P.WoodDark, Material = M.Wood, Name = "Rail", Parent = parent })
		end
		for y = 1, c.height, 2 do
			local p = face + Vector3.new(0, y, 0)
			Builder.cylinder(p - right * (c.width / 2), p + right * (c.width / 2), 0.14, { Color = P.Wood, Material = M.Wood, Name = "Rung", Parent = parent })
		end
	else
		-- trepadeiras: cipós grossos e folhas
		for k = -1, 1 do
			local p = face + right * (k * c.width * 0.38)
			Builder.cylinder(p, p + Vector3.new(0, c.height + 0.6, 0), 0.25, { Color = P.LeafDeep, Material = M.Grass, Name = "Vine", Parent = parent })
		end
		for y = 1.5, c.height, 3 do
			local p = face + right * rng:NextNumber(-c.width / 2, c.width / 2) + Vector3.new(0, y, 0)
			Builder.ball(p, rng:NextNumber(0.6, 0.9), { Color = (y % 2 < 1) and P.Leaf or P.Blossom, Name = "Leaf", Parent = parent })
		end
	end
end

-- ===================================================================
-- Zonas: caminhos (pedra/madeira) e decks
-- ===================================================================

function Pieces.zonePath(zone, parent: Instance, rng: Random)
	local deck = zone.surface == "deck"
	if deck and (zone.theme == "cloud_deck" or zone.theme == "sunset_deck") then
		-- ilha de nuvem: colisor exato + nuvem fofa em camadas
		local cf = Builder.frameOf(zone.center, zone.yaw)
		local top = topCollider(cf, zone.width, 1.2, zone.length, parent)
		top.Name = "Island"
		Clouds.island(cf, zone.width, zone.length, rng, parent, zone.theme == "sunset_deck" and "sunsetcloud" or "cloud")
		return
	end
	if deck then
		local cf = Builder.frameOf(zone.center, zone.yaw)
		topBox(cf, zone.width, 1.2, zone.length, { Color = P.Wood, Material = M.WoodPlanks, Name = "Deck", Parent = parent })
		for _, sx in { -1, 1 } do
			for _, sz in { -1, 1 } do
				local corner = (cf * CFrame.new(sx * (zone.width / 2 - 0.6), 0, sz * (zone.length / 2 - 0.6))).Position
				Builder.deco({ Size = Vector3.new(0.8, 2.2, 0.8), CFrame = CFrame.new(corner + Vector3.new(0, 1.1, 0)), Color = P.WoodDark, Material = M.Wood, Name = "Post", Parent = parent })
				Structures.paperLantern(corner + Vector3.new(0, 2.9, 0), parent, sx == sz)
			end
			Builder.deco({ Size = Vector3.new(0.8, 0.8, zone.length + 2), CFrame = cf * CFrame.new(sx * (zone.width / 2 - 1), -1.6, 0), Color = P.WoodDark, Material = M.Wood, Name = "Joist", Parent = parent })
		end
		return
	end
	-- trilha de lajes sobre o terreno (garante a superfície exata nas bordas)
	local villageLike = string.find(zone.theme, "village") ~= nil
	local celestial = zone.theme == "celestial" or zone.theme == "sanctuary" or zone.theme == "summit"
	local color = celestial and Color3.fromRGB(232, 228, 220) or (villageLike and Color3.fromRGB(196, 186, 170) or P.RockLight)
	local material = celestial and M.Marble or M.Slate
	for i = 1, #zone.path - 1 do
		local a, b = zone.path[i], zone.path[i + 1]
		local seg = Vector3.new(b.X - a.X, 0, b.Z - a.Z)
		local len = seg.Magnitude
		if len > 0.5 then
			local dir = seg.Unit
			local rot = CFrame.lookAt(Vector3.zero, dir).Rotation
			local n = math.max(1, math.ceil(len / 3.4))
			local step = len / n
			for k = 0, n - 1 do
				local c = a + dir * ((k + 0.5) * step)
				local slab = Builder.solid({
					Size = Vector3.new(villageLike and 5 or 3.8, 1, step - 0.35),
					CFrame = CFrame.new(Vector3.new(c.X, zone.top + 0.15 - 0.5, c.Z)) * rot * CFrame.Angles(0, rng:NextNumber(-0.04, 0.04), 0),
					Color = Builder.vary(color, rng, 0.03),
					Material = material,
					Name = "PathStone",
					Parent = parent,
				})
				slab.CastShadow = false
			end
		end
	end
end

-- ===================================================================
-- Checkpoint (estrela brilhante flutuando)
-- ===================================================================

function Pieces.checkpoint(cp, lateral: number, parent: Instance)
	local model = Builder.model("Checkpoint_" .. cp.index, parent)
	local f = Vector3.new(math.sin(cp.yaw), 0, math.cos(cp.yaw))
	local right = Vector3.new(-math.cos(cp.yaw), 0, math.sin(cp.yaw))
	local pos = cp.position
	-- só a estrela brilhante, flutuando ao lado do caminho
	local side = pos + right * lateral
	local crystal = Builder.deco({
		Size = Vector3.new(1.3, 1.3, 1.3),
		CFrame = CFrame.new(side + Vector3.new(0, 4.6, 0)) * CFrame.Angles(math.rad(45), 0, math.rad(45)),
		Color = P.CheckpointIdle,
		Material = M.Neon,
		Name = "Crystal",
		Parent = model,
	})
	crystal.CastShadow = false
	local glow = Instance.new("PointLight")
	glow.Name = "Glow"
	glow.Color = P.CheckpointActive
	glow.Range = 10
	glow.Brightness = 0
	glow.Shadows = false
	glow.Parent = crystal
	local att = Instance.new("Attachment")
	att.Parent = crystal
	local sparkle = Instance.new("ParticleEmitter")
	sparkle.Name = "Sparkle"
	sparkle.Texture = "rbxasset://textures/particles/sparkles_main.dds"
	sparkle.Color = ColorSequence.new(P.CheckpointActive)
	sparkle.Size = NumberSequence.new(0.4, 0)
	sparkle.Lifetime = NumberRange.new(1, 1.6)
	sparkle.Rate = 6
	sparkle.Speed = NumberRange.new(1, 2)
	sparkle.SpreadAngle = Vector2.new(180, 180)
	sparkle.LightEmission = 1
	sparkle.Enabled = false
	sparkle.Parent = att

	-- área de ativação (invisível)
	local trigger = Builder.collider({
		Size = Vector3.new(8, 7, 8),
		CFrame = CFrame.new(pos + Vector3.new(0, 3.5, 0)),
		Name = "Trigger",
		Parent = model,
	})
	trigger.CanCollide = false
	trigger.CanQuery = false
	trigger.CanTouch = true
	model.PrimaryPart = crystal
	model:SetAttribute(Config.Attr.CheckpointIndex, cp.index)
	model:SetAttribute("Label", cp.label or ("Checkpoint " .. cp.index))
	model:SetAttribute("Finish", cp.finish)
	model:SetAttribute("Region", cp.region)
	model:SetAttribute("SpawnCFrame", CFrame.lookAt(pos + Vector3.new(0, 3.5, 0), pos + Vector3.new(0, 3.5, 0) + f))
	model.ModelStreamingMode = Enum.ModelStreamingMode.Atomic
	model:AddTag(Tags.Checkpoint)
	return model, trigger
end

return Pieces
