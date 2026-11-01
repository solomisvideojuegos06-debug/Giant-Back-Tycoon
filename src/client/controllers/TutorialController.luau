--!strict
--[[
	TutorialController
	Primeros 60 segundos (GDD, sección D), sin ventanas de texto:
	1. Indicación de movimiento: joystick en móvil, teclas WASD en ordenador.
	2. Al tener monedas para la Trituradora, se resalta «Construir».
	3. Con Fruta para crecer, se resalta «Alimentar».
	Termina con el primer estirón. Solo para jugadores nuevos (generación 1, nivel 1).
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

local Shared = ReplicatedStorage.Shared
local Formulas = require(Shared.Formulas)
local Machines = require(Shared.Config.Machines)
local ClientState = require(script.Parent.Parent.ClientState)
local Theme = require(script.Parent.Parent.ui.Theme)
local Widgets = require(script.Parent.Parent.ui.Widgets)
local GiantRenderController = require(script.Parent.GiantRenderController)
local UIController = require(script.Parent.UIController)

local TutorialController = {}

local player = Players.LocalPlayer

local function hasMachine(id: string): boolean
	local machines = ClientState.get("machines")
	if type(machines) ~= "table" then
		return false
	end
	for _, machine in machines do
		if type(machine) == "table" and machine.id == id then
			return true
		end
	end
	return false
end

-- Indicación de movimiento: un joystick dibujado o las teclas WASD.
local function movementHint(gui: ScreenGui): Frame
	local touch = UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled
	local hint = Instance.new("Frame")
	hint.BackgroundTransparency = 1
	hint.Size = UDim2.fromOffset(260, 200)
	hint.AnchorPoint = if touch then Vector2.new(0, 1) else Vector2.new(0.5, 1)
	hint.Position = if touch then UDim2.new(0, 60, 1, -170) else UDim2.new(0.5, 0, 1, -40)
	hint.Parent = gui

	if touch then
		local ring = Widgets.panel(hint, UDim2.fromOffset(150, 150), UDim2.fromOffset(20, 20), nil, Theme.panel)
		ring.BackgroundTransparency = 0.4
		local corner = ring:FindFirstChildOfClass("UICorner")
		if corner then
			corner.CornerRadius = UDim.new(0.5, 0)
		end
		local knob = Widgets.panel(
			ring,
			UDim2.fromOffset(60, 60),
			UDim2.fromScale(0.5, 0.5),
			Vector2.new(0.5, 0.5),
			Theme.orange
		)
		local knobCorner = knob:FindFirstChildOfClass("UICorner")
		if knobCorner then
			knobCorner.CornerRadius = UDim.new(0.5, 0)
		end
		TweenService:Create(
			knob,
			TweenInfo.new(0.7, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true),
			{ Position = UDim2.fromScale(0.5, 0.2) }
		):Play()
	else
		local keys = { { "W", 1, 0 }, { "A", 0, 1 }, { "S", 1, 1 }, { "D", 2, 1 } }
		for _, key in keys do
			local cap = Widgets.panel(
				hint,
				UDim2.fromOffset(70, 70),
				UDim2.fromOffset(20 + key[2] * 76, 30 + key[3] * 76),
				nil,
				Theme.panel
			)
			local label = Widgets.label(cap, key[1], 34)
			label.Size = UDim2.fromScale(1, 1)
			if key[1] == "W" then
				TweenService:Create(
					cap,
					TweenInfo.new(0.5, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true),
					{ BackgroundColor3 = Theme.orange }
				):Play()
			end
		end
	end
	return hint
end

function TutorialController.init() end

function TutorialController.start()
	task.spawn(function()
		-- Espera al estado: solo jugadores nuevos.
		while not ClientState.isLoaded() do
			task.wait(0.2)
		end
		if ClientState.number("generation") > 1 or ClientState.number("level") > 1 then
			return
		end
		local gui = UIController.getGui()
		while not gui do
			task.wait(0.2)
			gui = UIController.getGui()
		end

		-- 1. Mover el gigante.
		local hint = movementHint(gui)
		local started = os.clock()
		while os.clock() - started < 30 do
			local giant = GiantRenderController.getGiant(player.UserId)
			if giant and giant.speed > 2 then
				break
			end
			task.wait(0.2)
		end
		hint:Destroy()

		-- 2 y 3. Construir la Trituradora y alimentar hasta el primer estirón.
		local build = UIController.getButton("build")
		local feed = UIController.getButton("feed")
		while ClientState.number("level") < 2 do
			local crusher = Machines.byId.Crusher
			local price = Formulas.machinePrice(crusher.price, 0, false, Machines.repeatCostMultiplier)
			local wantBuild = not hasMachine("Crusher") and ClientState.number("coins") >= price
			local need = ClientState.number("fruitToNext") - ClientState.number("growthFruit")
			local wantFeed = not wantBuild and ClientState.number("fruit") >= math.min(need, 3)
			if build then
				build.setHighlight(wantBuild)
			end
			if feed then
				feed.setHighlight(wantFeed)
			end
			task.wait(0.5)
		end
		if build then
			build.setHighlight(false)
		end
		if feed then
			feed.setHighlight(false)
		end
	end)
	print("[TutorialController] iniciado")
end

return TutorialController
