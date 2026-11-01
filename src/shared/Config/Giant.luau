--!strict
-- Config/Giant: movimiento, red y presentación del gigante (hito M1).
-- Las distancias están en studs a escala 1 y se multiplican por la escala del
-- gigante salvo que se indique lo contrario.

local Giant = table.freeze({
	movement = table.freeze({
		baseSpeed = 10, -- studs/s a escala 1; velocidad = baseSpeed * escala
		acceleration = 8, -- studs/s² a escala 1
		deceleration = 14, -- studs/s² a escala 1
		turnRate = math.rad(75), -- rad/s
		-- Si el giro pendiente supera este ángulo, el gigante gira casi parado.
		fullTurnAngle = math.rad(100),
		maxStepUp = 4, -- desnivel máximo que sube de golpe (escala con el gigante)
		maxSlope = 0.5, -- pendiente máxima (subida / distancia) que puede remontar
		frontProbeDistance = 30, -- distancia por delante en la que se mira el terreno
		groundProbeHeight = 300, -- desde cuánto por encima se busca el suelo (fija)
		groundProbeDepth = 600, -- hasta cuánto por debajo (fija)
		inputTimeout = 0.5, -- s sin DriveInput: el gigante se para
	}),

	spawn = table.freeze({
		center = Vector3.new(0, 0, 0),
		radius = 90, -- los gigantes aparecen en un círculo alrededor del centro
		slots = 6, -- jugadores por servidor
	}),

	network = table.freeze({
		snapshotRate = 20, -- instantáneas de posición por segundo (servidor → clientes)
		driveInputRate = 20, -- máximo de DriveInput por segundo (GDD, sección L)
		driveInputBurst = 5,
		riderRate = 15, -- RiderUpdate por segundo y jugador
		riderBurst = 5,
	}),

	-- Validación del conductor en el servidor: el personaje debe estar cerca del
	-- asiento. Se tolera el retraso de red, que crece con la velocidad.
	driver = table.freeze({
		maxSeatDistance = 16, -- escala con el gigante
		lagAllowance = 0.75, -- s de movimiento a máxima velocidad que se toleran
	}),

	render = table.freeze({
		minDelay = 0.08, -- s de retraso mínimo de interpolación
		maxDelay = 0.4,
		delayIntervals = 1.5, -- intervalos de instantánea añadidos a la latencia
		maxExtrapolation = 0.25, -- s que se extrapola si faltan instantáneas
		bufferSize = 12, -- instantáneas guardadas por gigante
		scaleChangeDuration = 1.0, -- s que tarda en cambiar de escala
		strideLength = 12, -- studs avanzados por ciclo de pasos (escala)
		legLift = 2, -- altura a la que levanta las patas (escala)
		bodyBob = 0.25, -- rebote del cuerpo al pisar (escala)
	}),

	platform = table.freeze({
		attachRayLength = 40, -- studs (fijo) bajo el personaje para saber si pisa un gigante
		seatHeight = 2.6, -- altura del HumanoidRootPart sobre el asiento (fija)
		riderStaleTime = 0.5, -- s sin RiderUpdate: se deja de corregir a ese jugador
		riderSmoothing = 15, -- suavizado de la posición de otros jugadores (1/s)
		maxRiderOffset = 60, -- studs a escala 1: más lejos se considera trampa
	}),

	prompt = table.freeze({
		driveDistance = 14, -- distancia para «Conducir» (escala con el gigante)
	}),

	debug = table.freeze({
		levelCommand = "/nivel", -- solo en Studio: «/nivel 7»
	}),
})

return Giant
