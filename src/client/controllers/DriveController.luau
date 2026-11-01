--!strict
--[[
	DriveController
	Entrada de dirección (joystick / WASD) hacia DriveInput.

	Hito M0: solo esqueleto. La lógica llega en el hito M1 (docs/GDD.md, sección M).
]]

local DriveController = {}

function DriveController.init()
	-- Preparación sin dependencias de otros módulos (no debe ceder).
end

function DriveController.start()
	print("[DriveController] iniciado")
end

return DriveController
