--!strict
-- Config/Economy: parámetros generales de economía y progresión.
-- Todas son hipótesis de partida (GDD, sección E); se ajustan aquí.

local Economy = table.freeze({
	storageBase = 100, -- capacidad inicial por recurso
	fruitSellPrice = 1.5, -- monedas por Fruta vendida
	productionInterval = 1, -- s entre ticks de producción

	stomp = table.freeze({
		interval = 1.2, -- s entre pisadas
		radius = 10, -- studs x escala del gigante
		minSpeed = 0.5, -- studs/s: parado no pisa
		effectRange = 400, -- studs: clientes que reciben el efecto
	}),

	lineage = table.freeze({
		coinBonusPerGeneration = 0.15, -- +15 % monedas por generación (acumulativo)
		feedBonusPerGeneration = 0.10, -- +10 % al valor de la Fruta como alimento
		traitBookReward = 100, -- monedas por combinación nueva del Libro
		maxAncestors = 50, -- antepasados guardados
	}),

	breeding = table.freeze({
		adultLevel = 10,
		maxDistance = 60, -- studs entre los cuerpos de los dos gigantes
		hatchTime = 15 * 60, -- s
		requestTimeout = 30, -- s que dura una petición a otro jugador
		mutationBadgeId = 0, -- insignia por criar una mutación (0 = sin insignia todavía)
	}),

	wildGiantsPerZone = 3, -- uno de cada especie

	offline = table.freeze({
		rate = 0.10, -- pastoreo nocturno: 10 % del rendimiento
		maxSeconds = 8 * 3600,
		minSeconds = 60, -- por debajo no se muestra nada
	}),

	social = table.freeze({
		herdDistance = 80, -- studs entre cuerpos de gigantes
		herdBonusPerGiant = 0.10,
		herdBonusMax = 0.40,
		passengerBonus = 0.20, -- pasajero y anfitrión
		boardDistance = 250, -- studs máximos para subirse a otro gigante
		updateInterval = 1, -- s
	}),

	autopilot = table.freeze({
		minLevel = 3,
		speedFactor = 0.5, -- piloto gratuito a velocidad reducida
		waypointTimeout = 20, -- s antes de elegir otro destino
		zoneMargin = 60, -- studs de margen con el borde de la zona
		expertSearchRadius = 250, -- piloto experto: radio de búsqueda de nodos
	}),

	fruitRain = table.freeze({
		duration = 10 * 60,
		multiplier = 2,
	}),

	-- Ofertas (GDD, sección H): nunca antes de este tiempo de sesión.
	offers = table.freeze({
		minSessionTime = 5 * 60,
		banquetMinProgress = 0.6,
		fruitRainMinPlayers = 3,
		coinPackMaxWait = 120, -- s que faltan para la siguiente máquina
	}),
})

return Economy
