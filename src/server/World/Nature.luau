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
	pine = {},
	bush = {},
	-- versões leves (menos peças) para as árvores distantes
	cherryFar = {},
	greenFar = {},
}

-- ===================================================================
-- Modelos-base
-- ===================================================================

-- Tufo de folhas "low poly": blocos achatados e girados (nada de bolas
-- perfeitas). Os de cima são mais claros (luz do sol), os de baixo mais
-- escuros, o que dá volume de copa de verdade.
local function leafClump(model: Model, center: Vector3, size: number, colors, rng: Random, name: string, material)
	local n = 3
	for i = 1, n do
		local s = size * rng:NextNumber(0.72, 1.0)
		local dims = Vector3.new(s * rng:NextNumber(1.05, 1.35), s * rng:NextNumber(0.5, 0.7), s * rng:NextNumber(0.95, 1.25))
		local offset = Vector3.new(rng:NextNumber(-0.32, 0.32) * size, (i - 2) * 0.22 * size, rng:NextNumber(-0.32, 0.32) * size)
		local part = Builder.deco({
			Size = dims,
			CFrame = CFrame.new(center + offset) * CFrame.Angles(rng:NextNumber(-0.4, 0.4), rng:NextNumber(0, math.pi * 2), rng:NextNumber(-0.4, 0.4)),
			Color = colors[math.clamp(i, 1, #colors)],
			Material = material,
			Name = name,
			Parent = model,
		})
		part.CastShadow = true
	end
end

-- Galho (cilindro) com junta arredondada na base
local function limb(model: Model, a: Vector3, b: Vector3, radius: number, bark: Color3, name: string?)
	Builder.cylinder(a, b, radius, { Color = bark, Material = M.Wood, Name = name or "Branch", Parent = model })
end

--[[
	Árvore comum (cerejeira ou folhosa): tronco afinando e levemente torto,
	raízes aparentes, galhos que se abrem em forquilha e copa feita de
	vários tufos achatados nas pontas dos galhos.
]]
local function buildBroadleaf(kind: string, rng: Random, simple: boolean?): Model
	local cherry = kind == "cherry"
	local model = Instance.new("Model")
	model.Name = cherry and "Cerejeira" or "Arvore"
	local bark = cherry and Color3.fromRGB(96, 68, 58) or P.BarkDark
	local height = rng:NextNumber(7.5, 10)
	local lean = Vector3.new(rng:NextNumber(-1.2, 1.2), 0, rng:NextNumber(-1.2, 1.2))
	local p0 = Vector3.new(0, -0.6, 0)
	local p1 = Vector3.new(lean.X * 0.25 + rng:NextNumber(-0.3, 0.3), height * 0.45, lean.Z * 0.25 + rng:NextNumber(-0.3, 0.3))
	local p2 = Vector3.new(lean.X, height, lean.Z)
	-- o tronco é sólido (o jogador não atravessa árvores)
	Builder.cylinder(p0, p1, 0.85, { Color = bark, Material = M.Wood, Name = "Trunk", Parent = model }, false)
	Builder.cylinder(p1, p2, 0.6, { Color = bark, Material = M.Wood, Name = "Trunk", Parent = model }, false)
	Builder.ball(p1, 0.68, { Color = bark, Material = M.Wood, Name = "Trunk", Parent = model })
	-- raízes aparentes saindo do pé do tronco
	for i = 1, simple and 0 or 3 do
		local a = (i / 3) * math.pi * 2 + rng:NextNumber(-0.4, 0.4)
		local dir = Vector3.new(math.cos(a), 0, math.sin(a))
		limb(model, Vector3.new(0, 0.9, 0) + dir * 0.4, dir * 1.9 + Vector3.new(0, -0.3, 0), 0.34, bark, "Root")
	end
	-- galhos principais (forquilha) e tufos nas pontas
	local colors
	if cherry then
		colors = { P.BlossomDeep, P.Blossom, P.BlossomLight }
	else
		colors = { P.LeafDeep, P.Leaf, P.GrassLight }
	end
	local material = cherry and M.SmoothPlastic or M.Grass
	local spread = cherry and 4.2 or 3.2 -- cerejeira abre mais, copa larga e baixa
	local rise = cherry and 1.8 or 3
	local count = simple and 2 or rng:NextInteger(3, 4)
	local base = rng:NextNumber(0, math.pi * 2)
	for i = 1, count do
		local a = base + (i / count) * math.pi * 2 + rng:NextNumber(-0.35, 0.35)
		local dir = Vector3.new(math.cos(a), 0, math.sin(a))
		local from = p1:Lerp(p2, rng:NextNumber(0.55, 0.9))
		local to = from + dir * spread * rng:NextNumber(0.8, 1.15) + Vector3.new(0, rise * rng:NextNumber(0.8, 1.2), 0)
		limb(model, from, to, 0.3, bark)
		-- galhinho secundário
		local twig = to + (dir + Vector3.new(-dir.Z, 0, dir.X) * rng:NextNumber(-0.8, 0.8)).Unit * 1.4 + Vector3.new(0, 0.9, 0)
		if not simple then
			limb(model, to, twig, 0.16, bark, "Twig")
		end
		leafClump(model, to:Lerp(twig, 0.5) + Vector3.new(0, 0.9, 0), rng:NextNumber(2.6, 3.4), colors, rng, "Canopy", material)
	end
	-- tufo central no topo
	leafClump(model, p2 + Vector3.new(0, 1.6, 0), rng:NextNumber(3.2, 4), colors, rng, "Canopy", material)
	if cherry and not simple then
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

--[[
	Pinheiro: tronco reto e camadas de "saias" de folhas (dois blocos
	girados 45° formam um octógono), cada camada menor que a de baixo.
]]
local function buildPine(rng: Random): Model
	local model = Instance.new("Model")
	model.Name = "Pinheiro"
	local height = rng:NextNumber(11, 15)
	Builder.cylinder(Vector3.new(0, -0.6, 0), Vector3.new(0, height * 0.55, 0), 0.55, { Color = P.BarkDark, Material = M.Wood, Name = "Trunk", Parent = model }, false)
	local tiers = 4
	local colors = { Color3.fromRGB(58, 104, 76), Color3.fromRGB(66, 118, 82), Color3.fromRGB(78, 132, 88), Color3.fromRGB(92, 146, 96) }
	for t = 1, tiers do
		local k = (t - 1) / tiers
		local w = 7.4 * (1 - k * 0.72)
		local y = 2.6 + k * (height - 3.2)
		local spin = rng:NextNumber(0, 0.6)
		for j = 0, 1 do
			local part = Builder.deco({
				Size = Vector3.new(w, 2.4 - k * 0.6, w),
				CFrame = CFrame.new(0, y, 0) * CFrame.Angles(0, spin + j * math.rad(45), 0) * CFrame.Angles(rng:NextNumber(-0.06, 0.06), 0, rng:NextNumber(-0.06, 0.06)),
				Color = colors[t],
				Material = M.Grass,
				Name = "Canopy",
				Parent = model,
			})
			part.CastShadow = true
		end
	end
	-- pontinha
	Builder.deco({
		Size = Vector3.new(1.2, 2.2, 1.2),
		CFrame = CFrame.new(0, height + 0.4, 0) * CFrame.Angles(0, math.rad(45), 0),
		Color = colors[tiers],
		Material = M.Grass,
		Name = "Canopy",
		Parent = model,
	})
	model.WorldPivot = CFrame.new()
	return model
end

local function buildTree(kind: string, rng: Random, simple: boolean?): Model
	if kind == "pine" then
		return buildPine(rng)
	end
	return buildBroadleaf(kind, rng, simple)
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
	for i = 1, 3 do
		local t = buildTree("pine", rng)
		t.Parent = folder
		templates.pine[i] = t
	end
	for i = 1, 3 do
		local c = buildTree("cherry", rng, true)
		c.Parent = folder
		templates.cherryFar[i] = c
		local g = buildTree("green", rng, true)
		g.Parent = folder
		templates.greenFar[i] = g
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

function Nature.cherryTree(position: Vector3, scale: number, rng: Random, parent: Instance, far: boolean?): Model
	local list = far and templates.cherryFar or templates.cherry
	local t = list[rng:NextInteger(1, #list)]
	return place(t, position, scale, rng, parent, { Canopy = 0.04, Trunk = 0.03 })
end

-- Árvore verde: folhosa ou pinheiro (mais pinheiros nas regiões altas)
function Nature.greenTree(position: Vector3, scale: number, rng: Random, parent: Instance, pineChance: number?, far: boolean?): Model
	local list = (rng:NextNumber() < (pineChance or 0.35)) and templates.pine or (far and templates.greenFar or templates.green)
	local t = list[rng:NextInteger(1, #list)]
	return place(t, position, scale, rng, parent, { Canopy = 0.05, Trunk = 0.03 })
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
	Árvore gigante da Floresta das Nuvens (as "torres" de madeira).
	data: center (base), radius, height, canopy (bool), name

	O tronco NUNCA passa do raio informado (o percurso sobe em volta dele).
	Ele afina para cima, tem sulcos de casca que torcem de leve, nós,
	musgo, cogumelos-orelha, raízes enormes no pé, galhos de verdade lá no
	alto e uma copa feita de tufos de folhas (não de bolas).
]]
function Nature.giantTree(data, rng: Random, parent: Instance, clearance)
	local model = Builder.model(data.name or "ArvoreGigante", parent)
	local base = data.center
	local r = data.radius
	local h = data.height
	local barkColor = Builder.vary(Color3.fromRGB(104, 76, 60), rng, 0.03)
	local barkDark = Color3.fromRGB(72, 52, 42)
	local function free(minV: Vector3, maxV: Vector3): boolean
		return not clearance or clearance:isFree(minV, maxV)
	end
	local function radiusAt(t: number): number
		return r * (1 - 0.3 * t)
	end

	-- tronco: segmentos que afinam para cima (juntas encaixadas)
	local segments = 6
	for i = 0, segments - 1 do
		local t0, t1 = i / segments, (i + 1) / segments
		local y0 = base.Y + h * t0
		local y1 = base.Y + h * t1
		Builder.cylinder(Vector3.new(base.X, y0, base.Z), Vector3.new(base.X, y1 + 0.6, base.Z), radiusAt(t0), {
			Color = Builder.vary(barkColor, rng, 0.02),
			Material = M.Wood,
			Name = "Trunk",
			Parent = model,
		}, false)
	end

	-- sulcos da casca: faixas verticais escuras que torcem devagar
	local ridges = math.clamp(math.floor(r * 1.6), 8, 14)
	for i = 1, ridges do
		local a0 = (i / ridges) * math.pi * 2
		for k = 0, 2 do
			local t = (k + 0.5) / 3
			local a = a0 + t * 0.5
			local dir = Vector3.new(math.cos(a), 0, math.sin(a))
			local rr = radiusAt(t) - 0.15
			local p = Vector3.new(base.X, base.Y + h * t, base.Z) + dir * rr
			Builder.deco({
				Size = Vector3.new(math.max(0.7, r * 0.18), h / 3 + 1, 0.7),
				CFrame = CFrame.lookAt(p, p + dir) * CFrame.Angles(0, 0, 0.08),
				Color = (i % 2 == 0) and barkDark or Builder.vary(Color3.fromRGB(84, 62, 50), rng, 0.03),
				Material = M.Wood,
				Name = "Ridge",
				Parent = model,
			})
		end
	end

	-- nós, musgo e cogumelos-orelha na casca (só onde não encostam no percurso)
	for _ = 1, 14 do
		local t = rng:NextNumber(0.08, 0.92)
		local a = rng:NextNumber(0, math.pi * 2)
		local dir = Vector3.new(math.cos(a), 0, math.sin(a))
		local rr = radiusAt(t)
		local p = Vector3.new(base.X, base.Y + h * t, base.Z) + dir * rr
		local kind = rng:NextInteger(1, 3)
		local half = Vector3.new(1.6, 1.6, 1.6)
		if free(p - half, p + half) then
			if kind == 1 then
				Builder.ball(p, rng:NextNumber(0.8, 1.3), { Color = barkDark, Material = M.Wood, Name = "Knot", Parent = model })
			elseif kind == 2 then
				Builder.deco({
					Size = Vector3.new(rng:NextNumber(2, 3.5), rng:NextNumber(3, 6), 0.4),
					CFrame = CFrame.lookAt(p, p + dir),
					Color = P.Moss,
					Material = M.Grass,
					CastShadow = false,
					Name = "Moss",
					Parent = model,
				})
			else
				local shelf = p + dir * 0.6
				Builder.deco({
					Shape = Enum.PartType.Cylinder,
					Size = Vector3.new(0.35, 1.8, 1.8),
					CFrame = CFrame.new(shelf) * CFrame.Angles(0, 0, math.rad(90)),
					Color = P.FungusCap,
					Name = "Bracket",
					Parent = model,
				})
			end
		end
	end

	-- raízes enormes abraçando o chão
	for i = 1, 6 do
		local a = (i / 6) * math.pi * 2 + rng:NextNumber(-0.2, 0.2)
		local dir = Vector3.new(math.cos(a), 0, math.sin(a))
		local from = Vector3.new(base.X, base.Y + math.min(h * 0.08, r * 1.6), base.Z) + dir * (r * 0.7)
		local to = Vector3.new(base.X, base.Y - 1.5, base.Z) + dir * (r * 2.1)
		local lo = Vector3.new(math.min(from.X, to.X), to.Y, math.min(from.Z, to.Z)) - Vector3.new(1, 1, 1) * r * 0.4
		local hi = Vector3.new(math.max(from.X, to.X), from.Y, math.max(from.Z, to.Z)) + Vector3.new(1, 1, 1) * r * 0.4
		if free(lo, hi) then
			Builder.cylinder(from, to, r * 0.32, { Color = barkColor, Material = M.Wood, Name = "Root", Parent = model })
		end
	end

	-- trepadeiras penduradas
	for _ = 1, 6 do
		local a = rng:NextNumber(0, math.pi * 2)
		local dir = Vector3.new(math.cos(a), 0, math.sin(a))
		local t = rng:NextNumber(0.7, 0.95)
		local top = Vector3.new(base.X, base.Y + h * t, base.Z) + dir * (radiusAt(t) + 0.2)
		local length = rng:NextNumber(14, 28)
		Builder.deco({
			Size = Vector3.new(0.5, length, 0.3),
			CFrame = CFrame.lookAt(top, top + dir) * CFrame.new(0, -length / 2, 0),
			Color = P.LeafDeep,
			Material = M.Grass,
			CastShadow = false,
			Name = "Vine",
			Parent = model,
		})
	end

	-- copa: galhos grossos no alto + tufos de folhas nas pontas
	if data.canopy ~= false then
		local topY = base.Y + h
		local leafColors = { P.LeafDeep, P.Leaf, P.GrassLight }
		local blossomColors = { P.BlossomDeep, P.Blossom, P.BlossomLight }
		local branches = 6
		for i = 1, branches do
			local a = (i / branches) * math.pi * 2 + rng:NextNumber(-0.25, 0.25)
			local dir = Vector3.new(math.cos(a), 0, math.sin(a))
			local from = Vector3.new(base.X, topY - rng:NextNumber(4, 10), base.Z) + dir * (r * 0.4)
			local to = from + dir * (r * rng:NextNumber(1.8, 2.4)) + Vector3.new(0, rng:NextNumber(5, 10), 0)
			local size = rng:NextNumber(11, 16)
			local half = Vector3.new(size, size * 0.7, size)
			local lo = Vector3.new(math.min(from.X, to.X), from.Y, math.min(from.Z, to.Z)) - Vector3.new(2, 2, 2)
			local hi = Vector3.new(math.max(from.X, to.X), to.Y, math.max(from.Z, to.Z)) + Vector3.new(2, 2, 2)
			if free(lo, hi) and free(to - half, to + half) then
				Builder.cylinder(from, to, math.max(1.2, r * 0.22), { Color = barkColor, Material = M.Wood, Name = "Branch", Parent = model })
				local colors = (i % 3 == 0) and blossomColors or leafColors
				local clump = Builder.model("Copa", model)
				leafClump(clump, to + Vector3.new(0, size * 0.25, 0), size, colors, rng, "Canopy", (i % 3 == 0) and M.SmoothPlastic or M.Grass)
			end
		end
		-- tufo do topo
		local crown = Vector3.new(base.X, topY + 4, base.Z)
		local size = r * 2.4 + 6
		if free(crown - Vector3.new(size, size * 0.6, size), crown + Vector3.new(size, size * 0.6, size)) then
			local clump = Builder.model("Copa", model)
			leafClump(clump, crown, size, leafColors, rng, "Canopy", M.Grass)
		end
	end
	return model
end

return Nature
