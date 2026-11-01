--!strict
--[[
	GiantService
	Estado lógico y movimiento autoritativo de cada gigante (GDD, sección L,
	«Arquitectura del gigante»).

	- Un gigante por jugador al entrar, en un hueco libre del círculo de aparición.
	- Se mueve en Heartbeat según DriveInput (validado) con GiantMath.steer.
	- La altura sale de un raycast hacia abajo contra Workspace.Map; los
	  desniveles demasiado altos bloquean el paso.
	- Publica la posición en una pieza invisible y anclada (GiantRoot) en
	  Workspace.Giants, con atributos OwnerUserId, Species y Level, y envía
	  instantáneas con la hora del servidor (GiantSnapshot) para que los
	  clientes interpolen sin tirones.
	- Reenvía RiderUpdate (posición de cada jugador relativa a un gigante).
	- Solo en Studio: comandos de chat «/nivel N» (probar las escalas) y
	  «/pasear» (el gigante camina solo, para probar a caminar por el lomo).
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TextChatService = game:GetService("TextChatService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage.Shared
local GiantConfig = require(Shared.Config.Giant)
local GiantMath = require(Shared.GiantMath)
local Levels = require(Shared.Config.Levels)
local Remotes = require(Shared.Remotes)
local Species = require(Shared.Config.Species)
local RateLimiter = require(script.Parent.Parent.RateLimiter)

local MOVEMENT = GiantConfig.movement
local NETWORK = GiantConfig.network
local DEFAULT_SPECIES = "Turtle"

type GiantState = {
	player: Player,
	userId: number,
	root: Part,
	species: string,
	level: number,
	scale: number,
	position: Vector3, -- punto de apoyo en el suelo
	yaw: number,
	speed: number, -- velocidad hacia delante (studs/s)
	input: Vector3, -- dirección deseada en el mundo (x, 0, z), magnitud 0..1
	inputAt: number,
	spawnSlot: number,
	debugWander: boolean, -- solo Studio: camina solo en círculos (/pasear)
}

local GiantService = {}

local giants: { [number]: GiantState } = {}
local usedSpawnSlots: { [number]: boolean } = {}
local giantsFolder: Folder
local groundParams: RaycastParams
local driveLimiter = RateLimiter.new(NETWORK.driveInputRate, NETWORK.driveInputBurst)
local riderLimiter = RateLimiter.new(NETWORK.riderRate, NETWORK.riderBurst)
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

local function giantCFrame(state: GiantState): CFrame
	return CFrame.new(state.position) * CFrame.Angles(0, state.yaw, 0)
end

local function maxSpeed(state: GiantState): number
	return MOVEMENT.baseSpeed * state.scale
end

local function bodyOf(state: GiantState)
	return Species[state.species].body
end

-- Altura del suelo en (x, z) buscando desde encima de `fromY`. nil si no hay suelo.
local function groundHeightAt(x: number, z: number, fromY: number): number?
	local origin = Vector3.new(x, fromY + MOVEMENT.groundProbeHeight, z)
	local direction = Vector3.new(0, -(MOVEMENT.groundProbeHeight + MOVEMENT.groundProbeDepth), 0)
	local result = Workspace:Raycast(origin, direction, groundParams)
	return if result then result.Position.Y else nil
end

-- Intenta desplazar el gigante; devuelve false si el terreno lo impide.
local function tryMove(state: GiantState, step: Vector3): boolean
	local distance = step.Magnitude
	if distance < 1e-6 then
		return true
	end

	local current = state.position
	local target = current + step
	local maxStep = MOVEMENT.maxStepUp * state.scale

	local groundY = groundHeightAt(target.X, target.Z, current.Y)
	if not groundY or groundY - current.Y > maxStep + MOVEMENT.maxSlope * distance then
		return false
	end

	-- Mirar el terreno por delante evita meter la cabeza en paredes altas.
	local reach = MOVEMENT.frontProbeDistance * state.scale
	local probe = target + step.Unit * reach
	local probeY = groundHeightAt(probe.X, probe.Z, current.Y)
	if not probeY or probeY - current.Y > maxStep + MOVEMENT.maxSlope * reach then
		return false
	end

	state.position = Vector3.new(target.X, groundY, target.Z)
	return true
end

local function applyLevel(state: GiantState, level: number)
	local clamped = math.clamp(math.floor(level), 1, #Levels)
	state.level = clamped
	state.scale = Levels[clamped].scale
	if state.root:GetAttribute("Level") ~= clamped then
		state.root:SetAttribute("Level", clamped)
	end
end

local function seatWorldPosition(state: GiantState): Vector3
	return giantCFrame(state):PointToWorldSpace(bodyOf(state).seat * state.scale)
end

-- El conductor debe estar cerca del asiento (con margen por el retraso de red).
local function isNearSeat(state: GiantState): boolean
	local character = state.player.Character
	local rootPart = character and character:FindFirstChild("HumanoidRootPart")
	if not rootPart or not rootPart:IsA("BasePart") then
		return false
	end
	local tolerance = GiantConfig.driver.maxSeatDistance * state.scale
		+ maxSpeed(state) * GiantConfig.driver.lagAllowance
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
	-- Más jugadores que huecos (no debería pasar con servidores de 6).
	return 1
end

local function spawnPose(slot: number): (Vector3, number)
	local angle = (slot - 1) / GiantConfig.spawn.slots * 2 * math.pi
	local outward = Vector3.new(math.cos(angle), 0, math.sin(angle))
	local spot = GiantConfig.spawn.center + outward * GiantConfig.spawn.radius
	local groundY = groundHeightAt(spot.X, spot.Z, spot.Y) or spot.Y
	return Vector3.new(spot.X, groundY, spot.Z), GiantMath.yawFromDirection(outward.X, outward.Z)
end

local function createGiant(player: Player)
	local slot = takeSpawnSlot()
	local position, yaw = spawnPose(slot)

	local root = Instance.new("Part")
	root.Name = tostring(player.UserId)
	root.Size = Vector3.one
	root.Transparency = 1
	root.Anchored = true
	root.CanCollide = false
	root.CanQuery = false
	root.CanTouch = false
	root.CFrame = CFrame.new(position) * CFrame.Angles(0, yaw, 0)
	root:SetAttribute("OwnerUserId", player.UserId)
	root:SetAttribute("Species", DEFAULT_SPECIES)
	root:SetAttribute("Level", 1)

	local state: GiantState = {
		player = player,
		userId = player.UserId,
		root = root,
		species = DEFAULT_SPECIES,
		level = 1,
		scale = Levels[1].scale,
		position = position,
		yaw = yaw,
		speed = 0,
		input = Vector3.zero,
		inputAt = 0,
		spawnSlot = slot,
		debugWander = false,
	}
	giants[player.UserId] = state

	-- Permite cambiar el nivel desde la ventana Properties en Studio.
	root:GetAttributeChangedSignal("Level"):Connect(function()
		local level = root:GetAttribute("Level")
		if type(level) == "number" and level ~= state.level then
			applyLevel(state, level)
		end
	end)

	root.Parent = giantsFolder

	local function onCharacter(character: Model)
		-- Un frame de margen para que el personaje termine de montarse.
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

local function removeGiant(player: Player)
	local state = giants[player.UserId]
	if not state then
		return
	end
	giants[player.UserId] = nil
	usedSpawnSlots[state.spawnSlot] = nil
	state.root:Destroy()
	driveLimiter.forget(player.UserId)
	riderLimiter.forget(player.UserId)
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
	if input.Magnitude > 1e-3 and not isNearSeat(state) then
		return
	end
	state.input = input
	state.inputAt = os.clock()
end

local function onRiderUpdate(player: Player, giantUserId: unknown, offset: unknown, yaw: unknown)
	if not riderLimiter.allow(player.UserId) then
		return
	end
	if giantUserId == 0 then
		Remotes.RiderUpdate:FireAllClients(player.UserId, 0, Vector3.zero, 0)
		return
	end
	if type(giantUserId) ~= "number" or not giants[giantUserId] then
		return
	end
	if not isFiniteVector(offset) or not isFiniteNumber(yaw) then
		return
	end
	local localOffset = offset :: Vector3
	if localOffset.Magnitude > GiantConfig.platform.maxRiderOffset then
		return
	end
	Remotes.RiderUpdate:FireAllClients(player.UserId, giantUserId, localOffset, yaw)
end

local function step(dt: number)
	local now = os.clock()

	for _, state in giants do
		local input = if now - state.inputAt <= MOVEMENT.inputTimeout then state.input else Vector3.zero
		if state.debugWander then
			local angle = now * GiantConfig.debug.wanderTurnRate
			input = Vector3.new(math.cos(angle), 0, math.sin(angle))
		end
		state.yaw, state.speed = GiantMath.steer(state.yaw, state.speed, input.X, input.Z, dt, {
			maxSpeed = maxSpeed(state),
			acceleration = MOVEMENT.acceleration * state.scale,
			deceleration = MOVEMENT.deceleration * state.scale,
			turnRate = MOVEMENT.turnRate,
			fullTurnAngle = MOVEMENT.fullTurnAngle,
		})

		if state.speed > 0 then
			local forwardX, forwardZ = GiantMath.forward(state.yaw)
			local move = Vector3.new(forwardX, 0, forwardZ) * state.speed * dt
			-- Si choca, intenta deslizarse a lo largo del obstáculo.
			local moved = tryMove(state, move)
				or tryMove(state, Vector3.new(move.X, 0, 0))
				or tryMove(state, Vector3.new(0, 0, move.Z))
			if not moved then
				state.speed = 0
			end
		end

		state.root.CFrame = giantCFrame(state)
	end

	snapshotAccumulator += dt
	local interval = 1 / NETWORK.snapshotRate
	if snapshotAccumulator >= interval then
		snapshotAccumulator %= interval
		local data: { number } = {}
		for userId, state in giants do
			table.insert(data, userId)
			table.insert(data, state.position.X)
			table.insert(data, state.position.Y)
			table.insert(data, state.position.Z)
			table.insert(data, state.yaw)
		end
		if #data > 0 then
			Remotes.GiantSnapshot:FireAllClients(Workspace:GetServerTimeNow(), data)
		end
	end
end

local function setupDebugCommand()
	if not RunService:IsStudio() then
		return
	end
	local command = Instance.new("TextChatCommand")
	command.Name = "GiantLevelCommand"
	command.PrimaryAlias = GiantConfig.debug.levelCommand
	command.Parent = TextChatService
	command.Triggered:Connect(function(source: TextSource, message: string)
		local player = Players:GetPlayerByUserId(source.UserId)
		local state = player and giants[player.UserId]
		local level = tonumber(string.match(message, "%d+"))
		if state and level then
			applyLevel(state, level)
			print(`[GiantService] {state.player.Name}: nivel {state.level} (escala {state.scale})`)
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
			print(
				`[GiantService] {state.player.Name}: paseo de prueba {if state.debugWander
					then "activado"
					else "desactivado"}`
			)
		end
	end)
end

-- Para otros services (hitos siguientes).
function GiantService.getGiantCFrame(userId: number): CFrame?
	local state = giants[userId]
	return if state then giantCFrame(state) else nil
end

function GiantService.setLevel(userId: number, level: number)
	local state = giants[userId]
	if state then
		applyLevel(state, level)
	end
end

function GiantService.init()
	local existing = Workspace:FindFirstChild("Giants")
	if existing and existing:IsA("Folder") then
		giantsFolder = existing
	else
		giantsFolder = Instance.new("Folder")
		giantsFolder.Name = "Giants"
		giantsFolder.Parent = Workspace
	end

	groundParams = RaycastParams.new()
	groundParams.FilterType = Enum.RaycastFilterType.Include
	local map = Workspace:FindFirstChild("Map")
	if map then
		groundParams.FilterDescendantsInstances = { map }
	else
		warn("[GiantService] Falta Workspace.Map: los gigantes no encontrarán suelo")
	end
end

function GiantService.start()
	Remotes.DriveInput.OnServerEvent:Connect(onDriveInput)
	Remotes.RiderUpdate.OnServerEvent:Connect(onRiderUpdate)

	Players.PlayerAdded:Connect(createGiant)
	Players.PlayerRemoving:Connect(removeGiant)
	for _, player in Players:GetPlayers() do
		createGiant(player)
	end

	RunService.Heartbeat:Connect(step)
	setupDebugCommand()

	print("[GiantService] iniciado")
end

return GiantService
