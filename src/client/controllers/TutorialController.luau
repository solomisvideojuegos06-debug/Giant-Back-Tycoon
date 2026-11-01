--!strict
--[[
	TutorialController
	Primeros 60 segundos (GDD, sección D).

	Hito M0: solo esqueleto. La lógica llega en el hito M9 (docs/GDD.md, sección M).
]]

local TutorialController = {}

function TutorialController.init()
	-- Preparación sin dependencias de otros módulos (no debe ceder).
end

function TutorialController.start()
	print("[TutorialController] iniciado")
end

return TutorialController
