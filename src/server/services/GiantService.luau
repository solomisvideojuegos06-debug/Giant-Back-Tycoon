--!strict
--[[
	GiantService
	Estado lógico y movimiento autoritativo de cada gigante (posición, orientación, altura del suelo).

	Hito M0: solo esqueleto. La lógica llega en el hito M1 (docs/GDD.md, sección M).
]]

local GiantService = {}

function GiantService.init()
	-- Preparación sin dependencias de otros módulos (no debe ceder).
end

function GiantService.start()
	print("[GiantService] iniciado")
end

return GiantService
