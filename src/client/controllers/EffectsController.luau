--!strict
--[[
	EffectsController
	Efectos visuales (GDD, sección I, «Efectos»):
	- Pisada: anillo de polvo, sacudida suave de cámara, nodos que saltan,
	  recursos que vuelan al lomo y números flotantes («+5 Madera»).
	- Nodos: se rompen al agotarse y vuelven a aparecer.
	- Estirón: destello, sacudida fuerte y «¡Nivel N!».
	- Eclosión: luz del color de la especie.
	- Lluvia de fruta: fruta cayendo alrededor de la cámara.
	Hay límites de efectos simultáneos para no saturar el móvil.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage.Shared
local Remotes = require(Shared.Remotes)
local Species = require(Shared.Config.Species)
local Theme = require(script.Parent.Parent.ui.Theme)
local GiantRenderController = require(script.Parent.GiantRenderController)
local PlatformController = require(script.Parent.PlatformController)

local EffectsController = {}

local RESOURCES = {
	{ name = "Madera", color = Theme.wood },
	{ name = "Piedra", color = Theme.stone },
	{ name = "Fruta", color = Theme.fruit },
}
local MAX_FLOATING = 24
local MAX_FLYING = 8
local MAX_RINGS = 8
local MAX_RAIN_DROPS = 40
local STOMP_SOUND = "rbxasset://sounds/action_jump_land.mp3"

local player = Players.LocalPlayer
local effectsFolder: Folder
local nodeModels: { [number]: Model } = {}
local nodeTransparency: { [BasePart]: number } = {}
local active = { floating = 0, flying = 0, rings = 0, rain = 0 }
local shakeIntensity = 0
local shakeUntil = 0
local fruitRainEnds = 0

local function effectPart(size: Vector3, cframe: CFrame, color: Color3, material: Enum.Material?): Part
	local part = Instance.new("Part")
	part.Anchored = true
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.CastShadow = false
	part.Size = size
	part.CFrame = cframe
	part.Color = color
	part.Material = material or Enum.Material.SmoothPlastic
	part.Parent = effectsFolder
	return part
end

function EffectsController.shake(intensity: number, duration: number)
	if intensity >= shakeIntensity or os.clock() > shakeUntil then
		shakeIntensity = intensity
	end
	shakeUntil = math.max(shakeUntil, os.clock() + duration)
end

function EffectsController.floatingText(position: Vector3, text: string, color: Color3, size: number?)
	if active.floating >= MAX_FLOATING then
		return
	end
	active.floating += 1
	local anchor = effectPart(Vector3.one * 0.2, CFrame.new(position), Color3.new(1, 1, 1))
	anchor.Transparency = 1
	local gui = Instance.new("BillboardGui")
	gui.Size = UDim2.fromOffset(220, size or 44)
	gui.AlwaysOnTop = true
	gui.LightInfluence = 0
	gui.MaxDistance = 400
	gui.Parent = anchor
	local label = Instance.new("TextLabel")
	label.BackgroundTransparency = 1
	label.Size = UDim2.fromScale(1, 1)
	label.Font = Theme.font
	label.TextScaled = true
	label.Text = text
	label.TextColor3 = color
	label.TextStrokeColor3 = Theme.stroke
	label.TextStrokeTransparency = 0
	label.Parent = gui

	local info = TweenInfo.new(1.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
	TweenService:Create(gui, info, { StudsOffsetWorldSpace = Vector3.new(0, 8, 0) }):Play()
	local fade = TweenService:Create(
		label,
		TweenInfo.new(0.5, Enum.EasingStyle.Linear, Enum.EasingDirection.In, 0, false, 0.7),
		{ TextTransparency = 1, TextStrokeTransparency = 1 }
	)
	fade.Completed:Connect(function()
		anchor:Destroy()
		active.floating -= 1
	end)
	fade:Play()
end

local function ring(position: Vector3, radius: number, color: Color3, duration: number)
	if active.rings >= MAX_RINGS then
		return
	end
	active.rings += 1
	local diameter = math.max(radius * 2, 4)
	local part = effectPart(
		Vector3.new(0.4, diameter * 0.4, diameter * 0.4),
		CFrame.new(position + Vector3.new(0, 0.3, 0)) * CFrame.Angles(0, 0, math.rad(90)),
		color
	)
	part.Shape = Enum.PartType.Cylinder
	part.Transparency = 0.35
	local tween = TweenService:Create(
		part,
		TweenInfo.new(duration, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
		{ Size = Vector3.new(0.4, diameter * 1.2, diameter * 1.2), Transparency = 1 }
	)
	tween.Completed:Connect(function()
		part:Destroy()
		active.rings -= 1
	end)
	tween:Play()
end

local function flash(position: Vector3, size: number, color: Color3, duration: number)
	local ball = effectPart(Vector3.one * size * 0.3, CFrame.new(position), color, Enum.Material.Neon)
	ball.Shape = Enum.PartType.Ball
	ball.Transparency = 0.2
	local tween = TweenService:Create(
		ball,
		TweenInfo.new(duration, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
		{ Size = Vector3.one * size, Transparency = 1 }
	)
	tween.Completed:Connect(function()
		ball:Destroy()
	end)
	tween:Play()
end

local function flyToDeck(from: Vector3, giantId: number, color: Color3)
	if active.flying >= MAX_FLYING then
		return
	end
	local giant = GiantRenderController.getGiant(giantId)
	if not giant then
		return
	end
	active.flying += 1
	local cube = effectPart(Vector3.one * 1.2, CFrame.new(from + Vector3.new(0, 2, 0)), color)
	local target = GiantRenderController.getDeckCFrame(giant).Position + Vector3.new(0, 2, 0)
	local tween = TweenService:Create(
		cube,
		TweenInfo.new(0.55, Enum.EasingStyle.Quad, Enum.EasingDirection.In),
		{ Position = target, Size = Vector3.one * 0.4 }
	)
	tween.Completed:Connect(function()
		cube:Destroy()
		active.flying -= 1
	end)
	tween:Play()
end

local function playSound(id: string, position: Vector3, volume: number, pitch: number)
	local anchor = effectPart(Vector3.one * 0.2, CFrame.new(position), Color3.new(1, 1, 1))
	anchor.Transparency = 1
	local sound = Instance.new("Sound")
	sound.SoundId = id
	sound.Volume = volume
	sound.PlaybackSpeed = pitch
	sound.RollOffMaxDistance = 300
	sound.Parent = anchor
	sound:Play()
	task.delay(3, function()
		anchor:Destroy()
	end)
end

-- Nodos -----------------------------------------------------------------

local function setNodeVisible(model: Model, visible: boolean)
	for _, part in model:GetDescendants() do
		if part:IsA("BasePart") then
			if nodeTransparency[part] == nil then
				nodeTransparency[part] = part.Transparency
			end
			local target = if visible then nodeTransparency[part] else 1
			TweenService:Create(part, TweenInfo.new(if visible then 0.4 else 0.2), { Transparency = target }):Play()
		end
	end
end

local function watchNode(model: Instance)
	if not model:IsA("Model") then
		return
	end
	local id = model:GetAttribute("NodeId")
	if type(id) ~= "number" then
		return
	end
	nodeModels[id] = model
	if model:GetAttribute("Depleted") == true then
		setNodeVisible(model, false)
	end
	model:GetAttributeChangedSignal("Depleted"):Connect(function()
		setNodeVisible(model, model:GetAttribute("Depleted") ~= true)
	end)
end

-- Eventos del servidor ------------------------------------------------------

local function onStomp(giantId: number, x: number, z: number, radius: number, collected: { number })
	local giant = GiantRenderController.getGiant(giantId)
	local y = if giant then giant.cframe.Position.Y else 0
	local position = Vector3.new(x, y, z)
	ring(position, radius, Color3.fromRGB(225, 205, 160), 0.6)

	local isOwn = giantId == player.UserId
	if isOwn then
		playSound(STOMP_SOUND, position, 0.5, 0.6)
	end
	if PlatformController.getAttachedTo() == giantId then
		EffectsController.shake(0.12 * (if giant then giant.scale else 1), 0.18)
	end

	if not isOwn or type(collected) ~= "table" then
		return
	end
	local totals = { 0, 0, 0 }
	for i = 1, #collected - 2, 3 do
		local nodeId, resourceIndex, amount = collected[i], collected[i + 1], collected[i + 2]
		if RESOURCES[resourceIndex] then
			totals[resourceIndex] += amount
			local model = nodeModels[nodeId]
			if model then
				flyToDeck(model:GetPivot().Position, giantId, RESOURCES[resourceIndex].color)
			end
		end
	end
	local offset = 0
	for index, total in totals do
		if total > 0 then
			local resource = RESOURCES[index]
			EffectsController.floatingText(
				position + Vector3.new(0, 10 + offset, 0),
				`+{math.floor(total)} {resource.name}`,
				resource.color
			)
			offset += 4
		end
	end
end

local function onGrowthSpurt(userId: number, level: number)
	local giant = GiantRenderController.getGiant(userId)
	if not giant then
		return
	end
	local center = giant.cframe.Position + Vector3.new(0, 10 * giant.scale, 0)
	flash(center, 70 * giant.scale, Color3.fromRGB(255, 240, 160), 0.9)
	ring(giant.cframe.Position, 40 * giant.scale, Color3.fromRGB(255, 220, 120), 1.2)
	EffectsController.floatingText(center + Vector3.new(0, 20 * giant.scale, 0), `¡Nivel {level}!`, Theme.gold, 70)
	local camera = Workspace.CurrentCamera
	if camera and (camera.CFrame.Position - giant.cframe.Position).Magnitude < 350 then
		EffectsController.shake(if userId == player.UserId then 0.9 else 0.4, 0.7)
	end
	playSound(STOMP_SOUND, giant.cframe.Position, 1, 0.35)
end

local function onHatch(userId: number, speciesName: string)
	local giant = GiantRenderController.getGiant(userId)
	local species = Species[speciesName]
	if not giant or not species then
		return
	end
	local deck = GiantRenderController.getDeckCFrame(giant).Position
	flash(deck + Vector3.new(0, 4, 0), 30 * giant.scale, species.eggColor, 1.2)
	EffectsController.floatingText(deck + Vector3.new(0, 14, 0), "¡Achís!", Theme.textLight, 50)
end

local function rainStep()
	if Workspace:GetServerTimeNow() > fruitRainEnds or active.rain >= MAX_RAIN_DROPS then
		return
	end
	local camera = Workspace.CurrentCamera
	if not camera then
		return
	end
	for _ = 1, 3 do
		active.rain += 1
		local origin = camera.CFrame.Position + Vector3.new(math.random(-60, 60), 40, math.random(-60, 60))
		local drop = effectPart(Vector3.one * 1.4, CFrame.new(origin), Theme.fruit)
		drop.Shape = Enum.PartType.Ball
		local tween = TweenService:Create(
			drop,
			TweenInfo.new(1.6, Enum.EasingStyle.Linear),
			{ Position = origin - Vector3.new(0, 55, 0) }
		)
		tween.Completed:Connect(function()
			drop:Destroy()
			active.rain -= 1
		end)
		tween:Play()
	end
end

local function updateShake()
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if not humanoid then
		return
	end
	if os.clock() < shakeUntil then
		local i = shakeIntensity
		humanoid.CameraOffset = Vector3.new(math.random() - 0.5, math.random() - 0.5, math.random() - 0.5) * 2 * i
	elseif humanoid.CameraOffset ~= Vector3.zero then
		humanoid.CameraOffset = Vector3.zero
	end
end

function EffectsController.init()
	effectsFolder = Instance.new("Folder")
	effectsFolder.Name = "Effects"
	effectsFolder.Parent = Workspace
end

function EffectsController.start()
	Remotes.Stomp.OnClientEvent:Connect(onStomp)
	Remotes.GrowthSpurt.OnClientEvent:Connect(onGrowthSpurt)
	Remotes.Hatch.OnClientEvent:Connect(onHatch)
	Remotes.FruitRain.OnClientEvent:Connect(function(_name: string, endsAt: number)
		if type(endsAt) == "number" then
			fruitRainEnds = endsAt
		end
	end)

	task.spawn(function()
		local nodes = Workspace:WaitForChild("Nodes")
		nodes.ChildAdded:Connect(watchNode)
		for _, child in nodes:GetChildren() do
			watchNode(child)
		end
	end)

	RunService.RenderStepped:Connect(updateShake)
	task.spawn(function()
		while true do
			task.wait(0.25)
			rainStep()
		end
	end)
	print("[EffectsController] iniciado")
end

return EffectsController
