--[[
	Região 3 — Penhascos Verdes
	Trilhas estreitas na encosta, passagem pela cachoeira, ponte suspensa,
	pedras que caem, tronco sobre o abismo, pilares de pedra e escaladas.
]]

return function(L)
	L:region(3)

	L:zone("cliff_ledge", 34, 24, { offset = -4 })
	L:walkToEdge()

	-- Trilhas na encosta (o paredão fica do lado da montanha)
	L:ledge({ length = 18, width = 3.4, tilt = 2, wall = "right", style = "cliff" })
	L:ledge({ length = 16, width = 2.8, tilt = 2, wall = "right", style = "cliff" })
	L:waterfallLedge({ length = 20, width = 3.2, wall = "right", period = 4.4, gustTime = 1.4 })
	L:ledge({ length = 12, width = 3, tilt = 1.5, wall = "right", style = "cliff" })

	-- Rocha de apoio e ponte suspensa
	L:pad({ gap = 3, rise = 1, size = 7, style = "cliffrock", support = -40 })
	L:bridge({ length = 34, width = 4, style = "rope" })

	L:zone("cliff_mid", 40, 32, { offset = 4 })
	L:walk(8)
	L:checkpoint({ label = "Mirante da Ponte" })
	L:walkToEdge()

	-- Pedras soltas que despencam quando pisadas
	L:fallingStones({ count = 6, gap = 3, rise = 1.2, size = 4.5, zigzag = 1.5 })

	-- Pilar de pedra e tronco sobre o abismo
	L:pad({ gap = 3, rise = 1, size = 6, style = "pillar", support = -40 })
	L:beam({ length = 18, width = 1.8, tilt = 1, style = "log" })
	L:pad({ size = 6, style = "pillar", support = -40 })
	L:turn(90) -- vira para oeste, contornando a montanha
	L:beam({ gap = 2.5, length = 14, width = 1.6, tilt = 2, style = "log" })

	L:zone("cliff_terrace", 40, 30)
	L:walkToEdge()

	-- Cachoeira que desce do platô de cima (o riacho nasce lá em cima)
	L:prop("waterfall", { top = L:at(-12, 24, 0), drop = 24, width = 9, yaw = L.yaw + math.pi, pool = true })
	L:prop("river", { center = L:at(-12, 24 - 0.6, 9), yaw = L.yaw, width = 6, length = 18, depth = 1.6 })

	-- Escalada pela rocha úmida
	L:climb({ height = 24, width = 4, style = "vine" })
	L:zone("cliff_high", 44, 40, { offset = 2 })
	L:walk(8)
	L:checkpoint({ label = "Topo da Cascata" })
	L:walkToEdge()

	-- Plataforma móvel lateral (pedra flutuando sobre a correnteza)
	L:mover({ gap = 3, axis = "lateral", travel = 12, size = 6, period = 6, style = "stone" })
	L:pad({ gap = 3, rise = 1, size = 6, style = "pillar", support = -40 })

	-- Pilares crescentes
	for i = 1, 5 do
		L:pad({ gap = 3, rise = 3, size = 5.5, style = "pillar", support = -40, lateral = (i % 2 == 0) and 1.5 or -1.5 })
	end

	L:bridge({ gap = 0, length = 26, width = 4, style = "rope" })
	L:zone("cliff_top", 46, 34)
	L:walk(6)
	L:checkpoint({ label = "Crista Verde" })
	L:walkToEdge()

	-- Trilha da crista: encosta, tronco e uma segunda ponte suspensa
	L:ledge({ length = 20, width = 3, tilt = 3, wall = "right", style = "cliff" })
	L:ledge({ length = 16, width = 2.6, tilt = 2, wall = "right", style = "cliff" })
	L:pad({ gap = 3, rise = 1, size = 6, style = "pillar", support = -40 })
	L:beam({ length = 16, width = 1.6, tilt = 0, style = "log" })
	L:pad({ size = 6, style = "pillar", support = -40 })
	L:bridge({ length = 30, width = 4, style = "rope" })
	L:zone("cliff_crown", 40, 30)
	L:walkToEdge()
	L:prop("waterfall", { top = L:at(12, 26, 0), drop = 26, width = 9, yaw = L.yaw + math.pi, pool = true })
	L:prop("river", { center = L:at(12, 26 - 0.6, 9), yaw = L.yaw, width = 6, length = 18, depth = 1.6 })

	L:climb({ height = 26, width = 4, style = "vine" })
end
