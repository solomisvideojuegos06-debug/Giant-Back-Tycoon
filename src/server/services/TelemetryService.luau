--!strict
--[[
	TelemetryService
	Analítica con AnalyticsService (GDD, sección L, «Analítica»).

	- Embudo de incorporación: cada paso se envía una sola vez por jugador
	  (se recuerda en data.funnel).
	- Economía: fuentes y gastos de monedas. La producción de las máquinas
	  se acumula y se envía una vez por minuto para no saturar.
]]

local AnalyticsService = game:GetService("AnalyticsService")
local Players = game:GetService("Players")

local DataService = require(script.Parent.DataService)

local TelemetryService = {
	priority = 2,
}

-- Orden del embudo (GDD): el número de paso es la posición en esta lista.
local FUNNEL_STEPS = {
	"MovedGiant",
	"FirstStomp",
	"FirstPurchase",
	"FirstGrowth",
	"Level3",
	"Level5",
	"FirstEgg",
	"FirstHatch",
}

local FUNNEL_NAMES: { [string]: string } = {
	MovedGiant = "Movió el gigante",
	FirstStomp = "Primera pisada",
	FirstPurchase = "Primera compra",
	FirstGrowth = "Primer estirón",
	Level3 = "Nivel 3",
	Level5 = "Nivel 5",
	FirstEgg = "Primer huevo",
	FirstHatch = "Primera eclosión",
}

local ECONOMY_FLUSH_INTERVAL = 60
local CURRENCY = "Coins"

local pendingProduction: { [Player]: number } = {}

local function log(fn: () -> ())
	local ok, err = pcall(fn)
	if not ok then
		warn(`[TelemetryService] {err}`)
	end
end

function TelemetryService.funnel(player: Player, stepId: string)
	local data = DataService.get(player)
	local stepNumber = table.find(FUNNEL_STEPS, stepId)
	if not data or not stepNumber or data.funnel[stepId] then
		return
	end
	data.funnel[stepId] = true
	log(function()
		AnalyticsService:LogOnboardingFunnelStepEvent(player, stepNumber, FUNNEL_NAMES[stepId])
	end)
end

-- Monedas ganadas (source) o gastadas (sink).
function TelemetryService.coins(player: Player, amount: number, isSource: boolean, transaction: string, sku: string?)
	local data = DataService.get(player)
	if not data or amount <= 0 then
		return
	end
	if transaction == "Production" then
		pendingProduction[player] = (pendingProduction[player] or 0) + amount
		return
	end
	local flow = if isSource then Enum.AnalyticsEconomyFlowType.Source else Enum.AnalyticsEconomyFlowType.Sink
	log(function()
		AnalyticsService:LogEconomyEvent(
			player,
			flow,
			CURRENCY,
			math.floor(amount),
			math.floor(data.coins),
			transaction,
			sku
		)
	end)
end

local function flushProduction()
	for player, amount in pendingProduction do
		local data = DataService.get(player)
		if data and amount >= 1 then
			log(function()
				AnalyticsService:LogEconomyEvent(
					player,
					Enum.AnalyticsEconomyFlowType.Source,
					CURRENCY,
					math.floor(amount),
					math.floor(data.coins),
					"Production"
				)
			end)
		end
	end
	table.clear(pendingProduction)
end

function TelemetryService.init() end

function TelemetryService.start()
	Players.PlayerRemoving:Connect(function(player)
		pendingProduction[player] = nil
	end)
	task.spawn(function()
		while true do
			task.wait(ECONOMY_FLUSH_INTERVAL)
			flushProduction()
		end
	end)
	print("[TelemetryService] iniciado")
end

return TelemetryService
