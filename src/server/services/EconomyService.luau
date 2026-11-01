--!strict
--[[
	EconomyService
	Almacén, huecos, compra y mejora de máquinas, tick de producción, venta de
	Fruta y pastoreo nocturno (GDD, sección E y C).

	El servidor no se fía del cliente: comprueba hueco, nivel, dinero y que la
	máquina exista en cada petición, y limita la frecuencia de los remotos.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local Economy = require(Shared.Config.Economy)
local Formulas = require(Shared.Formulas)
local Levels = require(Shared.Config.Levels)
local Machines = require(Shared.Config.Machines)
local Remotes = require(Shared.Remotes)
local Traits = require(Shared.Config.Traits)
local Types = require(Shared.Types)
local RateLimiter = require(script.Parent.Parent.RateLimiter)
local DataService = require(script.Parent.DataService)
local GiantService = require(script.Parent.GiantService)
local SocialService = require(script.Parent.SocialService)
local TelemetryService = require(script.Parent.TelemetryService)

type PlayerData = Types.PlayerData
export type Resource = "wood" | "stone" | "fruit"

local EconomyService = {}

local shopLimiter = RateLimiter.new(6, 6)
local sellLimiter = RateLimiter.new(4, 4)
local lastPerSecond: { [Player]: number } = {}

local function hasTrait(data: PlayerData, trait: string): boolean
	return table.find(data.giant.traits, trait) ~= nil
end

local function machineList(data: PlayerData): { { slot: number, id: string, level: number } }
	local list = {}
	for key, machine in data.giant.machines do
		local slot = tonumber(key)
		if slot and Machines.byId[machine.id] then
			table.insert(list, { slot = slot, id = machine.id, level = machine.level })
		end
	end
	table.sort(list, function(a, b)
		return a.slot < b.slot
	end)
	return list
end

function EconomyService.slotCount(data: PlayerData): number
	local level = math.clamp(data.giant.level, 1, #Levels)
	local extra = 0
	for _, trait in data.giant.traits do
		local def = Traits[trait]
		if def and def.extraSlots then
			extra += def.extraSlots
		end
	end
	return Levels[level].machineSlots + extra
end

function EconomyService.capacity(data: PlayerData): number
	local extras: { number } = {}
	for _, machine in machineList(data) do
		local def = Machines.byId[machine.id]
		if def.kind == "storage" and def.capacity then
			table.insert(extras, def.capacity * Formulas.levelFactor(machine.level, Machines.speedPerLevel))
		end
	end
	return Formulas.storageCapacity(Economy.storageBase, extras, data.passes.BigStorage == true)
end

-- Multiplicador de todo lo procesado (Taller, Brillo, Linaje, x2, social).
function EconomyService.processedMultiplier(player: Player, data: PlayerData): number
	local polish = 0
	for _, machine in machineList(data) do
		local def = Machines.byId[machine.id]
		if def.kind == "bonus" and def.bonus then
			polish += def.bonus * Formulas.levelFactor(machine.level, Machines.speedPerLevel)
		end
	end
	return Formulas.processedMultiplier({
		polishBonus = polish,
		glow = hasTrait(data, "Glow"),
		glowMultiplier = Traits.Glow.valueMultiplier or 1,
		generation = data.lineage.generation,
		generationBonus = Economy.lineage.coinBonusPerGeneration,
		doubleCoins = data.passes.DoubleCoins == true,
		socialBonus = SocialService.getBonus(player),
	})
end

-- Monedas por segundo si las máquinas tuvieran siempre material.
function EconomyService.potentialPerSecond(player: Player, data: PlayerData): number
	local total = 0
	for _, machine in machineList(data) do
		local def = Machines.byId[machine.id]
		if def.kind == "processor" and def.rate and def.value then
			total += def.rate * Formulas.levelFactor(machine.level, Machines.speedPerLevel) * def.value
		end
	end
	return total * EconomyService.processedMultiplier(player, data)
end

local function pushResources(player: Player, data: PlayerData)
	DataService.setView(player, "wood", data.resources.wood)
	DataService.setView(player, "stone", data.resources.stone)
	DataService.setView(player, "fruit", data.resources.fruit)
end

local function pushMachines(player: Player, data: PlayerData)
	DataService.setView(player, "machines", DataService.copy(data.giant.machines))
	DataService.setView(player, "slots", EconomyService.slotCount(data))
	DataService.setView(player, "capacity", EconomyService.capacity(data))
	local perSecond = EconomyService.potentialPerSecond(player, data)
	DataService.setView(player, "perSecond", perSecond)
	GiantService.setRootAttribute(player.UserId, "PerSecond", math.floor(perSecond))
	GiantService.setMachinesAttribute(player.UserId, data.giant.machines)
end

function EconomyService.pushAll(player: Player)
	local data = DataService.get(player)
	if not data then
		return
	end
	DataService.setView(player, "coins", data.coins)
	pushResources(player, data)
	pushMachines(player, data)
end

function EconomyService.addCoins(player: Player, amount: number, transaction: string, sku: string?)
	local data = DataService.get(player)
	if not data or amount <= 0 then
		return
	end
	data.coins += amount
	DataService.setView(player, "coins", data.coins)
	TelemetryService.coins(player, amount, true, transaction, sku)
end

local function spend(player: Player, data: PlayerData, amount: number, transaction: string, sku: string): boolean
	if data.coins < amount then
		return false
	end
	data.coins -= amount
	DataService.setView(player, "coins", data.coins)
	TelemetryService.coins(player, amount, false, transaction, sku)
	return true
end

-- Cuánto cabe todavía de un recurso.
function EconomyService.space(player: Player, resource: Resource): number
	local data = DataService.get(player)
	if not data then
		return 0
	end
	return math.max(EconomyService.capacity(data) - data.resources[resource], 0)
end

-- Añade recursos respetando la capacidad; devuelve lo que se ha guardado.
function EconomyService.addResource(player: Player, resource: Resource, amount: number): number
	local data = DataService.get(player)
	if not data or amount <= 0 then
		return 0
	end
	local added = math.min(amount, math.max(EconomyService.capacity(data) - data.resources[resource], 0))
	if added > 0 then
		data.resources[resource] += added
		DataService.setView(player, resource, data.resources[resource])
	end
	return added
end

function EconomyService.removeFruit(player: Player, amount: number): boolean
	local data = DataService.get(player)
	if not data or amount <= 0 or data.resources.fruit < amount then
		return false
	end
	data.resources.fruit -= amount
	DataService.setView(player, "fruit", data.resources.fruit)
	return true
end

function EconomyService.priceFor(data: PlayerData, machineId: string): number
	local def = Machines.byId[machineId]
	local owned = 0
	for _, machine in machineList(data) do
		if machine.id == machineId then
			owned += 1
		end
	end
	return Formulas.machinePrice(def.price, owned, def.firstFree == true, Machines.repeatCostMultiplier)
end

function EconomyService.upgradeCostFor(machineId: string, level: number): number
	local def = Machines.byId[machineId]
	return Formulas.upgradeCost(def.price, level, Machines.upgradeCostMultiplier)
end

local function validSlot(data: PlayerData, slot: unknown): number?
	if type(slot) ~= "number" or slot ~= math.floor(slot) then
		return nil
	end
	if slot < 1 or slot > EconomyService.slotCount(data) then
		return nil
	end
	return slot
end

local function onBuyMachine(player: Player, slot: unknown, machineId: unknown): (boolean, string?)
	if not shopLimiter.allow(player.UserId) then
		return false, "Demasiado rápido"
	end
	local data = DataService.get(player)
	if not data then
		return false, "Cargando datos"
	end
	local slotNumber = validSlot(data, slot)
	if not slotNumber then
		return false, "Ese hueco no está disponible"
	end
	if type(machineId) ~= "string" or not Machines.byId[machineId] then
		return false, "Máquina desconocida"
	end
	if data.giant.machines[tostring(slotNumber)] then
		return false, "El hueco ya está ocupado"
	end
	local price = EconomyService.priceFor(data, machineId)
	if not spend(player, data, price, "BuyMachine", machineId) then
		return false, "No tienes monedas suficientes"
	end
	data.giant.machines[tostring(slotNumber)] = { id = machineId, level = 1 }
	pushMachines(player, data)
	TelemetryService.funnel(player, "FirstPurchase")
	return true, nil
end

local function onUpgradeMachine(player: Player, slot: unknown): (boolean, string?)
	if not shopLimiter.allow(player.UserId) then
		return false, "Demasiado rápido"
	end
	local data = DataService.get(player)
	if not data then
		return false, "Cargando datos"
	end
	local slotNumber = validSlot(data, slot)
	local machine = slotNumber and data.giant.machines[tostring(slotNumber)]
	if not machine then
		return false, "No hay máquina en ese hueco"
	end
	if machine.level >= Machines.maxLevel then
		return false, "Ya está al nivel máximo"
	end
	local cost = EconomyService.upgradeCostFor(machine.id, machine.level)
	if not spend(player, data, cost, "UpgradeMachine", machine.id) then
		return false, "No tienes monedas suficientes"
	end
	machine.level += 1
	pushMachines(player, data)
	return true, nil
end

local function onSellFruit(player: Player, amount: unknown): (boolean, string?)
	if not sellLimiter.allow(player.UserId) then
		return false, "Demasiado rápido"
	end
	local data = DataService.get(player)
	if not data or type(amount) ~= "number" or amount ~= amount then
		return false, nil
	end
	local count = math.floor(math.min(amount, data.resources.fruit))
	if count <= 0 then
		return false, "No tienes Fruta"
	end
	data.resources.fruit -= count
	DataService.setView(player, "fruit", data.resources.fruit)
	local generation = Formulas.generationMultiplier(data.lineage.generation, Economy.lineage.coinBonusPerGeneration)
	EconomyService.addCoins(player, count * Economy.fruitSellPrice * generation, "SellFruit")
	return true, nil
end

-- Un tick de producción: cada procesadora consume y convierte en monedas.
local function produce(player: Player, data: PlayerData)
	local earned = 0
	for _, machine in machineList(data) do
		local def = Machines.byId[machine.id]
		if def.kind == "processor" and def.input and def.rate and def.value then
			local resource = def.input :: Resource
			local wanted = def.rate
				* Formulas.levelFactor(machine.level, Machines.speedPerLevel)
				* Economy.productionInterval
			local used = math.min(wanted, data.resources[resource])
			if used > 0 then
				data.resources[resource] -= used
				earned += used * def.value
			end
		end
	end
	if earned > 0 then
		pushResources(player, data)
		EconomyService.addCoins(player, earned * EconomyService.processedMultiplier(player, data), "Production")
	end
	-- El bonus social cambia con el tiempo: se reenvía la producción si varía.
	local perSecond = EconomyService.potentialPerSecond(player, data)
	if lastPerSecond[player] ~= perSecond then
		lastPerSecond[player] = perSecond
		DataService.setView(player, "perSecond", perSecond)
		GiantService.setRootAttribute(player.UserId, "PerSecond", math.floor(perSecond))
	end
end

local function onLoaded(player: Player, data: PlayerData, offlineSeconds: number)
	-- Por si cambió la configuración: las máquinas que ya no caben se conservan
	-- pero no se usan hasta que vuelvan a caber huecos.
	GiantService.setMachinesAttribute(player.UserId, data.giant.machines)

	if offlineSeconds >= Economy.offline.minSeconds then
		local perSecond = EconomyService.potentialPerSecond(player, data)
		local coins = Formulas.offlineCoins(offlineSeconds, perSecond, Economy.offline.rate, Economy.offline.maxSeconds)
		if coins > 0 then
			EconomyService.addCoins(player, coins, "OfflineGrazing")
			local hours = math.min(offlineSeconds, Economy.offline.maxSeconds) / 3600
			Remotes.Notify:FireClient(
				player,
				`Tu gigante ha pastado mientras no estabas ({string.format("%.1f", hours)} h): +{coins} monedas`
			)
		end
	end
end

function EconomyService.init()
	DataService.onLoaded(onLoaded)
	DataService.registerView(function(player: Player, data: PlayerData)
		return {
			coins = data.coins,
			wood = data.resources.wood,
			stone = data.resources.stone,
			fruit = data.resources.fruit,
			capacity = EconomyService.capacity(data),
			machines = DataService.copy(data.giant.machines),
			slots = EconomyService.slotCount(data),
			perSecond = EconomyService.potentialPerSecond(player, data),
		}
	end)
end

function EconomyService.start()
	Remotes.BuyMachine.OnServerInvoke = onBuyMachine
	Remotes.UpgradeMachine.OnServerInvoke = onUpgradeMachine
	Remotes.SellFruit.OnServerInvoke = onSellFruit
	Players.PlayerRemoving:Connect(function(player)
		shopLimiter.forget(player.UserId)
		sellLimiter.forget(player.UserId)
		lastPerSecond[player] = nil
	end)

	task.spawn(function()
		while true do
			task.wait(Economy.productionInterval)
			for _, player in Players:GetPlayers() do
				local data = DataService.get(player)
				if data then
					produce(player, data)
				end
			end
		end
	end)

	print("[EconomyService] iniciado")
end

return EconomyService
