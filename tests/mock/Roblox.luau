--!nocheck
--[[
	Simulação mínima da API do Roblox para testes fora do Studio.

	Não simula física nem renderização: serve para executar o código de
	construção do mundo e dos sistemas e pegar erros de execução (nil,
	argumentos errados, propriedades inexistentes em datatypes, etc.).
]]

local M = {}
local env = getfenv(1)

-- =====================================================================
-- typeof com suporte a tipos simulados
-- =====================================================================
local rawtypeof = typeof
local function mtypeof(v)
	if type(v) == "table" then
		local mt = getmetatable(v)
		if mt and rawget(mt, "__type") then
			return mt.__type
		end
	end
	return rawtypeof(v)
end
M.typeof = mtypeof

local function check(cond, msg)
	if not cond then
		error(msg, 3)
	end
end

local function isNum(v)
	return type(v) == "number"
end

-- =====================================================================
-- Vector3
-- =====================================================================
local Vector3 = {}
local V3 = { __type = "Vector3" }
V3.__index = function(v, k)
	if k == "Magnitude" then
		return math.sqrt(v.X * v.X + v.Y * v.Y + v.Z * v.Z)
	elseif k == "Unit" then
		local m = math.sqrt(v.X * v.X + v.Y * v.Y + v.Z * v.Z)
		if m == 0 then
			return Vector3.new(0 / 0, 0 / 0, 0 / 0)
		end
		return Vector3.new(v.X / m, v.Y / m, v.Z / m)
	end
	local f = rawget(Vector3, k)
	if f and type(f) == "function" and k ~= "new" then
		return f
	end
	error("Vector3 não tem membro '" .. tostring(k) .. "'", 2)
end
V3.__newindex = function()
	error("Vector3 é imutável", 2)
end
function Vector3.new(x, y, z)
	x, y, z = x or 0, y or 0, z or 0
	check(isNum(x) and isNum(y) and isNum(z), "Vector3.new espera números")
	return setmetatable({ X = x, Y = y, Z = z }, V3)
end
local function isV3(v)
	return getmetatable(v) == V3
end
V3.__add = function(a, b)
	check(isV3(a) and isV3(b), "Vector3 + espera Vector3")
	return Vector3.new(a.X + b.X, a.Y + b.Y, a.Z + b.Z)
end
V3.__sub = function(a, b)
	check(isV3(a) and isV3(b), "Vector3 - espera Vector3")
	return Vector3.new(a.X - b.X, a.Y - b.Y, a.Z - b.Z)
end
V3.__mul = function(a, b)
	if isNum(a) then
		a, b = b, a
	end
	if isNum(b) then
		return Vector3.new(a.X * b, a.Y * b, a.Z * b)
	end
	check(isV3(a) and isV3(b), "Vector3 * inválido")
	return Vector3.new(a.X * b.X, a.Y * b.Y, a.Z * b.Z)
end
V3.__div = function(a, b)
	if isNum(b) then
		return Vector3.new(a.X / b, a.Y / b, a.Z / b)
	end
	check(isV3(a) and isV3(b), "Vector3 / inválido")
	return Vector3.new(a.X / b.X, a.Y / b.Y, a.Z / b.Z)
end
V3.__unm = function(a)
	return Vector3.new(-a.X, -a.Y, -a.Z)
end
V3.__eq = function(a, b)
	return a.X == b.X and a.Y == b.Y and a.Z == b.Z
end
V3.__tostring = function(v)
	return string.format("%.3f, %.3f, %.3f", v.X, v.Y, v.Z)
end
function Vector3.Dot(a, b)
	return a.X * b.X + a.Y * b.Y + a.Z * b.Z
end
function Vector3.Cross(a, b)
	return Vector3.new(a.Y * b.Z - a.Z * b.Y, a.Z * b.X - a.X * b.Z, a.X * b.Y - a.Y * b.X)
end
function Vector3.Lerp(a, b, t)
	return a + (b - a) * t
end
function Vector3.Min(a, b)
	return Vector3.new(math.min(a.X, b.X), math.min(a.Y, b.Y), math.min(a.Z, b.Z))
end
function Vector3.Max(a, b)
	return Vector3.new(math.max(a.X, b.X), math.max(a.Y, b.Y), math.max(a.Z, b.Z))
end
function Vector3.Abs(a)
	return Vector3.new(math.abs(a.X), math.abs(a.Y), math.abs(a.Z))
end
function Vector3.FuzzyEq(a, b, eps)
	return (a - b).Magnitude <= (eps or 1e-5)
end
Vector3.zero = Vector3.new(0, 0, 0)
Vector3.one = Vector3.new(1, 1, 1)
Vector3.xAxis = Vector3.new(1, 0, 0)
Vector3.yAxis = Vector3.new(0, 1, 0)
Vector3.zAxis = Vector3.new(0, 0, 1)
M.Vector3 = Vector3

-- =====================================================================
-- Vector2 / UDim / UDim2 / Rect
-- =====================================================================
local Vector2 = {}
local V2 = { __type = "Vector2" }
V2.__index = function(v, k)
	if k == "Magnitude" then
		return math.sqrt(v.X * v.X + v.Y * v.Y)
	end
	error("Vector2 não tem membro " .. tostring(k), 2)
end
function Vector2.new(x, y)
	return setmetatable({ X = x or 0, Y = y or 0 }, V2)
end
V2.__add = function(a, b)
	return Vector2.new(a.X + b.X, a.Y + b.Y)
end
V2.__sub = function(a, b)
	return Vector2.new(a.X - b.X, a.Y - b.Y)
end
V2.__mul = function(a, b)
	if isNum(a) then
		a, b = b, a
	end
	return Vector2.new(a.X * b, a.Y * b)
end
Vector2.zero = Vector2.new(0, 0)
Vector2.one = Vector2.new(1, 1)
M.Vector2 = Vector2

local UDim = {}
local UD = { __type = "UDim" }
UD.__index = UD
function UDim.new(s, o)
	return setmetatable({ Scale = s or 0, Offset = o or 0 }, UD)
end
M.UDim = UDim

local UDim2 = {}
local UD2 = { __type = "UDim2" }
UD2.__index = function(u, k)
	if k == "Lerp" then
		return function(a, b, t)
			return UDim2.new(
				a.X.Scale + (b.X.Scale - a.X.Scale) * t,
				a.X.Offset + (b.X.Offset - a.X.Offset) * t,
				a.Y.Scale + (b.Y.Scale - a.Y.Scale) * t,
				a.Y.Offset + (b.Y.Offset - a.Y.Offset) * t
			)
		end
	elseif k == "Width" then
		return rawget(u, "X")
	elseif k == "Height" then
		return rawget(u, "Y")
	end
	error("UDim2 não tem membro " .. tostring(k), 2)
end
function UDim2.new(xs, xo, ys, yo)
	for _, v in { xs, xo, ys, yo } do
		check(v == nil or isNum(v), "UDim2.new espera números")
	end
	return setmetatable({ X = UDim.new(xs, xo), Y = UDim.new(ys, yo) }, UD2)
end
function UDim2.fromScale(x, y)
	return UDim2.new(x, 0, y, 0)
end
function UDim2.fromOffset(x, y)
	return UDim2.new(0, x, 0, y)
end
UD2.__add = function(a, b)
	return UDim2.new(a.X.Scale + b.X.Scale, a.X.Offset + b.X.Offset, a.Y.Scale + b.Y.Scale, a.Y.Offset + b.Y.Offset)
end
M.UDim2 = UDim2

M.Rect = {
	new = function(a, b, c, d)
		return setmetatable({ a, b, c, d }, { __type = "Rect" })
	end,
}

-- =====================================================================
-- CFrame (matriz 3x3 + posição)
-- =====================================================================
local CFrame = {}
local CF = { __type = "CFrame" }
local function mkcf(px, py, pz, r00, r01, r02, r10, r11, r12, r20, r21, r22)
	return setmetatable({
		p = Vector3.new(px, py, pz),
		m = { r00, r01, r02, r10, r11, r12, r20, r21, r22 },
	}, CF)
end
local function isCF(v)
	return getmetatable(v) == CF
end
CF.__index = function(c, k)
	local m = rawget(c, "m")
	if k == "Position" or k == "p" then
		return rawget(c, "p")
	elseif k == "X" then
		return rawget(c, "p").X
	elseif k == "Y" then
		return rawget(c, "p").Y
	elseif k == "Z" then
		return rawget(c, "p").Z
	elseif k == "RightVector" or k == "XVector" then
		return Vector3.new(m[1], m[4], m[7])
	elseif k == "UpVector" or k == "YVector" then
		return Vector3.new(m[2], m[5], m[8])
	elseif k == "LookVector" then
		return Vector3.new(-m[3], -m[6], -m[9])
	elseif k == "ZVector" then
		return Vector3.new(m[3], m[6], m[9])
	elseif k == "Rotation" then
		return mkcf(0, 0, 0, table.unpack(m))
	end
	local f = rawget(CFrame, k)
	if f and k ~= "new" then
		return f
	end
	error("CFrame não tem membro '" .. tostring(k) .. "'", 2)
end
CF.__newindex = function()
	error("CFrame é imutável", 2)
end
local function rotate(m, v)
	return Vector3.new(m[1] * v.X + m[2] * v.Y + m[3] * v.Z, m[4] * v.X + m[5] * v.Y + m[6] * v.Z, m[7] * v.X + m[8] * v.Y + m[9] * v.Z)
end
local function matmul(a, b)
	local r = {}
	for i = 0, 2 do
		for j = 0, 2 do
			local s = 0
			for k = 0, 2 do
				s += a[i * 3 + k + 1] * b[k * 3 + j + 1]
			end
			r[i * 3 + j + 1] = s
		end
	end
	return r
end
function CFrame.new(a, b, c, ...)
	if a == nil then
		return mkcf(0, 0, 0, 1, 0, 0, 0, 1, 0, 0, 0, 1)
	elseif isV3(a) and b == nil then
		return mkcf(a.X, a.Y, a.Z, 1, 0, 0, 0, 1, 0, 0, 0, 1)
	elseif isV3(a) and isV3(b) then
		return CFrame.lookAt(a, b)
	elseif isNum(a) and select("#", ...) == 0 then
		check(isNum(b) and isNum(c), "CFrame.new(x,y,z) espera números")
		return mkcf(a, b, c, 1, 0, 0, 0, 1, 0, 0, 0, 1)
	elseif isNum(a) then
		return mkcf(a, b, c, ...)
	end
	error("CFrame.new: argumentos inválidos", 2)
end
function CFrame.fromMatrix(pos, rx, ry, rz)
	rz = rz or rx:Cross(ry).Unit
	return mkcf(pos.X, pos.Y, pos.Z, rx.X, ry.X, rz.X, rx.Y, ry.Y, rz.Y, rx.Z, ry.Z, rz.Z)
end
function CFrame.lookAt(pos, target, up)
	check(isV3(pos) and isV3(target), "CFrame.lookAt espera Vector3")
	up = up or Vector3.yAxis
	local look = (target - pos).Unit
	if look.X ~= look.X then
		look = Vector3.new(0, 0, -1)
	end
	local right = look:Cross(up)
	if right.Magnitude < 1e-6 then
		right = look:Cross(Vector3.zAxis)
	end
	right = right.Unit
	local upv = right:Cross(look).Unit
	return CFrame.fromMatrix(pos, right, upv, -look)
end
local function rx(a)
	local c, s = math.cos(a), math.sin(a)
	return { 1, 0, 0, 0, c, -s, 0, s, c }
end
local function ry(a)
	local c, s = math.cos(a), math.sin(a)
	return { c, 0, s, 0, 1, 0, -s, 0, c }
end
local function rz(a)
	local c, s = math.cos(a), math.sin(a)
	return { c, -s, 0, s, c, 0, 0, 0, 1 }
end
function CFrame.Angles(x, y, z)
	check(isNum(x) and isNum(y) and isNum(z), "CFrame.Angles espera números")
	local m = matmul(matmul(rx(x), ry(y)), rz(z))
	return mkcf(0, 0, 0, table.unpack(m))
end
CFrame.fromEulerAnglesXYZ = CFrame.Angles
function CFrame.fromOrientation(x, y, z)
	local m = matmul(matmul(ry(y), rx(x)), rz(z))
	return mkcf(0, 0, 0, table.unpack(m))
end
CFrame.fromEulerAnglesYXZ = CFrame.fromOrientation
function CFrame.fromAxisAngle(axis, a)
	local u = axis.Unit
	local c, s, t = math.cos(a), math.sin(a), 1 - math.cos(a)
	local x, y, z = u.X, u.Y, u.Z
	return mkcf(
		0, 0, 0,
		t * x * x + c, t * x * y - s * z, t * x * z + s * y,
		t * x * y + s * z, t * y * y + c, t * y * z - s * x,
		t * x * z - s * y, t * y * z + s * x, t * z * z + c
	)
end
CF.__mul = function(a, b)
	check(isCF(a), "CFrame * : lado esquerdo não é CFrame")
	if isV3(b) then
		return rawget(a, "p") + rotate(rawget(a, "m"), b)
	end
	check(isCF(b), "CFrame * espera CFrame ou Vector3")
	local m = matmul(rawget(a, "m"), rawget(b, "m"))
	local p = rawget(a, "p") + rotate(rawget(a, "m"), rawget(b, "p"))
	return mkcf(p.X, p.Y, p.Z, table.unpack(m))
end
CF.__add = function(a, b)
	check(isCF(a) and isV3(b), "CFrame + espera Vector3")
	local p = rawget(a, "p") + b
	return mkcf(p.X, p.Y, p.Z, table.unpack(rawget(a, "m")))
end
CF.__sub = function(a, b)
	check(isCF(a) and isV3(b), "CFrame - espera Vector3")
	local p = rawget(a, "p") - b
	return mkcf(p.X, p.Y, p.Z, table.unpack(rawget(a, "m")))
end
CF.__tostring = function(c)
	return "CFrame(" .. tostring(rawget(c, "p")) .. ")"
end
function CFrame.Inverse(c)
	local m = rawget(c, "m")
	local t = { m[1], m[4], m[7], m[2], m[5], m[8], m[3], m[6], m[9] }
	local p = -rotate(t, rawget(c, "p"))
	return mkcf(p.X, p.Y, p.Z, table.unpack(t))
end
function CFrame.ToWorldSpace(a, b)
	return a * b
end
function CFrame.ToObjectSpace(a, b)
	return a:Inverse() * b
end
function CFrame.PointToWorldSpace(a, v)
	return a * v
end
function CFrame.PointToObjectSpace(a, v)
	return a:Inverse() * v
end
function CFrame.VectorToWorldSpace(a, v)
	return rotate(rawget(a, "m"), v)
end
function CFrame.VectorToObjectSpace(a, v)
	return rotate(rawget(a:Inverse(), "m"), v)
end
function CFrame.Lerp(a, b, t)
	local p = rawget(a, "p"):Lerp(rawget(b, "p"), t)
	local m = t < 0.5 and rawget(a, "m") or rawget(b, "m")
	return mkcf(p.X, p.Y, p.Z, table.unpack(m))
end
function CFrame.GetComponents(c)
	local p = rawget(c, "p")
	return p.X, p.Y, p.Z, table.unpack(rawget(c, "m"))
end
CFrame.components = CFrame.GetComponents
function CFrame.ToOrientation(c)
	local m = rawget(c, "m")
	local x = math.asin(math.clamp(-m[6], -1, 1))
	local y = math.atan2(m[3], m[9])
	local z = math.atan2(m[4], m[5])
	return x, y, z
end
CFrame.identity = CFrame.new()
M.CFrame = CFrame

-- =====================================================================
-- Color3, sequências, ranges
-- =====================================================================
local Color3 = {}
local C3 = { __type = "Color3" }
C3.__index = function(c, k)
	local f = rawget(Color3, k)
	if f and k ~= "new" then
		return f
	end
	error("Color3 não tem membro " .. tostring(k), 2)
end
function Color3.new(r, g, b)
	check((r == nil or isNum(r)) and (g == nil or isNum(g)) and (b == nil or isNum(b)), "Color3.new espera números")
	return setmetatable({ R = r or 0, G = g or 0, B = b or 0 }, C3)
end
function Color3.fromRGB(r, g, b)
	return Color3.new((r or 0) / 255, (g or 0) / 255, (b or 0) / 255)
end
function Color3.fromHSV(h, s, v)
	local i = math.floor(h * 6)
	local f = h * 6 - i
	local p, q, t = v * (1 - s), v * (1 - f * s), v * (1 - (1 - f) * s)
	local r, g, b
	i = i % 6
	if i == 0 then
		r, g, b = v, t, p
	elseif i == 1 then
		r, g, b = q, v, p
	elseif i == 2 then
		r, g, b = p, v, t
	elseif i == 3 then
		r, g, b = p, q, v
	elseif i == 4 then
		r, g, b = t, p, v
	else
		r, g, b = v, p, q
	end
	return Color3.new(r, g, b)
end
function Color3.Lerp(a, b, t)
	check(getmetatable(b) == C3, "Color3:Lerp espera Color3")
	return Color3.new(a.R + (b.R - a.R) * t, a.G + (b.G - a.G) * t, a.B + (b.B - a.B) * t)
end
function Color3.ToHSV(c)
	local r, g, b = c.R, c.G, c.B
	local mx, mn = math.max(r, g, b), math.min(r, g, b)
	local d = mx - mn
	local h = 0
	if d > 0 then
		if mx == r then
			h = ((g - b) / d) % 6
		elseif mx == g then
			h = (b - r) / d + 2
		else
			h = (r - g) / d + 4
		end
		h /= 6
	end
	return h, mx == 0 and 0 or d / mx, mx
end
C3.__eq = function(a, b)
	return a.R == b.R and a.G == b.G and a.B == b.B
end
M.Color3 = Color3

local function seqKeypoint(typeName)
	return {
		new = function(t, v, e)
			check(isNum(t), typeName .. ".new: tempo deve ser número")
			return setmetatable({ Time = t, Value = v, Envelope = e or 0 }, { __type = typeName })
		end,
	}
end
M.NumberSequenceKeypoint = seqKeypoint("NumberSequenceKeypoint")
M.ColorSequenceKeypoint = seqKeypoint("ColorSequenceKeypoint")
M.NumberSequence = {
	new = function(a, b)
		if isNum(a) then
			return setmetatable({ Keypoints = { { Time = 0, Value = a }, { Time = 1, Value = b or a } } }, { __type = "NumberSequence" })
		end
		check(type(a) == "table" and #a >= 2, "NumberSequence.new precisa de >= 2 keypoints")
		check(a[1].Time == 0 and a[#a].Time == 1, "NumberSequence: keypoints devem começar em 0 e terminar em 1")
		return setmetatable({ Keypoints = a }, { __type = "NumberSequence" })
	end,
}
M.ColorSequence = {
	new = function(a, b)
		if getmetatable(a) == C3 then
			return setmetatable({ Keypoints = { { Time = 0, Value = a }, { Time = 1, Value = b or a } } }, { __type = "ColorSequence" })
		end
		check(type(a) == "table" and #a >= 2, "ColorSequence.new precisa de >= 2 keypoints")
		check(a[1].Time == 0 and a[#a].Time == 1, "ColorSequence: keypoints devem começar em 0 e terminar em 1")
		return setmetatable({ Keypoints = a }, { __type = "ColorSequence" })
	end,
}
M.NumberRange = {
	new = function(a, b)
		check(isNum(a), "NumberRange.new espera número")
		return setmetatable({ Min = a, Max = b or a }, { __type = "NumberRange" })
	end,
}
M.TweenInfo = {
	new = function(t, style, dir, repeats, reverses, delay)
		return setmetatable({ Time = t or 1, EasingStyle = style, EasingDirection = dir, RepeatCount = repeats or 0, Reverses = reverses or false, DelayTime = delay or 0 }, { __type = "TweenInfo" })
	end,
}
M.PhysicalProperties = {
	new = function(...)
		return setmetatable({ ... }, { __type = "PhysicalProperties" })
	end,
}
M.Font = {
	new = function(family, weight, style)
		return setmetatable({ Family = family, Weight = weight, Style = style }, { __type = "Font" })
	end,
	fromEnum = function(e)
		return setmetatable({ Enum = e }, { __type = "Font" })
	end,
	fromName = function(n, weight)
		return setmetatable({ Family = n, Weight = weight }, { __type = "Font" })
	end,
}
M.BrickColor = {
	new = function(n)
		return setmetatable({ Name = n }, { __type = "BrickColor" })
	end,
}

-- =====================================================================
-- Enum (qualquer Enum.X.Y vira um token)
-- =====================================================================
local enumCache = {}
local Enum = setmetatable({}, {
	__index = function(_, enumName)
		local items = enumCache[enumName]
		if not items then
			items = setmetatable({}, {
				__index = function(t, itemName)
					if itemName == "GetEnumItems" then
						return function()
							return {}
						end
					end
					local token = setmetatable({ Name = itemName, EnumType = enumName, Value = 0 }, {
						__type = "EnumItem",
						__tostring = function()
							return "Enum." .. enumName .. "." .. itemName
						end,
					})
					rawset(t, itemName, token)
					return token
				end,
			})
			enumCache[enumName] = items
		end
		return items
	end,
})
M.Enum = Enum

-- =====================================================================
-- Signal
-- =====================================================================
local Signal = {}
Signal.__index = Signal
function Signal.new()
	return setmetatable({ handlers = {} }, Signal)
end
function Signal:Connect(fn)
	check(type(fn) == "function", "Connect espera função")
	local conn = { Connected = true }
	local handlers = self.handlers
	table.insert(handlers, fn)
	function conn.Disconnect()
		conn.Connected = false
		local i = table.find(handlers, fn)
		if i then
			table.remove(handlers, i)
		end
	end
	return conn
end
function Signal:Once(fn)
	local c
	c = self:Connect(function(...)
		c:Disconnect()
		fn(...)
	end)
	return c
end
function Signal:Wait()
	return nil
end
function Signal:Fire(...)
	for _, h in table.clone(self.handlers) do
		h(...)
	end
end
M.Signal = Signal

-- =====================================================================
-- Agendador de tarefas
-- =====================================================================
local queue = {}
local stats = { instances = 0, parts = 0, terrainCalls = 0 }
M.stats = stats
local clock = 0

local function resume(co, ...)
	local ok, err = coroutine.resume(co, ...)
	if not ok then
		error(debug.traceback(co, tostring(err)), 0)
	end
end

local task = {}
function task.spawn(f, ...)
	local co = type(f) == "thread" and f or coroutine.create(f)
	resume(co, ...)
	return co
end
function task.defer(f, ...)
	local co = type(f) == "thread" and f or coroutine.create(f)
	table.insert(queue, { at = clock, co = co, args = table.pack(...) })
	return co
end
function task.delay(t, f, ...)
	local co = coroutine.create(f)
	table.insert(queue, { at = clock + (t or 0), co = co, args = table.pack(...) })
	return co
end
function task.wait(t)
	local co = coroutine.running()
	if not coroutine.isyieldable() then
		return t or 0
	end
	table.insert(queue, { at = clock + (t or 1 / 60), co = co, args = table.pack() })
	coroutine.yield()
	return t or 1 / 60
end
function task.cancel(co)
	for i = #queue, 1, -1 do
		if queue[i].co == co then
			table.remove(queue, i)
		end
	end
end
M.task = task

-- Avança o relógio simulado, retomando tarefas vencidas.
function M.step(dt)
	clock += dt
	local guard = 0
	while true do
		guard += 1
		if guard > 100000 then
			error("agendador: possível laço infinito")
		end
		local idx
		for i, item in queue do
			if item.at <= clock and coroutine.status(item.co) == "suspended" then
				idx = i
				break
			end
		end
		if not idx then
			break
		end
		local item = table.remove(queue, idx)
		resume(item.co, table.unpack(item.args, 1, item.args.n))
	end
	for i = #queue, 1, -1 do
		if coroutine.status(queue[i].co) == "dead" then
			table.remove(queue, i)
		end
	end
end
function M.now()
	return clock
end

-- =====================================================================
-- Random (Park-Miller, determinístico)
-- =====================================================================
local Random = {}
local RNG = { __type = "Random" }
RNG.__index = RNG
function Random.new(seed)
	seed = math.floor(math.abs(seed or 12345)) % 2147483646 + 1
	return setmetatable({ s = seed }, RNG)
end
local function nextRaw(self)
	self.s = (self.s * 16807) % 2147483647
	return self.s / 2147483647
end
function RNG:NextNumber(a, b)
	local r = nextRaw(self)
	if a == nil then
		return r
	end
	check(isNum(a) and isNum(b), "NextNumber espera (min, max)")
	return a + (b - a) * r
end
function RNG:NextInteger(a, b)
	check(isNum(a) and isNum(b), "NextInteger espera (min, max)")
	check(a <= b, "NextInteger: min > max")
	return a + math.floor(nextRaw(self) * (b - a + 1))
end
function RNG:NextUnitVector()
	return Vector3.new(nextRaw(self) - 0.5, nextRaw(self) - 0.5, nextRaw(self) - 0.5).Unit
end
function RNG:Clone()
	return setmetatable({ s = self.s }, RNG)
end
M.Random = Random

-- =====================================================================
-- Instances
-- =====================================================================
local classParents = {
	Part = "BasePart",
	WedgePart = "BasePart",
	CornerWedgePart = "BasePart",
	TrussPart = "BasePart",
	SpawnLocation = "Part",
	MeshPart = "BasePart",
	UnionOperation = "BasePart",
	Terrain = "BasePart",
	BasePart = "PVInstance",
	Model = "PVInstance",
	Workspace = "Model",
	PVInstance = "Instance",
	ScreenGui = "LayerCollector",
	BillboardGui = "LayerCollector",
	SurfaceGui = "LayerCollector",
	LayerCollector = "GuiBase2d",
	Frame = "GuiObject",
	TextLabel = "GuiObject",
	TextButton = "GuiButton",
	ImageButton = "GuiButton",
	GuiButton = "GuiObject",
	ImageLabel = "GuiObject",
	CanvasGroup = "GuiObject",
	GuiObject = "GuiBase2d",
	GuiBase2d = "Instance",
	PointLight = "Light",
	SpotLight = "Light",
	SurfaceLight = "Light",
	Light = "Instance",
	Script = "BaseScript",
	LocalScript = "Script",
	BaseScript = "LuaSourceContainer",
	ModuleScript = "LuaSourceContainer",
	LuaSourceContainer = "Instance",
	Humanoid = "Instance",
	Folder = "Instance",
}

local function isA(className, target)
	local c = className
	while c do
		if c == target then
			return true
		end
		c = classParents[c]
	end
	return target == "Instance"
end

-- Propriedades padrão relevantes
local defaults = {
	BasePart = function(p)
		p.Size = Vector3.new(4, 1, 2)
		p.CFrame = CFrame.new()
		p.Anchored = false
		p.CanCollide = true
		p.CanTouch = true
		p.CanQuery = true
		p.CastShadow = true
		p.Transparency = 0
		p.Color = Color3.fromRGB(163, 162, 165)
		p.AssemblyLinearVelocity = Vector3.zero
		p.AssemblyAngularVelocity = Vector3.zero
	end,
}

local Instance = {}
local INST = { __type = "Instance" }

local methods = {}
local readOnly = { ClassName = true }

local function newInstance(className)
	local obj = {
		__props = { ClassName = className, Name = className, Archivable = true },
		__children = {},
		__attrs = {},
		__tags = {},
		__signals = {},
	}
	setmetatable(obj, INST)
	for c, fn in defaults do
		if isA(className, c) then
			fn(obj.__props)
		end
	end
	stats.instances += 1
	if isA(className, "BasePart") then
		stats.parts += 1
	end
	return obj
end

local function getSignal(self, name)
	local s = self.__signals[name]
	if not s then
		s = Signal.new()
		self.__signals[name] = s
	end
	return s
end

local signalNames = {
	Touched = true,
	TouchEnded = true,
	ChildAdded = true,
	ChildRemoved = true,
	DescendantAdded = true,
	DescendantRemoving = true,
	Changed = true,
	AncestryChanged = true,
	Destroying = true,
	Died = true,
	StateChanged = true,
	MouseButton1Click = true,
	Activated = true,
	OnServerEvent = true,
	OnClientEvent = true,
	Event = true,
	CharacterAdded = true,
	CharacterRemoving = true,
	Completed = true,
	MoveToFinished = true,
	Running = true,
	Triggered = true,
	FocusLost = true,
	InputBegan = true,
}

INST.__index = function(self, k)
	local m = methods[k]
	if m then
		return m
	end
	if signalNames[k] then
		return getSignal(self, k)
	end
	local props = rawget(self, "__props")
	if k == "Position" and props.CFrame and isA(props.ClassName, "BasePart") then
		return props.CFrame.Position
	elseif k == "Orientation" and props.CFrame and isA(props.ClassName, "BasePart") then
		local x, y, z = props.CFrame:ToOrientation()
		return Vector3.new(math.deg(x), math.deg(y), math.deg(z))
	elseif k == "AbsoluteSize" then
		return Vector2.new(1280, 720)
	elseif k == "AbsolutePosition" then
		return Vector2.new(0, 0)
	elseif k == "ViewportSize" then
		return props.ViewportSize or Vector2.new(1280, 720)
	end
	local v = props[k]
	if v ~= nil then
		return v
	end
	-- filho com esse nome?
	for _, child in rawget(self, "__children") do
		if child.__props.Name == k then
			return child
		end
	end
	return nil
end

local function setParent(self, parent)
	local old = self.__props.Parent
	if old == parent then
		return
	end
	if old then
		local list = old.__children
		local i = table.find(list, self)
		if i then
			table.remove(list, i)
		end
		getSignal(old, "ChildRemoved"):Fire(self)
	end
	self.__props.Parent = parent
	if parent then
		check(getmetatable(parent) == INST, "Parent deve ser Instance")
		table.insert(parent.__children, self)
		getSignal(parent, "ChildAdded"):Fire(self)
		local a = parent
		while a do
			getSignal(a, "DescendantAdded"):Fire(self)
			a = a.__props.Parent
		end
		if M.onParented then
			M.onParented(self)
		end
	end
end

INST.__newindex = function(self, k, v)
	if readOnly[k] then
		error("propriedade somente leitura: " .. k, 2)
	end
	local props = self.__props
	if k == "Parent" then
		setParent(self, v)
		return
	end
	if k == "Position" and isA(props.ClassName, "BasePart") then
		check(isV3(v), "Position espera Vector3")
		local cf = props.CFrame or CFrame.new()
		props.CFrame = CFrame.new(v) * cf.Rotation
		return
	elseif k == "Orientation" and isA(props.ClassName, "BasePart") then
		local cf = props.CFrame or CFrame.new()
		props.CFrame = CFrame.new(cf.Position) * CFrame.fromOrientation(math.rad(v.X), math.rad(v.Y), math.rad(v.Z))
		return
	elseif k == "CFrame" then
		check(isCF(v), "CFrame espera CFrame (recebeu " .. mtypeof(v) .. ")")
	elseif k == "Size" and isA(props.ClassName, "BasePart") then
		check(isV3(v), "Size espera Vector3")
		check(v.X >= 0 and v.Y >= 0 and v.Z >= 0, "Size negativo")
		if props.ClassName == "TrussPart" then
			check(v.X == 2 and v.Z == 2 or v.X == 2 and v.Y == 2 or v.Y == 2 and v.Z == 2, "TrussPart precisa de seção 2x2")
		end
	elseif k == "Color" and (props.ClassName == "ParticleEmitter" or props.ClassName == "Beam" or props.ClassName == "Trail" or props.ClassName == "UIGradient") then
		check(mtypeof(v) == "ColorSequence", k .. " de partículas espera ColorSequence")
	elseif (k == "Color" or k == "TextColor3" or k == "BackgroundColor3" or k == "ImageColor3") then
		check(getmetatable(v) == C3, k .. " espera Color3")
	elseif k == "Material" then
		check(mtypeof(v) == "EnumItem" and v.EnumType == "Material", "Material espera Enum.Material")
	elseif k == "Transparency" and (props.ClassName == "ParticleEmitter" or props.ClassName == "Beam" or props.ClassName == "Trail") then
		check(mtypeof(v) == "NumberSequence", k .. " de partículas espera NumberSequence")
	elseif (k == "Transparency" or k == "BackgroundTransparency" or k == "TextTransparency") then
		check(isNum(v), k .. " espera número")
	elseif k == "Size" or k == "Position" then
		-- GUI
	end
	if (k == "Size" or k == "Position") and isA(props.ClassName, "GuiObject") then
		check(mtypeof(v) == "UDim2", k .. " de GUI espera UDim2")
	end
	props[k] = v
	local s = self.__signals["Changed"]
	if s then
		s:Fire(k)
	end
	local ps = self.__signals["prop:" .. k]
	if ps then
		ps:Fire()
	end
end

INST.__tostring = function(self)
	return self.__props.Name
end

function Instance.new(className, parent)
	check(type(className) == "string", "Instance.new espera string")
	local obj = newInstance(className)
	if parent then
		obj.Parent = parent
	end
	return obj
end
M.Instance = Instance
M.newInstance = newInstance

function methods.IsA(self, c)
	return isA(self.__props.ClassName, c)
end
function methods.FindFirstChild(self, name, recursive)
	for _, c in self.__children do
		if c.__props.Name == name then
			return c
		end
	end
	if recursive then
		for _, c in self.__children do
			local r = c:FindFirstChild(name, true)
			if r then
				return r
			end
		end
	end
	return nil
end
function methods.WaitForChild(self, name)
	local c = self:FindFirstChild(name)
	if not c then
		error("WaitForChild: '" .. name .. "' não existe em " .. self.__props.Name .. " (travaria para sempre)", 2)
	end
	return c
end
function methods.FindFirstChildOfClass(self, cls)
	for _, c in self.__children do
		if c.__props.ClassName == cls then
			return c
		end
	end
	return nil
end
function methods.FindFirstChildWhichIsA(self, cls, recursive)
	for _, c in self.__children do
		if c:IsA(cls) then
			return c
		end
	end
	if recursive then
		for _, c in self.__children do
			local r = c:FindFirstChildWhichIsA(cls, true)
			if r then
				return r
			end
		end
	end
	return nil
end
function methods.FindFirstAncestorWhichIsA(self, cls)
	local p = self.__props.Parent
	while p do
		if p:IsA(cls) then
			return p
		end
		p = p.__props.Parent
	end
	return nil
end
function methods.FindFirstAncestor(self, name)
	local p = self.__props.Parent
	while p do
		if p.__props.Name == name then
			return p
		end
		p = p.__props.Parent
	end
	return nil
end
function methods.IsDescendantOf(self, other)
	local p = self.__props.Parent
	while p do
		if p == other then
			return true
		end
		p = p.__props.Parent
	end
	return false
end
function methods.GetChildren(self)
	return table.clone(self.__children)
end
function methods.GetDescendants(self)
	local out = {}
	local function rec(o)
		for _, c in o.__children do
			table.insert(out, c)
			rec(c)
		end
	end
	rec(self)
	return out
end
function methods.ClearAllChildren(self)
	for _, c in table.clone(self.__children) do
		c:Destroy()
	end
end
function methods.Destroy(self)
	getSignal(self, "Destroying"):Fire()
	setParent(self, nil)
	for _, c in table.clone(self.__children) do
		c:Destroy()
	end
end
function methods.Clone(self)
	local copy = newInstance(self.__props.ClassName)
	for k, v in self.__props do
		if k ~= "Parent" then
			copy.__props[k] = v
		end
	end
	for k, v in self.__attrs do
		copy.__attrs[k] = v
	end
	for k, v in self.__tags do
		copy.__tags[k] = v
	end
	for _, c in self.__children do
		local cc = c:Clone()
		cc.Parent = copy
	end
	return copy
end
function methods.SetAttribute(self, k, v)
	local t = mtypeof(v)
	check(v == nil or t == "number" or t == "string" or t == "boolean" or t == "Vector3" or t == "Color3" or t == "CFrame" or t == "UDim2" or t == "NumberRange", "SetAttribute: tipo não suportado " .. t)
	self.__attrs[k] = v
	local s = self.__signals["attr:" .. k]
	if s then
		s:Fire()
	end
end
function methods.GetAttribute(self, k)
	return self.__attrs[k]
end
function methods.GetAttributes(self)
	return table.clone(self.__attrs)
end
function methods.GetAttributeChangedSignal(self, k)
	return getSignal(self, "attr:" .. k)
end
function methods.GetPropertyChangedSignal(self, k)
	return getSignal(self, "prop:" .. k)
end
function methods.AddTag(self, tag)
	self.__tags[tag] = true
	if M.onTagAdded then
		M.onTagAdded(self, tag)
	end
end
function methods.RemoveTag(self, tag)
	self.__tags[tag] = nil
end
function methods.HasTag(self, tag)
	return self.__tags[tag] == true
end
function methods.GetTags(self)
	local out = {}
	for t in self.__tags do
		table.insert(out, t)
	end
	return out
end

-- Pivots
local function partsOf(model)
	local out = {}
	if model:IsA("BasePart") then
		table.insert(out, model)
	end
	for _, d in model:GetDescendants() do
		if d:IsA("BasePart") then
			table.insert(out, d)
		end
	end
	return out
end
function methods.GetPivot(self)
	if self:IsA("BasePart") then
		return self.__props.CFrame
	end
	if self.__props.WorldPivot then
		return self.__props.WorldPivot
	end
	local pp = self.__props.PrimaryPart
	if pp then
		return pp.__props.CFrame
	end
	local parts = partsOf(self)
	if #parts == 0 then
		return CFrame.new()
	end
	local sum = Vector3.zero
	for _, p in parts do
		sum += p.__props.CFrame.Position
	end
	return CFrame.new(sum / #parts)
end
function methods.PivotTo(self, cf)
	check(isCF(cf), "PivotTo espera CFrame")
	local old = self:GetPivot()
	local delta = cf * old:Inverse()
	for _, p in partsOf(self) do
		p.__props.CFrame = delta * p.__props.CFrame
	end
	if self:IsA("Model") then
		self.__props.WorldPivot = cf
	end
end
function methods.GetScale(self)
	return self.__props.__scale or 1
end
function methods.ScaleTo(self, s)
	check(isNum(s) and s > 0, "ScaleTo espera número > 0")
	local cur = self.__props.__scale or 1
	local f = s / cur
	local pivot = self:GetPivot()
	for _, p in partsOf(self) do
		local rel = pivot:Inverse() * p.__props.CFrame
		local pos = rel.Position * f
		p.__props.CFrame = pivot * (CFrame.new(pos) * rel.Rotation)
		p.__props.Size = p.__props.Size * f
	end
	self.__props.__scale = s
end
function methods.GetBoundingBox(self)
	local parts = partsOf(self)
	local mn, mx = Vector3.new(math.huge, math.huge, math.huge), Vector3.new(-math.huge, -math.huge, -math.huge)
	for _, p in parts do
		local c = p.__props.CFrame.Position
		local h = p.__props.Size / 2
		mn = mn:Min(c - h)
		mx = mx:Max(c + h)
	end
	return CFrame.new((mn + mx) / 2), mx - mn
end
function methods.GetExtentsSize(self)
	local _, s = self:GetBoundingBox()
	return s
end
function methods.GetMass(self)
	return 1
end
function methods.SetNetworkOwner() end
function methods.BreakJoints() end

-- Humanoid
function methods.ChangeState() end
function methods.GetState()
	return Enum.HumanoidStateType.Running
end
function methods.SetStateEnabled() end
function methods.LoadAnimation()
	return { Play = function() end, Stop = function() end }
end
function methods.MoveTo() end
function methods.TakeDamage(self, d)
	self.Health = (self.Health or 100) - d
end
function methods.GetPlayingAnimationTracks()
	return {}
end

-- Som / Partículas / Tween
function methods.Play() end
function methods.Stop() end
function methods.Pause() end
function methods.Emit() end
function methods.Clear() end
function methods.Fire(self, ...)
	-- BindableEvent / RemoteEvent no servidor
	getSignal(self, "Event"):Fire(...)
end
function methods.FireClient(self, player, ...)
	M.remoteLog = M.remoteLog or {}
	table.insert(M.remoteLog, { remote = self.__props.Name, player = player, args = { ... } })
end
function methods.FireAllClients(self, ...)
	M.remoteLog = M.remoteLog or {}
	table.insert(M.remoteLog, { remote = self.__props.Name, all = true, args = { ... } })
end
function methods.FireServer(self, ...)
	getSignal(self, "OnServerEvent"):Fire(M.localPlayer, ...)
end
function methods.InvokeServer() end

-- Terrain
local function terrainCall(name)
	return function(self, ...)
		stats.terrainCalls += 1
		local args = { ... }
		if name == "FillBlock" then
			check(isCF(args[1]) and isV3(args[2]) and mtypeof(args[3]) == "EnumItem", "FillBlock(cframe, size, material)")
			check(args[2].X > 0 and args[2].Y > 0 and args[2].Z > 0, "FillBlock: tamanho deve ser positivo")
		elseif name == "FillBall" then
			check(isV3(args[1]) and isNum(args[2]) and mtypeof(args[3]) == "EnumItem", "FillBall(center, radius, material)")
		elseif name == "FillCylinder" then
			check(isCF(args[1]) and isNum(args[2]) and isNum(args[3]) and mtypeof(args[4]) == "EnumItem", "FillCylinder(cframe, height, radius, material)")
		elseif name == "FillWedge" then
			check(isCF(args[1]) and isV3(args[2]) and mtypeof(args[3]) == "EnumItem", "FillWedge(cframe, size, material)")
		elseif name == "SetMaterialColor" then
			check(mtypeof(args[1]) == "EnumItem" and getmetatable(args[2]) == C3, "SetMaterialColor(material, color)")
		end
		M.terrainLog = M.terrainLog or {}
		table.insert(M.terrainLog, { name, args })
	end
end
methods.FillBlock = terrainCall("FillBlock")
methods.FillBall = terrainCall("FillBall")
methods.FillCylinder = terrainCall("FillCylinder")
methods.FillWedge = terrainCall("FillWedge")
-- voxels: lê tudo vazio e confere as dimensões na escrita
function methods.ReadVoxels(_, region, res)
	local s = (region.max - region.min) / res
	local mats, occ = {}, {}
	for x = 1, s.X do
		mats[x], occ[x] = {}, {}
		for y = 1, s.Y do
			mats[x][y], occ[x][y] = {}, {}
			for z = 1, s.Z do
				mats[x][y][z], occ[x][y][z] = Enum.Material.Air, 0
			end
		end
	end
	return mats, occ
end
function methods.WriteVoxels(_, region, res, mats, occ)
	stats.terrainCalls += 1
	local s = (region.max - region.min) / res
	assert(#mats == s.X and #mats[1] == s.Y and #mats[1][1] == s.Z and #occ == s.X, "WriteVoxels: dimensões erradas")
	assert(s.X * s.Y * s.Z <= 4194304, "WriteVoxels: região grande demais")
end
methods.SetMaterialColor = terrainCall("SetMaterialColor")
methods.Clear = function() end

-- Workspace
function methods.GetServerTimeNow()
	return 1000 + clock
end
function methods.Raycast()
	return nil
end
function methods.GetPartBoundsInBox()
	return {}
end
function methods.GetPartBoundsInRadius()
	return {}
end
function methods.GetPartsInPart()
	return {}
end

-- GUI
function methods.TweenPosition() end
function methods.TweenSize() end

-- =====================================================================
-- Serviços e DataModel
-- =====================================================================
local game = newInstance("DataModel")
game.Name = "Game"
M.game = game

local services = {}
local function service(name, className)
	local s = newInstance(className or name)
	s.Name = name
	s.Parent = game
	services[name] = s
	return s
end

local workspace = service("Workspace")
local terrain = newInstance("Terrain")
terrain.Name = "Terrain"
terrain.Parent = workspace
local camera = newInstance("Camera")
camera.Name = "Camera"
camera.CFrame = CFrame.new(0, 10, 0)
camera.Parent = workspace
workspace.CurrentCamera = camera
workspace.Gravity = 196.2

service("ReplicatedStorage")
service("ServerScriptService")
service("ServerStorage")
service("Lighting")
service("StarterGui")
service("SoundService")
service("Teams")
local starterPlayer = service("StarterPlayer")
local sps = newInstance("StarterPlayerScripts")
sps.Name = "StarterPlayerScripts"
sps.Parent = starterPlayer

-- Players
local players = service("Players")
local PlayerAdded, PlayerRemoving = Signal.new(), Signal.new()
local playerList = {}
players.__props.PlayerAdded = PlayerAdded
players.__props.PlayerRemoving = PlayerRemoving
function methods.GetPlayers(self)
	return table.clone(playerList)
end
function methods.GetPlayerFromCharacter(self, char)
	for _, p in playerList do
		if p.Character == char then
			return p
		end
	end
	return nil
end

-- cria um jogador simulado com personagem
function M.addPlayer(name, userId)
	local p = newInstance("Player")
	p.Name = name
	p.UserId = userId
	p.DisplayName = name
	local pg = newInstance("PlayerGui")
	pg.Name = "PlayerGui"
	pg.Parent = p
	local ps = newInstance("PlayerScripts")
	ps.Name = "PlayerScripts"
	ps.Parent = p
	p.Parent = players
	table.insert(playerList, p)
	PlayerAdded:Fire(p)
	M.spawnCharacter(p)
	return p
end

function M.spawnCharacter(p)
	local char = newInstance("Model")
	char.Name = p.Name
	local hrp = newInstance("Part")
	hrp.Name = "HumanoidRootPart"
	hrp.Size = Vector3.new(2, 2, 1)
	hrp.CFrame = CFrame.new(0, 5, 0)
	hrp.Parent = char
	local hum = newInstance("Humanoid")
	hum.Name = "Humanoid"
	hum.Health = 100
	hum.MaxHealth = 100
	hum.WalkSpeed = 16
	hum.FloorMaterial = Enum.Material.Grass
	hum.Parent = char
	char.PrimaryPart = hrp
	char.Parent = workspace
	p.Character = char
	getSignal(p, "CharacterAdded"):Fire(char)
	return char
end

function methods.LoadCharacter(self)
	if self.Character then
		self.Character:Destroy()
	end
	return M.spawnCharacter(self)
end
function methods.RequestStreamAroundAsync() end
function methods.Kick() end

local RunService = service("RunService")
RunService.__props.Heartbeat = Signal.new()
RunService.__props.Stepped = Signal.new()
RunService.__props.RenderStepped = Signal.new()
RunService.__props.PreSimulation = Signal.new()
RunService.__props.PostSimulation = Signal.new()
RunService.__props.PreRender = Signal.new()
M.isServer = true
function methods.IsServer()
	return M.isServer
end
function methods.IsClient()
	return not M.isServer
end
function methods.IsStudio()
	return true
end
function methods.BindToRenderStep() end
function methods.UnbindFromRenderStep() end

local CollectionService = service("CollectionService")
local tagSignals = {}
local function tagSignal(tag)
	tagSignals[tag] = tagSignals[tag] or { added = Signal.new(), removed = Signal.new() }
	return tagSignals[tag]
end
M.onTagAdded = function(inst, tag)
	tagSignal(tag).added:Fire(inst)
end
function methods.GetTagged(self, tag)
	local out = {}
	local function rec(o)
		if o.__tags[tag] then
			table.insert(out, o)
		end
		for _, c in o.__children do
			rec(c)
		end
	end
	rec(game)
	return out
end
function methods.GetInstanceAddedSignal(self, tag)
	return tagSignal(tag).added
end
function methods.GetInstanceRemovedSignal(self, tag)
	return tagSignal(tag).removed
end

local TweenService = service("TweenService")
function methods.Create(self, inst, info, goals)
	check(mtypeof(info) == "TweenInfo", "TweenService:Create espera TweenInfo")
	for k, v in goals do
		inst[k] = v -- aplica o estado final imediatamente
	end
	local t = { Completed = Signal.new(), PlaybackState = Enum.PlaybackState.Completed }
	function t.Play() end
	function t.Cancel() end
	function t.Pause() end
	function t.Destroy() end
	return t
end
function methods.GetValue(self, alpha)
	return alpha
end

local Debris = service("Debris")
function methods.AddItem() end

local UIS = service("UserInputService")
UIS.TouchEnabled = false
UIS.KeyboardEnabled = true
UIS.GamepadEnabled = false
function methods.GetLastInputType()
	return Enum.UserInputType.Keyboard
end

local GuiService = service("GuiService")
function methods.GetGuiInset()
	return Vector2.new(0, 36), Vector2.new(0, 0)
end
service("ContentProvider")
local PhysicsService = service("PhysicsService")
function methods.RegisterCollisionGroup() end
function methods.CollisionGroupSetCollidable() end
local StarterGui = services.StarterGui
function methods.SetCore() end
function methods.SetCoreGuiEnabled() end

function methods.GetService(self, name)
	local s = services[name]
	check(s ~= nil, "GetService: serviço desconhecido " .. tostring(name))
	return s
end
function methods.BindToClose() end

-- =====================================================================
-- Instalação dos globais
-- =====================================================================
function M.install(target)
	target.Vector3 = Vector3
	target.Vector2 = Vector2
	target.CFrame = CFrame
	target.Color3 = Color3
	target.UDim = UDim
	target.UDim2 = UDim2
	target.Rect = M.Rect
	target.NumberSequence = M.NumberSequence
	target.NumberSequenceKeypoint = M.NumberSequenceKeypoint
	target.ColorSequence = M.ColorSequence
	target.ColorSequenceKeypoint = M.ColorSequenceKeypoint
	target.NumberRange = M.NumberRange
	target.TweenInfo = M.TweenInfo
	target.PhysicalProperties = M.PhysicalProperties
	target.Font = M.Font
	target.BrickColor = M.BrickColor
	target.Enum = Enum
	target.Instance = Instance
	target.Random = Random
	target.Region3 = { new = function(a, b)
		return { min = a, max = b }
	end }
	target.task = task
	target.game = game
	target.workspace = workspace
	target.Workspace = workspace
	target.typeof = mtypeof
	target.tick = function()
		return clock
	end
	target.time = function()
		return clock
	end
	target.warn = function(...)
		M.warnings = M.warnings or {}
		local parts = {}
		for _, v in { ... } do
			table.insert(parts, tostring(v))
		end
		table.insert(M.warnings, table.concat(parts, " "))
	end
	target.RaycastParams = {
		new = function()
			return setmetatable({ FilterType = Enum.RaycastFilterType.Exclude, FilterDescendantsInstances = {} }, { __type = "RaycastParams" })
		end,
	}
	local userSettings = { GetService = function()
		return { SavedQualityLevel = Enum.SavedQualitySetting.QualityLevel5 }
	end }
	target.UserSettings = function()
		return userSettings
	end
	target.wait = task.wait
	target.spawn = task.spawn
	target.delay = task.delay
end

M.services = services
M.workspace = workspace
M.INST = INST
M.methods = methods

return M
