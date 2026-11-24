--[[
	Remotes
	-------
	Cria (no servidor) ou encontra (no cliente) os RemoteEvents do jogo.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local NAMES = {
	"CheckpointReached", -- servidor -> cliente (index, label, isFinish)
	"FallReset", -- servidor -> cliente (motivo)
	"RunFinished", -- servidor -> cliente (tempo, recorde, novoRecorde)
	"Announcement", -- servidor -> todos (texto)
	"RequestRestart", -- cliente -> servidor
	"RequestReturn", -- cliente -> servidor (voltar ao checkpoint)
}

local Remotes = {}

function Remotes.get()
	local folder = ReplicatedStorage:FindFirstChild("Remotes")
	if RunService:IsServer() then
		if not folder then
			folder = Instance.new("Folder")
			folder.Name = "Remotes"
			folder.Parent = ReplicatedStorage
		end
		for _, name in NAMES do
			if not folder:FindFirstChild(name) then
				local r = Instance.new("RemoteEvent")
				r.Name = name
				r.Parent = folder
			end
		end
	else
		folder = ReplicatedStorage:WaitForChild("Remotes")
	end
	local out = {}
	for _, name in NAMES do
		out[name] = RunService:IsServer() and folder:FindFirstChild(name) or folder:WaitForChild(name)
	end
	return out
end

return Remotes
