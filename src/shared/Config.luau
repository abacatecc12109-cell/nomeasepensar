--[[
	Config
	------
	Constantes globais do jogo, compartilhadas entre servidor e cliente.

	Tudo que influencia a justiça do parkour (física do personagem e limites
	de salto) está aqui, para que o layout do percurso, o validador de testes
	e o StarterPlayer usem exatamente os mesmos números.
]]

local Config = {}

-- Física do personagem (espelhada em default.project.json -> StarterPlayer)
Config.Physics = {
	Gravity = 196.2,
	WalkSpeed = 16,
	JumpHeight = 7.2,
	MaxSlopeAngle = 50,
}

-- Limites de dificuldade MÉDIA.
-- SafetyFactor: fração do alcance físico máximo que um salto pode exigir.
-- 0.72 significa que nenhum salto exige mais de 72% do alcance teórico,
-- então ninguém depende de sorte ou de "pixel perfect".
Config.Difficulty = {
	SafetyFactor = 0.72,
	MaxRise = 4.5, -- maior subida permitida em um único salto
	MinPlatformWidth = 1.2, -- vigas de equilíbrio mais estreitas
	MinLandingLength = 2.5,
}

-- Distância de queda abaixo do checkpoint que reinicia o jogador.
Config.FallResetDepth = 18

-- Nomes de atributos e tags (evita strings mágicas espalhadas)
Config.Attr = {
	Checkpoint = "Checkpoint", -- índice do checkpoint atual (Player)
	RunStart = "RunStart", -- workspace:GetServerTimeNow() do início
	RunFinish = "RunFinish", -- tempo final em segundos (0 = não terminou)
	BestTime = "BestTime",
	MaxHeight = "MaxHeight",
	CheckpointIndex = "CheckpointIndex", -- (Part do checkpoint)
	Region = "Region",
}

Config.Tags = {
	Checkpoint = "Checkpoint",
	MovingPlatform = "MovingPlatform",
	CollapsingPlank = "CollapsingPlank",
	FallingStone = "FallingStone",
	SwingingLog = "SwingingLog",
	WaterfallGust = "WaterfallGust",
	Waterfall = "Waterfall",
	GlowFlower = "GlowFlower",
}

-- Paleta suave (cores levemente dessaturadas, nada "neon" gritante)
Config.Palette = {
	Grass = Color3.fromRGB(104, 168, 82),
	GrassLight = Color3.fromRGB(132, 190, 98),
	GrassDark = Color3.fromRGB(78, 138, 70),
	Moss = Color3.fromRGB(96, 140, 84),
	Rock = Color3.fromRGB(128, 124, 118),
	RockDark = Color3.fromRGB(98, 96, 94),
	RockLight = Color3.fromRGB(168, 162, 152),
	Ground = Color3.fromRGB(122, 98, 74),
	Sand = Color3.fromRGB(214, 196, 160),

	Bark = Color3.fromRGB(92, 66, 54),
	BarkDark = Color3.fromRGB(70, 50, 42),
	Wood = Color3.fromRGB(160, 116, 78),
	WoodLight = Color3.fromRGB(196, 152, 106),
	WoodDark = Color3.fromRGB(116, 82, 58),
	Plaster = Color3.fromRGB(240, 230, 214),
	RoofRed = Color3.fromRGB(176, 88, 82),
	RoofTeal = Color3.fromRGB(86, 136, 140),
	RoofPlum = Color3.fromRGB(140, 92, 120),

	Blossom = Color3.fromRGB(246, 182, 204),
	BlossomLight = Color3.fromRGB(252, 210, 224),
	BlossomDeep = Color3.fromRGB(228, 146, 178),
	Leaf = Color3.fromRGB(92, 150, 80),
	LeafDeep = Color3.fromRGB(62, 116, 72),
	Fungus = Color3.fromRGB(214, 120, 96),
	FungusCap = Color3.fromRGB(236, 214, 188),

	Water = Color3.fromRGB(118, 186, 214),
	WaterFoam = Color3.fromRGB(232, 246, 252),

	Lantern = Color3.fromRGB(255, 214, 150),
	Glow = Color3.fromRGB(190, 236, 255),

	CheckpointIdle = Color3.fromRGB(196, 186, 176),
	CheckpointActive = Color3.fromRGB(255, 150, 190),

	FlowerColors = {
		Color3.fromRGB(250, 236, 120), -- amarelo
		Color3.fromRGB(246, 246, 250), -- branco
		Color3.fromRGB(196, 160, 236), -- lilás
		Color3.fromRGB(246, 150, 150), -- coral
		Color3.fromRGB(150, 190, 246), -- azul claro
		Color3.fromRGB(252, 190, 120), -- pêssego
	},
}

-- Ambientação sonora. Todos os áudios são públicos do Roblox (Pro Sound
-- Effects e APM Music), liberados para qualquer experiência. Para trocar um
-- som, basta trocar o número aqui.
local function id(n: number): string
	return "rbxassetid://" .. n
end

Config.Sounds = {
	-- dois sons em loop por região (misturados com volumes diferentes)
	Ambience = {
		{ { id(9116971174), 0.45 }, { id(9116258071), 0.25 } }, -- 1 Jardim: pássaros + vento nas folhas
		{ { id(9119383777), 0.4 }, { id(9120750367), 0.22 } }, -- 2 Vila: pássaros + sinos de vento
		{ { id(9112832297), 0.4 }, { id(9119646672), 0.3 } }, -- 3 Penhascos: pássaros da montanha + riacho
		{ { id(9114894498), 0.35 }, { id(9116258071), 0.3 } }, -- 4 Floresta: insetos + folhas
		{ { id(9120750073), 0.3 }, { id(9116971475), 0.35 } }, -- 5 Celestial: sinos de vento + pássaros
		{ { id(9114057128), 0.32 }, { id(9116390863), 0.2 } }, -- 6 Nuvens: vento leve + brilho mágico
		{ { id(9114057104), 0.3 }, { id(9116390952), 0.22 } }, -- 7 Entardecer: vento + brilho mágico
	},
	-- trilha calma, tocada em sequência, bem baixinha
	Music = {
		{ id(1839930857), 0.2 }, -- Sparkle Breeze (APM)
		{ id(9046862941), 0.2 }, -- Sunset Chill (APM)
		{ id(140619137413701), 0.18 }, -- Live Piano Stories 06 (APM)
	},
	Waterfall = { id(9120549564), 0.7 }, -- som 3D em cada cachoeira
	Checkpoint = { id(9116395089), 0.6 },
	Finish = { id(1842282377), 0.7 },
	NewRegion = { id(1840525342), 0.45 },
	FallReset = { id(9113078052), 0.5 },
	PlankCreak = { id(9120839010), 0.5 },
	CloudPuff = { id(9113840530), 0.45 },
}

-- Semente fixa: o mundo é sempre igual (bom para testes e para os jogadores
-- aprenderem o percurso).
Config.WorldSeed = 20261124

return Config
