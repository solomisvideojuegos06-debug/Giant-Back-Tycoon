--!strict
--[[
	ResourceService
	Nodos de recursos, pisadas y reaparición (GDD, secciones E y L).

	- Los nodos son datos en el servidor (posición, tipo, zona, agotado hasta)
	  indexados en una rejilla espacial de celdas de 32 studs. La pisada no usa
	  física: consulta las celdas cercanas.
	- Cada nodo tiene un modelo anclado en Workspace.Nodes con los atributos
	  NodeId y Depleted; los clientes animan la rotura y lo ocultan.
	- Una pisada cada 1,2 s por gigante de jugador en marcha. Si el almacén de
	  un recurso está lleno, la pisada no recoge ese recurso (ni agota el nodo).
	- Proporciona al piloto experto el mejor nodo cercano.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage.Shared
local Economy = require(Shared.Config.Economy)
local Nodes = require(Shared.Config.Nodes)
local Remotes = require(Shared.Remotes)
local VoxelArt = require(Shared.VoxelArt)
local World = require(Shared.World)
local Zones = require(Shared.Config.Zones)
local DataService = require(script.Parent.DataService)
local EconomyService = require(script.Parent.EconomyService)
local GiantService = require(script.Parent.GiantService)
local TelemetryService = require(script.Parent.TelemetryService)

type GiantState = GiantService.GiantState

type Node = {
	id: number,
	nodeType: string,
	resource: "wood" | "stone" | "fruit",
	amount: number, -- rendimiento ya multiplicado por la zona
	tall: boolean,
	zoneId: string,
	minLevel: number,
	position: Vector3,
	depleted: boolean,
	respawnAt: number,
	model: Model,
}

local ResourceService = {}

local CELL_SIZE = 32
local RESOURCE_INDEX = { wood = 1, stone = 2, fruit = 3 }
local MAX_COLLECTED_PER_STOMP = 20

local nodes: { Node } = {}
local grid: { [number]: { Node } } = {}
local depletedQueue: { Node } = {}
local lastStomp: { [number]: number } = {}
local nodesFolder: Folder
local fruitRainUntil = 0

local function cellKey(cx: number, cz: number): number
	return (cx + 1000) * 10000 + (cz + 1000)
end

local function cellOf(x: number, z: number): (number, number)
	return math.floor(x / CELL_SIZE), math.floor(z / CELL_SIZE)
end

local function forNodesNear(position: Vector3, radius: number, callback: (Node) -> ())
	local minX, minZ = cellOf(position.X - radius, position.Z - radius)
	local maxX, maxZ = cellOf(position.X + radius, position.Z + radius)
	for cx = minX, maxX do
		for cz = minZ, maxZ do
			local cell = grid[cellKey(cx, cz)]
			if cell then
				for _, node in cell do
					callback(node)
				end
			end
		end
	end
end

local function flatDistance(a: Vector3, b: Vector3): number
	return Vector3.new(a.X - b.X, 0, a.Z - b.Z).Magnitude
end

-- Modelos de bloques de los nodos (arte en VoxelArt) ----------------------------

local function buildNodeModel(nodeType: string, base: CFrame, random: Random): Model
	local model = Instance.new("Model")
	model.Name = nodeType
	local s = random:NextNumber(0.95, 1.3)
	for _, item in VoxelArt.node(nodeType, random:NextNumber()) do
		local part = Instance.new("Part")
		part.Anchored = true
		part.CanCollide = false
		part.CanQuery = false
		part.CanTouch = false
		part.Size = Vector3.new(item.sx, item.sy, item.sz) * s
		local cframe = base * CFrame.new(item.x * s, item.y * s, item.z * s)
		if item.rot then
			cframe *= CFrame.fromEulerAnglesYXZ(math.rad(item.rot[1]), math.rad(item.rot[2]), math.rad(item.rot[3]))
		end
		part.CFrame = cframe
		part.Color = Color3.fromRGB(item.color[1], item.color[2], item.color[3])
		part.Material = if nodeType == "Crystal" and item.y > 1 then Enum.Material.Neon else Enum.Material.Plastic
		part.TopSurface = Enum.SurfaceType.Studs
		part.FrontSurface = Enum.SurfaceType.Studs
		part.BackSurface = Enum.SurfaceType.Studs
		part.LeftSurface = Enum.SurfaceType.Studs
		part.RightSurface = Enum.SurfaceType.Studs
		part.BottomSurface = Enum.SurfaceType.Inlet
		part.Parent = model
	end
	model.WorldPivot = base
	return model
end

-- Generación -----------------------------------------------------------------

local groundParams = RaycastParams.new()
groundParams.FilterType = Enum.RaycastFilterType.Include

local function groundAt(x: number, z: number): number?
	local result = Workspace:Raycast(Vector3.new(x, 200, z), Vector3.new(0, -400, 0), groundParams)
	return if result then result.Position.Y else nil
end

local function tooClose(x: number, z: number): boolean
	local found = false
	forNodesNear(Vector3.new(x, 0, z), Nodes.minSpacing, function(node)
		if not found and flatDistance(node.position, Vector3.new(x, 0, z)) < Nodes.minSpacing then
			found = true
		end
	end)
	return found
end

local function addNode(nodeType: string, zone: Zones.ZoneDef, x: number, z: number, random: Random)
	local def = Nodes.types[nodeType]
	local y = groundAt(x, z)
	if not def or not y or y > 2 then
		return
	end
	local id = #nodes + 1
	local base = CFrame.new(x, y, z) * CFrame.Angles(0, random:NextNumber(0, math.pi * 2), 0)
	local model = buildNodeModel(nodeType, base, random)
	model:SetAttribute("NodeId", id)
	model:SetAttribute("Resource", def.resource)
	model:SetAttribute("Depleted", false)
	model.Parent = nodesFolder

	local node: Node = {
		id = id,
		nodeType = nodeType,
		resource = def.resource,
		amount = def.yield * zone.multiplier,
		tall = def.tall == true,
		zoneId = zone.id,
		minLevel = zone.minLevel,
		position = Vector3.new(x, y, z),
		depleted = false,
		respawnAt = 0,
		model = model,
	}
	table.insert(nodes, node)
	local key = cellKey(cellOf(x, z))
	local cell = grid[key]
	if not cell then
		cell = {}
		grid[key] = cell
	end
	table.insert(cell, node)
end

local function generate()
	local random = Random.new(Nodes.seed)
	local margin = 25
	for _, zone in Zones.list do
		local rect = zone.rect
		for _, spawn in zone.nodes do
			local clustered = if zone.id == "Meadow" then math.floor(spawn.count * Zones.clusterShare) else 0
			for i = 1, spawn.count do
				for _ = 1, 12 do
					local x, z
					if i <= clustered then
						local angle = random:NextNumber(0, math.pi * 2)
						local distance = math.sqrt(random:NextNumber()) * Zones.clusterRadius
						x = Zones.clusterCenter.X + math.cos(angle) * distance
						z = Zones.clusterCenter.Z + math.sin(angle) * distance
					else
						x = random:NextNumber(rect.minX + margin, rect.maxX - margin)
						z = random:NextNumber(rect.minZ + margin, rect.maxZ - margin)
					end
					if World.inRect(rect, x, z) and not tooClose(x, z) and not World.inRanch(x, z) then
						addNode(spawn.nodeType, zone, x, z, random)
						break
					end
				end
			end
		end
	end
end

-- Pisadas --------------------------------------------------------------------

local function canReachTall(state: GiantState): boolean
	return GiantService.hasTrait(state, "LongNeck") or state.level >= Nodes.tallTreeLevel
end

local function deplete(node: Node, now: number)
	node.depleted = true
	node.respawnAt = now + Nodes.respawnTime
	node.model:SetAttribute("Depleted", true)
	table.insert(depletedQueue, node)
end

local function stomp(state: GiantState, player: Player, now: number)
	local radius = Economy.stomp.radius * state.scale * GiantService.traitValue(state, "stompRadiusMultiplier", 1)
	local fruitReach = radius
	for _, trait in state.traits do
		if trait == "Trunk" then
			fruitReach += 10 * state.scale
		end
	end
	local fruitMultiplier = if now < fruitRainUntil then Economy.fruitRain.multiplier else 1
	local tall = canReachTall(state)

	local collected: { number } = {}
	local full: { [string]: boolean } = {}
	forNodesNear(state.position, math.max(radius, fruitReach), function(node)
		if node.depleted or #collected >= MAX_COLLECTED_PER_STOMP * 3 or full[node.resource] then
			return
		end
		local limit = if node.resource == "fruit" then fruitReach else radius
		if flatDistance(node.position, state.position) > limit or (node.tall and not tall) then
			return
		end
		local amount = node.amount * (if node.resource == "fruit" then fruitMultiplier else 1)
		local added = EconomyService.addResource(player, node.resource, amount)
		if added <= 0 then
			full[node.resource] = true
			return
		end
		deplete(node, now)
		table.insert(collected, node.id)
		table.insert(collected, RESOURCE_INDEX[node.resource])
		table.insert(collected, added)
	end)

	if #collected > 0 then
		TelemetryService.funnel(player, "FirstStomp")
	end

	-- Efectos para los jugadores cercanos (incluido el dueño).
	for _, other in Players:GetPlayers() do
		local character = other.Character
		local rootPart = character and character:FindFirstChild("HumanoidRootPart")
		if rootPart and rootPart:IsA("BasePart") then
			if flatDistance(rootPart.Position, state.position) <= Economy.stomp.effectRange then
				Remotes.Stomp:FireClient(other, state.id, state.position.X, state.position.Z, radius, collected)
			end
		end
	end

	-- Aviso de almacén lleno (como mucho cada pocos segundos lo controla el cliente).
	for resource in full do
		DataService.setView(player, "storageFull", resource)
	end
end

local function step()
	local now = os.clock()
	for id, state in GiantService.getAll() do
		local player = state.player
		if player and state.speed >= Economy.stomp.minSpeed then
			if now - (lastStomp[id] or 0) >= Economy.stomp.interval then
				lastStomp[id] = now
				stomp(state, player, now)
			end
		end
	end

	-- Reaparición.
	local i = 1
	while i <= #depletedQueue do
		local node = depletedQueue[i]
		if now >= node.respawnAt then
			node.depleted = false
			node.model:SetAttribute("Depleted", false)
			depletedQueue[i] = depletedQueue[#depletedQueue]
			depletedQueue[#depletedQueue] = nil
		else
			i += 1
		end
	end
end

-- Piloto experto: el nodo más valioso cerca, al que pueda llegar y quepa.
local function bestTarget(state: GiantState): Vector3?
	local player = state.player
	if not player then
		return nil
	end
	local tall = canReachTall(state)
	local space = {
		wood = EconomyService.space(player, "wood"),
		stone = EconomyService.space(player, "stone"),
		fruit = EconomyService.space(player, "fruit"),
	}
	local best: Node? = nil
	local bestScore = 0
	forNodesNear(state.position, Economy.autopilot.expertSearchRadius, function(node)
		if node.depleted or node.minLevel > state.level or (node.tall and not tall) then
			return
		end
		if space[node.resource] <= 0 then
			return
		end
		local score = node.amount / (flatDistance(node.position, state.position) + 20)
		if score > bestScore then
			bestScore = score
			best = node
		end
	end)
	return if best then best.position else nil
end

function ResourceService.startFruitRain(duration: number, byName: string)
	local now = os.clock()
	fruitRainUntil = math.max(fruitRainUntil, now) + duration
	Remotes.FruitRain:FireAllClients(byName, Workspace:GetServerTimeNow() + (fruitRainUntil - now))
end

function ResourceService.init()
	local old = Workspace:FindFirstChild("Nodes")
	if old then
		old:Destroy()
	end
	nodesFolder = Instance.new("Folder")
	nodesFolder.Name = "Nodes"
	nodesFolder.Parent = Workspace

	local map = Workspace:FindFirstChild("Map")
	if map then
		groundParams.FilterDescendantsInstances = { map }
	end
	generate()
	GiantService.setTargetProvider(bestTarget)
end

function ResourceService.start()
	RunService.Heartbeat:Connect(step)
	GiantService.onRemoved(function(state)
		lastStomp[state.id] = nil
	end)
	print(`[ResourceService] iniciado ({#nodes} nodos)`)
end

return ResourceService
