--[[
	Water
	-----
	Cachoeiras (lâminas transparentes + espuma + névoa), plantas aquáticas.
	Lagos e rios em si são Terrain (ver TerrainBuilder).
]]

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Config = require(Shared.Config)
local Builder = require(script.Parent.Builder)

local Water = {}
local P = Config.Palette
local M = Enum.Material

local function emitter(parent: Instance, props)
	local e = Instance.new("ParticleEmitter")
	for k, v in props do
		(e :: any)[k] = v
	end
	e.Parent = parent
	return e
end

--[[
	data:
	  top    -> ponto no alto da borda de onde a água sai
	  drop   -> altura da queda
	  width  -> largura da lâmina
	  yaw    -> direção para onde a água "olha" (para fora do paredão)
]]
function Water.waterfall(data, parent: Instance, lowQuality: boolean?)
	local model = Builder.model("Cachoeira", parent)
	local f = Vector3.new(math.sin(data.yaw), 0, math.cos(data.yaw))
	local rot = CFrame.lookAt(Vector3.zero, f).Rotation
	local top = data.top + f * 0.8
	local drop = data.drop
	local w = data.width

	local sheet = Builder.deco({
		Size = Vector3.new(w, drop, 1),
		CFrame = CFrame.new(top - Vector3.new(0, drop / 2, 0)) * rot,
		Color = P.Water,
		Material = M.Glass,
		Transparency = 0.4,
		CastShadow = false,
		Name = "Sheet",
		Parent = model,
	})
	sheet:AddTag(Config.Tags.Waterfall)
	Builder.deco({
		Size = Vector3.new(w * 0.65, drop, 0.4),
		CFrame = CFrame.new(top - Vector3.new(0, drop / 2, 0) + f * 0.7) * rot,
		Color = P.WaterFoam,
		Material = M.SmoothPlastic,
		Transparency = 0.55,
		CastShadow = false,
		Name = "Foam",
		Parent = model,
	})
	-- lábio de espuma no topo
	Builder.deco({
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(w + 0.6, 1.4, 1.4),
		CFrame = CFrame.new(top - f * 0.2) * rot * CFrame.Angles(0, math.rad(90), 0),
		Color = P.WaterFoam,
		Material = M.SmoothPlastic,
		Transparency = 0.25,
		CastShadow = false,
		Name = "Lip",
		Parent = model,
	})

	-- respingos descendo pela lâmina
	local topAtt = Instance.new("Attachment")
	topAtt.Parent = sheet
	topAtt.Position = Vector3.new(0, drop / 2 - 0.5, -0.8)
	emitter(topAtt, {
		Name = "Spray",
		Texture = "rbxasset://textures/particles/sparkles_main.dds",
		Color = ColorSequence.new(P.WaterFoam),
		Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.3), NumberSequenceKeypoint.new(1, 1) }),
		Size = NumberSequence.new(0.5, 0.2),
		Lifetime = NumberRange.new(math.sqrt(2 * drop / 70) * 0.9, math.sqrt(2 * drop / 70)),
		Acceleration = Vector3.new(0, -70, 0),
		Speed = NumberRange.new(1, 2),
		SpreadAngle = Vector2.new(25, 25),
		Rate = lowQuality and 6 or 14,
		LightEmission = 0.3,
	})
	-- névoa no pé da cachoeira
	local bottomAtt = Instance.new("Attachment")
	bottomAtt.Parent = sheet
	bottomAtt.Position = Vector3.new(0, -drop / 2 + 1, -1.5)
	emitter(bottomAtt, {
		Name = "Mist",
		Texture = "rbxasset://textures/particles/smoke_main.dds",
		Color = ColorSequence.new(P.WaterFoam),
		Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.55), NumberSequenceKeypoint.new(1, 1) }),
		Size = NumberSequence.new(w * 0.35, w * 0.7),
		Lifetime = NumberRange.new(1.6, 2.6),
		Speed = NumberRange.new(2, 5),
		SpreadAngle = Vector2.new(70, 30),
		Rate = lowQuality and 2 or 5,
		LightEmission = 0.15,
	})
	return model
end

-- Vitórias-régias e flores de lótus
function Water.lilies(center: Vector3, radius: number, rng: Random, parent: Instance, count: number?)
	for _ = 1, count or 6 do
		local a = rng:NextNumber(0, math.pi * 2)
		local d = rng:NextNumber(0, radius)
		local p = center + Vector3.new(math.cos(a) * d, 0.05, math.sin(a) * d)
		local size = rng:NextNumber(1.6, 2.6)
		Builder.deco({
			Shape = Enum.PartType.Cylinder,
			Size = Vector3.new(0.12, size, size),
			CFrame = CFrame.new(p) * CFrame.Angles(0, 0, math.rad(90)),
			Color = Builder.vary(P.Leaf, rng, 0.05),
			CastShadow = false,
			Name = "LilyPad",
			Parent = parent,
		})
		if rng:NextNumber() < 0.45 then
			Builder.ball(p + Vector3.new(0, 0.3, 0), 0.4, { Color = P.BlossomLight, Name = "Lotus", Parent = parent })
		end
	end
end

return Water
