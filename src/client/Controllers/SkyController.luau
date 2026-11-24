--[[
	SkyController (cliente)
	-----------------------
	Céu de pôr do sol em degradê: AMARELO no horizonte → LARANJA → ROSA
	CLARO no alto, com um sol grande e brilhante.

	O céu é uma cúpula de painéis bem longe da câmera. Cada painel tem uma
	SurfaceGui com UIGradient que pinta exatamente a faixa de cor da sua
	altura no céu, então a cúpula inteira forma um degradê contínuo.
	A cúpula acompanha a câmera (só a posição), por isso nunca se chega
	perto dela. Fica só no cliente: não pesa no servidor nem na rede.
]]

local Lighting = game:GetService("Lighting")
local RunService = game:GetService("RunService")

local SkyController = {}

SkyController.RADIUS = 1700
local AZIMUTH = 16

-- Paradas do degradê por elevação (graus acima do horizonte)
SkyController.Stops = {
	{ -90, Color3.fromRGB(255, 226, 140) },
	{ 0, Color3.fromRGB(255, 232, 130) }, -- amarelo no horizonte
	{ 9, Color3.fromRGB(255, 208, 112) },
	{ 22, Color3.fromRGB(255, 170, 104) }, -- laranja
	{ 38, Color3.fromRGB(255, 176, 150) },
	{ 56, Color3.fromRGB(255, 198, 210) }, -- rosa claro
	{ 90, Color3.fromRGB(255, 214, 228) },
}

-- Faixas da cúpula (de baixo para cima), em graus
local BANDS = { { -70, -20 }, { -20, -2 }, { -2, 7 }, { 7, 16 }, { 16, 27 }, { 27, 40 }, { 40, 55 }, { 55, 71 }, { 71, 86 } }

function SkyController.colorAt(elevation: number): Color3
	local stops = SkyController.Stops
	if elevation <= stops[1][1] then
		return stops[1][2]
	end
	for i = 2, #stops do
		local a, b = stops[i - 1], stops[i]
		if elevation <= b[1] then
			local t = (elevation - a[1]) / (b[1] - a[1])
			return a[2]:Lerp(b[2], t)
		end
	end
	return stops[#stops][2]
end

local function direction(elevation: number, azimuth: number): Vector3
	local e, a = math.rad(elevation), math.rad(azimuth)
	return Vector3.new(math.cos(e) * math.sin(a), math.sin(e), math.cos(e) * math.cos(a))
end

local function panel(parent: Instance, cf: CFrame, size: Vector3, top: number, bottom: number)
	local part = Instance.new("Part")
	part.Name = "SkyPanel"
	part.Anchored = true
	part.CanCollide = false
	part.CanTouch = false
	part.CanQuery = false
	part.CastShadow = false
	part.Transparency = 1
	part.Size = size
	part.CFrame = cf
	local gui = Instance.new("SurfaceGui")
	gui.Name = "Gradient"
	gui.Face = Enum.NormalId.Front
	gui.LightInfluence = 0
	gui.Brightness = 1
	gui.CanvasSize = Vector2.new(32, 128)
	gui.Parent = part
	local frame = Instance.new("Frame")
	frame.Size = UDim2.fromScale(1, 1)
	frame.BorderSizePixel = 0
	frame.BackgroundColor3 = Color3.new(1, 1, 1)
	frame.Parent = gui
	local gradient = Instance.new("UIGradient")
	-- Rotation 90: o ponto 0 fica em cima do painel
	gradient.Rotation = 90
	gradient.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, SkyController.colorAt(top)),
		ColorSequenceKeypoint.new(0.5, SkyController.colorAt((top + bottom) / 2)),
		ColorSequenceKeypoint.new(1, SkyController.colorAt(bottom)),
	})
	gradient.Parent = frame
	part.Parent = parent
	return part
end

-- Monta a cúpula em volta da origem (depois ela é movida para a câmera)
function SkyController.buildDome(parent: Instance): Model
	local dome = Instance.new("Model")
	dome.Name = "CeuDegrade"
	local R = SkyController.RADIUS
	for _, band in BANDS do
		local e0, e1 = band[1], band[2]
		local mid = (e0 + e1) / 2
		local height = 2 * R * math.sin(math.rad(e1 - e0) / 2) * 1.04
		-- a borda mais larga da faixa define a largura (sem frestas)
		local widest = math.max(math.cos(math.rad(e0)), math.cos(math.rad(e1)))
		if e0 < 0 and e1 > 0 then
			widest = 1
		end
		local width = 2 * R * widest * math.tan(math.pi / AZIMUTH) * 1.06
		local inward = R * math.cos(math.rad(e1 - e0) / 2)
		for i = 0, AZIMUTH - 1 do
			local az = (i + 0.5) * 360 / AZIMUTH
			local pos = direction(mid, az) * inward
			local cf = CFrame.lookAt(pos, Vector3.zero, Vector3.yAxis)
			panel(dome, cf, Vector3.new(width, height, 1), e1, e0)
		end
	end
	-- tampa no zênite
	local capY = R * math.sin(math.rad(84))
	local cap = panel(dome, CFrame.lookAt(Vector3.new(0, capY, 0), Vector3.zero, Vector3.zAxis), Vector3.new(R * 0.5, R * 0.5, 1), 90, 90)
	cap.Name = "SkyCap"
	dome.WorldPivot = CFrame.new()
	dome.Parent = parent
	return dome
end

-- Sol: disco brilhante com dois halos suaves
function SkyController.buildSun(parent: Instance): Model
	local sun = Instance.new("Model")
	sun.Name = "Sol"
	local layers = {
		{ "Disco", 70, Color3.fromRGB(255, 248, 214), 0, Enum.Material.Neon },
		{ "Halo", 125, Color3.fromRGB(255, 226, 150), 0.6, Enum.Material.Neon },
		{ "Brilho", 230, Color3.fromRGB(255, 204, 150), 0.82, Enum.Material.Neon },
	}
	for _, l in layers do
		local part = Instance.new("Part")
		part.Name = l[1]
		part.Shape = Enum.PartType.Ball
		part.Size = Vector3.new(l[2], l[2], l[2])
		part.Color = l[3]
		part.Transparency = l[4]
		part.Material = l[5]
		part.Anchored = true
		part.CanCollide = false
		part.CanTouch = false
		part.CanQuery = false
		part.CastShadow = false
		part.CFrame = CFrame.new()
		part.Parent = sun
	end
	sun.PrimaryPart = sun:FindFirstChild("Disco") :: BasePart
	sun.Parent = parent
	return sun
end

local function sunDirection(): Vector3
	local ok, dir = pcall(function()
		return Lighting:GetSunDirection()
	end)
	if ok and typeof(dir) == "Vector3" and dir.Magnitude > 0.1 then
		return dir.Unit
	end
	-- aproximação: fim de tarde, sol baixo a oeste
	return direction(18, 250)
end
SkyController.sunDirection = sunDirection

function SkyController.start()
	local camera = workspace.CurrentCamera
	local holder = camera or workspace
	local dome = SkyController.buildDome(holder)
	local sun = SkyController.buildSun(holder)
	SkyController.dome, SkyController.sun = dome, sun
	local last: Vector3? = nil
	local sunDir = sunDirection()
	local timer = 0
	RunService.RenderStepped:Connect(function(dt)
		local cam = workspace.CurrentCamera
		if not cam then
			return
		end
		timer += dt
		if timer > 5 then
			timer = 0
			sunDir = sunDirection()
			last = nil
		end
		local pos = cam.CFrame.Position
		if last and (pos - last).Magnitude < 0.5 then
			return
		end
		last = pos
		dome:PivotTo(CFrame.new(pos))
		local sunPos = pos + sunDir * (SkyController.RADIUS * 0.9)
		for _, part in sun:GetChildren() do
			if part:IsA("BasePart") then
				-- halos um pouco atrás do disco
				local back = part.Name == "Disco" and 0 or (part.Name == "Halo" and 20 or 40)
				part.CFrame = CFrame.new(sunPos + sunDir * back)
			end
		end
	end)
end

return SkyController
