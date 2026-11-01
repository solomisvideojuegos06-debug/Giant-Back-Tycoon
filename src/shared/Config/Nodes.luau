--!strict
-- Config/Nodes: nodos de recursos (GDD, sección E, «Nodos de recursos»).
-- El rendimiento se multiplica por el de la zona (x1, x2, x4, x8).

export type NodeDef = {
	resource: "wood" | "stone" | "fruit",
	yield: number,
	tall: boolean?, -- árbol frutal alto: Cuello largo o nivel tallTreeLevel
}

local Nodes = table.freeze({
	respawnTime = 30, -- s
	tallTreeLevel = 8, -- nivel a partir del cual se alcanzan los árboles altos sin Cuello largo
	minSpacing = 9, -- separación mínima entre nodos al generarlos
	seed = 20261101, -- semilla del reparto (mismo mapa en todos los servidores)

	types = table.freeze({
		Tree = { resource = "wood", yield = 5 } :: NodeDef,
		Palm = { resource = "wood", yield = 5 } :: NodeDef,
		Rock = { resource = "stone", yield = 4 } :: NodeDef,
		Coral = { resource = "stone", yield = 4 } :: NodeDef,
		Crystal = { resource = "stone", yield = 4 } :: NodeDef,
		Bush = { resource = "fruit", yield = 3 } :: NodeDef,
		TallFruitTree = { resource = "fruit", yield = 15, tall = true } :: NodeDef,
	}),
})

return Nodes
