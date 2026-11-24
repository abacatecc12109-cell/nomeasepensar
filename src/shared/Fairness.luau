--[[
	Fairness
	--------
	Calcula, a partir da física real do personagem, qual distância de salto é
	justa para uma determinada subida. Usado por:
	  * CourseLayout (gera erro na hora de montar um salto injusto)
	  * testes automatizados (tests/course_spec.luau)
]]

local Config = require(script.Parent.Config)

local Fairness = {}

local g = Config.Physics.Gravity
local speed = Config.Physics.WalkSpeed
local jumpVelocity = math.sqrt(2 * g * Config.Physics.JumpHeight)

-- Alcance horizontal máximo (teórico) ao pousar `rise` studs acima da decolagem.
-- Negativo = pouso mais baixo (descida).
function Fairness.maxReach(rise: number): number
	local disc = jumpVelocity * jumpVelocity - 2 * g * rise
	if disc < 0 then
		return 0
	end
	local airTime = (jumpVelocity + math.sqrt(disc)) / g
	return speed * airTime
end

-- Maior vão (borda a borda) permitido para dificuldade média.
function Fairness.maxGap(rise: number): number
	if rise > Config.Difficulty.MaxRise then
		return 0
	end
	return Fairness.maxReach(math.max(rise, -6)) * Config.Difficulty.SafetyFactor
end

-- Retorna true se o salto é justo, ou false + motivo.
function Fairness.check(gap: number, rise: number): (boolean, string?)
	if rise > Config.Difficulty.MaxRise + 1e-6 then
		return false, string.format("subida %.2f > máximo %.2f", rise, Config.Difficulty.MaxRise)
	end
	local limit = Fairness.maxGap(rise)
	if gap > limit + 1e-6 then
		return false, string.format("vão %.2f > limite %.2f (subida %.2f)", gap, limit, rise)
	end
	return true, nil
end

Fairness.JumpVelocity = jumpVelocity

return Fairness
