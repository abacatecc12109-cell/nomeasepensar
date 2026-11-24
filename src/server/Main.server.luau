--[[
	Main (servidor)
	---------------
	Ordem de inicialização do jogo:
	  1. iluminação
	  2. layout do percurso (dados) + validação
	  3. reserva de espaço do percurso
	  4. terreno, peças do percurso, checkpoints e decoração
	  5. sistemas (checkpoints, progresso) e liberação dos jogadores
]]

local Players = game:GetService("Players")
local ServerStorage = game:GetService("ServerStorage")
local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Config = require(Shared.Config)

local Server = script.Parent
local Builder = require(Server.World.Builder)
local Clearance = require(Server.World.Clearance)
local TerrainBuilder = require(Server.World.TerrainBuilder)
local Nature = require(Server.World.Nature)
local Decorator = require(Server.World.Decorator)
local CourseDefinition = require(Server.Course.CourseDefinition)
local CourseBuilder = require(Server.Course.CourseBuilder)
local LightingService = require(Server.Systems.LightingService)
local CourseInfo = require(Server.Systems.CourseInfo)
local CheckpointService = require(Server.Systems.CheckpointService)
local ProgressService = require(Server.Systems.ProgressService)

-- Ninguém nasce antes de o mundo existir
Players.CharacterAutoLoads = false

local started = os.clock()
local rng = Random.new(Config.WorldSeed)

LightingService.apply()

local layout = CourseDefinition.build()
for _, err in layout.errors do
	warn("[Percurso] " .. err)
end

local clearance = Clearance.new()
CourseBuilder.reserve(layout, clearance)

local worldInfo = TerrainBuilder.build(layout, clearance, rng)

local root = Builder.folder("Mundo", workspace)
Nature.init(rng, ServerStorage)
local triggers = CourseBuilder.build(layout, Builder.folder("Percurso", root), rng)
local decorations = Decorator.build(layout, Builder.folder("Cenario", root), rng, clearance, worldInfo)

CourseInfo.publish(layout)
CheckpointService.init(triggers)
ProgressService.init(CheckpointService)
ProgressService.markReady()

local summary = layout:summary()
print(string.format(
	"[Mundo das Cerejeiras] pronto em %.2fs — %d peças, %d decorações, %d checkpoints, altura %.0f a %.0f",
	os.clock() - started,
	Builder.stats.parts,
	decorations,
	summary.checkpoints,
	summary.minY,
	summary.maxY
))
