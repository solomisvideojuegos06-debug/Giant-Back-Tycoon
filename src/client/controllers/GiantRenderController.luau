--!strict
--[[
	GiantRenderController
	Dibuja los gigantes en este cliente (GDD, sección L, «Arquitectura del gigante»).

	- Por cada GiantRoot de Workspace.Giants crea el modelo de bloques de su
	  especie en Workspace.GiantVisuals (solo existe en este cliente).
	- Lo coloca interpolando las instantáneas GiantSnapshot, que llevan la hora
	  del servidor: todos los clientes dibujan el gigante con el mismo ritmo,
	  sin tirones aunque los paquetes lleguen a destiempo.
	- Escala el modelo según el atributo Level y anima patas y rebote según la
	  velocidad.
	- Cada frame (PreSimulation, antes de la física) avisa a los oyentes de
	  onMoved con la posición anterior y la nueva: PlatformController lo usa
	  para llevar al jugador encima.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage.Shared
local GiantConfig = require(Shared.Config.Giant)
local GiantMath = require(Shared.GiantMath)
local GiantModel = require(Shared.GiantModel)
local Levels = require(Shared.Config.Levels)
local Remotes = require(Shared.Remotes)
local Species = require(Shared.Config.Species)

local RENDER = GiantConfig.render
local SNAPSHOT_INTERVAL = 1 / GiantConfig.network.snapshotRate

export type Giant = {
	userId: number,
	root: BasePart, -- GiantRoot replicado desde el servidor
	built: GiantModel.Built,
	body: Species.BodyDef,
	snapshots: { GiantMath.Snapshot },
	cframe: CFrame, -- punto de apoyo interpolado (sin rebote)
	bodyCFrame: CFrame, -- con rebote: el que mueve la cubierta y el asiento
	scale: number,
	targetScale: number,
	scaleRate: number, -- unidades de escala por segundo durante un cambio
	speed: number, -- velocidad visual en studs/s
	stepPhase: number, -- 0..1 dentro del ciclo de pasos
	walkAmount: number, -- 0..1: cuánto está caminando
}

export type MoveListener = (giant: Giant, previousBody: CFrame, previousScale: number) -> ()
export type GiantListener = (giant: Giant) -> ()

local GiantRenderController = {}

local giants: { [number]: Giant } = {}
local moveListeners: { MoveListener } = {}
local addedListeners: { GiantListener } = {}
local removedListeners: { GiantListener } = {}
local visualsFolder: Folder
local latency = 0.1

local function scaleForLevel(level: unknown): number
	local index = if type(level) == "number" then math.clamp(math.floor(level), 1, #Levels) else 1
	return Levels[index].scale
end

local function renderDelay(): number
	return math.clamp(latency + SNAPSHOT_INTERVAL * RENDER.delayIntervals, RENDER.minDelay, RENDER.maxDelay)
end

-- La latencia sube rápido (para no quedarse sin instantáneas) y baja despacio.
local function observeLatency(sample: number)
	local value = math.max(sample, 0)
	local rate = if value > latency then 0.25 else 0.02
	latency += (value - latency) * rate
end

local function addGiant(instance: Instance)
	if not instance:IsA("BasePart") then
		return
	end
	local userId = instance:GetAttribute("OwnerUserId")
	if type(userId) ~= "number" or giants[userId] then
		return
	end
	local speciesName = instance:GetAttribute("Species")
	if type(speciesName) ~= "string" or not Species[speciesName] then
		speciesName = "Turtle"
	end
	local species = Species[speciesName :: string]

	local built = GiantModel.build(speciesName :: string, userId)
	local scale = scaleForLevel(instance:GetAttribute("Level"))
	built.model:ScaleTo(scale)
	built.model:PivotTo(instance.CFrame)
	built.model.Parent = visualsFolder

	local giant: Giant = {
		userId = userId,
		root = instance,
		built = built,
		body = species.body,
		snapshots = {},
		cframe = instance.CFrame,
		bodyCFrame = instance.CFrame,
		scale = scale,
		targetScale = scale,
		scaleRate = 0,
		speed = 0,
		stepPhase = 0,
		walkAmount = 0,
	}
	giants[userId] = giant

	instance:GetAttributeChangedSignal("Level"):Connect(function()
		local target = scaleForLevel(instance:GetAttribute("Level"))
		giant.targetScale = target
		giant.scaleRate = math.abs(target - giant.scale) / RENDER.scaleChangeDuration
	end)

	for _, listener in addedListeners do
		task.spawn(listener, giant)
	end
end

local function removeGiant(instance: Instance)
	local userId = instance:GetAttribute("OwnerUserId")
	if type(userId) ~= "number" then
		return
	end
	local giant = giants[userId]
	if not giant or giant.root ~= instance then
		return
	end
	giants[userId] = nil
	for _, listener in removedListeners do
		task.spawn(listener, giant)
	end
	giant.built.model:Destroy()
end

local function onSnapshot(serverTime: number, data: { number })
	if type(serverTime) ~= "number" or type(data) ~= "table" then
		return
	end
	observeLatency(Workspace:GetServerTimeNow() - serverTime)

	for i = 1, #data - 4, 5 do
		local giant = giants[data[i]]
		if giant then
			local snapshots = giant.snapshots
			local last = snapshots[#snapshots]
			-- Los paquetes no fiables pueden llegar desordenados: se descartan los viejos.
			if not last or serverTime > last.t then
				table.insert(snapshots, {
					t = serverTime,
					x = data[i + 1],
					y = data[i + 2],
					z = data[i + 3],
					yaw = data[i + 4],
				})
				if #snapshots > RENDER.bufferSize then
					table.remove(snapshots, 1)
				end
			end
		end
	end
end

local function updateGiant(giant: Giant, renderTime: number, dt: number)
	local previousBody = giant.bodyCFrame
	local previousScale = giant.scale
	local model = giant.built.model

	local sample = GiantMath.sample(giant.snapshots, renderTime, RENDER.maxExtrapolation)
	local cframe = if sample
		then CFrame.new(sample.x, sample.y, sample.z) * CFrame.Angles(0, sample.yaw, 0)
		else giant.root.CFrame

	if giant.scale ~= giant.targetScale then
		giant.scale = GiantMath.moveToward(giant.scale, giant.targetScale, giant.scaleRate * dt)
		model:ScaleTo(giant.scale)
	end
	local scale = giant.scale

	-- Paso y rebote según lo que ha avanzado en este frame.
	local moved = cframe.Position - giant.cframe.Position
	local distance = Vector3.new(moved.X, 0, moved.Z).Magnitude
	giant.speed = if dt > 0 then distance / dt else 0
	giant.stepPhase = (giant.stepPhase + distance / (RENDER.strideLength * scale)) % 1
	local walking = if giant.speed > 0.5 then 1 else 0
	giant.walkAmount = GiantMath.moveToward(giant.walkAmount, walking, dt * 3)

	local bob = RENDER.bodyBob * scale * giant.walkAmount * math.abs(math.sin(giant.stepPhase * 2 * math.pi))
	local bodyCFrame = cframe * CFrame.new(0, bob, 0)
	model:PivotTo(bodyCFrame)

	for _, leg in giant.built.legs do
		local lift = GiantMath.legLift(giant.stepPhase, leg.def.phase) * RENDER.legLift * scale * giant.walkAmount
		leg.part.CFrame = cframe * CFrame.new(leg.def.position * scale + Vector3.new(0, lift, 0))
	end

	giant.cframe = cframe
	giant.bodyCFrame = bodyCFrame

	for _, listener in moveListeners do
		listener(giant, previousBody, previousScale)
	end
end

local function update(dt: number)
	local renderTime = Workspace:GetServerTimeNow() - renderDelay()
	for _, giant in giants do
		updateGiant(giant, renderTime, dt)
	end
end

function GiantRenderController.getGiant(userId: number): Giant?
	return giants[userId]
end

function GiantRenderController.getVisualsFolder(): Folder
	return visualsFolder
end

-- Posición del asiento de la cabeza en el mundo (superficie del asiento).
function GiantRenderController.getSeatCFrame(giant: Giant): CFrame
	return giant.bodyCFrame * CFrame.new(giant.body.seat * giant.scale)
end

-- Se llama cada frame tras mover cada gigante, antes de la física.
function GiantRenderController.onMoved(listener: MoveListener)
	table.insert(moveListeners, listener)
end

function GiantRenderController.onAdded(listener: GiantListener)
	table.insert(addedListeners, listener)
	for _, giant in giants do
		task.spawn(listener, giant)
	end
end

function GiantRenderController.onRemoved(listener: GiantListener)
	table.insert(removedListeners, listener)
end

function GiantRenderController.init()
	visualsFolder = Instance.new("Folder")
	visualsFolder.Name = "GiantVisuals"
	visualsFolder.Parent = Workspace
end

function GiantRenderController.start()
	Remotes.GiantSnapshot.OnClientEvent:Connect(onSnapshot)

	local giantsFolder = Workspace:WaitForChild("Giants")
	giantsFolder.ChildAdded:Connect(addGiant)
	giantsFolder.ChildRemoved:Connect(removeGiant)
	for _, child in giantsFolder:GetChildren() do
		addGiant(child)
	end

	RunService.PreSimulation:Connect(update)

	print("[GiantRenderController] iniciado")
end

return GiantRenderController
