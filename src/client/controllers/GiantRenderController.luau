--!strict
--[[
	GiantRenderController
	Dibuja los gigantes visuales e interpola hacia su GiantRoot replicado.

	Hito M0: solo esqueleto. La lógica llega en el hito M1 (docs/GDD.md, sección M).
]]

local GiantRenderController = {}

function GiantRenderController.init()
	-- Preparación sin dependencias de otros módulos (no debe ceder).
end

function GiantRenderController.start()
	print("[GiantRenderController] iniciado")
end

return GiantRenderController
