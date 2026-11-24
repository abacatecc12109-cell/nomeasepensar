--[[
	Região 4 — Floresta das Nuvens
	Raízes gigantes, espiral de cogumelos em volta de árvores enormes,
	galhos como pontes, troncos balançando, elevador de cipó, tronco
	inclinado e uma ponte que desaba na copa.
]]

-- Sobe em espiral ao redor de um tronco gigante usando cogumelos-prateleira.
-- Retorna o centro e o raio do tronco para a decoração.
local function spiral(L, opts)
	local pads = {}
	local turnAngle = opts.turn or 40
	for i = 1, opts.count do
		local p = L:pad({
			gap = (i == 1 and opts.firstGap) or opts.gap,
			rise = (i == 1 and opts.firstRise) or opts.rise,
			size = opts.size,
			style = opts.style or "fungus",
		})
		table.insert(pads, p)
		if i < opts.count then
			L:turn(turnAngle)
		end
	end
	local center = L.circumcenter(pads[2].center, pads[3].center, pads[4].center)
	local ring = (Vector3.new(pads[2].center.X, 0, pads[2].center.Z) - center).Magnitude
	local radius = ring - opts.size * 0.72 - 0.6
	return center, radius, pads
end

-- Tronco ao lado de um deck (o deck fica "pendurado" na árvore)
local function trunkBeside(L, deck, side, radius, depth, name)
	local r = L.rightOf(deck.yaw)
	local c = deck.center + r * (side * (deck.width / 2 + radius + 0.5))
	L:prop("gianttree", {
		center = Vector3.new(c.X, deck.top - depth, c.Z),
		radius = radius,
		height = depth + 60,
		name = name,
	})
end

return function(L)
	L:region(4)

	local floor = L:zone("forest_floor", 80, 96, { offset = -8 })
	L:walk(8)
	L:checkpoint({ label = "Portal da Névoa" })
	L:walk(58)
	L:turn(90) -- vira para o sul
	L:walkToEdge()

	-- Raízes gigantes como rampa
	L:beam({ gap = 0, length = 18, width = 3.2, tilt = 5, style = "root" })
	L:beam({ gap = 2.5, length = 14, width = 2.6, tilt = 3, style = "root" })

	-- Espiral ao redor da Árvore Anciã
	local centerA, radiusA, padsA = spiral(L, {
		count = 10,
		gap = 2.5,
		rise = 2.5,
		size = 5,
		turn = 40,
		firstGap = 2.5,
		firstRise = 1,
	})
	L:prop("gianttree", {
		center = Vector3.new(centerA.X, floor.top - 12, centerA.Z),
		radius = radiusA,
		height = padsA[#padsA].center.Y - floor.top + 80,
		name = "Árvore Anciã",
		canopy = true,
	})

	-- Galho até a casa na árvore
	L:beam({ gap = 2.5, length = 20, width = 2.6, tilt = 2, style = "branch" })
	local deckB = L:zone("deck_b", 18, 16, { surface = "deck" })
	trunkBeside(L, deckB, -1, 7, 120, "Árvore da Casa")
	L:walk(8)
	L:checkpoint({ label = "Casa na Árvore" })
	L:walkToEdge()

	-- Ponte de galhos com troncos balançando
	L:swingBridge({ length = 26, width = 5, logs = 3, period = 3.4, style = "branch" })
	L:pad({ size = 7, style = "deck" })

	-- Elevador de cipó (plataforma vertical)
	L:mover({ gap = 2.5, axis = "vertical", travel = 18, size = 6, period = 9, style = "basket" })
	L:pad({ gap = 3, rise = 1, size = 7, style = "deck" })

	-- Tronco inclinado subindo pela névoa
	L:beam({ gap = 2.5, length = 24, width = 2.4, tilt = 7, style = "log" })
	local deckC = L:zone("deck_c", 14, 18, { surface = "deck", offset = -4 })
	trunkBeside(L, deckC, -1, 8, 150, "Árvore do Ninho")
	L:walk(9)
	L:checkpoint({ label = "Ninho das Nuvens" })
	L:walkToEdge()

	-- Segunda espiral ao redor da Árvore das Nuvens
	local centerB, radiusB, padsB = spiral(L, {
		count = 9,
		gap = 2.5,
		rise = 2.5,
		size = 5,
		turn = 45,
		firstGap = 3,
		firstRise = 1,
	})
	L:prop("gianttree", {
		center = Vector3.new(centerB.X, padsB[1].center.Y - 150, centerB.Z),
		radius = radiusB,
		height = padsB[#padsB].center.Y - padsB[1].center.Y + 200,
		name = "Árvore das Nuvens",
		canopy = true,
	})

	L:collapseBridge({ gap = 2.5, length = 20, width = 4, style = "branch" })
	L:pad({ size = 7, style = "deck" })
	L:mover({ gap = 3, axis = "forward", travel = 14, size = 6, period = 7, style = "cloudstone" })
	local landing = L:zone("canopy_low", 22, 18, { gap = 3, surface = "deck" })
	trunkBeside(L, landing, 1, 9, 220, "Árvore da Copa")
	L:walkToEdge()

	-- Última escalada pelos cipós até a copa
	L:climb({ height = 22, width = 4, style = "vine" })
	L:zone("canopy", 26, 22, { surface = "deck" })
	L:walk(6)
	L:checkpoint({ label = "Copa das Nuvens" })
	L:walk(5)
	L:turn(90) -- vira para o leste, rumo ao topo da montanha
	L:walkToEdge()
end
