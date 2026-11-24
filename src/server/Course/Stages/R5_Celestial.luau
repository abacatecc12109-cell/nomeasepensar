--[[
	Região 5 — Jardim Celestial
	O topo do mundo: grande jardim com cerejeiras gigantes, lagos e cascatas,
	flores luminosas, um desafio sobre a cascata e o mirante, de onde
	saem as ilhas de nuvem.
	Também ergue o maciço central (a montanha que sustenta o jardim).
]]

return function(L)
	L:region(5)

	-- Ponte de pedra que sai da copa e chega ao jardim
	L:bridge({ gap = 0, length = 30, width = 5, style = "stonebridge" })

	local garden = L:zone("celestial", 100, 96, { offset = 6 })
	L:walk(10)
	L:checkpoint({ label = "Jardim Celestial" })
	L:walk(22)
	L:prop("lake", {
		center = L:at(-26, -0.8, 12),
		yaw = L.yaw,
		width = 24,
		length = 36,
		depth = 3,
		bank = garden.top + 0.5,
		decorative = true,
	})
	L:prop("temple", { position = L:at(24, 0, 10) })
	L:walkToEdge()

	-- Pedras de mármore sobre a cascata que despenca do jardim
	L:prop("river", { center = L:at(-12, -0.6, -11), yaw = L.yaw, width = 7, length = 22, depth = 1.8 })
	L:prop("waterfall", { top = L:at(-12, 0, 0), drop = 140, width = 14, yaw = L.yaw })
	L:fallingStones({ count = 4, gap = 3, rise = 1, size = 5, zigzag = 1.2, style = "marble" })
	L:mover({ gap = 3, axis = "forward", travel = 12, size = 6, period = 7, style = "petal" })

	local sanctuary = L:zone("sanctuary", 54, 46, { gap = 3, rise = 1 })
	L:walk(8)
	L:checkpoint({ label = "Santuário" })
	L:walkToEdge()

	-- Escadaria final até o mirante
	L:stairs({ steps = 16, stepRise = 1, stepRun = 2, width = 8, style = "marble" })
	local summit = L:zone("summit", 36, 36)
	L:walk(10)
	L:checkpoint({ label = "Mirante do Céu" })
	-- o caminho passa por baixo do pagode (só tem postes nos cantos) e segue
	-- para as ilhas de nuvem
	L:prop("pagoda", { position = L:at(0, 0, 0), ground = summit.top })
	L:walk(6)
	L:walkToEdge()

	-- Maciço central: degraus de montanha sob o jardim, o santuário e o mirante
	local function under(zone, grow, drop)
		local c = zone.center
		return L:massif(Vector3.new(c.X, zone.top - drop, c.Z), zone.width + grow, zone.length + grow, zone.yaw, "massif")
	end
	under(garden, 24, 30)
	under(garden, 60, 90)
	under(sanctuary, 30, 24)
	under(summit, 40, 20)
end
