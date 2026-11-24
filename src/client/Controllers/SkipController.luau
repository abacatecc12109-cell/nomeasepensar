--[[
	SkipController (cliente): botão "Pular fase" (Produto de Desenvolvedor).
	O número do produto fica em Config.SkipProductId.
]]

local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Config = require(ReplicatedStorage:WaitForChild("Shared").Config)

local SkipController = {}
local player = Players.LocalPlayer

function SkipController.start(toast)
	local info = ReplicatedStorage:WaitForChild("CourseInfo")
	local gui = Instance.new("ScreenGui")
	gui.Name = "PularFase"
	gui.ResetOnSpawn = false
	local b = Instance.new("TextButton")
	b.Name = "Pular"
	b.AnchorPoint = Vector2.new(0, 1)
	b.Position = UDim2.new(0, 14, 0.62, 0)
	b.Size = UDim2.fromOffset(150, 48)
	b.BackgroundColor3 = Color3.fromRGB(92, 190, 112)
	b.Font = Enum.Font.GothamBold
	b.TextSize = 18
	b.TextColor3 = Color3.fromRGB(255, 255, 255)
	b.Text = "Pular fase"
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(0, 12)
	c.Parent = b
	b.Parent = gui
	-- ficou preso? volta ao checkpoint
	local back = b:Clone()
	back.Name = "Voltar"
	back.Position = UDim2.new(0, 14, 0.62, 56)
	back.BackgroundColor3 = Color3.fromRGB(96, 140, 214)
	back.Text = "Voltar"
	back.Parent = gui
	local remotes = require(ReplicatedStorage.Shared.Remotes).get()
	back.Activated:Connect(function()
		remotes.RequestReturn:FireServer()
	end)
	gui.Parent = player:WaitForChild("PlayerGui")

	local function refresh()
		local index = player:GetAttribute(Config.Attr.Checkpoint) or 1
		-- a última fase (chegada) não pode ser pulada
		b.Visible = index < (info:GetAttribute("CheckpointCount") or 0) - 1
	end
	refresh()
	player:GetAttributeChangedSignal(Config.Attr.Checkpoint):Connect(refresh)

	b.Activated:Connect(function()
		if Config.SkipProductId == 0 then
			toast("Pular fase ainda não está à venda")
			return
		end
		MarketplaceService:PromptProductPurchase(player, Config.SkipProductId)
	end)
	if Config.SkipProductId ~= 0 then
		task.spawn(function()
			local ok, data = pcall(function()
				return MarketplaceService:GetProductInfo(Config.SkipProductId, Enum.InfoType.Product)
			end)
			if ok and data and data.PriceInRobux then
				b.Text = "Pular fase · R$ " .. data.PriceInRobux
			end
		end)
	end
end

return SkipController