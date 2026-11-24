--[[
	LightingService
	---------------
	Iluminação de pôr do sol: névoa quente (Atmosphere), brilho (Bloom),
	raios de sol e correção de cor suave. O céu em degradê amarelo →
	laranja → rosa claro e o sol são desenhados no cliente (SkyController).
	O cliente ajusta a atmosfera por região (AmbientController).
]]

local Lighting = game:GetService("Lighting")
local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Regions = require(Shared.Regions)

local LightingService = {}

local function ensure(className: string, name: string, parent: Instance)
	local obj = parent:FindFirstChild(name)
	if not obj then
		obj = Instance.new(className)
		obj.Name = name
		obj.Parent = parent
	end
	return obj
end

function LightingService.apply()
	-- fim de tarde: sol baixo, luz dourada e sombras compridas
	Lighting.ClockTime = 17
	Lighting.GeographicLatitude = 30
	Lighting.Brightness = 2.3
	Lighting.Ambient = Color3.fromRGB(132, 112, 116)
	Lighting.OutdoorAmbient = Color3.fromRGB(172, 146, 146)
	Lighting.ColorShift_Top = Color3.fromRGB(255, 220, 176)
	Lighting.ColorShift_Bottom = Color3.fromRGB(255, 200, 210)
	Lighting.EnvironmentDiffuseScale = 1
	Lighting.EnvironmentSpecularScale = 0.6
	Lighting.ExposureCompensation = 0.1
	Lighting.GlobalShadows = true

	-- névoa quente (amarelo/laranja do lado do sol, rosa do lado oposto):
	-- combina com o céu em degradê que o cliente desenha (SkyController)
	local base = Regions[1].Atmosphere
	local atmosphere = ensure("Atmosphere", "Atmosphere", Lighting)
	atmosphere.Density = base.Density
	atmosphere.Offset = 0.25
	atmosphere.Color = base.Color
	atmosphere.Decay = base.Decay
	atmosphere.Glare = 0.6
	atmosphere.Haze = base.Haze

	-- o sol e o céu são desenhados pelo cliente; o céu padrão fica sem
	-- sol/lua/estrelas para não aparecer um segundo sol
	local sky = ensure("Sky", "Sky", Lighting)
	sky.SunAngularSize = 21
	sky.MoonAngularSize = 9
	sky.StarCount = 0
	sky.CelestialBodiesShown = false

	local bloom = ensure("BloomEffect", "Bloom", Lighting)
	bloom.Intensity = 0.7
	bloom.Size = 30
	bloom.Threshold = 1.4

	local rays = ensure("SunRaysEffect", "SunRays", Lighting)
	rays.Intensity = 0.08
	rays.Spread = 0.7

	local cc = ensure("ColorCorrectionEffect", "ColorCorrection", Lighting)
	cc.Brightness = 0.02
	cc.Contrast = 0.06
	cc.Saturation = 0
	cc.TintColor = Color3.fromRGB(255, 244, 236)

	-- poucas nuvens: as nuvens volumétricas ficam desligadas e o céu ganha
	-- só algumas nuvens grandes de verdade (Decorator)
	local clouds = ensure("Clouds", "Clouds", workspace.Terrain)
	clouds.Cover = 0
	clouds.Density = 0
	clouds.Color = Color3.fromRGB(255, 232, 220)
end

return LightingService
