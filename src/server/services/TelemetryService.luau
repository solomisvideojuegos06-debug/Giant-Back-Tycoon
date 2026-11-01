--!strict
--[[
	TelemetryService
	Embudo de incorporación y eventos de economía con AnalyticsService.

	Hito M0: solo esqueleto. La lógica llega en el hito M10 (docs/GDD.md, sección M).
]]

local TelemetryService = {}

function TelemetryService.init()
	-- Preparación sin dependencias de otros módulos (no debe ceder).
end

function TelemetryService.start()
	print("[TelemetryService] iniciado")
end

return TelemetryService
