--!strict
-- Config/Levels: niveles del gigante (GDD, sección E, «Crecimiento»).
-- Hito M1: solo escala y huecos, que necesita el modelo. La Fruta por nivel
-- y los desbloqueos se añaden en el hito M4.

export type LevelInfo = {
	scale: number, -- escala del gigante respecto al nivel 1
	machineSlots: number, -- huecos de máquina (sin contar rasgos)
}

local Levels: { LevelInfo } = {
	{ scale = 1.0, machineSlots = 2 },
	{ scale = 1.2, machineSlots = 3 },
	{ scale = 1.4, machineSlots = 4 },
	{ scale = 1.6, machineSlots = 5 },
	{ scale = 1.8, machineSlots = 6 },
	{ scale = 2.0, machineSlots = 7 },
	{ scale = 2.25, machineSlots = 8 },
	{ scale = 2.5, machineSlots = 9 },
	{ scale = 2.75, machineSlots = 10 },
	{ scale = 3.0, machineSlots = 12 }, -- adulto
}

return table.freeze(Levels)
