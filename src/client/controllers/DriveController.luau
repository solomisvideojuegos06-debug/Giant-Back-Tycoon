--!strict
--[[
	DriveController
	Entrada de dirección del gigante (GDD, sección L, «Asiento de la cabeza»).

	Mientras el jugador está sentado en la cabeza de su gigante, lee el
	movimiento de los controles estándar de Roblox (WASD, flechas, joystick
	táctil o mando), lo convierte en una dirección del mundo según la cámara y
	la envía por DriveInput, como mucho 20 veces por segundo. El servidor la
	valida y mueve el gigante.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage.Shared
local GiantConfig = require(Shared.Config.Giant)
local Remotes = require(Shared.Remotes)
local PlatformController = require(script.Parent.PlatformController)

local SEND_INTERVAL = 1 / GiantConfig.network.driveInputRate
local DEADZONE = 0.05
-- Al soltar, se repite el «parar» unas veces por si se pierde algún paquete.
local STOP_REPEATS = 3

type Controls = {
	GetMoveVector: (self: Controls) -> Vector3,
}

local DriveController = {}

local controls: Controls? = nil
local accumulator = 0
local stopsToSend = 0

-- Vector de movimiento relativo a la cámara → dirección en el mundo (x, z).
local function worldDirection(moveVector: Vector3): Vector3
	local camera = Workspace.CurrentCamera
	if not camera or moveVector.Magnitude < DEADZONE then
		return Vector3.zero
	end
	local look = camera.CFrame.LookVector
	local right = camera.CFrame.RightVector
	local forward = Vector3.new(look.X, 0, look.Z)
	local side = Vector3.new(right.X, 0, right.Z)
	if forward.Magnitude < 1e-3 or side.Magnitude < 1e-3 then
		return Vector3.zero
	end
	local direction = side.Unit * moveVector.X + forward.Unit * -moveVector.Z
	if direction.Magnitude > 1 then
		direction = direction.Unit
	end
	return direction
end

local function tick(dt: number)
	accumulator += dt
	if accumulator < SEND_INTERVAL then
		return
	end
	accumulator = 0

	local direction = Vector3.zero
	if controls and PlatformController.isDriving() then
		direction = worldDirection(controls:GetMoveVector())
	end

	if direction.Magnitude > 0 then
		Remotes.DriveInput:FireServer(direction.X, direction.Z)
		stopsToSend = STOP_REPEATS
	elseif stopsToSend > 0 then
		Remotes.DriveInput:FireServer(0, 0)
		stopsToSend -= 1
	end
end

function DriveController.init() end

function DriveController.start()
	RunService.Heartbeat:Connect(tick)

	-- PlayerModule lo añade Roblox; se espera en un hilo aparte para no bloquear.
	task.spawn(function()
		local playerScripts = Players.LocalPlayer:WaitForChild("PlayerScripts")
		local playerModule = require(playerScripts:WaitForChild("PlayerModule") :: ModuleScript) :: any
		controls = playerModule:GetControls()
	end)

	print("[DriveController] iniciado")
end

return DriveController
