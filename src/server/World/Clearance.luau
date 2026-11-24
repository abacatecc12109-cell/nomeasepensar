--[[
	Clearance
	---------
	Mapa de espaços ocupados, usado para que terreno, árvores, pedras e casas
	NUNCA invadam o percurso (nem o espaço da cabeça acima dele).

	Usa uma grade espacial (hash) para consultas rápidas.
]]

local Clearance = {}
Clearance.__index = Clearance

local CELL = 32

function Clearance.new()
	local self = setmetatable({}, Clearance)
	self.cells = {}
	self.paths = {} -- segmentos de caminho {a, b, radius}
	return self
end

local function key(ix: number, iz: number): string
	return ix .. ":" .. iz
end

function Clearance:_cellsFor(minV: Vector3, maxV: Vector3)
	local out = {}
	for ix = math.floor(minV.X / CELL), math.floor(maxV.X / CELL) do
		for iz = math.floor(minV.Z / CELL), math.floor(maxV.Z / CELL) do
			table.insert(out, key(ix, iz))
		end
	end
	return out
end

-- Reserva uma caixa (min, max) como ocupada.
function Clearance:reserve(minV: Vector3, maxV: Vector3, tag: string?)
	local box = { min = minV, max = maxV, tag = tag }
	for _, k in self:_cellsFor(minV, maxV) do
		local list = self.cells[k]
		if not list then
			list = {}
			self.cells[k] = list
		end
		table.insert(list, box)
	end
end

-- Reserva o corredor de um caminho (para decoração não bloquear trilhas).
function Clearance:reservePath(a: Vector3, b: Vector3, radius: number, height: number?)
	local h = height or 8
	local minV = Vector3.new(math.min(a.X, b.X) - radius, math.min(a.Y, b.Y) - 1, math.min(a.Z, b.Z) - radius)
	local maxV = Vector3.new(math.max(a.X, b.X) + radius, math.max(a.Y, b.Y) + h, math.max(a.Z, b.Z) + radius)
	local seg = { a = a, b = b, radius = radius, min = minV, max = maxV, segment = true }
	for _, k in self:_cellsFor(minV, maxV) do
		local list = self.cells[k]
		if not list then
			list = {}
			self.cells[k] = list
		end
		table.insert(list, seg)
	end
end

local function boxesOverlap(aMin, aMax, bMin, bMax): boolean
	return aMin.X < bMax.X and aMax.X > bMin.X and aMin.Y < bMax.Y and aMax.Y > bMin.Y and aMin.Z < bMax.Z and aMax.Z > bMin.Z
end

local function distToSegment2D(p: Vector3, a: Vector3, b: Vector3): number
	local ab = Vector3.new(b.X - a.X, 0, b.Z - a.Z)
	local ap = Vector3.new(p.X - a.X, 0, p.Z - a.Z)
	local len2 = ab:Dot(ab)
	local t = len2 > 0 and math.clamp(ap:Dot(ab) / len2, 0, 1) or 0
	local closest = Vector3.new(a.X, 0, a.Z) + ab * t
	return (Vector3.new(p.X, 0, p.Z) - closest).Magnitude
end

-- A caixa está livre?
function Clearance:isFree(minV: Vector3, maxV: Vector3): boolean
	for _, k in self:_cellsFor(minV, maxV) do
		local list = self.cells[k]
		if list then
			for _, box in list do
				if boxesOverlap(minV, maxV, box.min, box.max) then
					if not box.segment then
						return false
					end
					-- segmento: testa distância real ao corredor
					local center = (minV + maxV) / 2
					local half = math.max(maxV.X - minV.X, maxV.Z - minV.Z) / 2
					if distToSegment2D(center, box.a, box.b) < box.radius + half then
						return false
					end
				end
			end
		end
	end
	return true
end

-- Até que altura o terreno pode subir em (x, z) sem encostar no percurso.
function Clearance:ceiling(x: number, z: number, r: number, floorY: number): number
	local best = math.huge
	local p = Vector3.new(x, 0, z)
	for _, k in self:_cellsFor(Vector3.new(x - r, 0, z - r), Vector3.new(x + r, 0, z + r)) do
		for _, box in self.cells[k] or {} do
			if box.max.Y > floorY and box.min.Y < best and x + r > box.min.X and x - r < box.max.X and z + r > box.min.Z and z - r < box.max.Z then
				if not box.segment or distToSegment2D(p, box.a, box.b) < box.radius + r then
					best = box.min.Y
				end
			end
		end
	end
	return best
end

-- Atalho: um objeto de raio r e altura h apoiado no ponto p está livre?
function Clearance:isFreeAt(p: Vector3, r: number, h: number): boolean
	return self:isFree(Vector3.new(p.X - r, p.Y, p.Z - r), Vector3.new(p.X + r, p.Y + h, p.Z + r))
end

return Clearance
