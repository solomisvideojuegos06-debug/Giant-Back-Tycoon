--!strict
--[[
	LineageService
	El Linaje (GDD, sección F): criar, huevo, herencia, retiro, Salón del
	Linaje y Libro de rasgos.

	- Criar: gigante adulto (nivel 10), sin huevo, con pareja adulta a menos
	  de 60 studs: un salvaje (inmediato) o otro jugador (los dos aceptan y
	  ambos reciben huevo). Con Nido doble salen 2 huevos y se elige uno.
	- El huevo tarda 15 minutos reales (os.time), aunque estés desconectado.
	- Continuar con la cría: el adulto se retira como estatua; se pierden
	  monedas, recursos, máquinas y nivel; se conservan Linaje, Libro, pieles
	  y pases; la generación sube (+15 % monedas, +10 % alimento).
	  Las estatuas se colocan en el rancho del jugador (RanchService).
]]

local BadgeService = game:GetService("BadgeService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local Economy = require(Shared.Config.Economy)
local Formulas = require(Shared.Formulas)
local Inheritance = require(Shared.Inheritance)
local Machines = require(Shared.Config.Machines)
local Mutations = require(Shared.Config.Mutations)
local Remotes = require(Shared.Remotes)
local Traits = require(Shared.Config.Traits)
local Types = require(Shared.Types)
local RateLimiter = require(script.Parent.Parent.RateLimiter)
local DataService = require(script.Parent.DataService)
local EconomyService = require(script.Parent.EconomyService)
local GiantService = require(script.Parent.GiantService)
local GrowthService = require(script.Parent.GrowthService)
local RanchService = require(script.Parent.RanchService)
local TelemetryService = require(script.Parent.TelemetryService)

type PlayerData = Types.PlayerData
type Genome = Inheritance.Genome

local BREEDING = Economy.breeding

local LineageService = {}

type PendingRequest = {
	from: Player,
	expiresAt: number,
}

local pending: { [Player]: PendingRequest } = {} -- clave: el que recibe la petición
local announcedHatch: { [Player]: boolean } = {}
local breedLimiter = RateLimiter.new(1, 3)
local continueLimiter = RateLimiter.new(1, 2)
local random = Random.new()

local function rng(): number
	return random:NextNumber()
end

local function genomeOf(data: PlayerData): Genome
	return { species = data.giant.species, traits = table.clone(data.giant.traits) }
end

local function eggsView(data: PlayerData): { any }
	return DataService.copy(data.eggs)
end

-- El huevo se ve en el lomo para todo el servidor.
local function updateEggAttribute(player: Player, data: PlayerData)
	local egg = data.eggs[1]
	GiantService.setRootAttribute(player.UserId, "Egg", if egg then egg.species else "")
end

local function pushLineage(player: Player, data: PlayerData)
	DataService.setView(player, "eggs", eggsView(data))
	DataService.setView(player, "generation", data.lineage.generation)
	DataService.setView(player, "ancestors", DataService.copy(data.lineage.ancestors))
	DataService.setView(player, "traitBook", DataService.copy(data.traitBook))
	DataService.setView(player, "species", data.giant.species)
	DataService.setView(player, "traits", table.clone(data.giant.traits))
end

local function canBreed(data: PlayerData): (boolean, string?)
	if data.giant.level < BREEDING.adultLevel then
		return false, `Tu gigante tiene que ser adulto (nivel {BREEDING.adultLevel})`
	end
	if #data.eggs > 0 then
		return false, "Ya tienes un huevo"
	end
	return true, nil
end

local function createEggs(player: Player, data: PlayerData, partner: Genome)
	local count = if data.passes.DoubleNest then 2 else 1
	local hatchAt = os.time() + BREEDING.hatchTime
	for _ = 1, count do
		local child = Inheritance.breed(genomeOf(data), partner, Mutations.chance, Mutations.list, rng)
		table.insert(data.eggs, { species = child.species, traits = child.traits, hatchAt = hatchAt })
	end
	announcedHatch[player] = nil
	DataService.setView(player, "eggs", eggsView(data))
	updateEggAttribute(player, data)
	TelemetryService.funnel(player, "FirstEgg")
	Remotes.Notify:FireClient(player, if count > 1 then "¡Dos huevos en el nido!" else "¡Un huevo en tu lomo!")
end

local function partnersClose(a: number, b: number): boolean
	local giantA = GiantService.get(a)
	local giantB = GiantService.get(b)
	return giantA ~= nil and giantB ~= nil and GiantService.bodyDistance(giantA, giantB) <= BREEDING.maxDistance
end

local function onRequestBreed(player: Player, partnerId: unknown): (boolean, string?)
	if not breedLimiter.allow(player.UserId) then
		return false, "Demasiado rápido"
	end
	local data = DataService.get(player)
	if not data or type(partnerId) ~= "number" or partnerId == player.UserId then
		return false, nil
	end
	local ok, reason = canBreed(data)
	if not ok then
		return false, reason
	end
	local partner = GiantService.get(partnerId)
	if not partner then
		return false, "Esa pareja ya no está"
	end
	if not partnersClose(player.UserId, partnerId) then
		return false, `Acércate más (menos de {BREEDING.maxDistance} studs)`
	end

	if partner.wildZone then
		createEggs(player, data, { species = partner.species, traits = table.clone(partner.traits) })
		return true, nil
	end

	local partnerPlayer = partner.player
	local partnerData = partnerPlayer and DataService.get(partnerPlayer)
	if not partnerPlayer or not partnerData then
		return false, "Esa pareja ya no está"
	end
	local partnerOk, partnerReason = canBreed(partnerData)
	if not partnerOk then
		return false, `{partnerPlayer.DisplayName}: {partnerReason}`
	end
	pending[partnerPlayer] = { from = player, expiresAt = os.clock() + BREEDING.requestTimeout }
	Remotes.BreedPrompt:FireClient(
		partnerPlayer,
		player.UserId,
		player.DisplayName,
		data.giant.species,
		data.giant.traits
	)
	return true, `Petición enviada a {partnerPlayer.DisplayName}`
end

local function onRespondBreed(player: Player, fromUserId: unknown, accept: unknown)
	local request = pending[player]
	if not request or type(fromUserId) ~= "number" or request.from.UserId ~= fromUserId then
		return
	end
	pending[player] = nil
	local requester = request.from
	if accept ~= true then
		Remotes.Notify:FireClient(requester, `{player.DisplayName} ha rechazado criar`)
		return
	end
	if os.clock() > request.expiresAt or requester.Parent ~= Players then
		Remotes.Notify:FireClient(player, "La petición ha caducado")
		return
	end
	local data = DataService.get(player)
	local requesterData = DataService.get(requester)
	if not data or not requesterData then
		return
	end
	local okA, reasonA = canBreed(data)
	local okB = canBreed(requesterData)
	if not okA or not okB then
		Remotes.Notify:FireClient(player, reasonA or "No se puede criar ahora")
		return
	end
	if not partnersClose(player.UserId, requester.UserId) then
		Remotes.Notify:FireClient(player, "Los gigantes se han alejado demasiado")
		return
	end
	-- Ambos reciben un huevo y ninguno pierde nada.
	createEggs(player, data, genomeOf(requesterData))
	createEggs(requester, requesterData, genomeOf(data))
end

function LineageService.hatchNow(player: Player): boolean
	local data = DataService.get(player)
	if not data or #data.eggs == 0 then
		return false
	end
	for _, egg in data.eggs do
		egg.hatchAt = math.min(egg.hatchAt, os.time())
	end
	DataService.setView(player, "eggs", eggsView(data))
	return true
end

-- Retiro y nueva generación ---------------------------------------------------

local function onContinue(player: Player, eggIndex: unknown): (boolean, string?)
	if not continueLimiter.allow(player.UserId) then
		return false, "Demasiado rápido"
	end
	local data = DataService.get(player)
	if not data or #data.eggs == 0 then
		return false, "No tienes huevo"
	end
	local index = if type(eggIndex) == "number" then math.floor(eggIndex) else 1
	local egg = data.eggs[index]
	if not egg then
		return false, "Ese huevo no existe"
	end
	if os.time() < egg.hatchAt then
		return false, "El huevo todavía no ha eclosionado"
	end

	-- El adulto se retira.
	table.insert(data.lineage.ancestors, genomeOf(data))
	while #data.lineage.ancestors > Economy.lineage.maxAncestors do
		table.remove(data.lineage.ancestors, 1)
	end
	data.lineage.generation += 1

	-- Se pierde: monedas, recursos, máquinas y nivel.
	data.coins = 0
	data.resources = { wood = 0, stone = 0, fruit = 0 }
	data.giant.machines = { ["1"] = { id = Machines.starting, level = 1 } }
	data.giant.species = egg.species
	data.giant.traits = table.clone(egg.traits)
	data.giant.growthFruit = 0
	data.eggs = {}
	announcedHatch[player] = nil

	local startLevel = 1
	for _, trait in egg.traits do
		local def = Traits[trait]
		if def and def.startLevel then
			startLevel = math.max(startLevel, def.startLevel)
		end
	end
	data.giant.level = startLevel

	-- Libro de rasgos.
	local key = Formulas.traitBookKey(egg.species, egg.traits)
	local isNew = not data.traitBook[key]
	data.traitBook[key] = true

	GrowthService.setLevel(player, startLevel)
	EconomyService.pushAll(player)
	pushLineage(player, data)
	updateEggAttribute(player, data)

	if isNew then
		EconomyService.addCoins(player, Economy.lineage.traitBookReward, "TraitBook", key)
		Remotes.Notify:FireClient(
			player,
			`Combinación nueva en el Libro de rasgos: +{Economy.lineage.traitBookReward} monedas`
		)
	end
	for _, trait in egg.traits do
		local def = Traits[trait]
		if def and def.isMutation then
			Remotes.Notify:FireClient(player, `¡Mutación rara: {def.displayName}!`)
			if BREEDING.mutationBadgeId ~= 0 then
				task.spawn(pcall, BadgeService.AwardBadge, BadgeService, player.UserId, BREEDING.mutationBadgeId)
			end
		end
	end

	RanchService.refreshStatues(player)
	return true, nil
end

-- Avisa (una vez) cuando un huevo eclosiona estando conectado.
local function checkHatching()
	local now = os.time()
	for _, player in Players:GetPlayers() do
		local data = DataService.get(player)
		if data and #data.eggs > 0 and not announcedHatch[player] then
			local ready = true
			for _, egg in data.eggs do
				if now < egg.hatchAt then
					ready = false
				end
			end
			if ready then
				announcedHatch[player] = true
				local egg = data.eggs[1]
				Remotes.Hatch:FireAllClients(player.UserId, egg.species, egg.traits)
				TelemetryService.funnel(player, "FirstHatch")
			end
		end
	end
end

function LineageService.init()
	DataService.onLoaded(function(player: Player, data: PlayerData)
		-- La combinación inicial cuenta en el Libro (sin premio).
		local key = Formulas.traitBookKey(data.giant.species, data.giant.traits)
		if not data.traitBook[key] then
			data.traitBook[key] = true
		end
		-- Esperar al gigante para saber la fila del Salón.
		for _ = 1, 50 do
			if GiantService.get(player.UserId) then
				break
			end
			task.wait(0.1)
		end
		updateEggAttribute(player, data)
		RanchService.refreshStatues(player)
	end)
	DataService.registerView(function(_player: Player, data: PlayerData)
		return {
			eggs = eggsView(data),
			generation = data.lineage.generation,
			ancestors = DataService.copy(data.lineage.ancestors),
			traitBook = DataService.copy(data.traitBook),
			species = data.giant.species,
			traits = table.clone(data.giant.traits),
		}
	end)
end

function LineageService.start()
	Remotes.RequestBreed.OnServerInvoke = onRequestBreed
	Remotes.RespondBreed.OnServerEvent:Connect(onRespondBreed)
	Remotes.ContinueWithHatchling.OnServerInvoke = onContinue
	Players.PlayerRemoving:Connect(function(player)
		pending[player] = nil
		announcedHatch[player] = nil
		breedLimiter.forget(player.UserId)
		continueLimiter.forget(player.UserId)
	end)
	task.spawn(function()
		while true do
			task.wait(1)
			checkHatching()
		end
	end)
	print("[LineageService] iniciado")
end

return LineageService
