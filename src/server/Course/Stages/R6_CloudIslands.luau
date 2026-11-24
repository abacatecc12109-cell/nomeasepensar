--[[
	Região 6 — Ilhas de Nuvens
	Do mirante sai uma ponte de nuvens para o céu. 32 fases de parkour em
	nuvens fofas: saltos, nuvens que se movem, que se desfazem, elevadores e
	pontes de arco-íris, subindo em espiral sobre a montanha.
]]

local SkyPhases = require(script.Parent.Parent.SkyPhases)

local NAMES = {
	"Ilha Algodão",
	"Ninho de Brisa",
	"Nuvem Travesseiro",
	"Ilha do Orvalho",
	"Recanto das Andorinhas",
	"Nuvem Marshmallow",
	"Ilha da Garoa",
	"Varanda do Vento",
}

return function(L)
	L:region(6)

	-- ponte de nuvem saindo do mirante (encosta no fim do platô)
	L:pad({ gap = 3, rise = 1.5, size = 6, style = "cloud" })
	L:pad({ gap = 3, rise = 1.5, size = 6, style = "cloud" })

	-- espiral larga: o centro fica do lado do meio do mapa
	local spiral = SkyPhases.spiral(L, 150, 1)
	L.skySpiral = spiral
	SkyPhases.build(L, 32, {
		spiral = spiral,
		firstIndex = 1,
		names = NAMES,
		look = { cloud = "cloud", deck = "cloud_deck", size = 5, beam = 2.2, fallDelay = 0.6 },
	})
end
