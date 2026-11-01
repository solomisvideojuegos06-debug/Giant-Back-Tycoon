--!strict
--[[
	GrowthService
	Alimentar al gigante, niveles 1-10 y estirón (GDD, sección E, «Crecimiento»).

	- Feed(cantidad): gasta Fruta del almacén. Doble estómago y el Linaje
	  aumentan lo que cuenta cada Fruta.
	- Al llenar la barra sube de nivel: GiantService cambia la escala, se
	  abren huecos y todos los clientes ven el estirón (GrowthSpurt).
	- El bloqueo de zonas por nivel lo aplica GiantService al moverse.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local Economy = require(Shared.Config.Economy)
local Formulas = require(Shared.Formulas)
local Levels = require(Shared.Config.Levels)
local Remotes = require(Shared.Remotes)
local Traits = require(Shared.Config.Traits)
local Types = require(Shared.Types)
local RateLimiter = require(script.Parent.Parent.RateLimiter)
local DataService = require(script.Parent.DataService)
local EconomyService = require(script.Parent.EconomyService)
local GiantService = require(script.Parent.GiantService)
local TelemetryService = require(script.Parent.TelemetryService)

type PlayerData = Types.PlayerData

local GrowthService = {}

local feedLimiter = RateLimiter.new(4, 4)

local FRUIT_TO_NEXT: { number } = {}
for index, info in Levels do
	if info.fruitToNext then
		FRUIT_TO_NEXT[index] = info.fruitToNext
	end
end

local function feedMultiplier(data: PlayerData): number
	local multiplier = 1
	for _, trait in data.giant.traits do
		local def = Traits[trait]
		if def and def.feedMultiplier then
			multiplier *= def.feedMultiplier
		end
	end
	return multiplier
end

local function pushGrowth(player: Player, data: PlayerData)
	DataService.setView(player, "level", data.giant.level)
	DataService.setView(player, "growthFruit", data.giant.growthFruit)
	DataService.setView(player, "fruitToNext", FRUIT_TO_NEXT[data.giant.level] or 0)
end

local function onLevelsGained(player: Player, data: PlayerData, previousLevel: number)
	local level = data.giant.level
	GiantService.refresh(player)
	EconomyService.pushAll(player)
	Remotes.GrowthSpurt:FireAllClients(player.UserId, level)

	TelemetryService.funnel(player, "FirstGrowth")
	if level >= 3 then
		TelemetryService.funnel(player, "Level3")
	end
	if level >= 5 then
		TelemetryService.funnel(player, "Level5")
	end
	for reached = previousLevel + 1, level do
		local unlocks = Levels[reached].unlocks
		if unlocks then
			Remotes.Notify:FireClient(player, `¡Nivel {reached}! Desbloqueas {unlocks}`)
		end
	end
end

-- Suma Fruta de crecimiento (ya multiplicada) y aplica las subidas de nivel.
function GrowthService.addGrowth(player: Player, value: number)
	local data = DataService.get(player)
	if not data or value <= 0 then
		return
	end
	local previous = data.giant.level
	local result = Formulas.applyGrowth(previous, data.giant.growthFruit, value, FRUIT_TO_NEXT)
	data.giant.level = result.level
	data.giant.growthFruit = result.growthFruit
	pushGrowth(player, data)
	if result.levelsGained > 0 then
		onLevelsGained(player, data, previous)
	end
end

-- Fruta que falta para el siguiente nivel (0 si es adulto).
function GrowthService.missingFruit(player: Player): number
	local data = DataService.get(player)
	if not data then
		return 0
	end
	local need = FRUIT_TO_NEXT[data.giant.level]
	return if need then math.max(need - data.giant.growthFruit, 0) else 0
end

function GrowthService.isAdult(data: PlayerData): boolean
	return FRUIT_TO_NEXT[data.giant.level] == nil
end

local function onFeed(player: Player, amount: unknown): (boolean, string?)
	if not feedLimiter.allow(player.UserId) then
		return false, "Demasiado rápido"
	end
	local data = DataService.get(player)
	if not data or type(amount) ~= "number" or amount ~= amount then
		return false, nil
	end
	if GrowthService.isAdult(data) then
		return false, "Tu gigante ya es adulto"
	end
	local count = math.floor(math.min(amount, data.resources.fruit))
	if count <= 0 then
		return false, "No tienes Fruta"
	end
	if not EconomyService.removeFruit(player, count) then
		return false, nil
	end
	local value =
		Formulas.feedValue(count, feedMultiplier(data), data.lineage.generation, Economy.lineage.feedBonusPerGeneration)
	GrowthService.addGrowth(player, value)
	return true, nil
end

-- Para el Linaje: deja el nivel y la barra como se indique (sin estirón).
function GrowthService.setLevel(player: Player, level: number)
	local data = DataService.get(player)
	if not data then
		return
	end
	local previous = data.giant.level
	data.giant.level = math.clamp(level, 1, #Levels)
	data.giant.growthFruit = 0
	pushGrowth(player, data)
	GiantService.refresh(player)
	EconomyService.pushAll(player)
	if data.giant.level > previous then
		Remotes.GrowthSpurt:FireAllClients(player.UserId, data.giant.level)
	end
end

function GrowthService.init()
	DataService.registerView(function(_player: Player, data: PlayerData)
		return {
			level = data.giant.level,
			growthFruit = data.giant.growthFruit,
			fruitToNext = FRUIT_TO_NEXT[data.giant.level] or 0,
		}
	end)
	-- Comando de prueba /nivel N (solo Studio).
	GiantService.setDebugLevelHandler(GrowthService.setLevel)
end

function GrowthService.start()
	Remotes.Feed.OnServerInvoke = onFeed
	Players.PlayerRemoving:Connect(function(player)
		feedLimiter.forget(player.UserId)
	end)
	print("[GrowthService] iniciado")
end

return GrowthService
