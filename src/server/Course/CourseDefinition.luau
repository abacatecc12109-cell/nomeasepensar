--[[
	CourseDefinition
	----------------
	Monta o percurso completo, região por região, em ordem de subida.
	Retorna um CourseLayout (dados puros) que é usado para construir terreno,
	obstáculos, decoração, checkpoints e as informações da interface.
]]

local CourseLayout = require(script.Parent.CourseLayout)
local Stages = script.Parent.Stages

local CourseDefinition = {}

CourseDefinition.Start = Vector3.new(-170, 0, -230)
CourseDefinition.StartYaw = math.rad(90) -- olhando para +X (leste)

local order = {
	"R1_Garden",
	"R2_Village",
	"R3_Cliffs",
	"R4_CloudForest",
	"R5_Celestial",
	"R6_CloudIslands",
	"R7_SunsetSky",
}

function CourseDefinition.build()
	local layout = CourseLayout.new(CourseDefinition.Start, CourseDefinition.StartYaw)
	for _, name in order do
		local stage = require(Stages:FindFirstChild(name))
		stage(layout)
	end
	return layout
end

return CourseDefinition
