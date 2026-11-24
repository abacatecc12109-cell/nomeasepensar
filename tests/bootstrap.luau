--!nocheck
-- Prepara o ambiente simulado, monta a árvore do projeto e executa um spec.
local specPath = ...

local mockChunk = __loadFile(__testRoot .. "/tests/mock/Roblox.luau")
local Roblox = mockChunk()
local G = getfenv(1)
Roblox.install(G)

local moduleCache = {}

local function makeEnv(scriptInstance)
	local env = setmetatable({}, { __index = G })
	env.script = scriptInstance
	env.require = G.require
	return env
end

function G.require(target)
	if type(target) == "table" and getmetatable(target) == Roblox.INST then
		local cached = moduleCache[target]
		if cached ~= nil then
			if cached == "__loading" then
				error("require circular: " .. target:GetFullName(), 2)
			end
			return cached.value
		end
		local file = target.__props.__file
		assert(file, "ModuleScript sem arquivo: " .. tostring(target.Name))
		moduleCache[target] = "__loading"
		local chunk = __loadFile(file)
		setfenv(chunk, makeEnv(target))
		local value = chunk()
		moduleCache[target] = { value = value }
		return value
	end
	error("require espera ModuleScript (recebeu " .. typeof(target) .. ")", 2)
end

-- GetFullName para mensagens
Roblox.INST.__index = (function(old)
	return function(self, k)
		if k == "GetFullName" then
			return function(o)
				local parts = {}
				local cur = o
				while cur and cur.__props.ClassName ~= "DataModel" do
					table.insert(parts, 1, cur.__props.Name)
					cur = cur.__props.Parent
				end
				return table.concat(parts, ".")
			end
		end
		return old(self, k)
	end
end)(Roblox.INST.__index)

-- Monta a árvore de scripts igual ao Rojo
local scripts = {}
for line in string.gmatch(__filesList, "[^\n]+") do
	local className, file, instPath = string.match(line, "^([^\t]*)\t([^\t]*)\t(.*)$")
	local parent = Roblox.game
	local names = string.split(instPath, "/")
	for i, name in names do
		local child = parent:FindFirstChild(name)
		if not child then
			child = Roblox.newInstance(i == #names and className or "Folder")
			child.Name = name
			child.Parent = parent
		end
		if i == #names and file ~= "" then
			child.__props.__file = file
			table.insert(scripts, { inst = child, className = className })
		end
		parent = child
	end
end

-- Executa um Script/LocalScript (usado pelos specs de integração)
function G.runScript(inst)
	local chunk = __loadFile(inst.__props.__file)
	setfenv(chunk, makeEnv(inst))
	return task.spawn(chunk)
end

-- ===================================================================
-- Mini framework de testes
-- ===================================================================
local passed, failed = 0, 0
local currentGroup = ""

function G.describe(name, fn)
	currentGroup = name
	fn()
end

function G.it(name, fn)
	local ok, err = xpcall(fn, debug.traceback)
	if ok then
		passed += 1
		__print("  ✓ " .. currentGroup .. " › " .. name)
	else
		failed += 1
		__print("  ✗ " .. currentGroup .. " › " .. name .. "\n      " .. tostring(err))
	end
end

function G.expect(cond, msg)
	if not cond then
		error(msg or "expectativa falhou", 2)
	end
end

G.Roblox = Roblox
G.log = function(...)
	local parts = {}
	for _, v in { ... } do
		table.insert(parts, tostring(v))
	end
	__print("      " .. table.concat(parts, " "))
end

local specChunk = __loadFile(specPath)
setfenv(specChunk, setmetatable({}, { __index = G }))
local ok, err = xpcall(specChunk, debug.traceback)
if not ok then
	failed += 1
	__print("  ✗ erro ao carregar spec: " .. tostring(err))
end

return passed, failed
