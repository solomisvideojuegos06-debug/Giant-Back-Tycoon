--!strict
--[[
	PlatformController
	Mantiene al jugador local encima del gigante en movimiento (GDD, sección L).

	1. Plataforma móvil: si el personaje pisa un gigante, cada vez que el gigante
	   se mueve se le aplica el mismo desplazamiento (y el mismo cambio de escala)
	   antes de la física. Así puede caminar por el lomo sin caerse.
	2. Asiento de la cabeza: al aparecer, el jugador se sienta en la cabeza de su
	   gigante. Saltar le levanta; el aviso «Conducir» del asiento le vuelve a sentar.
	3. Otros jugadores: cada cliente envía su posición relativa al gigante que pisa
	   (RiderUpdate) y aquí se dibuja a los demás en esa posición sobre nuestra
	   copia del gigante. Sin esto, por el retraso de red se les vería
	   resbalar hacia atrás sobre los gigantes en marcha.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage.Shared
local GiantConfig = require(Shared.Config.Giant)
local GiantMath = require(Shared.GiantMath)
local Remotes = require(Shared.Remotes)
local GiantRenderController = require(script.Parent.GiantRenderController)

type Giant = GiantRenderController.Giant

local PLATFORM = GiantConfig.platform
local RIDER_INTERVAL = 1 / GiantConfig.network.riderRate

type Rider = {
	giantUserId: number,
	target: Vector3, -- posición relativa al gigante, a escala 1
	targetYaw: number,
	current: Vector3,
	currentYaw: number,
	receivedAt: number,
}

local PlatformController = {}

local player = Players.LocalPlayer
local character: Model? = nil
local humanoid: Humanoid? = nil
local rootPart: BasePart? = nil

local seated = false
local pendingSeat = false -- sentarse en cuanto exista nuestro gigante
local attachedTo: number? = nil -- gigante que pisa el personaje (UserId del dueño)
local rayParams = RaycastParams.new()

local riders: { [number]: Rider } = {}
local riderAccumulator = 0
local lastSentGiant: number? = nil

local drivePrompt: ProximityPrompt? = nil

local function ownGiant(): Giant?
	return GiantRenderController.getGiant(player.UserId)
end

local function seatPinCFrame(giant: Giant): CFrame
	return GiantRenderController.getSeatCFrame(giant) * CFrame.new(0, PLATFORM.seatHeight, 0)
end

local function pinToSeat(giant: Giant)
	local part = rootPart
	if not part then
		return
	end
	part.CFrame = seatPinCFrame(giant)
	part.AssemblyLinearVelocity = Vector3.zero
	part.AssemblyAngularVelocity = Vector3.zero
end

local function updatePrompt()
	if drivePrompt then
		drivePrompt.Enabled = not seated and humanoid ~= nil
	end
end

local function sit()
	local giant = ownGiant()
	local hum = humanoid
	if not giant or not hum or hum.Health <= 0 then
		return
	end
	seated = true
	pendingSeat = false
	attachedTo = giant.userId
	hum.Sit = true
	pinToSeat(giant)
	updatePrompt()
end

local function standUp()
	if not seated then
		return
	end
	seated = false
	local hum = humanoid
	if hum then
		hum.Sit = false
	end
	updatePrompt()
end

-- Llamado por GiantRenderController justo después de mover cada gigante.
local function onGiantMoved(giant: Giant, previousBody: CFrame, previousScale: number)
	if giant.userId == player.UserId and drivePrompt and giant.scale ~= previousScale then
		drivePrompt.MaxActivationDistance = GiantConfig.prompt.driveDistance * giant.scale
	end
	local part = rootPart
	if not part then
		return
	end
	if seated and giant.userId == player.UserId then
		pinToSeat(giant)
		return
	end
	if attachedTo ~= giant.userId then
		return
	end
	local relative = previousBody:ToObjectSpace(part.CFrame)
	local ratio = if previousScale > 0 then giant.scale / previousScale else 1
	part.CFrame = giant.bodyCFrame * CFrame.new(relative.Position * ratio) * relative.Rotation
end

-- ¿Qué gigante hay bajo el personaje? (después de la física de este frame)
local function detectGiantUnderfoot(part: BasePart): number?
	rayParams.FilterDescendantsInstances = { GiantRenderController.getVisualsFolder() }
	local result = Workspace:Raycast(part.Position, Vector3.new(0, -PLATFORM.attachRayLength, 0), rayParams)
	if not result then
		return nil
	end
	local model = result.Instance:FindFirstAncestorOfClass("Model")
	local owner = model and model:GetAttribute("OwnerUserId")
	return if type(owner) == "number" then owner else nil
end

local function sendRiderUpdate(dt: number)
	riderAccumulator += dt
	if riderAccumulator < RIDER_INTERVAL then
		return
	end
	riderAccumulator = 0

	local part = rootPart
	local giant = if attachedTo then GiantRenderController.getGiant(attachedTo) else nil
	if not part or not giant then
		if lastSentGiant ~= nil then
			Remotes.RiderUpdate:FireServer(0, Vector3.zero, 0)
			lastSentGiant = nil
		end
		return
	end

	local relative = giant.bodyCFrame:ToObjectSpace(part.CFrame)
	local look = relative.LookVector
	Remotes.RiderUpdate:FireServer(
		giant.userId,
		relative.Position / giant.scale,
		GiantMath.yawFromDirection(look.X, look.Z)
	)
	lastSentGiant = giant.userId
end

local function postSimulation(dt: number)
	local part = rootPart
	local hum = humanoid
	if not part or not hum then
		return
	end

	if pendingSeat and ownGiant() then
		sit()
	end

	if seated then
		local giant = ownGiant()
		if giant and hum.Health > 0 then
			-- Segunda fijación tras la física: la gravedad no lo mueve ni un pelo.
			pinToSeat(giant)
			attachedTo = giant.userId
		else
			standUp()
		end
	else
		attachedTo = detectGiantUnderfoot(part)
	end

	sendRiderUpdate(dt)
end

-- Coloca a los demás jugadores sobre nuestra copia de su gigante.
local function preRender(dt: number)
	local now = os.clock()
	local alpha = 1 - math.exp(-PLATFORM.riderSmoothing * dt)
	for userId, rider in riders do
		if now - rider.receivedAt > PLATFORM.riderStaleTime then
			riders[userId] = nil
			continue
		end
		local other = Players:GetPlayerByUserId(userId)
		local otherCharacter = other and other.Character
		local otherRoot = otherCharacter and otherCharacter:FindFirstChild("HumanoidRootPart")
		local giant = GiantRenderController.getGiant(rider.giantUserId)
		if otherRoot and otherRoot:IsA("BasePart") and giant then
			rider.current = rider.current:Lerp(rider.target, alpha)
			rider.currentYaw = GiantMath.lerpAngle(rider.currentYaw, rider.targetYaw, alpha)
			otherRoot.CFrame = giant.bodyCFrame
				* CFrame.new(rider.current * giant.scale)
				* CFrame.Angles(0, rider.currentYaw, 0)
		end
	end
end

local function onRiderUpdate(userId: number, giantUserId: number, offset: Vector3, yaw: number)
	if userId == player.UserId then
		return
	end
	if giantUserId == 0 then
		riders[userId] = nil
		return
	end
	local rider = riders[userId]
	if rider and rider.giantUserId == giantUserId then
		rider.target = offset
		rider.targetYaw = yaw
		rider.receivedAt = os.clock()
	else
		riders[userId] = {
			giantUserId = giantUserId,
			target = offset,
			targetYaw = yaw,
			current = offset,
			currentYaw = yaw,
			receivedAt = os.clock(),
		}
	end
end

-- Teletransporta al jugador a la cubierta de un gigante (pasajero).
local function boardOnto(giant: Giant)
	local part = rootPart
	if not part then
		return
	end
	standUp()
	part.CFrame = GiantRenderController.getDeckCFrame(giant) * CFrame.new(0, 3, 0)
	part.AssemblyLinearVelocity = Vector3.zero
	attachedTo = giant.userId
end

local function attachBoardPrompt(giant: Giant)
	local deck = giant.built.model:FindFirstChild("Deck")
	if not deck or not deck:IsA("BasePart") then
		return
	end
	local prompt = Instance.new("ProximityPrompt")
	prompt.ActionText = "Subir (+20 %)"
	prompt.ObjectText = "Pasajero"
	prompt.KeyboardKeyCode = Enum.KeyCode.F
	prompt.RequiresLineOfSight = false
	prompt.HoldDuration = 0.3
	prompt.MaxActivationDistance = GiantConfig.prompt.boardDistance * giant.scale
	prompt.Parent = deck
	prompt.Triggered:Connect(function()
		local ok, result = pcall(function()
			return Remotes.BoardGiant:InvokeServer(giant.userId)
		end)
		local current = GiantRenderController.getGiant(giant.userId)
		if ok and result == true and current then
			boardOnto(current)
		end
	end)
end

local function attachPrompt(giant: Giant)
	if giant.userId > 0 and giant.userId ~= player.UserId then
		attachBoardPrompt(giant)
		return
	end
	if giant.userId ~= player.UserId then
		return
	end
	local seatPart = giant.built.seatPart
	if not seatPart then
		return
	end
	local prompt = Instance.new("ProximityPrompt")
	prompt.ActionText = "Conducir"
	prompt.ObjectText = "Gigante"
	prompt.KeyboardKeyCode = Enum.KeyCode.E
	prompt.RequiresLineOfSight = false
	prompt.HoldDuration = 0
	prompt.MaxActivationDistance = GiantConfig.prompt.driveDistance * giant.scale
	prompt.Parent = seatPart
	prompt.Triggered:Connect(sit)
	drivePrompt = prompt
	updatePrompt()
end

local function onCharacterAdded(newCharacter: Model)
	character = newCharacter
	local hum = newCharacter:WaitForChild("Humanoid") :: Humanoid
	local part = newCharacter:WaitForChild("HumanoidRootPart") :: BasePart
	if character ~= newCharacter then
		return
	end
	humanoid = hum
	rootPart = part
	seated = false
	attachedTo = nil
	pendingSeat = true -- el jugador aparece sentado en la cabeza (GDD, sección D)

	hum:GetPropertyChangedSignal("Sit"):Connect(function()
		if humanoid == hum and seated and not hum.Sit then
			standUp()
		end
	end)
	hum.Died:Connect(function()
		if humanoid == hum then
			standUp()
		end
	end)
	updatePrompt()
end

local function onCharacterRemoving(oldCharacter: Model)
	if character == oldCharacter then
		character = nil
		humanoid = nil
		rootPart = nil
		seated = false
		pendingSeat = false
		attachedTo = nil
		updatePrompt()
	end
end

-- Vuelve al asiento del propio gigante (botón «Volver» de la interfaz).
function PlatformController.returnHome()
	if ownGiant() then
		sit()
	end
end

-- UserId del dueño del gigante que pisa el jugador (nil si está en el suelo).
function PlatformController.getAttachedTo(): number?
	return attachedTo
end

function PlatformController.isSeated(): boolean
	return seated
end

-- Para DriveController: solo se conduce sentado en el propio gigante.
function PlatformController.isDriving(): boolean
	return seated and humanoid ~= nil and ownGiant() ~= nil
end

function PlatformController.init()
	rayParams.FilterType = Enum.RaycastFilterType.Include
end

function PlatformController.start()
	GiantRenderController.onMoved(onGiantMoved)
	GiantRenderController.onAdded(attachPrompt)
	GiantRenderController.onRemoved(function(giant: Giant)
		if attachedTo == giant.userId then
			attachedTo = nil
		end
		if giant.userId == player.UserId then
			standUp()
			drivePrompt = nil
		end
	end)

	Remotes.RiderUpdate.OnClientEvent:Connect(onRiderUpdate)
	UserInputService.JumpRequest:Connect(standUp)
	RunService.PostSimulation:Connect(postSimulation)
	RunService.PreRender:Connect(preRender)

	player.CharacterAdded:Connect(onCharacterAdded)
	player.CharacterRemoving:Connect(onCharacterRemoving)
	if player.Character then
		task.spawn(onCharacterAdded, player.Character)
	end

	print("[PlatformController] iniciado")
end

return PlatformController
