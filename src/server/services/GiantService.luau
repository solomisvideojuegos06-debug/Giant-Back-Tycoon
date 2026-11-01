--!strict
--[[
	GiantService
	Estado lógico y movimiento autoritativo de todos los gigantes: los de los
	jugadores (id = UserId) y los salvajes (id negativo). GDD, sección L.

	- Se mueven en Heartbeat con GiantMath.steer según DriveInput (validado),
	  el piloto automático (desde el nivel 3) o el paseo de los salvajes.
	- La altura sale de un raycast hacia abajo contra Workspace.Map; los
	  desniveles altos bloquean el paso, igual que las zonas sin nivel.
	- Rasgos sobre el terreno: el agua frena sin Patas anchas, los espinos sin
	  Piel dura; Zancada da +25 % de velocidad.
	- Publica cada gigante en Workspace.Giants.<id> (pieza invisible y anclada)
	  con atributos y envía instantáneas GiantSnapshot para interpolar.
	- Reenvía RiderUpdate y recuerda sobre qué gigante va cada jugador.
]]

local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TextChatService = game:GetService("TextChatService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage.Shared
local Economy = require(Shared.Config.Economy)
local GiantConfig = require(Shared.Config.Giant)
local GiantMath = require(Shared.GiantMath)
local Levels = require(Shared.Config.Levels)
local Remotes = require(Shared.Remotes)
local Species = require(Shared.Config.Species)
local Traits = require(Shared.Config.Traits)
local World = require(Shared.World)
local Zones = require(Shared.Config.Zones)
local RateLimiter = require(script.Parent.Parent.RateLimiter)
local DataService = require(script.Parent.DataService)
local TelemetryService = require(script.Parent.TelemetryService)

local MOVEMENT = GiantConfig.movement
local NETWORK = GiantConfig.network
local AUTOPILOT = Economy.autopilot

export type GiantState = {
	id: number,
	player: Player?, -- nil en los salvajes
	root: Part,
	species: string,
	traits: { string },
	skin: string?,
	level: number,
	scale: number,
	scaleBonus: number, -- Gigantismo
	position: Vector3, -- punto de apoyo en el suelo
	yaw: number,
	speed: number, -- velocidad hacia delante (studs/s)
	input: Vector3, -- dirección manual en el mundo (x, 0, z), magnitud 0..1
	inputAt: number,
	spawnSlot: number,
	autopilot: boolean,
	expertPilot: boolean,
	wildZone: string?, -- zona de la que no sale un salvaje
	waypoint: Vector3?,
	waypointAt: number,
	lastBlockedNotice: number,
	debugWander: boolean,
}

export type TargetProvider = (state: GiantState) -> Vector3?
export type GiantCallback = (state: GiantState) -> ()

local GiantService = {
	priority = 5,
}

local giants: { [number]: GiantState } = {}
local usedSpawnSlots: { [number]: boolean } = {}
local riders: { [number]: { giantId: number, at: number } } = {}
local createdCallbacks: { GiantCallback } = {}
local removedCallbacks: { GiantCallback } = {}
local targetProvider: TargetProvider? = nil
local debugLevelHandler: ((player: Player, level: number) -> ())? = nil
local giantsFolder: Folder
local groundParams: RaycastParams
local driveLimiter = RateLimiter.new(NETWORK.driveInputRate, NETWORK.driveInputBurst)
local riderLimiter = RateLimiter.new(NETWORK.riderRate, NETWORK.riderBurst)
local autopilotLimiter = RateLimiter.new(NETWORK.autopilotRate, 3)
local random = Random.new()
local snapshotAccumulator = 0

local function isFiniteNumber(value: unknown): boolean
	return type(value) == "number" and value == value and math.abs(value) < math.huge
end

local function isFiniteVector(value: unknown): boolean
	if typeof(value) ~= "Vector3" then
		return false
	end
	local vector = value :: Vector3
	return isFiniteNumber(vector.X) and isFiniteNumber(vector.Y) and isFiniteNumber(vector.Z)
end

local function hasTrait(state: GiantState, trait: string): boolean
	return table.find(state.traits, trait) ~= nil
end

local function traitValue(state: GiantState, field: string, default: number): number
	local value = default
	for _, trait in state.traits do
		local def = Traits[trait] :: any
		if def and type(def[field]) == "number" then
			value *= def[field]
		end
	end
	return value
end

local function giantCFrame(state: GiantState): CFrame
	return CFrame.new(state.position) * CFrame.Angles(0, state.yaw, 0)
end

local function computeScale(level: number, scaleBonus: number): number
	return Levels[math.clamp(level, 1, #Levels)].scale * scaleBonus
end

local function bodyOf(state: GiantState)
	return (Species[state.species] or Species.Turtle).body
end

local function notify(player: Player?, message: string)
	if player then
		Remotes.Notify:FireClient(player, message)
	end
end

-- Velocidad máxima según escala, rasgos, terreno y piloto.
local function maxSpeed(state: GiantState, autopilotActive: boolean): number
	local speed = MOVEMENT.baseSpeed * state.scale * traitValue(state, "speedMultiplier", 1)
	local area = World.slowAreaAt(state.position.X, state.position.Z)
	if area then
		local immune = (area.kind == "water" and hasTrait(state, "WideFeet"))
			or (area.kind == "thorns" and hasTrait(state, "ToughSkin"))
		if not immune then
			speed *= Zones.slowFactor
		end
	end
	if state.wildZone then
		speed *= GiantConfig.wild.speedFactor
	elseif autopilotActive and not state.expertPilot then
		speed *= AUTOPILOT.speedFactor
	end
	return speed
end

-- Altura del suelo en (x, z) buscando desde encima de `fromY`. nil si no hay suelo.
local function groundHeightAt(x: number, z: number, fromY: number): number?
	local origin = Vector3.new(x, fromY + MOVEMENT.groundProbeHeight, z)
	local direction = Vector3.new(0, -(MOVEMENT.groundProbeHeight + MOVEMENT.groundProbeDepth), 0)
	local result = Workspace:Raycast(origin, direction, groundParams)
	return if result then result.Position.Y else nil
end

-- ¿Puede estar el gigante en (x, z)? Devuelve también la zona que lo impide.
local function zoneAllows(state: GiantState, x: number, z: number): (boolean, Zones.ZoneDef?)
	local zone = World.zoneAt(x, z)
	if not zone then
		return false, nil
	end
	if state.wildZone then
		return zone.id == state.wildZone, nil
	end
	if zone.minLevel > state.level then
		return false, zone
	end
	return true, nil
end

-- Intenta desplazar el gigante; devuelve false (y la zona bloqueada) si no puede.
local function tryMove(state: GiantState, step: Vector3): (boolean, Zones.ZoneDef?)
	local distance = step.Magnitude
	if distance < 1e-6 then
		return true, nil
	end

	local current = state.position
	local target = current + step
	local maxStep = MOVEMENT.maxStepUp * state.scale
	local reach = MOVEMENT.frontProbeDistance * state.scale
	local probe = target + step.Unit * reach

	local allowed, lockedZone = zoneAllows(state, probe.X, probe.Z)
	if not allowed then
		return false, lockedZone
	end
	allowed, lockedZone = zoneAllows(state, target.X, target.Z)
	if not allowed then
		return false, lockedZone
	end

	local groundY = groundHeightAt(target.X, target.Z, current.Y)
	if not groundY or groundY - current.Y > maxStep + MOVEMENT.maxSlope * distance then
		return false, nil
	end
	local probeY = groundHeightAt(probe.X, probe.Z, current.Y)
	if not probeY or probeY - current.Y > maxStep + MOVEMENT.maxSlope * reach then
		return false, nil
	end

	state.position = Vector3.new(target.X, groundY, target.Z)
	return true, nil
end

local function setAttributes(state: GiantState)
	local root = state.root
	root:SetAttribute("OwnerUserId", state.id)
	root:SetAttribute("Species", state.species)
	root:SetAttribute("Traits", table.concat(state.traits, ","))
	root:SetAttribute("Skin", state.skin or "")
	root:SetAttribute("ScaleBonus", state.scaleBonus)
	root:SetAttribute("Level", state.level)
	root:SetAttribute("Wild", state.wildZone ~= nil)
	if state.player then
		root:SetAttribute("DisplayName", state.player.DisplayName)
	else
		local speciesDef = Species[state.species]
		root:SetAttribute("DisplayName", `{if speciesDef then speciesDef.displayName else "Gigante"} salvaje`)
	end
end

local function seatWorldPosition(state: GiantState): Vector3
	return giantCFrame(state):PointToWorldSpace(bodyOf(state).seat * state.scale)
end

-- El conductor debe estar cerca del asiento (con margen por el retraso de red).
local function isNearSeat(state: GiantState): boolean
	local player = state.player
	local character = player and player.Character
	local rootPart = character and character:FindFirstChild("HumanoidRootPart")
	if not rootPart or not rootPart:IsA("BasePart") then
		return false
	end
	local tolerance = GiantConfig.driver.maxSeatDistance * state.scale
		+ maxSpeed(state, false) * GiantConfig.driver.lagAllowance
	return (rootPart.Position - seatWorldPosition(state)).Magnitude <= tolerance
end

local function placeCharacterOnSeat(state: GiantState, character: Model)
	local seatTop = seatWorldPosition(state) + Vector3.new(0, GiantConfig.platform.seatHeight, 0)
	character:PivotTo(CFrame.new(seatTop) * CFrame.Angles(0, state.yaw, 0))
end

local function takeSpawnSlot(): number
	for slot = 1, GiantConfig.spawn.slots do
		if not usedSpawnSlots[slot] then
			usedSpawnSlots[slot] = true
			return slot
		end
	end
	return 1
end

local function spawnPose(slot: number): (Vector3, number)
	local angle = (slot - 1) / GiantConfig.spawn.slots * 2 * math.pi
	local outward = Vector3.new(math.cos(angle), 0, math.sin(angle))
	local spot = Zones.spawnCenter + outward * Zones.spawnRadius
	local groundY = groundHeightAt(spot.X, spot.Z, spot.Y) or spot.Y
	return Vector3.new(spot.X, groundY, spot.Z), GiantMath.yawFromDirection(outward.X, outward.Z)
end

local function newState(id: number, player: Player?, position: Vector3, yaw: number): GiantState
	local root = Instance.new("Part")
	root.Name = tostring(id)
	root.Size = Vector3.one
	root.Transparency = 1
	root.Anchored = true
	root.CanCollide = false
	root.CanQuery = false
	root.CanTouch = false
	root.CFrame = CFrame.new(position) * CFrame.Angles(0, yaw, 0)

	return {
		id = id,
		player = player,
		root = root,
		species = "Turtle",
		traits = {},
		skin = nil,
		level = 1,
		scale = 1,
		scaleBonus = 1,
		position = position,
		yaw = yaw,
		speed = 0,
		input = Vector3.zero,
		inputAt = 0,
		spawnSlot = 0,
		autopilot = false,
		expertPilot = false,
		wildZone = nil,
		waypoint = nil,
		waypointAt = 0,
		lastBlockedNotice = 0,
		debugWander = false,
	}
end

local function register(state: GiantState)
	setAttributes(state)
	giants[state.id] = state
	state.root.Parent = giantsFolder
	for _, callback in createdCallbacks do
		task.spawn(callback, state)
	end
end

-- Copia en el estado lo que dicen los datos guardados (especie, rasgos, nivel…).
local function applyData(state: GiantState, player: Player)
	local data = DataService.get(player)
	if not data then
		return
	end
	state.species = if Species[data.giant.species] then data.giant.species else "Turtle"
	state.traits = table.clone(data.giant.traits)
	state.skin = data.giant.skin
	state.level = math.clamp(data.giant.level, 1, #Levels)
	state.scaleBonus = traitValue(state, "scaleMultiplier", 1)
	state.scale = computeScale(state.level, state.scaleBonus)
	state.autopilot = data.autopilot and state.level >= AUTOPILOT.minLevel
	state.expertPilot = data.passes.ExpertPilot == true
	setAttributes(state)
end

local function createPlayerGiant(player: Player)
	if giants[player.UserId] then
		return
	end
	local slot = takeSpawnSlot()
	local position, yaw = spawnPose(slot)
	local state = newState(player.UserId, player, position, yaw)
	state.spawnSlot = slot
	applyData(state, player)
	register(state)

	local function onCharacter(character: Model)
		task.defer(function()
			if giants[player.UserId] == state and character.Parent then
				placeCharacterOnSeat(state, character)
			end
		end)
	end
	player.CharacterAdded:Connect(onCharacter)
	if player.Character then
		onCharacter(player.Character)
	end
end

local function removeGiant(id: number)
	local state = giants[id]
	if not state then
		return
	end
	giants[id] = nil
	if state.spawnSlot > 0 then
		usedSpawnSlots[state.spawnSlot] = nil
	end
	for _, callback in removedCallbacks do
		task.spawn(callback, state)
	end
	state.root:Destroy()
end

local function onPlayerRemoving(player: Player)
	removeGiant(player.UserId)
	riders[player.UserId] = nil
	driveLimiter.forget(player.UserId)
	riderLimiter.forget(player.UserId)
	autopilotLimiter.forget(player.UserId)
	Remotes.RiderUpdate:FireAllClients(player.UserId, 0, Vector3.zero, 0)
end

local function onDriveInput(player: Player, x: unknown, z: unknown)
	if not driveLimiter.allow(player.UserId) then
		return
	end
	local state = giants[player.UserId]
	if not state or not isFiniteNumber(x) or not isFiniteNumber(z) then
		return
	end
	local input = Vector3.new(x :: number, 0, z :: number)
	if input.Magnitude > 1 then
		input = input.Unit
	end
	if input.Magnitude > 1e-3 then
		if not isNearSeat(state) then
			return
		end
		TelemetryService.funnel(player, "MovedGiant")
	end
	state.input = input
	state.inputAt = os.clock()
end

local function onSetAutopilot(player: Player, enabled: unknown)
	if not autopilotLimiter.allow(player.UserId) or type(enabled) ~= "boolean" then
		return
	end
	local state = giants[player.UserId]
	local data = DataService.get(player)
	if not state or not data then
		return
	end
	if enabled and state.level < AUTOPILOT.minLevel then
		notify(player, `El piloto automático se desbloquea en el nivel {AUTOPILOT.minLevel}`)
		enabled = false
	end
	state.autopilot = enabled :: boolean
	state.waypoint = nil
	data.autopilot = state.autopilot
	DataService.setView(player, "autopilot", state.autopilot)
end

local function onRiderUpdate(player: Player, giantId: unknown, offset: unknown, yaw: unknown)
	if not riderLimiter.allow(player.UserId) then
		return
	end
	if giantId == 0 then
		riders[player.UserId] = nil
		Remotes.RiderUpdate:FireAllClients(player.UserId, 0, Vector3.zero, 0)
		return
	end
	if type(giantId) ~= "number" or not giants[giantId] then
		return
	end
	if not isFiniteVector(offset) or not isFiniteNumber(yaw) then
		return
	end
	local localOffset = offset :: Vector3
	if localOffset.Magnitude > GiantConfig.platform.maxRiderOffset then
		return
	end
	riders[player.UserId] = { giantId = giantId, at = os.clock() }
	Remotes.RiderUpdate:FireAllClients(player.UserId, giantId, localOffset, yaw)
end

-- Destino aleatorio dentro de la zona (con margen al borde).
local function randomWaypoint(state: GiantState): Vector3?
	local zone = if state.wildZone then Zones.byId[state.wildZone] else World.zoneAt(state.position.X, state.position.Z)
	if not zone then
		return nil
	end
	local margin = AUTOPILOT.zoneMargin
	local rect = zone.rect
	return Vector3.new(
		random:NextNumber(rect.minX + margin, rect.maxX - margin),
		0,
		random:NextNumber(rect.minZ + margin, rect.maxZ - margin)
	)
end

local function autopilotDirection(state: GiantState, now: number): Vector3
	local reached = state.waypoint
		and Vector3.new(state.waypoint.X - state.position.X, 0, state.waypoint.Z - state.position.Z).Magnitude
			< 15 * state.scale
	if not state.waypoint or reached or now - state.waypointAt > AUTOPILOT.waypointTimeout then
		local target: Vector3? = nil
		if state.expertPilot and targetProvider and not state.wildZone then
			target = targetProvider(state)
		end
		state.waypoint = target or randomWaypoint(state)
		state.waypointAt = now
	end
	local waypoint = state.waypoint
	if not waypoint then
		return Vector3.zero
	end
	local delta = Vector3.new(waypoint.X - state.position.X, 0, waypoint.Z - state.position.Z)
	return if delta.Magnitude > 1e-3 then delta.Unit else Vector3.zero
end

local function step(dt: number)
	local now = os.clock()

	for _, state in giants do
		local manual = now - state.inputAt <= MOVEMENT.inputTimeout and state.input.Magnitude > 1e-3
		local input = if manual then state.input else Vector3.zero
		local autopilotActive = false

		if state.debugWander then
			local angle = now * GiantConfig.debug.wanderTurnRate
			input = Vector3.new(math.cos(angle), 0, math.sin(angle))
		elseif not manual and (state.wildZone or (state.autopilot and state.level >= AUTOPILOT.minLevel)) then
			input = autopilotDirection(state, now)
			autopilotActive = true
		end

		state.yaw, state.speed = GiantMath.steer(state.yaw, state.speed, input.X, input.Z, dt, {
			maxSpeed = maxSpeed(state, autopilotActive),
			acceleration = MOVEMENT.acceleration * state.scale,
			deceleration = MOVEMENT.deceleration * state.scale,
			turnRate = MOVEMENT.turnRate,
			fullTurnAngle = MOVEMENT.fullTurnAngle,
		})

		if state.speed > 0 then
			local forwardX, forwardZ = GiantMath.forward(state.yaw)
			local move = Vector3.new(forwardX, 0, forwardZ) * state.speed * dt
			local moved, lockedZone = tryMove(state, move)
			if not moved then
				moved = tryMove(state, Vector3.new(move.X, 0, 0)) or tryMove(state, Vector3.new(0, 0, move.Z))
			end
			if not moved then
				state.speed = 0
				state.waypoint = nil -- el piloto busca otro destino
				if lockedZone and manual and now - state.lastBlockedNotice > GiantConfig.blockedNoticeInterval then
					state.lastBlockedNotice = now
					notify(
						state.player,
						`Necesitas nivel {lockedZone.minLevel} para entrar en: {lockedZone.displayName}`
					)
				end
			end
		end

		state.root.CFrame = giantCFrame(state)
	end

	snapshotAccumulator += dt
	local interval = 1 / NETWORK.snapshotRate
	if snapshotAccumulator >= interval then
		snapshotAccumulator %= interval
		local serverTime = Workspace:GetServerTimeNow()
		local data: { number } = {}
		local count = 0
		for id, state in giants do
			table.insert(data, id)
			table.insert(data, state.position.X)
			table.insert(data, state.position.Y)
			table.insert(data, state.position.Z)
			table.insert(data, state.yaw)
			count += 1
			if count >= NETWORK.snapshotGiantsPerPacket then
				Remotes.GiantSnapshot:FireAllClients(serverTime, data)
				data = {}
				count = 0
			end
		end
		if count > 0 then
			Remotes.GiantSnapshot:FireAllClients(serverTime, data)
		end
	end
end

local function setupDebugCommands()
	if not RunService:IsStudio() then
		return
	end
	local levelCommand = Instance.new("TextChatCommand")
	levelCommand.Name = "GiantLevelCommand"
	levelCommand.PrimaryAlias = GiantConfig.debug.levelCommand
	levelCommand.Parent = TextChatService
	levelCommand.Triggered:Connect(function(source: TextSource, message: string)
		local player = Players:GetPlayerByUserId(source.UserId)
		local level = tonumber(string.match(message, "%d+"))
		if player and level and debugLevelHandler then
			debugLevelHandler(player, math.clamp(math.floor(level), 1, #Levels))
		end
	end)

	local wander = Instance.new("TextChatCommand")
	wander.Name = "GiantWanderCommand"
	wander.PrimaryAlias = GiantConfig.debug.wanderCommand
	wander.Parent = TextChatService
	wander.Triggered:Connect(function(source: TextSource)
		local player = Players:GetPlayerByUserId(source.UserId)
		local state = player and giants[player.UserId]
		if state then
			state.debugWander = not state.debugWander
			notify(player, if state.debugWander then "Paseo de prueba activado" else "Paseo de prueba desactivado")
		end
	end)
end

-- API para otros services ------------------------------------------------

function GiantService.get(id: number): GiantState?
	return giants[id]
end

function GiantService.getAll(): { [number]: GiantState }
	return giants
end

function GiantService.getCFrame(id: number): CFrame?
	local state = giants[id]
	return if state then giantCFrame(state) else nil
end

function GiantService.hasTrait(state: GiantState, trait: string): boolean
	return hasTrait(state, trait)
end

function GiantService.traitValue(state: GiantState, field: string, default: number): number
	return traitValue(state, field, default)
end

function GiantService.bodyRadius(state: GiantState): number
	return bodyOf(state).radius * state.scale
end

-- Distancia entre los cuerpos de dos gigantes (centro a centro menos radios).
function GiantService.bodyDistance(a: GiantState, b: GiantState): number
	local delta = a.position - b.position
	local flat = Vector3.new(delta.X, 0, delta.Z).Magnitude
	return flat - GiantService.bodyRadius(a) - GiantService.bodyRadius(b)
end

-- Vuelve a leer especie, rasgos, nivel y piel de los datos guardados.
function GiantService.refresh(player: Player)
	local state = giants[player.UserId]
	if state then
		applyData(state, player)
	end
end

function GiantService.setMachinesAttribute(id: number, machines: { [string]: { id: string, level: number } })
	local state = giants[id]
	if state then
		state.root:SetAttribute("Machines", HttpService:JSONEncode(machines))
	end
end

-- Atributo libre en el GiantRoot (por ejemplo Egg, que dibujan los clientes).
function GiantService.setRootAttribute(id: number, name: string, value: any)
	local state = giants[id]
	if state then
		state.root:SetAttribute(name, value)
	end
end

-- Gigante sobre el que va un jugador (según RiderUpdate reciente).
function GiantService.getRiderGiant(userId: number): number?
	local rider = riders[userId]
	if rider and os.clock() - rider.at <= GiantConfig.platform.riderMemory then
		return rider.giantId
	end
	return nil
end

function GiantService.getRiders(): { [number]: number }
	local result: { [number]: number } = {}
	local now = os.clock()
	for userId, rider in riders do
		if now - rider.at <= GiantConfig.platform.riderMemory then
			result[userId] = rider.giantId
		end
	end
	return result
end

function GiantService.createWild(id: number, speciesName: string, traits: { string }, zoneId: string, position: Vector3)
	assert(id < 0, "Los gigantes salvajes usan ids negativos")
	local groundY = groundHeightAt(position.X, position.Z, 0) or 0
	local state = newState(id, nil, Vector3.new(position.X, groundY, position.Z), random:NextNumber(0, math.pi * 2))
	state.species = speciesName
	state.traits = table.clone(traits)
	state.level = GiantConfig.wild.level
	state.scaleBonus = traitValue(state, "scaleMultiplier", 1)
	state.scale = computeScale(state.level, state.scaleBonus)
	state.wildZone = zoneId
	register(state)
end

function GiantService.onCreated(callback: GiantCallback)
	table.insert(createdCallbacks, callback)
	for _, state in giants do
		task.spawn(callback, state)
	end
end

function GiantService.onRemoved(callback: GiantCallback)
	table.insert(removedCallbacks, callback)
end

function GiantService.setTargetProvider(provider: TargetProvider)
	targetProvider = provider
end

function GiantService.setDebugLevelHandler(handler: (player: Player, level: number) -> ())
	debugLevelHandler = handler
end

function GiantService.init()
	local existing = Workspace:FindFirstChild("Giants")
	if existing then
		existing:Destroy()
	end
	giantsFolder = Instance.new("Folder")
	giantsFolder.Name = "Giants"
	giantsFolder.Parent = Workspace

	groundParams = RaycastParams.new()
	groundParams.FilterType = Enum.RaycastFilterType.Include
	local map = Workspace:FindFirstChild("Map")
	if map then
		groundParams.FilterDescendantsInstances = { map }
	else
		warn("[GiantService] Falta Workspace.Map: los gigantes no encontrarán suelo")
	end

	DataService.onLoaded(function(player: Player)
		createPlayerGiant(player)
	end)
	DataService.registerView(function(player: Player, data)
		return { autopilot = data.autopilot, giantId = player.UserId }
	end)
end

function GiantService.start()
	Remotes.DriveInput.OnServerEvent:Connect(onDriveInput)
	Remotes.RiderUpdate.OnServerEvent:Connect(onRiderUpdate)
	Remotes.SetAutopilot.OnServerEvent:Connect(onSetAutopilot)
	Players.PlayerRemoving:Connect(onPlayerRemoving)
	RunService.Heartbeat:Connect(step)
	setupDebugCommands()
	print("[GiantService] iniciado")
end

return GiantService
