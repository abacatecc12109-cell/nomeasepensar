--[[
	Nature
	------
	Vegetação e elementos naturais.

	Árvores são construídas uma vez como MODELOS-BASE (várias variações) e
	depois clonadas com escala, rotação e tons de cor diferentes. Isso evita
	"árvores repetidas de maneira artificial" e economiza processamento.
]]

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Config = require(Shared.Config)
local Builder = require(script.Parent.Builder)

local Nature = {}
local P = Config.Palette
local M = Enum.Material

local templates = {
	cherry = {},
	green = {},
	bush = {},
}

-- ===================================================================
-- Modelos-base
-- ===================================================================

local function canopyCluster(model: Model, center: Vector3, size: number, colors, rng: Random, tag: string)
	local main = Builder.ball(center, size, { Color = colors[1], Material = M.SmoothPlastic, Name = tag, Parent = model })
	main.CastShadow = true
	for i = 1, 5 do
		local angle = (i / 5) * math.pi * 2 + rng:NextNumber(-0.4, 0.4)
		local d = size * rng:NextNumber(0.55, 0.8)
		local offset = Vector3.new(math.cos(angle) * d, rng:NextNumber(-size * 0.35, size * 0.25), math.sin(angle) * d)
		local b = Builder.ball(center + offset, size * rng:NextNumber(0.55, 0.75), {
			Color = colors[(i % #colors) + 1],
			Material = M.SmoothPlastic,
			Name = tag,
			Parent = model,
		})
		b.CastShadow = true
	end
	-- realces claros no topo
	for _ = 1, 2 do
		local offset = Vector3.new(rng:NextNumber(-size * 0.4, size * 0.4), size * rng:NextNumber(0.45, 0.65), rng:NextNumber(-size * 0.4, size * 0.4))
		Builder.ball(center + offset, size * 0.42, { Color = colors[#colors], Material = M.SmoothPlastic, Name = tag, Parent = model })
	end
end

local function buildTree(kind: string, rng: Random): Model
	local model = Instance.new("Model")
	model.Name = kind == "cherry" and "Cerejeira" or "Arvore"
	local height = rng:NextNumber(9, 13)
	local lean = Vector3.new(rng:NextNumber(-1.6, 1.6), 0, rng:NextNumber(-1.6, 1.6))
	local p0 = Vector3.new(0, -0.5, 0)
	local p1 = Vector3.new(lean.X * 0.4, height * 0.5, lean.Z * 0.4)
	local p2 = Vector3.new(lean.X, height, lean.Z)
	local bark = kind == "cherry" and P.Bark or P.BarkDark
	-- o tronco é sólido (o jogador não atravessa árvores)
	Builder.cylinder(p0, p1, 0.95, { Color = bark, Material = M.Wood, Name = "Trunk", Parent = model }, false)
	Builder.cylinder(p1, p2, 0.72, { Color = bark, Material = M.Wood, Name = "Trunk", Parent = model }, false)
	Builder.ball(p1, 0.85, { Color = bark, Material = M.Wood, Name = "Trunk", Parent = model })
	-- galhos
	for i = 1, 2 do
		local angle = rng:NextNumber(0, math.pi * 2)
		local from = p1:Lerp(p2, 0.4 + i * 0.2)
		local to = from + Vector3.new(math.cos(angle) * 3.6, 2.4, math.sin(angle) * 3.6)
		Builder.cylinder(from, to, 0.35, { Color = bark, Material = M.Wood, Name = "Branch", Parent = model })
	end
	local colors
	if kind == "cherry" then
		colors = { P.Blossom, P.BlossomDeep, P.Blossom, P.BlossomLight }
	else
		colors = { P.Leaf, P.LeafDeep, P.Leaf, P.GrassLight }
	end
	canopyCluster(model, p2 + Vector3.new(0, 2.2, 0), rng:NextNumber(4.4, 5.4), colors, rng, "Canopy")
	if kind == "cherry" then
		-- tapete de pétalas caídas
		local petals = Builder.deco({
			Shape = Enum.PartType.Cylinder,
			Size = Vector3.new(0.1, 11, 11),
			CFrame = CFrame.new(lean.X * 0.6, 0.06, lean.Z * 0.6) * CFrame.Angles(0, 0, math.rad(90)),
			Color = P.BlossomLight,
			Transparency = 0.25,
			Name = "Petals",
			Parent = model,
		})
		petals.CastShadow = false
	end
	model.WorldPivot = CFrame.new(0, 0, 0)
	return model
end

local function buildBush(rng: Random, flowering: boolean): Model
	local model = Instance.new("Model")
	model.Name = "Arbusto"
	local base = rng:NextNumber(1.6, 2.3)
	Builder.ball(Vector3.new(0, base * 0.55, 0), base, { Color = P.LeafDeep, Material = M.SmoothPlastic, Name = "Leaf", Parent = model })
	for i = 1, 2 do
		local a = i * math.pi + rng:NextNumber(-0.5, 0.5)
		Builder.ball(Vector3.new(math.cos(a) * base * 0.7, base * 0.45, math.sin(a) * base * 0.7), base * 0.75, { Color = P.Leaf, Material = M.SmoothPlastic, Name = "Leaf", Parent = model })
	end
	if flowering then
		for i = 1, 3 do
			local a = rng:NextNumber(0, math.pi * 2)
			Builder.ball(Vector3.new(math.cos(a) * base * 0.6, base * 1.05, math.sin(a) * base * 0.6), 0.35, {
				Color = P.FlowerColors[(i % #P.FlowerColors) + 1],
				Name = "Flower",
				Parent = model,
			})
		end
	end
	model.WorldPivot = CFrame.new()
	return model
end

function Nature.init(rng: Random, storage: Instance)
	local folder = Builder.folder("NatureTemplates", storage)
	for i = 1, 6 do
		local t = buildTree("cherry", rng)
		t.Parent = folder
		templates.cherry[i] = t
	end
	for i = 1, 4 do
		local t = buildTree("green", rng)
		t.Parent = folder
		templates.green[i] = t
	end
	for i = 1, 4 do
		local b = buildBush(rng, i <= 2)
		b.Parent = folder
		templates.bush[i] = b
	end
end

-- ===================================================================
-- Posicionamento
-- ===================================================================

local function place(template: Model, position: Vector3, scale: number, rng: Random, parent: Instance, recolor): Model
	local clone = template:Clone()
	clone:PivotTo(CFrame.new(position) * CFrame.Angles(0, rng:NextNumber(0, math.pi * 2), 0))
	if math.abs(scale - 1) > 0.01 then
		clone:ScaleTo(scale)
	end
	if recolor then
		for _, part in clone:GetChildren() do
			if part:IsA("BasePart") and recolor[part.Name] then
				part.Color = Builder.vary(part.Color, rng, recolor[part.Name])
			end
		end
	end
	clone.Parent = parent
	return clone
end

-- Raio aproximado (para checar espaço livre)
Nature.Footprint = {
	tree = 6,
	bush = 2.5,
	rock = 2,
	flowers = 1.2,
	mushroom = 1,
}

function Nature.cherryTree(position: Vector3, scale: number, rng: Random, parent: Instance): Model
	local t = templates.cherry[rng:NextInteger(1, #templates.cherry)]
	return place(t, position, scale, rng, parent, { Canopy = 0.04, Trunk = 0.03 })
end

function Nature.greenTree(position: Vector3, scale: number, rng: Random, parent: Instance): Model
	local t = templates.green[rng:NextInteger(1, #templates.green)]
	return place(t, position, scale, rng, parent, { Canopy = 0.05 })
end

function Nature.bush(position: Vector3, scale: number, rng: Random, parent: Instance): Model
	local t = templates.bush[rng:NextInteger(1, #templates.bush)]
	return place(t, position, scale, rng, parent, { Leaf = 0.04 })
end

-- Tufo de flores (3 a 5 flores pequenas, cores variadas)
function Nature.flowers(position: Vector3, rng: Random, parent: Instance, glow: boolean?)
	local count = rng:NextInteger(3, 5)
	local color = P.FlowerColors[rng:NextInteger(1, #P.FlowerColors)]
	if glow then
		color = ({ Color3.fromRGB(190, 236, 255), Color3.fromRGB(226, 196, 255), Color3.fromRGB(255, 236, 196) })[rng:NextInteger(1, 3)]
	end
	for _ = 1, count do
		local offset = Vector3.new(rng:NextNumber(-1.1, 1.1), 0, rng:NextNumber(-1.1, 1.1))
		local size = rng:NextNumber(0.35, 0.6)
		Builder.deco({
			Shape = Enum.PartType.Ball,
			Size = Vector3.new(size, size, size),
			CFrame = CFrame.new(position + offset + Vector3.new(0, rng:NextNumber(0.35, 0.9), 0)),
			Color = Builder.vary(color, rng, 0.04),
			Material = glow and M.Neon or M.SmoothPlastic,
			CastShadow = false,
			Name = glow and "GlowFlower" or "Flower",
			Parent = parent,
		})
	end
end

function Nature.rock(position: Vector3, scale: number, rng: Random, parent: Instance, mossy: boolean?)
	local s = Vector3.new(rng:NextNumber(2, 3.4), rng:NextNumber(1.2, 2.2), rng:NextNumber(2, 3)) * scale
	local cf = CFrame.new(position + Vector3.new(0, s.Y * 0.3, 0)) * CFrame.Angles(rng:NextNumber(-0.25, 0.25), rng:NextNumber(0, 6.28), rng:NextNumber(-0.25, 0.25))
	local rock = Builder.deco({
		Size = s,
		CFrame = cf,
		Color = Builder.vary(P.Rock, rng, 0.05),
		Material = M.Slate,
		Name = "Rock",
		Parent = parent,
	})
	rock.CanCollide = true -- pedras grandes são sólidas (não ficam no caminho)
	if mossy then
		Builder.deco({
			Size = Vector3.new(s.X * 0.8, 0.3, s.Z * 0.7),
			CFrame = cf * CFrame.new(0, s.Y / 2, 0),
			Color = P.Moss,
			Material = M.Grass,
			CastShadow = false,
			Name = "Moss",
			Parent = parent,
		})
	end
	return rock
end

function Nature.mushroom(position: Vector3, scale: number, rng: Random, parent: Instance, glow: boolean?)
	local h = rng:NextNumber(0.8, 1.6) * scale
	Builder.cylinder(position, position + Vector3.new(0, h, 0), 0.18 * scale, { Color = P.FungusCap, Name = "Stem", Parent = parent })
	local capColor = glow and Color3.fromRGB(170, 210, 255) or ((rng:NextNumber() < 0.5) and P.Fungus or Color3.fromRGB(236, 150, 120))
	Builder.deco({
		Shape = Enum.PartType.Ball,
		Size = Vector3.new(0.9, 0.5, 0.9) * scale,
		CFrame = CFrame.new(position + Vector3.new(0, h, 0)),
		Color = capColor,
		Material = glow and M.Neon or M.SmoothPlastic,
		CastShadow = false,
		Name = "Cap",
		Parent = parent,
	})
end

-- Tufos de capim alto (variação perto das bordas e da água)
function Nature.reeds(position: Vector3, rng: Random, parent: Instance)
	for _ = 1, 4 do
		local base = position + Vector3.new(rng:NextNumber(-0.8, 0.8), 0, rng:NextNumber(-0.8, 0.8))
		local tip = base + Vector3.new(rng:NextNumber(-0.4, 0.4), rng:NextNumber(1.6, 2.6), rng:NextNumber(-0.4, 0.4))
		Builder.cylinder(base, tip, 0.08, { Color = P.GrassDark, CastShadow = false, Name = "Reed", Parent = parent })
	end
end

--[[
	Árvore gigante da Floresta das Nuvens.
	data: center (base), radius, height, canopy (bool), name
]]
function Nature.giantTree(data, rng: Random, parent: Instance, clearance)
	local model = Builder.model(data.name or "ArvoreGigante", parent)
	local base = data.center
	local r = data.radius
	local h = data.height
	local segments = 4
	for i = 0, segments - 1 do
		local y0 = base.Y + h * (i / segments)
		local y1 = base.Y + h * ((i + 1) / segments)
		local rr = r * (1 - i * 0.07)
		Builder.cylinder(Vector3.new(base.X, y0, base.Z), Vector3.new(base.X, y1 + 1, base.Z), rr, {
			Color = Builder.vary(P.Bark, rng, 0.03),
			Material = M.Wood,
			Name = "Trunk",
			Parent = model,
		}, false)
	end
	-- sulcos da casca (detalhe vertical)
	for i = 1, 8 do
		local a = (i / 8) * math.pi * 2
		local dir = Vector3.new(math.cos(a), 0, math.sin(a))
		local p = Vector3.new(base.X, base.Y + h * 0.45, base.Z) + dir * (r * 0.97)
		Builder.deco({
			Size = Vector3.new(r * 0.25, h * 0.85, r * 0.25),
			CFrame = CFrame.lookAt(p, p + dir),
			Color = P.BarkDark,
			Material = M.Wood,
			Name = "Ridge",
			Parent = model,
		})
	end
	-- trepadeiras penduradas
	for i = 1, 6 do
		local a = rng:NextNumber(0, math.pi * 2)
		local dir = Vector3.new(math.cos(a), 0, math.sin(a))
		local top = Vector3.new(base.X, base.Y + h * rng:NextNumber(0.7, 0.95), base.Z) + dir * (r + 0.2)
		Builder.deco({
			Size = Vector3.new(0.5, rng:NextNumber(14, 28), 0.3),
			CFrame = CFrame.lookAt(top, top + dir) * CFrame.new(0, -10, 0),
			Color = P.LeafDeep,
			Material = M.Grass,
			CastShadow = false,
			Name = "Vine",
			Parent = model,
		})
	end
	-- copa gigante
	if data.canopy ~= false then
		local top = Vector3.new(base.X, base.Y + h, base.Z)
		for i = 1, 7 do
			local a = (i / 7) * math.pi * 2
			local size = rng:NextNumber(12, 18)
			local c = top + Vector3.new(math.cos(a) * r * 1.6, rng:NextNumber(-4, 6), math.sin(a) * r * 1.6)
			local half = Vector3.new(size, size, size)
			if not clearance or clearance:isFree(c - half, c + half) then
				local ball = Builder.ball(c, size, {
					Color = (i % 3 == 0) and P.BlossomLight or Builder.vary(P.Leaf, rng, 0.05),
					Name = "Canopy",
					Parent = model,
				})
				ball.CastShadow = true
			end
		end
	end
	return model
end

return Nature
