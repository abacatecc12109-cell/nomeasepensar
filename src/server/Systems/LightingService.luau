--[[
	LightingService
	---------------
	Iluminação suave de fim de tarde: céu rosa e azul (Atmosphere), nuvens,
	brilho leve (Bloom), raios de sol e correção de cor levemente
	dessaturada para evitar cores exageradas.
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
	Lighting.ClockTime = 16.6
	Lighting.GeographicLatitude = 30
	Lighting.Brightness = 2.4
	Lighting.Ambient = Color3.fromRGB(118, 108, 126)
	Lighting.OutdoorAmbient = Color3.fromRGB(150, 140, 160)
	Lighting.ColorShift_Top = Color3.fromRGB(255, 228, 236)
	Lighting.ColorShift_Bottom = Color3.fromRGB(196, 210, 255)
	Lighting.EnvironmentDiffuseScale = 1
	Lighting.EnvironmentSpecularScale = 0.6
	Lighting.ExposureCompensation = 0.1
	Lighting.GlobalShadows = true

	local base = Regions[1].Atmosphere
	local atmosphere = ensure("Atmosphere", "Atmosphere", Lighting)
	atmosphere.Density = base.Density
	atmosphere.Offset = 0.2
	atmosphere.Color = base.Color
	atmosphere.Decay = base.Decay
	atmosphere.Glare = 0.35
	atmosphere.Haze = base.Haze

	local sky = ensure("Sky", "Sky", Lighting)
	sky.SunAngularSize = 16
	sky.MoonAngularSize = 9
	sky.StarCount = 1500
	sky.CelestialBodiesShown = true

	local bloom = ensure("BloomEffect", "Bloom", Lighting)
	bloom.Intensity = 0.55
	bloom.Size = 26
	bloom.Threshold = 1.6

	local rays = ensure("SunRaysEffect", "SunRays", Lighting)
	rays.Intensity = 0.06
	rays.Spread = 0.6

	local cc = ensure("ColorCorrectionEffect", "ColorCorrection", Lighting)
	cc.Brightness = 0.02
	cc.Contrast = 0.06
	cc.Saturation = -0.06
	cc.TintColor = Color3.fromRGB(255, 246, 248)

	local clouds = ensure("Clouds", "Clouds", workspace.Terrain)
	clouds.Cover = 0.52
	clouds.Density = 0.55
	clouds.Color = Color3.fromRGB(255, 236, 244)
end

return LightingService
