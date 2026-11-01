--!strict
--[[
	DataService
	ProfileStore: carga y guardado de PlayerData, migraciones, pastoreo nocturno.

	Hito M0: solo esqueleto. La lógica llega en el hito M5 (docs/GDD.md, sección M).
]]

local DataService = {}

function DataService.init()
	-- Preparación sin dependencias de otros módulos (no debe ceder).
end

function DataService.start()
	print("[DataService] iniciado")
end

return DataService
