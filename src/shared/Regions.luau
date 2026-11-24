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
			Density = 0.24,
			Haze = 1.4,
			Color = Color3.fromRGB(255, 214, 160),
			Decay = Color3.fromRGB(252, 196, 210),
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
			Density = 0.24,
			Haze = 1.3,
			Color = Color3.fromRGB(255, 210, 156),
			Decay = Color3.fromRGB(252, 192, 206),
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
			Density = 0.26,
			Haze = 1.6,
			Color = Color3.fromRGB(255, 206, 160),
			Decay = Color3.fromRGB(246, 190, 206),
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
			Density = 0.36,
			Haze = 2.4,
			Color = Color3.fromRGB(246, 214, 196),
			Decay = Color3.fromRGB(236, 196, 212),
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
			Density = 0.2,
			Haze = 1.0,
			Color = Color3.fromRGB(255, 214, 170),
			Decay = Color3.fromRGB(252, 196, 220),
		},
	},
	{
		Index = 6,
		Name = "Ilhas de Nuvens",
		Subtitle = "Pulando de nuvem em nuvem",
		Accent = Color3.fromRGB(255, 214, 150),
		Petals = false,
		Fireflies = false,
		Atmosphere = {
			Density = 0.2,
			Haze = 1.4,
			Color = Color3.fromRGB(255, 214, 160),
			Decay = Color3.fromRGB(252, 196, 214),
		},
	},
	{
		Index = 7,
		Name = "Céu do Entardecer",
		Subtitle = "Rumo ao Trono do Sol",
		Accent = Color3.fromRGB(255, 170, 150),
		Petals = true,
		Fireflies = true,
		Atmosphere = {
			Density = 0.18,
			Haze = 1.2,
			Color = Color3.fromRGB(255, 196, 140),
			Decay = Color3.fromRGB(255, 186, 210),
		},
	},
}

return Regions
