--!strict
--[[
	EffectsController
	Pisadas, estirones y números flotantes.

	Hito M0: solo esqueleto. La lógica llega en el hito M2 (docs/GDD.md, sección M).
]]

local EffectsController = {}

function EffectsController.init()
	-- Preparación sin dependencias de otros módulos (no debe ceder).
end

function EffectsController.start()
	print("[EffectsController] iniciado")
end

return EffectsController
