--!strict
-- Tipos compartidos entre servidor y cliente.

-- Contrato de cada service y controller (CLAUDE.md, «Arquitectura»).
-- priority (opcional): los de menor valor hacen init() antes (por defecto 10).
export type Lifecycle = {
	init: () -> (),
	start: () -> (),
	priority: number?,
}

export type MachineSlot = {
	id: string,
	level: number,
}

export type GenomeSummary = {
	species: string,
	traits: { string },
}

export type Egg = {
	species: string,
	traits: { string },
	hatchAt: number, -- os.time()
}

--[[
	Datos guardados del jugador.

	Versión 1: la del GDD (sección L).
	Versión 2 (DataService migra la 1 a la 2):
	  - `egg` pasa a `eggs` (lista) para el pase Nido doble.
	  - `giant.machines` usa como clave el hueco en texto ("1", "2"…): los
	    DataStores no admiten listas con huecos vacíos.
	  - nuevos `autopilot` (preferencia) y `funnel` (pasos de analítica ya enviados).
]]
export type PlayerData = {
	version: number,
	coins: number,
	resources: { wood: number, stone: number, fruit: number },
	giant: {
		species: string, -- "Turtle" | "Elephant" | "Giraffe"
		traits: { string }, -- 2 rasgos o mutaciones
		level: number, -- 1..10
		growthFruit: number, -- Fruta acumulada hacia el siguiente nivel
		machines: { [string]: MachineSlot }, -- por hueco ("1".."14")
		skin: string?,
	},
	eggs: { Egg },
	lineage: { generation: number, ancestors: { GenomeSummary } },
	traitBook: { [string]: boolean }, -- clave "Especie:rasgoA+rasgoB"
	lastLogout: number,
	passes: { [string]: boolean },
	purchaseHistory: { [string]: boolean }, -- PurchaseId ya procesados
	autopilot: boolean,
	funnel: { [string]: boolean },
}

return {}
