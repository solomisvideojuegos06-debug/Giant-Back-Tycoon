--!strict
-- Config/Levels: niveles del gigante (GDD, sección E, «Crecimiento»).

export type LevelInfo = {
	fruitToNext: number?, -- Fruta para subir al siguiente (nil en el nivel máximo)
	scale: number, -- escala del gigante respecto al nivel 1
	machineSlots: number, -- huecos de máquina (sin contar rasgos)
	unlocks: string?, -- texto para el objetivo de la interfaz
}

local Levels: { LevelInfo } = {
	{ fruitToNext = 12, scale = 1.0, machineSlots = 2 },
	{ fruitToNext = 30, scale = 1.2, machineSlots = 3 },
	{ fruitToNext = 60, scale = 1.4, machineSlots = 4, unlocks = "piloto automático y Bosque alto" },
	{ fruitToNext = 110, scale = 1.6, machineSlots = 5 },
	{ fruitToNext = 200, scale = 1.8, machineSlots = 6, unlocks = "la Costa" },
	{ fruitToNext = 350, scale = 2.0, machineSlots = 7 },
	{ fruitToNext = 600, scale = 2.25, machineSlots = 8, unlocks = "las Montañas" },
	{ fruitToNext = 1000, scale = 2.5, machineSlots = 9 },
	{ fruitToNext = 1600, scale = 2.75, machineSlots = 10 },
	{ fruitToNext = nil, scale = 3.0, machineSlots = 12, unlocks = "criar" }, -- adulto
}

return table.freeze(Levels)
