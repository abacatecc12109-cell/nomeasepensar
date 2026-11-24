--[[
	CourseInfo
	----------
	Publica em ReplicatedStorage.CourseInfo (atributos) as alturas reais do
	percurso: início/fim de cada região, checkpoints e altura do topo.
	A interface do cliente lê daqui, então nunca fica fora de sincronia.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local CourseInfo = {}

function CourseInfo.publish(layout)
	local info = ReplicatedStorage:FindFirstChild("CourseInfo") or Instance.new("Configuration")
	info.Name = "CourseInfo"

	local regionStart = {}
	for _, e in layout.elements do
		local y = e.kind == "zone" and e.top or math.min(e.entry.Y, e.exit.Y)
		if regionStart[e.region] == nil then
			regionStart[e.region] = y
		end
	end
	local regionCount = #regionStart
	for i = 1, regionCount do
		info:SetAttribute("Region" .. i .. "Start", regionStart[i])
	end
	info:SetAttribute("RegionCount", regionCount)

	local cps = layout.checkpoints
	info:SetAttribute("CheckpointCount", #cps)
	for _, cp in cps do
		info:SetAttribute("Checkpoint" .. cp.index .. "Label", cp.label or ("Checkpoint " .. cp.index))
		info:SetAttribute("Checkpoint" .. cp.index .. "Y", cp.position.Y)
		info:SetAttribute("Checkpoint" .. cp.index .. "Region", cp.region)
	end
	-- centro do mapa (para pássaros e outros efeitos do cliente)
	local sum, n = Vector3.zero, 0
	for _, z in layout.zones do
		sum += Vector3.new(z.center.X, 0, z.center.Z)
		n += 1
	end
	info:SetAttribute("WorldCenter", n > 0 and sum / n or Vector3.zero)
	info:SetAttribute("StartY", cps[1].position.Y)
	info:SetAttribute("SummitY", cps[#cps].position.Y)
	info:SetAttribute("Ready", true)
	info.Parent = ReplicatedStorage
	return info
end

return CourseInfo
