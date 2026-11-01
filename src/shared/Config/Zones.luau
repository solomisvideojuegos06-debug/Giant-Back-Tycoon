--!strict
--[[
	Config/Zones: el continente compartido (GDD, sección E, «Zonas»).
	Las zonas son franjas a lo largo del eje X, de la Pradera a las Montañas.
	MapService construye el mapa a partir de esta tabla.
]]

export type Rect = { minX: number, maxX: number, minZ: number, maxZ: number }

export type SlowArea = {
	kind: "water" | "thorns",
	rect: Rect,
}

export type NodeSpawn = {
	nodeType: string, -- clave de Config/Nodes
	count: number,
}

export type ZoneDef = {
	id: string,
	displayName: string,
	minLevel: number,
	rect: Rect,
	multiplier: number, -- rendimiento de los nodos (x1, x2, x4, x8)
	groundColor: Color3,
	groundMaterial: Enum.Material,
	nodes: { NodeSpawn },
	slowAreas: { SlowArea },
	borderColor: Color3, -- franja que separa esta zona de la anterior
}

local Z_MIN, Z_MAX = -500, 500

local list: { ZoneDef } = {
	{
		id = "Meadow",
		displayName = "Pradera",
		minLevel = 1,
		rect = { minX = -1100, maxX = -350, minZ = Z_MIN, maxZ = Z_MAX },
		multiplier = 1,
		groundColor = Color3.fromRGB(110, 200, 80),
		groundMaterial = Enum.Material.Grass,
		nodes = {
			{ nodeType = "Tree", count = 80 },
			{ nodeType = "Rock", count = 60 },
			{ nodeType = "Bush", count = 70 },
		},
		slowAreas = {},
		borderColor = Color3.fromRGB(110, 200, 80),
	},
	{
		id = "TallForest",
		displayName = "Bosque alto",
		minLevel = 3,
		rect = { minX = -350, maxX = 150, minZ = Z_MIN, maxZ = Z_MAX },
		multiplier = 2,
		groundColor = Color3.fromRGB(60, 150, 60),
		groundMaterial = Enum.Material.LeafyGrass,
		nodes = {
			{ nodeType = "Tree", count = 90 },
			{ nodeType = "TallFruitTree", count = 25 },
			{ nodeType = "Rock", count = 20 },
			{ nodeType = "Bush", count = 25 },
		},
		slowAreas = {},
		borderColor = Color3.fromRGB(70, 150, 230), -- río
	},
	{
		id = "Coast",
		displayName = "Costa",
		minLevel = 5,
		rect = { minX = 150, maxX = 600, minZ = Z_MIN, maxZ = Z_MAX },
		multiplier = 4,
		groundColor = Color3.fromRGB(240, 220, 150),
		groundMaterial = Enum.Material.Sand,
		nodes = {
			{ nodeType = "Coral", count = 55 },
			{ nodeType = "Palm", count = 30 },
			{ nodeType = "Bush", count = 30 },
		},
		slowAreas = {
			{ kind = "water", rect = { minX = 230, maxX = 420, minZ = -320, maxZ = -80 } },
			{ kind = "water", rect = { minX = 380, maxX = 570, minZ = 90, maxZ = 360 } },
		},
		borderColor = Color3.fromRGB(200, 170, 110), -- dunas
	},
	{
		id = "Mountains",
		displayName = "Montañas",
		minLevel = 7,
		rect = { minX = 600, maxX = 1000, minZ = Z_MIN, maxZ = Z_MAX },
		multiplier = 8,
		groundColor = Color3.fromRGB(140, 140, 150),
		groundMaterial = Enum.Material.Slate,
		nodes = {
			{ nodeType = "Crystal", count = 45 },
			{ nodeType = "Rock", count = 30 },
			{ nodeType = "Bush", count = 25 },
		},
		slowAreas = {
			{ kind = "thorns", rect = { minX = 690, maxX = 850, minZ = -400, maxZ = -150 } },
			{ kind = "thorns", rect = { minX = 780, maxX = 960, minZ = 120, maxZ = 380 } },
		},
		borderColor = Color3.fromRGB(110, 100, 95), -- ladera
	},
}

local byId: { [string]: ZoneDef } = {}
for _, zone in list do
	byId[zone.id] = zone
end

local Zones = table.freeze({
	list = table.freeze(list),
	byId = table.freeze(byId),
	borderWidth = 30, -- ancho de la franja entre zonas
	slowFactor = 0.55, -- velocidad en agua o espinos sin el rasgo adecuado

	-- Nodos concentrados junto al rancho (GDD, sección D: nada de caminar sin recompensa).
	clusterCenter = Vector3.new(-760, 0, 0),
	clusterRadius = 190,
	clusterShare = 0.6, -- parte de los nodos de la Pradera que van aquí

	-- Suelo a cuadros (estilo bloques con studs).
	tileSize = 50,

	-- El rancho: una parcela por jugador en el lado oeste de la Pradera.
	-- Cada parcela tiene valla, cartel, nido (casa del gigante), plataforma
	-- para montar y las estatuas del Linaje.
	ranch = table.freeze({
		centerX = -1020, -- centro de las parcelas en X
		firstZ = -400, -- centro de la primera parcela en Z
		spacing = 160, -- distancia entre centros de parcela
		count = 6,
		size = 140, -- lado de la parcela
		gateWidth = 60, -- hueco de la valla en el lado este
		padOffset = Vector3.new(85, 0, -30), -- plataforma de montar (fuera, junto a la puerta)
		spawnOffset = Vector3.new(90, 0, 10), -- donde aparece el jugador
		statueX = -60, -- estatuas junto a la valla oeste (relativo al centro)
		statueSpacing = 22,
		statuesShown = 6,
		statueScale = 0.45,
		returnDelay = 12, -- s sin el dueño encima: el gigante vuelve a casa
		returnTimeout = 45, -- s volviendo: si se atasca, aparece en casa
		homeRadius = 12, -- a esta distancia ya está en casa
	}),
})

return Zones
