--[[
	SkyPhases
	---------
	Gerador das fases no céu (regiões 6 e 7).

	Cada FASE é: uma ilha de nuvem (deck) com checkpoint + um desafio de
	parkour que leva até a próxima ilha. As fases sobem em espiral larga em
	volta de um centro fixo acima da montanha. A cada ilha o cursor mira um
	ponto mais à frente no círculo, então a espiral nunca se afasta do mapa.

	Os desafios variam em ciclo (saltos, nuvens que se movem, nuvens que se
	desfazem, elevadores, arco-íris, escadas...) e ficam um pouco mais
	exigentes nas fases finais, sempre dentro dos limites de Fairness.
]]

local CourseLayout = require(script.Parent.CourseLayout)

local SkyPhases = {}

local function flat(v: Vector3): Vector3
	return Vector3.new(v.X, 0, v.Z)
end

-- Ângulo do ponto p no círculo (convenção: ponto = centro + (sin a, 0, cos a) * R)
local function angleOf(center: Vector3, p: Vector3): number
	local rel = flat(p - center)
	return math.atan2(rel.X, rel.Z)
end

local function wrap(a: number): number
	while a > math.pi do
		a -= 2 * math.pi
	end
	while a < -math.pi do
		a += 2 * math.pi
	end
	return a
end

--[[
	Cria o controlador da espiral a partir da posição atual do cursor.
	side = +1 gira para a direita (o centro fica à direita do cursor).
]]
function SkyPhases.spiral(L, radius: number, side: number)
	local center = flat(L.pos + L:right() * (radius * side))
	return { center = center, radius = radius, side = side }
end

-- Vira o cursor para mirar um ponto `ahead` studs à frente no círculo.
function SkyPhases.aim(L, spiral, ahead: number)
	local a = angleOf(spiral.center, L.pos)
	-- girar com o centro à direita = sentido horário visto de cima
	local dir = -spiral.side
	local target = a + dir * (ahead / spiral.radius)
	local point = spiral.center + Vector3.new(math.sin(target), 0, math.cos(target)) * spiral.radius
	local to = flat(point - L.pos)
	if to.Magnitude < 0.5 then
		return
	end
	local desired = math.atan2(to.X, to.Z)
	local delta = wrap(desired - L.yaw)
	-- turn(+graus) diminui o yaw
	L:turn(-math.deg(delta))
end

-- ===================================================================
-- Desafios (cada um começa no fim da ilha e termina antes da próxima)
-- ===================================================================

local challenges = {}

-- Saltos em nuvens fofas, em zigue-zague
function challenges.hops(L, k, look)
	local n = 4 + (k % 2)
	for i = 1, n do
		L:pad({ gap = 3, rise = 1.5, size = look.size, style = look.cloud, lateral = (i % 2 == 0) and 1.6 or -1.6 })
	end
end

-- Escadinha de nuvens subindo
function challenges.stairs(L, k, look)
	for _ = 1, 5 do
		L:pad({ gap = 2.5, rise = 2.5, size = look.size, style = look.cloud })
	end
end

-- Nuvem que vai e volta levando o jogador
function challenges.ferry(L, k, look)
	L:pad({ gap = 3, rise = 1.5, size = look.size, style = look.cloud })
	L:mover({ gap = 2.5, axis = "forward", travel = 12 + (k % 3) * 2, size = 6, period = 7, style = look.cloud })
	L:pad({ gap = 2.5, rise = 1, size = look.size, style = look.cloud })
end

-- Nuvens que se desfazem ao serem pisadas
function challenges.crumble(L, k, look)
	L:fallingStones({ count = 5, gap = 3, rise = 1.2, size = look.size, zigzag = 1.3, style = look.cloud, fallDelay = look.fallDelay })
end

-- Elevador de nuvem
function challenges.lift(L, k, look)
	L:pad({ gap = 3, rise = 1, size = 6, style = look.cloud })
	L:mover({ gap = 2.5, axis = "vertical", travel = 12, size = 6, period = 8, style = look.cloud })
	L:pad({ gap = 3, rise = 1, size = look.size, style = look.cloud })
end

-- Pontes de arco-íris (vigas estreitas e inclinadas)
function challenges.rainbow(L, k, look)
	L:pad({ gap = 3, rise = 1.5, size = look.size, style = look.cloud })
	L:beam({ length = 14, width = look.beam, tilt = 3, style = "rainbow" })
	L:pad({ size = look.size, style = look.cloud })
	L:beam({ length = 12, width = look.beam, tilt = 2.5, style = "rainbow" })
end

-- Nuvens que cruzam o caminho de um lado para o outro
function challenges.drift(L, k, look)
	L:mover({ gap = 3, rise = 1, axis = "lateral", travel = 10, size = 6, period = 6, style = look.cloud })
	L:pad({ gap = 3, rise = 1.5, size = look.size, style = look.cloud })
	L:mover({ gap = 3, rise = 1, axis = "lateral", travel = 10, size = 6, period = 5.5, style = look.cloud })
end

-- Ponte de nuvem que se desfaz atrás de você
function challenges.fade(L, k, look)
	L:pad({ gap = 3, rise = 1.5, size = look.size, style = look.cloud })
	L:collapseBridge({ gap = 2.5, length = 16, width = 4, style = look.cloud })
	L:pad({ size = look.size, style = look.cloud })
end

-- Pedras-estrela pequenas (precisão)
function challenges.stars(L, k, look)
	for i = 1, 5 do
		L:pad({ gap = 3.2, rise = 1.2, size = 3.6, style = "star", lateral = (i % 2 == 0) and 1.2 or -1.2 })
	end
end

local CYCLE = { "hops", "ferry", "stairs", "crumble", "rainbow", "lift", "drift", "fade", "stars" }

SkyPhases.Challenges = challenges

--[[
	Constrói `count` fases.
	opts:
	  spiral       -> controlador da espiral (SkyPhases.spiral)
	  firstIndex   -> número da primeira fase (para nomes e variação)
	  look         -> visual: cloud (estilo), deck (tema), size, beam, fallDelay
	  names        -> lista de nomes para as ilhas
	  finish       -> se true, a última ilha é a chegada
]]
function SkyPhases.build(L, count: number, opts)
	local spiral = opts.spiral
	local look = opts.look
	local names = opts.names
	local islands = {}
	for i = 1, count do
		local index = opts.firstIndex + i - 1
		local last = opts.finish and i == count
		local size = last and 26 or 14
		local deck = L:zone(look.deck, size, size, { gap = 3, rise = 1, surface = "deck" })
		table.insert(islands, deck)
		L:walk(size / 2)
		local label = names[((index - 1) % #names) + 1]
		if last then
			L:finish({ label = opts.finishLabel or label })
			break
		end
		L:checkpoint({ label = string.format("%s · Fase %d", label, index) })
		SkyPhases.aim(L, spiral, 52)
		L:walkToEdge()
		local kind = CYCLE[((index - 1) % #CYCLE) + 1]
		challenges[kind](L, index, look)
	end
	return islands
end

SkyPhases.flat = flat
SkyPhases.angleOf = angleOf
SkyPhases.forwardOf = CourseLayout.forwardOf

return SkyPhases
