--[[
	Regions
	-------
	Identidade de cada região do mundo vertical.

	As alturas reais de início de cada região são calculadas pelo servidor a
	partir do percurso construído e publicadas em ReplicatedStorage.CourseInfo
	(atributos), para que a interface nunca fique dessincronizada do mapa.
	Aqui ficam apenas nome, cor e atmosfera.
]]

export type Region = {
	Index: number,
	Name: string,
	Subtitle: string,
	Accent: Color3,
	Petals: boolean, -- pétalas de cerejeira caindo
	Fireflies: boolean, -- partículas de luz (regiões altas)
	Atmosphere: {
		Density: number,
		Haze: number,
		Color: Color3,
		Decay: Color3,
	},
}

local Regions: { Region } = {
	{
		Index = 1,
		Name = "Jardim das Cerejeiras",
		Subtitle = "Onde a subida começa",
		Accent = Color3.fromRGB(246, 168, 196),
		Petals = true,
		Fireflies = false,
		Atmosphere = {
			Density = 0.28,
			Haze = 1.2,
			Color = Color3.fromRGB(236, 206, 222),
			Decay = Color3.fromRGB(150, 176, 222),
		},
	},
	{
		Index = 2,
		Name = "Vila das Flores",
		Subtitle = "Telhados, pontes e jardins",
		Accent = Color3.fromRGB(250, 206, 120),
		Petals = true,
		Fireflies = false,
		Atmosphere = {
			Density = 0.27,
			Haze = 1.1,
			Color = Color3.fromRGB(240, 214, 214),
			Decay = Color3.fromRGB(156, 182, 226),
		},
	},
	{
		Index = 3,
		Name = "Penhascos Verdes",
		Subtitle = "Cachoeiras e trilhas suspensas",
		Accent = Color3.fromRGB(140, 206, 150),
		Petals = false,
		Fireflies = false,
		Atmosphere = {
			Density = 0.3,
			Haze = 1.6,
			Color = Color3.fromRGB(214, 222, 230),
			Decay = Color3.fromRGB(140, 176, 220),
		},
	},
	{
		Index = 4,
		Name = "Floresta das Nuvens",
		Subtitle = "Raízes gigantes na névoa",
		Accent = Color3.fromRGB(170, 200, 236),
		Petals = false,
		Fireflies = true,
		Atmosphere = {
			Density = 0.42,
			Haze = 2.6,
			Color = Color3.fromRGB(222, 226, 236),
			Decay = Color3.fromRGB(176, 190, 226),
		},
	},
	{
		Index = 5,
		Name = "Jardim Celestial",
		Subtitle = "O topo do mundo",
		Accent = Color3.fromRGB(214, 180, 250),
		Petals = true,
		Fireflies = true,
		Atmosphere = {
			Density = 0.22,
			Haze = 0.8,
			Color = Color3.fromRGB(246, 214, 236),
			Decay = Color3.fromRGB(170, 160, 236),
		},
	},
}

return Regions
