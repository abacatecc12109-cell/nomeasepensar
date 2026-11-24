--[[
	Região 2 — Vila das Flores
	Caixotes, saltos entre telhados, prancha entre casas, ponte que desaba,
	escalada da torre do sino, ponte de corda até os jardins altos e o
	elevador do moinho.
]]

return function(L)
	L:region(2)

	local village = L:zone("village", 96, 150, { offset = 8 })
	local ground = village.top
	L:walk(8)
	L:checkpoint({ label = "Portão da Vila" })
	L:walk(22)
	L:prop("well", { position = L:at(9, 0, 4) })

	-- Caixotes encostados na primeira casa
	L:pad({ gap = 2, rise = 2.5, size = 4, style = "crate", support = ground })
	L:pad({ gap = 2, rise = 2.5, size = 4, style = "crate", support = ground, lateral = 1 })

	-- Telhados (casas de terraço com jardim no telhado)
	L:pad({ gap = 2.5, rise = 2.5, width = 11, length = 12, style = "roof", support = ground, house = { color = "RoofRed" } })
	L:pad({ gap = 4.5, rise = 0, width = 10, length = 11, style = "roof", support = ground, house = { color = "RoofTeal" } })

	-- Prancha estreita entre duas casas
	L:beam({ length = 12, width = 1.6, tilt = 2.5, style = "plank" })
	L:pad({ width = 11, length = 11, style = "roof", support = ground, house = { color = "RoofPlum" } })

	-- Ponte de tábuas que desaba até a base da torre
	L:collapseBridge({ length = 18, width = 4, style = "plank" })
	L:pad({ width = 10, length = 9, style = "towerbase", support = ground })

	-- Torre do sino: escada na fachada
	L:climb({ height = 18, width = 4, style = "ladder" })
	L:pad({ width = 11, length = 11, style = "towertop", support = ground })
	L:checkpoint({ label = "Torre do Sino" })

	-- Ponte de corda até os jardins altos
	L:bridge({ length = 24, width = 4.5, style = "rope" })

	local high = L:zone("village_high", 72, 54, { offset = 6 })
	-- cachoeira descendo dos jardins altos até a vila
	L:prop("river", { center = L:at(18, -0.6, 9), yaw = L.yaw, width = 5, length = 18, depth = 1.6 })
	L:prop("waterfall", { top = L:at(18, 0, 0), drop = high.top - ground, width = 8, yaw = L.yaw + math.pi, pool = true })
	L:walk(10)
	L:prop("gazebo", { position = L:at(-16, 0, 6) })
	L:walk(17)
	L:turn(-90)
	L:walk(8)
	L:turn(90)
	L:walkToEdge()

	-- Moinho: elevador de madeira (plataforma vertical)
	L:prop("windmill", { position = L:at(-13, 0, -7), ground = high.top })
	L:mover({ gap = 2.5, axis = "vertical", travel = 16, size = 6, period = 8, style = "lift" })

	L:zone("village_ledge", 40, 30, { gap = 3, rise = 1 })
	L:walk(6)
	L:checkpoint({ label = "Varanda do Moinho" })
	L:walkToEdge()

	L:stairs({ steps = 9, stepRise = 1, stepRun = 2, width = 6, style = "stone" })
end
