--[[
	LifeController (cliente)
	------------------------
	Dá vida à paisagem com bichinhos que só existem no cliente:
	  * bandos de pássaros voando em círculos em volta da montanha, batendo
	    as asas (alguns bem alto, perto das ilhas de nuvem);
	  * borboletas coloridas voando perto do jogador nos jardins.

	Tudo é decoração (sem colisão) e só é animado perto da câmera.
]]

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local LifeController = {}
local player = Players.LocalPlayer

local UPDATE_RADIUS = 700

local function decoPart(props): BasePart
	local part = Instance.new("Part")
	part.Anchored = true
	part.CanCollide = false
	part.CanTouch = false
	part.CanQuery = false
	part.CastShadow = false
	part.Material = Enum.Material.SmoothPlastic
	for k, v in props do
		if k ~= "Parent" then
			(part :: any)[k] = v
		end
	end
	part.Parent = props.Parent
	return part
end

-- Pássaro: corpo + duas asas (as asas giram em volta do ombro)
local function bird(parent: Instance, color: Color3, scale: number)
	local body = decoPart({ Name = "Corpo", Size = Vector3.new(0.6, 0.5, 1.6) * scale, Color = color, Parent = parent })
	local wings = {}
	for _, side in { -1, 1 } do
		wings[side] = decoPart({ Name = "Asa", Size = Vector3.new(1.8, 0.12, 0.8) * scale, Color = color:Lerp(Color3.new(1, 1, 1), 0.2), Parent = parent })
	end
	return { body = body, wings = wings, scale = scale }
end

local function placeBird(b, cf: CFrame, flap: number)
	b.body.CFrame = cf
	for side, wing in b.wings do
		local shoulder = cf * CFrame.new(side * 0.3 * b.scale, 0.1 * b.scale, 0)
		wing.CFrame = shoulder * CFrame.Angles(0, 0, side * flap) * CFrame.new(side * 0.9 * b.scale, 0, 0)
	end
end

-- Borboleta: duas asas que abrem e fecham
local function butterfly(parent: Instance, color: Color3)
	local wings = {}
	for _, side in { -1, 1 } do
		wings[side] = decoPart({ Name = "Asa", Size = Vector3.new(0.5, 0.05, 0.42), Color = color, Material = Enum.Material.Neon, Transparency = 0.1, Parent = parent })
	end
	return { wings = wings }
end

local function placeButterfly(b, cf: CFrame, flap: number)
	for side, wing in b.wings do
		wing.CFrame = cf * CFrame.Angles(0, 0, side * flap) * CFrame.new(side * 0.25, 0, 0)
	end
end

function LifeController.start()
	local info = ReplicatedStorage:FindFirstChild("CourseInfo")
	local center = (info and info:GetAttribute("WorldCenter")) or Vector3.zero
	local folder = Instance.new("Folder")
	folder.Name = "Vida"
	folder.Parent = workspace.CurrentCamera or workspace
	local rng = Random.new(7)

	-- bandos: raio da volta, altura, velocidade (rad/s), quantidade
	local flocks = {}
	local specs = {
		{ 260, 70, 0.05, 6 },
		{ 380, 140, -0.04, 5 },
		{ 220, 230, 0.06, 5 },
		{ 330, 420, -0.045, 4 },
		{ 240, 620, 0.05, 4 },
	}
	for _, spec in specs do
		local flock = { radius = spec[1], height = spec[2], speed = spec[3], phase = rng:NextNumber(0, math.pi * 2), birds = {} }
		for i = 1, spec[4] do
			local color = (rng:NextNumber() < 0.5) and Color3.fromRGB(96, 86, 92) or Color3.fromRGB(240, 236, 232)
			local b = bird(folder, color, rng:NextNumber(0.9, 1.3))
			-- formação em "V" solta
			b.offset = Vector3.new((i % 2 == 0 and 1 or -1) * math.ceil(i / 2) * 3, rng:NextNumber(-1.5, 1.5), -math.ceil(i / 2) * 3)
			b.flapSpeed = rng:NextNumber(7, 10)
			b.flapPhase = rng:NextNumber(0, 6)
			table.insert(flock.birds, b)
		end
		table.insert(flocks, flock)
	end

	-- borboletas perto do jogador (só nas regiões de jardim)
	local colors = { Color3.fromRGB(255, 196, 120), Color3.fromRGB(255, 170, 200), Color3.fromRGB(196, 170, 255), Color3.fromRGB(255, 240, 150) }
	local butterflies = {}
	for i = 1, 8 do
		local b = butterfly(folder, colors[(i % #colors) + 1])
		b.seed = rng:NextNumber(0, 100)
		b.radius = rng:NextNumber(6, 16)
		table.insert(butterflies, b)
	end
	LifeController.flocks, LifeController.butterflies = flocks, butterflies

	local gardenTop = info and info:GetAttribute("Region3Start") or 98
	local celestial = info and info:GetAttribute("Region5Start") or 290
	local skyStart = info and info:GetAttribute("Region6Start") or 312

	RunService.RenderStepped:Connect(function()
		local camera = workspace.CurrentCamera
		if not camera then
			return
		end
		local t = os.clock()
		local focus = camera.CFrame.Position
		for _, flock in flocks do
			local a = flock.phase + t * flock.speed
			local pos = center + Vector3.new(math.sin(a) * flock.radius, flock.height + math.sin(t * 0.3 + flock.phase) * 6, math.cos(a) * flock.radius)
			if (pos - focus).Magnitude < UPDATE_RADIUS then
				-- direção do voo = tangente do círculo
				local dir = Vector3.new(math.cos(a), 0, -math.sin(a)) * math.sign(flock.speed)
				local lead = CFrame.lookAt(pos, pos + dir)
				for _, b in flock.birds do
					local flap = math.sin(t * b.flapSpeed + b.flapPhase) * 0.7
					placeBird(b, lead * CFrame.new(b.offset), flap)
				end
			end
		end
		-- borboletas: só no Jardim/Vila (baixo) e no Jardim Celestial
		local character = player.Character
		local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
		local y = root and root.Position.Y or focus.Y
		local show = root ~= nil and (y < gardenTop or (y >= celestial and y < skyStart))
		for _, b in butterflies do
			if show and root then
				local s = b.seed
				local p = root.Position
					+ Vector3.new(math.sin(t * 0.37 + s) * b.radius, 1.5 + math.sin(t * 0.9 + s) * 1.2, math.cos(t * 0.29 + s * 1.7) * b.radius)
				local dir = Vector3.new(math.cos(t * 0.37 + s), 0.1, -math.sin(t * 0.29 + s * 1.7))
				placeButterfly(b, CFrame.lookAt(p, p + dir), math.sin(t * 14 + s) * 1.1)
			else
				for _, wing in b.wings do
					wing.CFrame = CFrame.new(0, -1000, 0)
				end
			end
		end
	end)
end

return LifeController
