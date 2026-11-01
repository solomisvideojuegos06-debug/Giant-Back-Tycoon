--!strict
--[[
	MonetizationService
	Developer Products y Game Passes (GDD, secciones H y L).

	- ProcessReceipt idempotente: el PurchaseId se guarda en purchaseHistory
	  antes de confirmar la compra; si llega dos veces, no se concede dos veces.
	- Los pases se comprueban al entrar y con PromptGamePassPurchaseFinished.
	- Pieles: pases cosméticos; EquipSkin las pone o las quita.
	- Modo prueba (solo Studio): los productos con id 0 en Config/Products se
	  conceden directamente con DebugGrant, para poder probar la lógica.
]]

local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage.Shared
local Economy = require(Shared.Config.Economy)
local Products = require(Shared.Config.Products)
local Remotes = require(Shared.Remotes)
local Skins = require(Shared.Config.Skins)
local Types = require(Shared.Types)
local RateLimiter = require(script.Parent.Parent.RateLimiter)
local DataService = require(script.Parent.DataService)
local EconomyService = require(script.Parent.EconomyService)
local GiantService = require(script.Parent.GiantService)
local GrowthService = require(script.Parent.GrowthService)
local LineageService = require(script.Parent.LineageService)
local ResourceService = require(script.Parent.ResourceService)

type PlayerData = Types.PlayerData

local MonetizationService = {}

local skinLimiter = RateLimiter.new(2, 3)
local debugLimiter = RateLimiter.new(2, 3)

-- Lo que hace cada producto. Devuelve true si se ha concedido.
local HANDLERS: { [string]: (player: Player, data: PlayerData) -> boolean } = {
	Banquet = function(player)
		local missing = GrowthService.missingFruit(player)
		if missing <= 0 then
			return false
		end
		GrowthService.addGrowth(player, math.ceil(missing * 0.5))
		return true
	end,
	InstantHatch = function(player)
		return LineageService.hatchNow(player)
	end,
	FruitRain = function(player)
		ResourceService.startFruitRain(Economy.fruitRain.duration, player.DisplayName)
		return true
	end,
}

local function productKeyById(productId: number): string?
	for key, def in Products.products do
		if def.id ~= 0 and def.id == productId then
			return key
		end
	end
	return nil
end

local function grantProduct(player: Player, data: PlayerData, key: string): boolean
	local def = Products.products[key]
	if not def then
		return false
	end
	if def.coins then
		EconomyService.addCoins(player, def.coins, "CoinPack", key)
		return true
	end
	local handler = HANDLERS[key]
	return handler ~= nil and handler(player, data)
end

local function pushPasses(player: Player, data: PlayerData)
	DataService.setView(player, "passes", DataService.copy(data.passes))
	DataService.setView(player, "skin", data.giant.skin or "")
end

local function grantPass(player: Player, key: string)
	local data = DataService.get(player)
	if not data or data.passes[key] then
		return
	end
	data.passes[key] = true
	local def = Products.passes[key]
	if def and def.skin and not data.giant.skin then
		data.giant.skin = def.skin -- se estrena al comprarla
	end
	GiantService.refresh(player)
	EconomyService.pushAll(player)
	pushPasses(player, data)
	if def then
		Remotes.Notify:FireClient(player, `¡Gracias! Ya tienes: {def.displayName}`)
	end
end

local function processReceipt(receipt: { [string]: any }): Enum.ProductPurchaseDecision
	local player = Players:GetPlayerByUserId(receipt.PlayerId)
	if not player then
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end
	local data = DataService.get(player)
	if not data then
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end
	local purchaseId = tostring(receipt.PurchaseId)
	if data.purchaseHistory[purchaseId] then
		return Enum.ProductPurchaseDecision.PurchaseGranted
	end
	local key = productKeyById(receipt.ProductId)
	if not key then
		warn(`[MonetizationService] Producto desconocido: {receipt.ProductId}`)
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end
	local ok, granted = pcall(grantProduct, player, data, key)
	if not ok or not granted then
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end
	data.purchaseHistory[purchaseId] = true
	return Enum.ProductPurchaseDecision.PurchaseGranted
end

local function checkPasses(player: Player, data: PlayerData)
	for key, def in Products.passes do
		if def.id ~= 0 and not data.passes[key] then
			local ok, owns = pcall(MarketplaceService.UserOwnsGamePassAsync, MarketplaceService, player.UserId, def.id)
			if ok and owns then
				grantPass(player, key)
			end
		end
	end
end

local function onEquipSkin(player: Player, skin: unknown): (boolean, string?)
	if not skinLimiter.allow(player.UserId) then
		return false, "Demasiado rápido"
	end
	local data = DataService.get(player)
	if not data or type(skin) ~= "string" then
		return false, nil
	end
	if skin == "" then
		data.giant.skin = nil
	else
		if not Skins[skin] then
			return false, "Esa piel no existe"
		end
		local owned = false
		for key, def in Products.passes do
			if def.skin == skin and data.passes[key] then
				owned = true
			end
		end
		if not owned then
			return false, "No tienes esa piel"
		end
		data.giant.skin = skin
	end
	GiantService.refresh(player)
	pushPasses(player, data)
	return true, nil
end

-- Solo Studio y solo con id 0: concede el producto o el pase para probar.
local function onDebugGrant(player: Player, kind: unknown, key: unknown): (boolean, string?)
	if not RunService:IsStudio() or not debugLimiter.allow(player.UserId) then
		return false, nil
	end
	local data = DataService.get(player)
	if not data or type(key) ~= "string" then
		return false, nil
	end
	if kind == "product" then
		local def = Products.products[key]
		if not def or def.id ~= 0 then
			return false, nil
		end
		local granted = grantProduct(player, data, key)
		return granted, if granted then "Modo prueba: concedido" else "No se puede usar ahora"
	elseif kind == "pass" then
		local def = Products.passes[key]
		if not def or def.id ~= 0 then
			return false, nil
		end
		grantPass(player, key)
		return true, "Modo prueba: pase concedido"
	end
	return false, nil
end

function MonetizationService.init()
	DataService.onLoaded(function(player: Player, data: PlayerData)
		checkPasses(player, data)
	end)
	DataService.registerView(function(_player: Player, data: PlayerData)
		return {
			passes = DataService.copy(data.passes),
			skin = data.giant.skin or "",
			isStudio = RunService:IsStudio(),
		}
	end)
end

function MonetizationService.start()
	MarketplaceService.ProcessReceipt = processReceipt
	MarketplaceService.PromptGamePassPurchaseFinished:Connect(
		function(player: Player, passId: number, purchased: boolean)
			if not purchased then
				return
			end
			for key, def in Products.passes do
				if def.id ~= 0 and def.id == passId then
					grantPass(player, key)
				end
			end
		end
	)
	Remotes.EquipSkin.OnServerInvoke = onEquipSkin
	Remotes.DebugGrant.OnServerInvoke = onDebugGrant
	Players.PlayerRemoving:Connect(function(player)
		skinLimiter.forget(player.UserId)
		debugLimiter.forget(player.UserId)
	end)
	print("[MonetizationService] iniciado")
end

return MonetizationService
