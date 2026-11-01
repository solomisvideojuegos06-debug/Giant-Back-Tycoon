--!strict
--[[
	EconomyService
	Almacén, huecos, compra y mejora de máquinas, tick de producción, venta de Fruta.

	Hito M0: solo esqueleto. La lógica llega en el hito M3 (docs/GDD.md, sección M).
]]

local EconomyService = {}

function EconomyService.init()
	-- Preparación sin dependencias de otros módulos (no debe ceder).
end

function EconomyService.start()
	print("[EconomyService] iniciado")
end

return EconomyService
