--!strict
-- Config/Machines: máquinas del lomo (GDD, sección E, «Máquinas del lomo»).

export type MachineKind = "processor" | "storage" | "bonus"

export type MachineDef = {
	id: string,
	displayName: string,
	description: string,
	kind: MachineKind,
	price: number, -- monedas (la primera Sierra es gratis: firstFree)
	firstFree: boolean?,
	input: string?, -- "wood" | "stone" (procesadoras)
	rate: number?, -- unidades por segundo a nivel 1
	value: number?, -- monedas por unidad procesada
	capacity: number?, -- almacén: capacidad extra por recurso a nivel 1
	bonus: number?, -- taller: bonus al valor de lo procesado a nivel 1
	color: Color3,
	order: number,
}

local list: { MachineDef } = {
	{
		id = "Saw",
		displayName = "Sierra",
		description = "1 Madera/s → 2 monedas",
		kind = "processor",
		price = 60,
		firstFree = true,
		input = "wood",
		rate = 1,
		value = 2,
		color = Color3.fromRGB(205, 120, 60),
		order = 1,
	},
	{
		id = "Crusher",
		displayName = "Trituradora",
		description = "1 Piedra/s → 3 monedas",
		kind = "processor",
		price = 25,
		input = "stone",
		rate = 1,
		value = 3,
		color = Color3.fromRGB(120, 130, 150),
		order = 2,
	},
	{
		id = "Storage",
		displayName = "Almacén",
		description = "+100 de capacidad por recurso",
		kind = "storage",
		price = 150,
		capacity = 100,
		color = Color3.fromRGB(180, 140, 90),
		order = 3,
	},
	{
		id = "IndustrialSaw",
		displayName = "Sierra industrial",
		description = "3 Madera/s → 2 monedas",
		kind = "processor",
		price = 800,
		input = "wood",
		rate = 3,
		value = 2,
		color = Color3.fromRGB(230, 90, 40),
		order = 4,
	},
	{
		id = "RockMill",
		displayName = "Molino de roca",
		description = "3 Piedra/s → 3 monedas",
		kind = "processor",
		price = 1500,
		input = "stone",
		rate = 3,
		value = 3,
		color = Color3.fromRGB(90, 100, 130),
		order = 5,
	},
	{
		id = "PolishWorkshop",
		displayName = "Taller de pulido",
		description = "+25 % al valor de todo lo procesado",
		kind = "bonus",
		price = 4000,
		bonus = 0.25,
		color = Color3.fromRGB(80, 200, 220),
		order = 6,
	},
}

local byId: { [string]: MachineDef } = {}
for _, def in list do
	byId[def.id] = def
end

local Machines = table.freeze({
	list = table.freeze(list),
	byId = table.freeze(byId),
	maxLevel = 5,
	speedPerLevel = 0.4, -- +40 % por nivel (también capacidad y bonus)
	upgradeCostMultiplier = 1.6, -- coste x1,6 por nivel
	repeatCostMultiplier = 1.3, -- cada máquina del mismo tipo, +30 %
	starting = "Saw", -- la Sierra regalada del hueco 1
})

return Machines
