--!strict
--[[
	GiantRenderController
	Dibuja los gigantes en este cliente (GDD, sección L, «Arquitectura del gigante»).

	- Por cada GiantRoot de Workspace.Giants crea el modelo de bloques de su
	  especie (con su piel y el Brillo) en Workspace.GiantVisuals.
	- Lo coloca interpolando las instantáneas GiantSnapshot (hora del servidor).
	- Escala según Level y ScaleBonus; anima patas, rebote y máquinas.
	- Máquinas del lomo según el atributo Machines; huevo según Egg.
	- Etiqueta sobre la cabeza (nombre y nivel; rasgos en los salvajes) y la
	  barra de crecimiento en el propio gigante.
	- A más de 400 studs se dibuja sin máquinas (rendimiento en móvil).
	- Cada frame (PreSimulation) avisa a onMoved: PlatformController lleva al
	  jugador encima.
]]

local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage.Shared
local GiantConfig = require(Shared.Config.Giant)
local GiantMath = require(Shared.GiantMath)
local GiantModel = require(Shared.GiantModel)
local Levels = require(Shared.Config.Levels)
local MachineModel = require(Shared.MachineModel)
local Remotes = require(Shared.Remotes)
local Species = require(Shared.Config.Species)
local Traits = require(Shared.Config.Traits)
local ClientState = require(script.Parent.Parent.ClientState)
local Theme = require(script.Parent.Parent.ui.Theme)

local RENDER = GiantConfig.render
local SNAPSHOT_INTERVAL = 1 / GiantConfig.network.snapshotRate

type MachineVisual = {
	model: Model,
	slot: number,
	animated: { MachineModel.Animated },
}

export type Giant = {
	userId: number,
	root: BasePart, -- GiantRoot replicado desde el servidor
	built: GiantModel.Built,
	body: Species.BodyDef,
	speciesName: string,
	snapshots: { GiantMath.Snapshot },
	cframe: CFrame, -- punto de apoyo interpolado (sin rebote)
	bodyCFrame: CFrame, -- con rebote: el que mueve la cubierta y el asiento
	scale: number,
	targetScale: number,
	scaleRate: number,
	speed: number, -- velocidad visual en studs/s
	stepPhase: number,
	walkAmount: number,
	machines: { MachineVisual },
	machinesVisible: boolean,
	egg: BasePart?,
	label: BillboardGui?,
	growthFill: Frame?,
	labelLines: { top: TextLabel, middle: TextLabel, bottom: TextLabel }?,
	isWild: boolean,
}

export type MoveListener = (giant: Giant, previousBody: CFrame, previousScale: number) -> ()
export type GiantListener = (giant: Giant) -> ()

local GiantRenderController = {}

local localPlayer = Players.LocalPlayer
local giants: { [number]: Giant } = {}
local moveListeners: { MoveListener } = {}
local addedListeners: { GiantListener } = {}
local removedListeners: { GiantListener } = {}
local visualsFolder: Folder
local latency = 0.1

local function scaleFor(root: BasePart): number
	local level = root:GetAttribute("Level")
	local index = if type(level) == "number" then math.clamp(math.floor(level), 1, #Levels) else 1
	local bonus = root:GetAttribute("ScaleBonus")
	return Levels[index].scale * (if type(bonus) == "number" then bonus else 1)
end

local function stringAttribute(root: Instance, name: string): string
	local value = root:GetAttribute(name)
	return if type(value) == "string" then value else ""
end

local function traitsOf(root: Instance): { string }
	local text = stringAttribute(root, "Traits")
	return if text == "" then {} else string.split(text, ",")
end

local function renderDelay(): number
	return math.clamp(latency + SNAPSHOT_INTERVAL * RENDER.delayIntervals, RENDER.minDelay, RENDER.maxDelay)
end

local function observeLatency(sample: number)
	local value = math.max(sample, 0)
	local rate = if value > latency then 0.25 else 0.02
	latency += (value - latency) * rate
end

local function slotCFrame(giant: Giant, slot: number): CFrame
	local position = giant.body.slots[slot] or Vector3.zero
	return giant.bodyCFrame * CFrame.new(position * giant.scale)
end

-- Máquinas ------------------------------------------------------------------

local function clearMachines(giant: Giant)
	for _, machine in giant.machines do
		machine.model:Destroy()
	end
	table.clear(giant.machines)
end

local function buildMachines(giant: Giant)
	clearMachines(giant)
	if not giant.machinesVisible then
		return
	end
	local ok, decoded = pcall(function()
		return HttpService:JSONDecode(stringAttribute(giant.root, "Machines"))
	end)
	if not ok or type(decoded) ~= "table" then
		return
	end
	for key, machine in decoded do
		local slot = tonumber(key)
		if slot and type(machine) == "table" and type(machine.id) == "string" and giant.body.slots[slot] then
			local built = MachineModel.build(machine.id)
			built.model:ScaleTo(giant.scale)
			built.model:PivotTo(slotCFrame(giant, slot))
			local joint = Instance.new("Weld")
			joint.Part0 = giant.built.root
			joint.Part1 = built.root
			joint.C0 = giant.built.root.CFrame:ToObjectSpace(built.root.CFrame)
			joint.Parent = built.root
			built.model.Parent = giant.built.model
			table.insert(giant.machines, { model = built.model, slot = slot, animated = built.animated })
		end
	end
end

local function animateMachines(giant: Giant, now: number)
	for _, machine in giant.machines do
		for _, item in machine.animated do
			item.motor.C0 = MachineModel.animate(item, now, giant.scale)
		end
	end
end

-- Huevo en el lomo ------------------------------------------------------------

local function updateEgg(giant: Giant)
	if giant.egg then
		giant.egg:Destroy()
		giant.egg = nil
	end
	local speciesName = stringAttribute(giant.root, "Egg")
	local species = Species[speciesName]
	if not species then
		return
	end
	local egg = Instance.new("Part")
	egg.Name = "Egg"
	egg.Shape = Enum.PartType.Ball
	egg.Size = Vector3.new(4, 4, 4) * giant.scale
	egg.Color = species.eggColor
	egg.Material = Enum.Material.SmoothPlastic
	egg.Anchored = false
	egg.Massless = true
	egg.CanCollide = false
	egg.CanQuery = false
	egg.CanTouch = false
	local last = giant.body.slots[#giant.body.slots] or Vector3.zero
	egg.CFrame = giant.bodyCFrame * CFrame.new(Vector3.new(0, giant.body.deckTop + 2, last.Z + 2) * giant.scale)
	local joint = Instance.new("Weld")
	joint.Part0 = giant.built.root
	joint.Part1 = egg
	joint.C0 = giant.built.root.CFrame:ToObjectSpace(egg.CFrame)
	joint.Parent = egg
	egg.Parent = giant.built.model
	giant.egg = egg
end

-- Etiquetas y barra de crecimiento -----------------------------------------

local function outlinedText(parent: Instance, y: number, height: number, color: Color3): TextLabel
	local label = Instance.new("TextLabel")
	label.BackgroundTransparency = 1
	label.Size = UDim2.new(1, 0, 0, height)
	label.Position = UDim2.fromOffset(0, y)
	label.Font = Theme.font
	label.TextScaled = true
	label.TextColor3 = color
	local stroke = Instance.new("UIStroke")
	stroke.Color = Theme.stroke
	stroke.Thickness = 2.5
	stroke.LineJoinMode = Enum.LineJoinMode.Round
	stroke.Parent = label
	label.Parent = parent
	return label
end

local function updateLabel(giant: Giant)
	local lines = giant.labelLines
	if not lines then
		return
	end
	local level = giant.root:GetAttribute("Level")
	local name = stringAttribute(giant.root, "DisplayName")
	local species = Species[stringAttribute(giant.root, "Species")]
	local speciesName = if species then species.displayName else "Gigante"
	if giant.isWild then
		local names = {}
		for _, trait in traitsOf(giant.root) do
			local def = Traits[trait]
			table.insert(names, if def then def.displayName else trait)
		end
		lines.top.Text = "Salvaje · Adulto"
		lines.middle.Text = speciesName
		lines.bottom.Text = table.concat(names, " · ")
	else
		local perSecond = giant.root:GetAttribute("PerSecond")
		lines.top.Text = name
		lines.middle.Text = `{speciesName} · Nv {level}`
		lines.bottom.Text = if type(perSecond) == "number" and perSecond > 0 then `+{perSecond}/s` else ""
	end
end

local function updateGrowthBar(giant: Giant)
	local fill = giant.growthFill
	if not fill then
		return
	end
	local need = ClientState.number("fruitToNext")
	local progress = if need > 0 then math.clamp(ClientState.number("growthFruit") / need, 0, 1) else 1
	fill.Size = UDim2.fromScale(progress, 1)
end

local function buildLabel(giant: Giant)
	if giant.label then
		giant.label:Destroy()
	end
	local isOwn = giant.userId == localPlayer.UserId
	local gui = Instance.new("BillboardGui")
	gui.Name = "GiantLabel"
	gui.Size = UDim2.fromOffset(260, if isOwn then 112 else 88)
	gui.StudsOffsetWorldSpace = Vector3.new(0, 3, 0)
	gui.MaxDistance = if isOwn then 1000 else 400
	gui.LightInfluence = 0
	gui.Parent = giant.built.headPart

	giant.labelLines = {
		top = outlinedText(gui, 0, 24, if giant.isWild then Theme.gold else Color3.fromRGB(235, 235, 235)),
		middle = outlinedText(gui, 24, 32, Theme.textLight),
		bottom = outlinedText(gui, 56, 26, if giant.isWild then Color3.fromRGB(255, 235, 150) else Theme.moneyGreen),
	}

	if isOwn then
		local bar = Instance.new("Frame")
		bar.Size = UDim2.new(1, -40, 0, 18)
		bar.Position = UDim2.new(0, 20, 0, 88)
		bar.BackgroundColor3 = Color3.fromRGB(45, 32, 22)
		bar.BorderSizePixel = 0
		local corner = Instance.new("UICorner")
		corner.CornerRadius = UDim.new(0.5, 0)
		corner.Parent = bar
		local stroke = Instance.new("UIStroke")
		stroke.Color = Theme.stroke
		stroke.Thickness = 2.5
		stroke.Parent = bar
		bar.Parent = gui

		local fill = Instance.new("Frame")
		fill.BackgroundColor3 = Color3.new(1, 1, 1)
		fill.BorderSizePixel = 0
		fill.Size = UDim2.fromScale(0, 1)
		local gradient = Instance.new("UIGradient")
		gradient.Color = ColorSequence.new(Color3.fromRGB(150, 255, 120), Color3.fromRGB(50, 190, 70))
		gradient.Rotation = 90
		gradient.Parent = fill
		local fillCorner = Instance.new("UICorner")
		fillCorner.CornerRadius = UDim.new(0.5, 0)
		fillCorner.Parent = fill
		fill.Parent = bar
		giant.growthFill = fill
		updateGrowthBar(giant)
	end

	giant.label = gui
	updateLabel(giant)
end

-- Construcción del modelo -------------------------------------------------------

local function buildVisual(giant: Giant)
	local root = giant.root
	local speciesName = stringAttribute(root, "Species")
	if not Species[speciesName] then
		speciesName = "Turtle"
	end
	local skin = stringAttribute(root, "Skin")
	local traits = traitsOf(root)
	local built = GiantModel.build(speciesName, giant.userId, {
		skin = if skin ~= "" then skin else nil,
		glow = table.find(traits, "Glow") ~= nil,
	})
	built.model:ScaleTo(giant.scale)
	built.model:PivotTo(giant.bodyCFrame)
	built.model.Parent = visualsFolder

	giant.built = built
	giant.body = Species[speciesName].body
	giant.speciesName = speciesName
	giant.growthFill = nil
	giant.labelLines = nil
	giant.label = nil
	giant.egg = nil
	giant.machines = {}
	buildMachines(giant)
	updateEgg(giant)
	buildLabel(giant)
end

local function rebuild(giant: Giant)
	clearMachines(giant)
	giant.built.model:Destroy()
	buildVisual(giant)
	for _, listener in addedListeners do
		task.spawn(listener, giant)
	end
end

local function addGiant(instance: Instance)
	if not instance:IsA("BasePart") then
		return
	end
	local userId = instance:GetAttribute("OwnerUserId")
	if type(userId) ~= "number" or giants[userId] then
		return
	end
	local scale = scaleFor(instance)
	local giant: Giant = {
		userId = userId,
		root = instance,
		built = (nil :: any) :: GiantModel.Built,
		body = Species.Turtle.body,
		speciesName = "Turtle",
		snapshots = {},
		cframe = instance.CFrame,
		bodyCFrame = instance.CFrame,
		scale = scale,
		targetScale = scale,
		scaleRate = 0,
		speed = 0,
		stepPhase = 0,
		walkAmount = 0,
		machines = {},
		machinesVisible = true,
		egg = nil,
		label = nil,
		growthFill = nil,
		labelLines = nil,
		isWild = instance:GetAttribute("Wild") == true,
	}
	buildVisual(giant)
	giants[userId] = giant

	local function onScale()
		local target = scaleFor(instance)
		giant.targetScale = target
		giant.scaleRate = math.abs(target - giant.scale) / RENDER.scaleChangeDuration
	end
	instance:GetAttributeChangedSignal("Level"):Connect(function()
		onScale()
		updateLabel(giant)
	end)
	instance:GetAttributeChangedSignal("ScaleBonus"):Connect(onScale)
	for _, name in { "Species", "Skin", "Traits" } do
		instance:GetAttributeChangedSignal(name):Connect(function()
			if giants[userId] == giant then
				rebuild(giant)
			end
		end)
	end
	instance:GetAttributeChangedSignal("Machines"):Connect(function()
		buildMachines(giant)
	end)
	instance:GetAttributeChangedSignal("Egg"):Connect(function()
		updateEgg(giant)
	end)
	for _, name in { "DisplayName", "PerSecond" } do
		instance:GetAttributeChangedSignal(name):Connect(function()
			updateLabel(giant)
		end)
	end

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

local function updateGiant(giant: Giant, renderTime: number, dt: number, now: number, cameraPosition: Vector3)
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

	local moved = cframe.Position - giant.cframe.Position
	local distance = Vector3.new(moved.X, 0, moved.Z).Magnitude
	giant.speed = if dt > 0 then distance / dt else 0
	giant.stepPhase = (giant.stepPhase + distance / (RENDER.strideLength * scale)) % 1
	local walking = if giant.speed > 0.5 then 1 else 0
	giant.walkAmount = GiantMath.moveToward(giant.walkAmount, walking, dt * 3)

	local bob = RENDER.bodyBob * scale * giant.walkAmount * math.abs(math.sin(giant.stepPhase * 2 * math.pi))
	local bodyCFrame = cframe * CFrame.new(0, bob, 0)
	-- Todo va soldado a la raíz anclada: basta con mover la raíz.
	giant.built.root.CFrame = bodyCFrame

	-- Patas: se levantan y balancean; restan el rebote para seguir pisando el suelo.
	for _, leg in giant.built.legs do
		local lift = GiantMath.legLift(giant.stepPhase, leg.phase) * RENDER.legLift * scale * giant.walkAmount
		local swing = math.sin((giant.stepPhase + leg.phase) * 2 * math.pi) * 0.35 * giant.walkAmount
		leg.motor.C0 = CFrame.new(leg.hip * scale + Vector3.new(0, lift - bob, 0)) * CFrame.Angles(swing, 0, 0)
	end

	giant.cframe = cframe
	giant.bodyCFrame = bodyCFrame

	-- Máquinas: LOD por distancia y animación.
	local far = (cframe.Position - cameraPosition).Magnitude > RENDER.machineLodDistance
	if far == giant.machinesVisible then
		giant.machinesVisible = not far
		buildMachines(giant)
	end
	if giant.machinesVisible then
		animateMachines(giant, now)
	end

	for _, listener in moveListeners do
		listener(giant, previousBody, previousScale)
	end
end

local function update(dt: number)
	local renderTime = Workspace:GetServerTimeNow() - renderDelay()
	local now = os.clock()
	local camera = Workspace.CurrentCamera
	local cameraPosition = if camera then camera.CFrame.Position else Vector3.zero
	for _, giant in giants do
		updateGiant(giant, renderTime, dt, now, cameraPosition)
	end
end

function GiantRenderController.getGiant(userId: number): Giant?
	return giants[userId]
end

function GiantRenderController.getGiants(): { [number]: Giant }
	return giants
end

function GiantRenderController.getVisualsFolder(): Folder
	return visualsFolder
end

-- Posición del asiento de la cabeza en el mundo (superficie del asiento).
function GiantRenderController.getSeatCFrame(giant: Giant): CFrame
	return giant.bodyCFrame * CFrame.new(giant.body.seat * giant.scale)
end

-- Centro de la cubierta (superficie), para subir pasajeros o lanzar recursos.
function GiantRenderController.getDeckCFrame(giant: Giant): CFrame
	return giant.bodyCFrame * CFrame.new(0, giant.body.deckTop * giant.scale, 0)
end

-- Distancia entre cuerpos (centro a centro menos radios), como en el servidor.
function GiantRenderController.bodyDistance(a: Giant, b: Giant): number
	local delta = a.cframe.Position - b.cframe.Position
	return Vector3.new(delta.X, 0, delta.Z).Magnitude - a.body.radius * a.scale - b.body.radius * b.scale
end

function GiantRenderController.onMoved(listener: MoveListener)
	table.insert(moveListeners, listener)
end

-- También se llama cuando se reconstruye el modelo (cambio de especie o piel).
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

	for _, key in { "growthFruit", "fruitToNext", "level" } do
		ClientState.onChanged(key, function()
			local own = giants[localPlayer.UserId]
			if own then
				updateGrowthBar(own)
			end
		end)
	end

	RunService.PreSimulation:Connect(update)
	print("[GiantRenderController] iniciado")
end

return GiantRenderController
