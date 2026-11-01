--!strict
--[[
	GrowthService
	Alimentar, niveles 1-10, estirón y bloqueo de zonas por nivel.

	Hito M0: solo esqueleto. La lógica llega en el hito M4 (docs/GDD.md, sección M).
]]

local GrowthService = {}

function GrowthService.init()
	-- Preparación sin dependencias de otros módulos (no debe ceder).
end

function GrowthService.start()
	print("[GrowthService] iniciado")
end

return GrowthService
