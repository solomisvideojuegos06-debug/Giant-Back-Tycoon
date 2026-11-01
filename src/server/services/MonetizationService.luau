--!strict
--[[
	MonetizationService
	ProcessReceipt idempotente y pases.

	Hito M0: solo esqueleto. La lógica llega en el hito M10 (docs/GDD.md, sección M).
]]

local MonetizationService = {}

function MonetizationService.init()
	-- Preparación sin dependencias de otros módulos (no debe ceder).
end

function MonetizationService.start()
	print("[MonetizationService] iniciado")
end

return MonetizationService
