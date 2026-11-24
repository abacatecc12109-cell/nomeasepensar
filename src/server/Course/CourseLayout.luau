--[[
	CourseLayout
	------------
	Descreve o percurso inteiro como DADOS (sem criar Instances).

	Funciona como uma "tartaruga": um cursor com posição e direção avança
	pelo mundo e cada chamada (zone, pad, beam, climb...) registra um
	elemento já conectado ao anterior. Por isso todas as regiões ficam
	fisicamente ligadas: o fim de um desafio é sempre o começo do próximo.

	Cada salto é verificado com Fairness (física real do personagem). Saltos
	injustos são registrados em layout.errors, que os testes exigem vazio.

	Convenções:
	  * Y de um elemento = altura da superfície onde o jogador pisa.
	  * yaw = 0 aponta para +Z. turn(+90) vira para a direita.
	  * width = largura (eixo lateral), length = comprimento (eixo do avanço).
]]

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Fairness = require(Shared.Fairness)
local Config = require(Shared.Config)

local CourseLayout = {}
CourseLayout.__index = CourseLayout

local GROUND_BOTTOM = -40 -- fundo do terreno das zonas

local function forwardOf(yaw: number): Vector3
	return Vector3.new(math.sin(yaw), 0, math.cos(yaw))
end

local function rightOf(yaw: number): Vector3
	return Vector3.new(-math.cos(yaw), 0, math.sin(yaw))
end

local function flat(v: Vector3): Vector3
	return Vector3.new(v.X, 0, v.Z)
end

CourseLayout.forwardOf = forwardOf
CourseLayout.rightOf = rightOf
CourseLayout.GROUND_BOTTOM = GROUND_BOTTOM

function CourseLayout.new(startPos: Vector3, yaw: number)
	local self = setmetatable({}, CourseLayout)
	self.pos = startPos
	self.yaw = yaw
	self.regionIndex = 1
	self.elements = {} -- tudo que é pisável, em ordem (zonas + peças)
	self.zones = {} -- subconjunto: áreas de terreno/deck
	self.pieces = {} -- subconjunto: peças de parkour
	self.walls = {} -- paredes de penhasco (terreno sem caminho)
	self.checkpoints = {}
	self.props = {} -- dicas de decoração amarradas ao percurso
	self.errors = {}
	self.current = nil -- elemento onde o cursor está
	self.pendingClimb = nil
	self.nextId = 1
	return self
end

-- ===================================================================
-- Utilidades internas
-- ===================================================================

function CourseLayout:_error(msg: string)
	table.insert(self.errors, string.format("[região %d, elemento %d] %s", self.regionIndex, self.nextId, msg))
end

function CourseLayout:fwd(): Vector3
	return forwardOf(self.yaw)
end

function CourseLayout:right(): Vector3
	return rightOf(self.yaw)
end

function CourseLayout:region(index: number)
	self.regionIndex = index
end

-- Ponto local (lateral, altura, avanço) relativo ao cursor.
function CourseLayout:at(lateral: number, up: number, ahead: number): Vector3
	return self.pos + self:right() * lateral + Vector3.new(0, up, 0) + self:fwd() * ahead
end

-- Calcula onde o próximo elemento começa e valida o salto.
function CourseLayout:_beginElement(gap: number, rise: number, lateral: number?): (Vector3, string, number)
	lateral = lateral or 0
	if self.pendingClimb then
		local climb = self.pendingClimb
		self.pendingClimb = nil
		if math.abs(gap) > 1e-6 or math.abs(lateral :: number) > 1e-6 then
			self:_error("depois de uma escalada o próximo elemento deve começar colado na parede")
		end
		return self.pos + Vector3.new(0, climb.height, 0), "climb", 0
	end
	local entry = self.pos + self:fwd() * gap + self:right() * (lateral :: number) + Vector3.new(0, rise, 0)
	local dist = flat(entry - self.pos).Magnitude
	if dist < 0.05 and math.abs(rise) < 0.05 then
		return entry, "walk", 0
	end
	local ok, why = Fairness.check(dist, rise)
	if not ok then
		self:_error("salto injusto: " .. tostring(why))
	end
	if dist < 1 and math.abs(rise) > 1.2 then
		self:_error("degrau alto sem vão (o jogador bate a cabeça/fica preso)")
	end
	return entry, "jump", dist
end

function CourseLayout:_register(element)
	element.id = self.nextId
	element.region = self.regionIndex
	self.nextId += 1
	table.insert(self.elements, element)
	if element.kind == "zone" then
		table.insert(self.zones, element)
	else
		table.insert(self.pieces, element)
	end
	self.current = element
	return element
end

-- Retângulo orientado: centro (no topo), yaw, largura, comprimento.
local function insideRect(element, point: Vector3, margin: number): boolean
	local rel = flat(point - element.center)
	local f = forwardOf(element.yaw)
	local r = rightOf(element.yaw)
	local along = rel:Dot(f)
	local side = rel:Dot(r)
	return math.abs(along) <= element.length / 2 + margin and math.abs(side) <= element.width / 2 + margin
end
CourseLayout.insideRect = insideRect

-- ===================================================================
-- Zonas: áreas grandes de terreno (ou decks de madeira) onde se caminha
-- ===================================================================

--[[
	opts:
	  gap, rise, lateral -> como chegar nela (salto a partir do cursor)
	  offset  -> desloca o retângulo para o lado (o caminho não fica no meio)
	  back    -> quanto da zona se estende para trás do ponto de entrada
	  surface -> "terrain" (padrão) ou "deck" (plataforma construída)
	  bottom  -> base do terreno (padrão: chão do mundo)
]]
function CourseLayout:zone(theme: string, width: number, length: number, opts)
	opts = opts or {}
	local entry, connect, dist = self:_beginElement(opts.gap or 0, opts.rise or 0, opts.lateral)
	local back = opts.back or 0
	local center = entry + self:fwd() * (length / 2 - back) + self:right() * (opts.offset or 0)
	local surface = opts.surface or "terrain"
	local zone = self:_register({
		kind = "zone",
		theme = theme,
		surface = surface,
		center = center,
		top = entry.Y,
		-- decks são plataformas construídas (finas); terreno vai até o chão
		bottom = opts.bottom or (surface == "deck" and entry.Y - 3 or GROUND_BOTTOM),
		yaw = self.yaw,
		width = width,
		length = length,
		entry = entry,
		connect = connect,
		gap = dist,
		rise = opts.rise or 0,
		path = { entry },
		params = opts,
	})
	self.pos = entry
	return zone
end

-- Caminha dentro da zona atual (o caminho vira trilha de pedra/madeira).
function CourseLayout:walk(distance: number)
	local cur = self.current
	local target = self.pos + self:fwd() * distance
	if not cur or not insideRect(cur, target, 0.05) then
		self:_error(string.format("walk(%.1f) sai da área atual", distance))
	end
	self.pos = target
	if cur and cur.path then
		table.insert(cur.path, target)
	end
end

-- Distância até a borda do elemento atual na direção do cursor.
function CourseLayout:distanceToEdge(): number
	local cur = self.current
	if not cur then
		return 0
	end
	local f = self:fwd()
	local rel = flat(self.pos - cur.center)
	local ef = forwardOf(cur.yaw)
	local er = rightOf(cur.yaw)
	local best = math.huge
	for _, axis in { { ef, cur.length / 2 }, { er, cur.width / 2 } } do
		local dir, half = axis[1], axis[2]
		local d = f:Dot(dir)
		local p = rel:Dot(dir)
		if math.abs(d) > 1e-6 then
			local t = d > 0 and (half - p) / d or (-half - p) / d
			if t >= -1e-6 and t < best then
				best = t
			end
		end
	end
	return math.max(0, best)
end

function CourseLayout:walkToEdge(margin: number?)
	self:walk(self:distanceToEdge() - (margin or 0))
end

-- Vira o cursor. Em zonas vira no lugar; em plataformas pequenas vira em
-- torno do centro da plataforma (para curvas e espirais).
function CourseLayout:turn(degrees: number)
	local cur = self.current
	if cur and cur.kind ~= "zone" and cur.pivotTurn then
		local c = Vector3.new(cur.center.X, self.pos.Y, cur.center.Z)
		self.yaw -= math.rad(degrees)
		local half = (math.abs(degrees) % 180 == 90) and cur.width / 2 or cur.length / 2
		if math.abs(degrees) % 90 ~= 0 then
			half = math.min(cur.width, cur.length) / 2
		end
		self.pos = c + self:fwd() * half
	else
		self.yaw -= math.rad(degrees)
	end
end

-- ===================================================================
-- Peças de parkour
-- ===================================================================

local function straightPiece(self, kind: string, opts, defaults)
	local width = opts.width or defaults.width
	local length = opts.length or defaults.length
	local tilt = opts.tilt or 0 -- subida ao longo da peça (troncos inclinados)
	local entry, connect, dist = self:_beginElement(opts.gap or 0, opts.rise or 0, opts.lateral)
	local f = self:fwd()
	local exit = entry + f * length + Vector3.new(0, tilt, 0)
	if width < Config.Difficulty.MinPlatformWidth - 1e-6 then
		self:_error(string.format("%s estreito demais (%.2f)", kind, width))
	end
	if tilt ~= 0 then
		local slope = math.deg(math.atan(math.abs(tilt) / length))
		if slope > Config.Physics.MaxSlopeAngle - 8 then
			self:_error(string.format("inclinação de %.1f° é íngreme demais", slope))
		end
	end
	local piece = self:_register({
		kind = kind,
		style = opts.style or defaults.style,
		center = (entry + exit) / 2,
		yaw = self.yaw,
		width = width,
		length = length,
		thickness = opts.thickness or defaults.thickness or 1.2,
		tilt = tilt,
		entry = entry,
		exit = exit,
		connect = connect,
		gap = dist,
		rise = opts.rise or 0,
		support = opts.support, -- altura do chão para colunas/pilares/casas
		pivotTurn = opts.pivotTurn,
		params = opts,
	})
	self.pos = exit
	return piece
end

-- Plataforma natural: pedra, toco, cogumelo, telhado...
function CourseLayout:pad(opts)
	opts = opts or {}
	local size = opts.size or 5
	opts.width = opts.width or size
	opts.length = opts.length or size
	if opts.pivotTurn == nil then
		opts.pivotTurn = true
	end
	if opts.length < Config.Difficulty.MinLandingLength then
		self:_error("plataforma curta demais para pousar")
	end
	return straightPiece(self, "pad", opts, { style = "stone", thickness = 2 })
end

-- Viga de equilíbrio: tronco, prancha, galho.
function CourseLayout:beam(opts)
	return straightPiece(self, "beam", opts or {}, { width = 2, length = 12, style = "log", thickness = 1.6 })
end

-- Ponte de madeira (com corrimão). Fixa.
function CourseLayout:bridge(opts)
	return straightPiece(self, "bridge", opts or {}, { width = 5, length = 20, style = "rope", thickness = 0.6 })
end

-- Trilha estreita na encosta, com paredão de pedra ao lado.
function CourseLayout:ledge(opts)
	opts = opts or {}
	local piece = straightPiece(self, "ledge", opts, { width = 3, length = 16, style = "cliff", thickness = 3 })
	local side = opts.wall == "left" and -1 or 1
	local wallWidth = opts.wallDepth or 14
	local r = rightOf(piece.yaw)
	local wallTop = math.max(piece.entry.Y, piece.exit.Y) + (opts.wallHeight or 24)
	local wall = {
		kind = "wall",
		region = self.regionIndex,
		center = Vector3.new(piece.center.X, wallTop, piece.center.Z) + r * side * (piece.width / 2 + wallWidth / 2),
		top = wallTop,
		bottom = GROUND_BOTTOM,
		yaw = piece.yaw,
		width = wallWidth,
		length = piece.length + 2,
		owner = piece.id,
	}
	piece.wallSide = side
	table.insert(self.walls, wall)
	return piece
end

-- Escadas (caminháveis, degraus de 1 stud).
function CourseLayout:stairs(opts)
	opts = opts or {}
	local steps = opts.steps or 8
	local stepRise = opts.stepRise or 1
	local stepRun = opts.stepRun or 2
	if stepRise > 1.6 then
		self:_error("degrau de escada alto demais para caminhar")
	end
	opts.length = steps * stepRun
	opts.tilt = steps * stepRise
	opts.thickness = opts.thickness or 1
	local piece = straightPiece(self, "stairs", opts, { width = opts.width or 6, style = "stone" })
	piece.steps = steps
	piece.stepRise = stepRise
	piece.stepRun = stepRun
	return piece
end

-- Ponte que desaba: tábuas caem logo após serem pisadas e voltam depois.
function CourseLayout:collapseBridge(opts)
	opts = opts or {}
	local piece = straightPiece(self, "collapse", opts, { width = 4, length = 20, style = "plank", thickness = 0.6 })
	piece.planks = opts.planks or math.floor(piece.length / 2.5)
	return piece
end

-- Sequência de pedras que caem quando o jogador pisa.
function CourseLayout:fallingStones(opts)
	opts = opts or {}
	local list = {}
	for i = 1, (opts.count or 4) do
		local p = straightPiece(self, "fallstone", {
			gap = (i == 1 and opts.firstGap) or opts.gap or 3,
			rise = opts.rise or 0,
			lateral = opts.zigzag and ((i % 2 == 0) and opts.zigzag or -opts.zigzag) or 0,
			width = opts.size or 4.5,
			length = opts.size or 4.5,
			style = opts.style or "stone",
		}, { thickness = 2 })
		p.fallDelay = opts.fallDelay or 0.55
		table.insert(list, p)
	end
	return list
end

--[[
	Plataforma móvel.
	  axis = "forward": vai e volta na direção do avanço (leva o jogador)
	  axis = "lateral": cruza o caminho de um lado para o outro
	  axis = "vertical": elevador natural (sobe `travel` studs)
	O jogador entra na posição A e sai na posição B.
]]
function CourseLayout:mover(opts)
	opts = opts or {}
	local axis = opts.axis or "forward"
	local travel = opts.travel or 12
	local size = opts.size or 5
	local entry, connect, dist = self:_beginElement(opts.gap or 3, opts.rise or 0, opts.lateral)
	local f = self:fwd()
	local centerA = entry + f * (size / 2)
	local centerB, exit
	if axis == "forward" then
		centerB = centerA + f * travel
		exit = entry + f * (size + travel)
	elseif axis == "vertical" then
		centerB = centerA + Vector3.new(0, travel, 0)
		exit = entry + f * size + Vector3.new(0, travel, 0)
	else
		-- lateral: oscila ±travel/2 em torno do caminho; alinhado no meio
		centerB = centerA
		exit = entry + f * size
	end
	local piece = self:_register({
		kind = "mover",
		style = opts.style or "stone",
		axis = axis,
		travel = travel,
		period = opts.period or 6,
		center = centerA,
		centerB = centerB,
		yaw = self.yaw,
		width = size,
		length = size,
		thickness = 1.5,
		entry = entry,
		exit = exit,
		connect = connect,
		gap = dist,
		rise = opts.rise or 0,
		params = opts,
	})
	self.pos = exit
	return piece
end

-- Ponte com troncos balançando (obstáculo com tempo).
function CourseLayout:swingBridge(opts)
	opts = opts or {}
	local piece = straightPiece(self, "swing", opts, { width = 5, length = 26, style = "branch", thickness = 1.2 })
	piece.logs = opts.logs or 3
	piece.period = opts.period or 3.4
	return piece
end

-- Trilha atrás/através de uma cachoeira que tem rajadas periódicas.
function CourseLayout:waterfallLedge(opts)
	opts = opts or {}
	opts.wall = opts.wall or "left"
	local piece = self:ledge(opts)
	piece.kind = "waterfall"
	piece.period = opts.period or 4.2
	piece.gustTime = opts.gustTime or 1.4
	return piece
end

-- Parede de escalada (treliça coberta de trepadeiras/escada).
-- A próxima zona/peça deve começar colada (gap 0) e fica `height` acima.
function CourseLayout:climb(opts)
	opts = opts or {}
	local height = opts.height or 12
	local width = opts.width or 4
	local cur = self.current
	local base = self.pos
	local climb = {
		kind = "climb",
		style = opts.style or "vine",
		region = self.regionIndex,
		base = base,
		height = height,
		width = width,
		yaw = self.yaw,
		-- a treliça fica sobre o fim da superfície atual, encostada na parede
		center = base - self:fwd() * 1 + Vector3.new(0, height / 2, 0),
	}
	if not cur then
		self:_error("escalada sem superfície de partida")
	elseif cur.kind ~= "zone" and (cur.length or 0) < 4 then
		self:_error("superfície curta demais antes da escalada")
	end
	table.insert(self.props, { type = "climb", data = climb, region = self.regionIndex })
	self.pendingClimb = climb
	return climb
end

-- ===================================================================
-- Marcadores
-- ===================================================================

function CourseLayout:checkpoint(opts)
	opts = opts or {}
	local cp = {
		index = #self.checkpoints + 1,
		position = self.pos,
		yaw = self.yaw,
		region = self.regionIndex,
		finish = opts.finish == true,
		label = opts.label,
		elementId = self.current and self.current.id,
	}
	table.insert(self.checkpoints, cp)
	return cp
end

function CourseLayout:finish(opts)
	opts = opts or {}
	opts.finish = true
	return self:checkpoint(opts)
end

-- Maciço de montanha (terreno sem caminho em cima) para dar corpo ao mundo.
-- center é o centro do topo; o terreno desce até o chão.
function CourseLayout:massif(center: Vector3, width: number, length: number, yaw: number?, theme: string?)
	local wall = {
		kind = "wall",
		theme = theme or "massif",
		region = self.regionIndex,
		center = center,
		top = center.Y,
		bottom = GROUND_BOTTOM,
		yaw = yaw or 0,
		width = width,
		length = length,
	}
	table.insert(self.walls, wall)
	return wall
end

-- Dica de decoração presa ao percurso (cachoeira, casa, árvore gigante...).
function CourseLayout:prop(propType: string, data)
	data = data or {}
	data.yaw = data.yaw or self.yaw
	table.insert(self.props, { type = propType, data = data, region = self.regionIndex })
	return data
end

-- Centro do círculo que passa por três pontos (no plano XZ).
function CourseLayout.circumcenter(a: Vector3, b: Vector3, c: Vector3): Vector3
	local ax, az, bx, bz, cx, cz = a.X, a.Z, b.X, b.Z, c.X, c.Z
	local d = 2 * (ax * (bz - cz) + bx * (cz - az) + cx * (az - bz))
	local ux = ((ax * ax + az * az) * (bz - cz) + (bx * bx + bz * bz) * (cz - az) + (cx * cx + cz * cz) * (az - bz)) / d
	local uz = ((ax * ax + az * az) * (cx - bx) + (bx * bx + bz * bz) * (ax - cx) + (cx * cx + cz * cz) * (bx - ax)) / d
	return Vector3.new(ux, 0, uz)
end

-- ===================================================================
-- Consultas usadas pelos construtores e pela interface
-- ===================================================================

-- Caixa (min, max) de um elemento, incluindo suportes e curso de movimento.
function CourseLayout.bounds(element): (Vector3, Vector3)
	local f = forwardOf(element.yaw)
	local r = rightOf(element.yaw)
	local hl, hw = element.length / 2, element.width / 2
	local ex = math.abs(f.X) * hl + math.abs(r.X) * hw
	local ez = math.abs(f.Z) * hl + math.abs(r.Z) * hw
	local c = element.center
	local top, bottom
	if element.kind == "zone" or element.kind == "wall" then
		top, bottom = element.top, element.bottom
	else
		local tilt = element.tilt or 0
		top = c.Y + math.abs(tilt) / 2
		bottom = c.Y - math.abs(tilt) / 2 - (element.thickness or 1)
		if element.support then
			bottom = math.min(bottom, element.support)
		end
	end
	local minV = Vector3.new(c.X - ex, bottom, c.Z - ez)
	local maxV = Vector3.new(c.X + ex, top, c.Z + ez)
	if element.kind == "mover" then
		local b = element.centerB
		if element.axis == "lateral" then
			local half = element.travel / 2
			local o = r * half
			minV = Vector3.new(math.min(minV.X, c.X - ex - math.abs(o.X)), minV.Y, math.min(minV.Z, c.Z - ez - math.abs(o.Z)))
			maxV = Vector3.new(math.max(maxV.X, c.X + ex + math.abs(o.X)), maxV.Y, math.max(maxV.Z, c.Z + ez + math.abs(o.Z)))
		else
			minV = Vector3.new(math.min(minV.X, b.X - ex), math.min(minV.Y, b.Y - 1.5), math.min(minV.Z, b.Z - ez))
			maxV = Vector3.new(math.max(maxV.X, b.X + ex), math.max(maxV.Y, b.Y), math.max(maxV.Z, b.Z + ez))
		end
	end
	return minV, maxV
end

function CourseLayout:summary()
	local minY, maxY = math.huge, -math.huge
	for _, e in self.elements do
		local top = e.kind == "zone" and e.top or (e.exit and e.exit.Y) or e.center.Y
		minY = math.min(minY, top)
		maxY = math.max(maxY, top)
	end
	return {
		elements = #self.elements,
		zones = #self.zones,
		pieces = #self.pieces,
		checkpoints = #self.checkpoints,
		minY = minY,
		maxY = maxY,
	}
end

return CourseLayout
