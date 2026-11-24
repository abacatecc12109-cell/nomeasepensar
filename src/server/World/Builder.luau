--[[
	Builder
	-------
	Fábrica de peças com padrões otimizados.

	* Tudo é ancorado.
	* Peças decorativas (deco) não colidem, não disparam Touched, não são
	  consultadas por raycasts e (quando pequenas) não projetam sombra:
	  isso economiza muito processamento de física, principalmente no celular.
	* Peças pisáveis (solid) usam colisão padrão.
]]

local Builder = {}

local DEFAULT_MATERIAL = Enum.Material.SmoothPlastic

local stats = { parts = 0 }
Builder.stats = stats

local function apply(part: BasePart, props)
	for k, v in props do
		if k ~= "Parent" then
			(part :: any)[k] = v
		end
	end
	if props.Parent then
		part.Parent = props.Parent
	end
end

local function base(className: string, props): BasePart
	local part = Instance.new(className) :: BasePart
	part.Anchored = true
	part.Material = DEFAULT_MATERIAL
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	apply(part, props)
	stats.parts += 1
	return part
end

-- Peça pisável (colisão normal)
function Builder.solid(props): BasePart
	return base("Part", props)
end

-- Peça decorativa (sem colisão, sem toque, sem consulta)
function Builder.deco(props): BasePart
	local part = base(props.ClassName or "Part", props)
	part.CanCollide = false
	part.CanTouch = false
	part.CanQuery = false
	if props.CastShadow == nil then
		local s = part.Size
		part.CastShadow = (s.X * s.Y * s.Z) > 60
	end
	return part
end

-- Colisor invisível exato (garante que a física bata com os dados do layout)
function Builder.collider(props): BasePart
	local part = base("Part", props)
	part.Transparency = 1
	part.CastShadow = false
	part.Name = props.Name or "Collider"
	return part
end

function Builder.wedge(props): BasePart
	local part = base("WedgePart", props)
	if props.CanCollide == false then
		part.CanTouch = false
		part.CanQuery = false
	end
	return part
end

function Builder.folder(name: string, parent: Instance?): Folder
	local f = Instance.new("Folder")
	f.Name = name
	f.Parent = parent
	return f
end

function Builder.model(name: string, parent: Instance?): Model
	local m = Instance.new("Model")
	m.Name = name
	m.Parent = parent
	return m
end

-- Cilindro entre dois pontos (eixo X do cilindro aponta de a para b)
function Builder.cylinderCFrame(a: Vector3, b: Vector3): CFrame
	local mid = (a + b) / 2
	local dir = b - a
	local up = math.abs(dir.Unit.Y) > 0.99 and Vector3.xAxis or Vector3.yAxis
	return CFrame.lookAt(mid, b, up) * CFrame.Angles(0, math.rad(90), 0)
end

function Builder.cylinder(a: Vector3, b: Vector3, radius: number, props, decorative: boolean?): BasePart
	props.Shape = Enum.PartType.Cylinder
	props.Size = Vector3.new((b - a).Magnitude, radius * 2, radius * 2)
	props.CFrame = Builder.cylinderCFrame(a, b)
	if decorative == false then
		return Builder.solid(props)
	end
	return Builder.deco(props)
end

function Builder.ball(center: Vector3, radius: number, props): BasePart
	props.Shape = Enum.PartType.Ball
	props.Size = Vector3.new(radius * 2, radius * 2, radius * 2)
	props.CFrame = CFrame.new(center)
	return Builder.deco(props)
end

-- CFrame de um elemento do layout: centro no topo, olhando para a frente.
function Builder.frameOf(center: Vector3, yaw: number): CFrame
	local f = Vector3.new(math.sin(yaw), 0, math.cos(yaw))
	return CFrame.lookAt(center, center + f)
end

-- Variação suave de cor (evita repetição artificial)
function Builder.vary(color: Color3, rng: Random, amount: number?): Color3
	local h, s, v = color:ToHSV()
	local a = amount or 0.05
	h = (h + rng:NextNumber(-a, a) * 0.3) % 1
	s = math.clamp(s + rng:NextNumber(-a, a), 0, 1)
	v = math.clamp(v + rng:NextNumber(-a, a), 0, 1)
	return Color3.fromHSV(h, s, v)
end

return Builder
