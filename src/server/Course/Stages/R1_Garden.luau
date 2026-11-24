--[[
	Região 1 — Jardim das Cerejeiras
	Prado inicial, riacho com pedras, raízes e tocos, troncos sobre a ravina,
	jangada no lago e a primeira parede de escalada.
]]

-- Área de água/ravina exatamente entre dois pontos do percurso
local function between(L, a: Vector3, b: Vector3, width: number, y: number, extra)
	local mid = (a + b) / 2
	local data = {
		center = Vector3.new(mid.X, y, mid.Z),
		yaw = L.yaw,
		width = width,
		length = (Vector3.new(b.X, 0, b.Z) - Vector3.new(a.X, 0, a.Z)).Magnitude - 1,
	}
	for k, v in extra or {} do
		data[k] = v
	end
	return data
end

return function(L)
	L:region(1)

	-- Prado de partida (se estende também para trás do ponto inicial)
	L:zone("meadow", 76, 60, { back = 28 })
	L:walk(4)
	L:checkpoint({ label = "Prado Inicial" })
	L:walkToEdge()

	-- Riacho: pedras de rio (primeiros saltos, bem fáceis)
	local streamStart = L.pos
	L:pad({ gap = 3, rise = 0.8, size = 5, style = "riverstone" })
	L:pad({ gap = 3, rise = 0, size = 5, style = "riverstone", lateral = 1.5 })
	L:pad({ gap = 3, rise = 0, size = 5, style = "riverstone", lateral = -1.5 })
	L:pad({ gap = 3, rise = 0, size = 5, style = "riverstone" })
	local streamEnd = L.pos + L:fwd() * 3
	-- o riacho corre de lado (atravessa o caminho); depth em studs
	local s = between(L, streamStart, streamEnd, 1, -0.6, { depth = 3.5 })
	s.width, s.length = 220, s.length - 6
	L:prop("stream", s)

	-- Jardim baixo com cerejeiras
	L:zone("garden", 60, 56, { gap = 3, rise = -0.8, offset = -4 })
	L:walk(18)
	L:prop("bench", { position = L:at(-7, 0, 0) })
	L:walkToEdge()

	-- Tocos e raízes subindo a colina
	for _ = 1, 4 do
		L:pad({ gap = 2.5, rise = 2, size = 4.5, style = "stump", support = 0 })
	end
	L:pad({ gap = 3, rise = 2.5, size = 5, style = "boulder", support = 0 })
	L:pad({ gap = 3, rise = 2.5, size = 5, style = "boulder", support = 0 })

	-- Colina das raízes
	L:zone("hill", 52, 44, { gap = 3, rise = 1.5, offset = 4 })
	L:walk(10)
	L:checkpoint({ label = "Colina das Raízes" })
	L:walkToEdge()

	-- Ravina com rio: tronco caído, rocha, tronco inclinado
	local ravineStart = L.pos
	L:beam({ gap = 2.5, length = 14, width = 2.4, style = "log" })
	L:pad({ size = 6, style = "boulder", support = -10 })
	L:beam({ length = 16, width = 2.2, tilt = 4, style = "log" })
	L:prop("ravine", between(L, ravineStart, L.pos, 90, 0, { depth = 10 }))

	-- Bosque com laguinho
	L:zone("grove", 50, 42, { offset = -3 })
	L:walk(16)
	L:prop("pond", { center = L:at(12, 0, 0), radius = 6 })
	L:walkToEdge()

	-- Jangada que atravessa o vão sobre o lago (plataforma móvel)
	local lakeStart = L.pos
	L:mover({ gap = 2.5, axis = "forward", travel = 14, size = 6, period = 7, style = "raft" })
	L:prop("lake", between(L, lakeStart, L.pos + L:fwd() * 2.5, 70, -0.5, { depth = 6 }))

	L:zone("cliffbase", 34, 22, { gap = 2.5 })
	L:walkToEdge()

	-- Primeira escalada: paredão coberto de trepadeiras
	L:climb({ height = 16, width = 4, style = "vine" })
	L:zone("orchard", 64, 52, { offset = 0 })
	L:walk(4)
	L:checkpoint({ label = "Pomar Florido" })
	L:walk(22)
	L:turn(90) -- vira para o norte, rumo à vila
	L:walkToEdge()

	-- Escadaria de pedra até o portão da vila
	L:stairs({ steps = 10, stepRise = 1, stepRun = 2, width = 7, style = "stone" })
end
