--!strict
-- Tipos compartidos entre servidor y cliente.

-- Contrato de cada service y controller (CLAUDE.md, «Arquitectura»).
export type Lifecycle = {
	init: () -> (),
	start: () -> (),
}

export type MachineSlot = {
	id: string,
	level: number,
}

export type GenomeSummary = {
	species: string,
	traits: { string },
}

-- Datos guardados del jugador, esquema versión 1 (GDD, sección L).
-- Cualquier cambio sube la versión y añade una migración en DataService.
export type PlayerData = {
	version: number,
	coins: number,
	resources: { wood: number, stone: number, fruit: number },
	giant: {
		species: string, -- "Turtle" | "Elephant" | "Giraffe"
		traits: { string }, -- 2 rasgos o mutaciones
		level: number, -- 1..10
		growthFruit: number, -- Fruta acumulada hacia el siguiente nivel
		machines: { [number]: MachineSlot }, -- por hueco
		skin: string?,
	},
	egg: { species: string, traits: { string }, hatchAt: number }?, -- os.time()
	lineage: { generation: number, ancestors: { GenomeSummary } },
	traitBook: { [string]: boolean }, -- clave "Especie:rasgoA+rasgoB"
	lastLogout: number,
	passes: { [string]: boolean },
	purchaseHistory: { [string]: boolean }, -- PurchaseId ya procesados
}

return {}
