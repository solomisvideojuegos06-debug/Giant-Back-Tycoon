--!strict
--[[
	WildGiantService
	Gigantes salvajes NPC por zona.

	Hito M0: solo esqueleto. La lógica llega en el hito M7 (docs/GDD.md, sección M).
]]

local WildGiantService = {}

function WildGiantService.init()
	-- Preparación sin dependencias de otros módulos (no debe ceder).
end

function WildGiantService.start()
	print("[WildGiantService] iniciado")
end

return WildGiantService
