--!strict
--[[
	ResourceService
	Nodos de recursos en rejilla espacial, pisadas y reaparición.

	Hito M0: solo esqueleto. La lógica llega en el hito M2 (docs/GDD.md, sección M).
]]

local ResourceService = {}

function ResourceService.init()
	-- Preparación sin dependencias de otros módulos (no debe ceder).
end

function ResourceService.start()
	print("[ResourceService] iniciado")
end

return ResourceService
