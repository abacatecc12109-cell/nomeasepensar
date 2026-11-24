--[[
	CourseBuilder
	-------------
	Constrói as peças do percurso (por região), as escaladas, os caminhos das
	zonas e os checkpoints. Também preenche o mapa de espaços ocupados
	(Clearance) para que a decoração nunca invada o percurso.
]]

local CourseLayout = require(script.Parent.CourseLayout)
local Pieces = require(script.Parent.Pieces)
local World = script.Parent.Parent.World
local Builder = require(World.Builder)

local CourseBuilder = {}

local HEADROOM = 7 -- espaço livre acima de qualquer superfície pisável
local MARGIN = 2.5 -- folga lateral

-- Reserva todo o percurso no Clearance (antes de construir o terreno)
function CourseBuilder.reserve(layout, clearance)
	for _, e in layout.elements do
		local minV, maxV = CourseLayout.bounds(e)
		if e.kind == "zone" then
			-- zonas: só o corredor do caminho é reservado (o resto é decorável)
			for i = 1, #e.path - 1 do
				clearance:reservePath(e.path[i], e.path[i + 1], 3.5, HEADROOM)
			end
			if e.surface == "deck" then
				clearance:reserve(minV - Vector3.new(0.5, 2, 0.5), maxV + Vector3.new(0.5, HEADROOM, 0.5), "deck")
			end
		else
			clearance:reserve(minV - Vector3.new(MARGIN, 0.5, MARGIN), maxV + Vector3.new(MARGIN, HEADROOM, MARGIN), e.kind)
		end
	end
	for _, prop in layout.props do
		if prop.type == "climb" then
			local c = prop.data
			local half = Vector3.new(c.width / 2 + 2, 0, c.width / 2 + 2)
			clearance:reserve(c.base - half - Vector3.new(0, 1, 0), c.base + half + Vector3.new(0, c.height + HEADROOM, 0), "climb")
		elseif prop.type == "gianttree" then
			local d = prop.data
			local r = d.radius + 1
			clearance:reserve(d.center - Vector3.new(r, 0, r), d.center + Vector3.new(r, d.height, r), "tree")
		end
	end
	-- área de cada checkpoint
	for _, cp in layout.checkpoints do
		clearance:reserve(cp.position - Vector3.new(6, 1, 6), cp.position + Vector3.new(6, 8, 6), "checkpoint")
	end
end

local function elementById(layout, id)
	for _, e in layout.elements do
		if e.id == id then
			return e
		end
	end
	return nil
end

function CourseBuilder.build(layout, root: Instance, rng: Random)
	local regionFolders = {}
	local function folderFor(region: number): Folder
		local f = regionFolders[region]
		if not f then
			f = Builder.folder(string.format("Regiao%d", region), root)
			regionFolders[region] = f
		end
		return f
	end

	for _, e in layout.elements do
		local regionFolder = folderFor(e.region)
		local parent = Builder.model(string.format("%03d_%s", e.id, e.kind), regionFolder)
		local mini = e.params and e.params.mini
		if mini then
			parent:SetAttribute("MiniIndex", mini.index)
			if mini.kind then
				parent:SetAttribute("MiniKind", mini.kind)
				parent:SetAttribute("MiniLevel", mini.level)
				parent:SetAttribute("MiniCFrame", CFrame.new(e.center.X, e.top, e.center.Z) * CFrame.Angles(0, e.yaw, 0))
			end
			parent:AddTag(mini.kind and "Minigame" or "MiniGate")
		end
		if e.kind == "zone" then
			Pieces.zonePath(e, parent, rng)
		elseif e.kind == "pad" then
			Pieces.pad(e, parent, rng)
		elseif e.kind == "beam" then
			Pieces.beam(e, parent, rng)
		elseif e.kind == "bridge" then
			Pieces.bridge(e, parent, rng)
		elseif e.kind == "ledge" then
			Pieces.ledge(e, parent, rng)
		elseif e.kind == "waterfall" then
			Pieces.waterfall(e, parent, rng)
		elseif e.kind == "stairs" then
			Pieces.stairs(e, parent, rng)
		elseif e.kind == "collapse" then
			Pieces.collapse(e, parent, rng)
		elseif e.kind == "fallstone" then
			Pieces.fallstone(e, parent, rng)
		elseif e.kind == "mover" then
			Pieces.mover(e, parent, rng)
		elseif e.kind == "swing" then
			Pieces.swing(e, parent, rng)
		else
			warn("[CourseBuilder] tipo de peça desconhecido: " .. tostring(e.kind))
		end
	end

	for _, prop in layout.props do
		if prop.type == "climb" then
			local parent = Builder.model("Escalada", folderFor(prop.region))
			Pieces.climb(prop.data, parent, rng)
		end
	end

	-- checkpoints
	local checkpointFolder = Builder.folder("Checkpoints", root)
	local triggers = {}
	for _, cp in layout.checkpoints do
		local host = cp.elementId and elementById(layout, cp.elementId)
		local half = host and host.width / 2 or 6
		local lateral = math.clamp(half - 1.2, 2.5, 4.5)
		local model, trigger = Pieces.checkpoint(cp, lateral, checkpointFolder)
		triggers[cp.index] = { model = model, trigger = trigger, data = cp }
	end
	return triggers, regionFolders
end

return CourseBuilder
