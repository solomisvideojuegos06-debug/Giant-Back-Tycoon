--!strict
--[[
	PlatformController
	Mantiene al jugador local sobre el gigante en movimiento.

	Hito M0: solo esqueleto. La lógica llega en el hito M1 (docs/GDD.md, sección M).
]]

local PlatformController = {}

function PlatformController.init()
	-- Preparación sin dependencias de otros módulos (no debe ceder).
end

function PlatformController.start()
	print("[PlatformController] iniciado")
end

return PlatformController
