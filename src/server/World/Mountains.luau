--[[
	Mountains
	---------
	Esculpe montanhas voxel a voxel (WriteVoxels), com formas de erosão:
	  * encostas côncavas: íngremes no alto e espalhadas na base;
	  * cristas e ravinas (ruído em crista), degraus de estratos;
	  * paredes com reentrâncias e faixas de rochas diferentes;
	  * grama só onde é plano, cascalho no pé, neve nos picos do horizonte.
	Nunca sobe além do que o Clearance permite (o percurso fica livre).
]]

local Builder = require(script.Parent.Builder)

local Mountains = {}

local M = Enum.Material
local RES = 4
local N = 16 -- colunas por bloco
local SEED = 41.37

local slopeHeight = {}

local function hkey(ix: number, iz: number): number
	return (ix + 4096) * 8192 + (iz + 4096)
end

-- altura da encosta num ponto (0 = não há), para a decoração
function Mountains.heightAt(x: number, z: number): number
	return slopeHeight[hkey(math.floor(x / RES), math.floor(z / RES))] or 0
end

local function fbm(x: number, z: number, scale: number): number
	local s = scale
	return math.noise(x / s, SEED, z / s) + 0.5 * math.noise(x / s * 2.1, SEED + 9, z / s * 2.1) + 0.25 * math.noise(x / s * 4.3, SEED + 17, z / s * 4.3)
end

-- 0..1, alto nas cristas
local function ridge(x: number, z: number, scale: number): number
	local a = 1 - math.min(1, math.abs(math.noise(x / scale, SEED + 31, z / scale)) * 2.2)
	local b = 1 - math.min(1, math.abs(math.noise(x / scale * 2.3, SEED + 57, z / scale * 2.3)) * 2.2)
	return a * 0.68 + b * 0.32
end

-- faixas de rocha (estratos) levemente inclinadas
local function strata(x: number, y: number, z: number, body)
	local v = y + x * 0.1 - z * 0.06 + math.noise(x / 26, y / 40, z / 26) * 12
	local band = (v / 11) % 5
	if band < 1.6 then
		return body
	elseif band < 2.5 then
		return M.Slate
	elseif band < 3.3 then
		return M.Rock
	elseif band < 3.8 then
		return M.Basalt
	end
	return (body == M.Limestone) and M.Sandstone or body
end

--[[
	Escreve um bloco de N x N colunas.
	col(x, z) -> h?, floor?   altura da superfície e até onde preencher
	mat(x, y, z, h, slope)    material
	carve(x, y, z)            (opcional) novo valor de ocupação para paredes existentes
]]
local function writeTile(terrain, x0: number, z0: number, col, mat, wall)
	local hs, floors = {}, {}
	local lo, hi = math.huge, -math.huge
	for ix = 0, N + 1 do
		hs[ix], floors[ix] = {}, {}
		for iz = 0, N + 1 do
			local h, f = col(x0 + (ix - 0.5) * RES, z0 + (iz - 0.5) * RES)
			hs[ix][iz], floors[ix][iz] = h or false, f or 0
			if h and ix >= 1 and ix <= N and iz >= 1 and iz <= N then
				lo, hi = math.min(lo, f), math.max(hi, h)
			end
		end
	end
	if wall then
		lo, hi = math.min(lo, wall.bottom), math.max(hi, wall.top - 6)
	end
	Builder.pace()
	if hi <= lo then
		return
	end
	local y0, y1 = math.floor(lo / RES) * RES, math.ceil(hi / RES) * RES
	local region = Region3.new(Vector3.new(x0, y0, z0), Vector3.new(x0 + N * RES, y1, z0 + N * RES))
	local mats, occ = terrain:ReadVoxels(region, RES)
	local ny = (y1 - y0) / RES
	local changed = false
	for ix = 1, N do
		local x = x0 + (ix - 0.5) * RES
		for iz = 1, N do
			local z = z0 + (iz - 0.5) * RES
			local h = hs[ix][iz]
			if h then
				local hx = (hs[ix + 1][iz] or h) - (hs[ix - 1][iz] or h)
				local hz = (hs[ix][iz + 1] or h) - (hs[ix][iz - 1] or h)
				local slope = math.sqrt(hx * hx + hz * hz) / (2 * RES)
				local from = math.max(1, math.floor((floors[ix][iz] - y0) / RES) + 1)
				local to = math.min(ny, math.ceil((h - y0) / RES))
				for iy = from, to do
					local bottom = y0 + (iy - 1) * RES
					local o = math.clamp((h - 2 - bottom) / RES, 0, 1) -- 2 = meio voxel (veja TerrainBuilder)
					if o > occ[ix][iy][iz] then
						occ[ix][iy][iz] = o
						mats[ix][iy][iz] = mat(x, bottom + 2, z, h, slope)
						changed = true
					end
				end
			elseif wall then
				local d = wall.dist(x, z)
				if d < 0 and d > -10 then
					for iy = math.max(1, math.floor((wall.bottom - y0) / RES) + 1), math.min(ny, math.floor((wall.top - 6 - y0) / RES)) do
						if occ[ix][iy][iz] > 0 then
							local y = y0 + (iy - 0.5) * RES
							mats[ix][iy][iz] = strata(x, y, z, wall.body)
							-- reentrâncias e fendas na face da parede
							if d > -6 then
								local n = math.noise(x / 13, y / 17, z / 13) + 0.5 * math.noise(x / 6.5, y / 7, z / 6.5)
								local depth = math.max(0, n) * 7
								local keep = math.clamp((-d - depth + 3) / RES, 0, 1)
								occ[ix][iy][iz] = math.min(occ[ix][iy][iz], keep)
								if keep <= 0 then
									mats[ix][iy][iz] = M.Air
								end
							end
							changed = true
						end
					end
				end
			end
		end
		Builder.pace()
	end
	if changed then
		terrain:WriteVoxels(region, RES, mats, occ)
	end
end

local function distFn(rect)
	local sx, cz = math.sin(rect.yaw), math.cos(rect.yaw)
	local cx0, cz0 = rect.center.X, rect.center.Z
	return function(x: number, z: number): number
		local dx, dz = x - cx0, z - cz0
		local qa = math.abs(dx * sx + dz * cz) - rect.length / 2
		local qs = math.abs(-dx * cz + dz * sx) - rect.width / 2
		if qa > 0 and qs > 0 then
			return math.sqrt(qa * qa + qs * qs)
		end
		return math.max(qa, qs)
	end
end

-- Encosta natural em volta de um platô/paredão.
-- others: { rect, dist, cap }  áreas que a encosta não pode cobrir
function Mountains.slopes(terrain, clearance, rect, theme, others)
	local top, bottom = rect.top, rect.bottom
	local height = top - bottom
	if height < 6 then
		return
	end
	local dist = distFn(rect)
	local reach = math.clamp(height * 0.55, 7, 64)
	local maxReach = reach * 1.25
	local hl = math.sqrt(rect.width ^ 2 + rect.length ^ 2) / 2 + maxReach + RES
	local near = {}
	for _, o in others do
		if o.rect ~= rect then
			local dx, dz = o.rect.center.X - rect.center.X, o.rect.center.Z - rect.center.Z
			if math.sqrt(dx * dx + dz * dz) < hl + math.sqrt(o.rect.width ^ 2 + o.rect.length ^ 2) / 2 + 8 then
				table.insert(near, o)
			end
		end
	end
	local cache = {}
	local function col(x: number, z: number)
		local k = hkey(math.floor(x / RES), math.floor(z / RES))
		local c = cache[k]
		if c ~= nil then
			return c, bottom
		end
		c = false
		local d = dist(x, z)
		if d >= 0 and d < maxReach then
			local r = reach * (0.3 + 0.95 * ridge(x, z, 46))
			local t = d / r
			if t < 1 then
				local h = bottom + (height - 2) * (1 - t) ^ 1.55
				h += fbm(x, z, 17) * math.min(7, height * 0.12) * math.min(1, d / 6)
				-- degraus de estrato
				local step = 13
				local s = (h + fbm(x, z, 60) * 8) % step / step
				h += (s * s * (3 - 2 * s) - s) * step * 0.6
				h = math.min(h, top - 2)
				for _, o in near do
					if h > o.cap and o.dist(x, z) < 3 then
						h = math.min(h, o.cap)
					end
				end
				h = math.min(h, clearance:ceiling(x, z, 4, bottom) - 1)
				if h > bottom + 1 then
					c = h
				end
			end
		end
		cache[k] = c
		return c, bottom
	end
	local function mat(x, y, z, h, slope)
		if h - y < 5 then
			local n = math.noise(x / 14, 7.7, z / 14)
			if slope < 0.75 + n * 0.5 then
				return (n > 0.15) and M.LeafyGrass or theme.top
			elseif y < bottom + math.min(16, height * 0.25) and n > -0.1 then
				return M.Ground
			end
		end
		return strata(x, y, z, theme.body)
	end
	local wall = { top = top, bottom = bottom, body = theme.body, dist = dist }
	local size = N * RES
	for x0 = math.floor((rect.center.X - hl) / size) * size, rect.center.X + hl, size do
		for z0 = math.floor((rect.center.Z - hl) / size) * size, rect.center.Z + hl, size do
			local d = dist(x0 + size / 2, z0 + size / 2)
			local diag = size * 0.71
			if d < maxReach + diag and d > -diag - 10 then
				writeTile(terrain, x0, z0, col, mat, (d < diag) and wall or nil)
			end
		end
	end
	if bottom <= 5 then
		for k, h in cache do
			if h and h > (slopeHeight[k] or 0) then
				slopeHeight[k] = h
			end
		end
	end
end

-- Cordilheira contínua no horizonte, com vales, cristas e picos nevados.
function Mountains.horizon(terrain, center: Vector3, inner: number, outer: number)
	local function col(x: number, z: number)
		local dx, dz = x - center.X, z - center.Z
		local d = math.sqrt(dx * dx + dz * dz) + fbm(x, z, 120) * 40
		local t = (d - inner) / (outer - inner)
		if t <= 0 or t >= 1 then
			return nil, 0
		end
		local env = math.sin(math.pi * t ^ 1.5)
		local big = 0.62 + 0.55 * math.noise(x / 310, SEED + 3, z / 310)
		local rg = ridge(x, z, 170)
		local h = env * big * (45 + 290 * rg * rg) + fbm(x, z, 42) * 14 * env
		if h < 1 then
			return nil, 0
		end
		return h, math.max(-8, h - 28)
	end
	local function mat(x, y, z, h, slope)
		local n = math.noise(x / 30, 3.3, z / 30)
		if h > 205 + n * 30 and slope < 1.5 then
			return M.Snow
		elseif slope < 0.7 + n * 0.3 and h < 130 + n * 40 then
			return (n > 0.1) and M.LeafyGrass or M.Grass
		end
		return strata(x, y, z, M.Slate)
	end
	local size = N * RES
	local lim = outer + 64
	for x0 = math.floor((center.X - lim) / size) * size, center.X + lim, size do
		for z0 = math.floor((center.Z - lim) / size) * size, center.Z + lim, size do
			local dx, dz = x0 + size / 2 - center.X, z0 + size / 2 - center.Z
			local d = math.sqrt(dx * dx + dz * dz)
			if d > inner - 115 and d < outer + 115 then
				writeTile(terrain, x0, z0, col, mat, nil)
			end
		end
	end
end

Mountains.distFn = distFn

return Mountains