--[[
	SkipService: entrega a compra "Pular fase". Só o servidor avança o jogador,
	e só depois que o Roblox confirma o pagamento (ProcessReceipt).
]]

local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Config = require(Shared.Config)

local SkipService = {}
local granted = {}

function SkipService.init(progress)
	MarketplaceService.ProcessReceipt = function(receipt)
		if Config.SkipProductId == 0 or receipt.ProductId ~= Config.SkipProductId then
			return Enum.ProductPurchaseDecision.NotProcessedYet
		end
		if granted[receipt.PurchaseId] then
			return Enum.ProductPurchaseDecision.PurchaseGranted
		end
		local player = Players:GetPlayerByUserId(receipt.PlayerId)
		if not player or not progress.skip(player) then
			return Enum.ProductPurchaseDecision.NotProcessedYet
		end
		granted[receipt.PurchaseId] = true
		return Enum.ProductPurchaseDecision.PurchaseGranted
	end
end

return SkipService