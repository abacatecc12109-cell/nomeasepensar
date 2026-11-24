--[[
	Região 7 — Céu do Entardecer
	As últimas 32 fases, nas nuvens douradas e rosadas do pôr do sol.
	Plataformas um pouco menores, nuvens que se desfazem mais rápido e o
	Trono do Sol, a chegada, no alto da espiral.
]]

local SkyPhases = require(script.Parent.Parent.SkyPhases)

local NAMES = {
	"Nuvem Dourada",
	"Ilha do Crepúsculo",
	"Jardim Rosado",
	"Mirante Âmbar",
	"Nuvem de Pêssego",
	"Ilha da Aurora",
	"Ponte do Poente",
	"Ninho do Sol",
}

return function(L)
	L:region(7)
	SkyPhases.build(L, 32, {
		spiral = L.skySpiral,
		firstIndex = 33,
		names = NAMES,
		finish = true,
		finishLabel = "Trono do Sol",
		look = { cloud = "sunsetcloud", deck = "sunset_deck", size = 4.6, beam = 1.9, fallDelay = 0.5 },
	})
end
