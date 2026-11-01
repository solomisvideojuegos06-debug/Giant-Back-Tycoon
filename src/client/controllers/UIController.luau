--!strict
--[[
	UIController
	HUD, tiendas, Libro de rasgos y Linaje.

	Hito M0: solo esqueleto. La lógica llega en el hito M3 (docs/GDD.md, sección M).
]]

local UIController = {}

function UIController.init()
	-- Preparación sin dependencias de otros módulos (no debe ceder).
end

function UIController.start()
	print("[UIController] iniciado")
end

return UIController
