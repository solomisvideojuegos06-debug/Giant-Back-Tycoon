--!strict
--[[
	Config/Species: especies de gigante (GDD, sección F) y su cuerpo de bloques.

	Medidas a escala 1, en studs, relativas al punto de apoyo del gigante:
	el centro del suelo bajo el cuerpo. El gigante mira hacia -Z.
	Cada pieza tiene un «role» que decide su color: primary/secondary/accent
	salen de la paleta de la especie (o de la piel, Config/Skins); el resto
	tiene color fijo. El arte final debe respetar asiento, cubierta y huecos.
]]

export type Role = "primary" | "secondary" | "accent" | "deck" | "seat" | "eye" | "shine"

export type PartDef = {
	name: string,
	size: Vector3,
	position: Vector3,
	role: Role,
	collide: boolean?, -- por defecto true
}

export type LegDef = {
	name: string,
	size: Vector3,
	position: Vector3,
	phase: number, -- 0 o 0.5: las patas en diagonal pisan a la vez
}

export type BodyDef = {
	parts: { PartDef },
	legs: { LegDef },
	seat: Vector3, -- superficie del asiento de la cabeza
	head: Vector3, -- dónde va la barra de crecimiento (encima de la cabeza)
	deckTop: number, -- altura de la cubierta donde van las máquinas
	slots: { Vector3 }, -- huecos de máquina (superficie de la cubierta), en orden
	radius: number, -- radio horizontal aproximado del gigante
}

export type SpeciesDef = {
	displayName: string,
	traits: { string }, -- rasgos naturales de la especie
	palette: { primary: Color3, secondary: Color3, accent: Color3 },
	eggColor: Color3, -- color de la cáscara (pista de la especie)
	body: BodyDef,
}

-- 14 huecos en rejilla de 3 columnas (12 del adulto + 2 del Caparazón).
local function gridSlots(columnSpacing: number, firstRow: number, rowStep: number, deckTop: number): { Vector3 }
	local slots: { Vector3 } = {}
	for row = 0, 4 do
		for column = -1, 1 do
			if #slots < 14 then
				table.insert(slots, Vector3.new(column * columnSpacing, deckTop, firstRow + row * rowStep))
			end
		end
	end
	return slots
end

local function rims(width: number, length: number, y: number, height: number): { PartDef }
	local thickness = 1.5
	local halfW, halfL = width / 2, length / 2
	return {
		{
			name = "RimFront",
			size = Vector3.new(width + thickness * 2, height, thickness),
			position = Vector3.new(0, y, -halfL - thickness / 2),
			role = "secondary",
		},
		{
			name = "RimBack",
			size = Vector3.new(width + thickness * 2, height, thickness),
			position = Vector3.new(0, y, halfL + thickness / 2),
			role = "secondary",
		},
		{
			name = "RimLeft",
			size = Vector3.new(thickness, height, length),
			position = Vector3.new(-halfW - thickness / 2, y, 0),
			role = "secondary",
		},
		{
			name = "RimRight",
			size = Vector3.new(thickness, height, length),
			position = Vector3.new(halfW + thickness / 2, y, 0),
			role = "secondary",
		},
	}
end

local function join(...: { PartDef }): { PartDef }
	local result: { PartDef } = {}
	for _, list in { ... } do
		for _, part in list do
			table.insert(result, part)
		end
	end
	return result
end

local function eyes(x: number, y: number, z: number, size: number): { PartDef }
	return {
		{
			name = "EyeLeft",
			size = Vector3.new(size, size, 0.5),
			position = Vector3.new(-x, y, z),
			role = "eye",
			collide = false,
		},
		{
			name = "EyeRight",
			size = Vector3.new(size, size, 0.5),
			position = Vector3.new(x, y, z),
			role = "eye",
			collide = false,
		},
		{
			name = "ShineLeft",
			size = Vector3.new(size * 0.32, size * 0.32, 0.3),
			position = Vector3.new(-x + size * 0.2, y + size * 0.24, z - 0.3),
			role = "shine",
			collide = false,
		},
		{
			name = "ShineRight",
			size = Vector3.new(size * 0.32, size * 0.32, 0.3),
			position = Vector3.new(x + size * 0.2, y + size * 0.24, z - 0.3),
			role = "shine",
			collide = false,
		},
	}
end

-- Tortuga: cubierta amplia sobre el caparazón, cabeza baja delante.
local TURTLE_DECK = 12
local Turtle: SpeciesDef = {
	displayName = "Tortuga",
	traits = { "Shell", "ToughSkin" },
	palette = {
		primary = Color3.fromRGB(88, 196, 72),
		secondary = Color3.fromRGB(46, 125, 50),
		accent = Color3.fromRGB(240, 200, 110),
	},
	eggColor = Color3.fromRGB(120, 210, 100),
	body = {
		parts = join({
			{ name = "Belly", size = Vector3.new(26, 3, 34), position = Vector3.new(0, 9.5, 0), role = "accent" },
			{
				name = "Deck",
				size = Vector3.new(24, 1, 32),
				position = Vector3.new(0, TURTLE_DECK - 0.5, 0),
				role = "deck",
			},
			{ name = "Neck", size = Vector3.new(8, 5, 6), position = Vector3.new(0, 12.5, -20), role = "primary" },
			{ name = "Head", size = Vector3.new(12, 7, 11), position = Vector3.new(0, 13.5, -28), role = "primary" },
			{ name = "Seat", size = Vector3.new(4, 1, 4), position = Vector3.new(0, 17.5, -27), role = "seat" },
			{ name = "Tail", size = Vector3.new(3, 2, 4), position = Vector3.new(0, 9, 19), role = "primary" },
		}, rims(24, 32, 13.5, 3), eyes(3.5, 14.5, -33.6, 2.5)),
		legs = {
			{ name = "LegFrontLeft", size = Vector3.new(6, 9, 6), position = Vector3.new(-10, 4.5, -11), phase = 0 },
			{ name = "LegFrontRight", size = Vector3.new(6, 9, 6), position = Vector3.new(10, 4.5, -11), phase = 0.5 },
			{ name = "LegBackLeft", size = Vector3.new(6, 9, 6), position = Vector3.new(-10, 4.5, 11), phase = 0.5 },
			{ name = "LegBackRight", size = Vector3.new(6, 9, 6), position = Vector3.new(10, 4.5, 11), phase = 0 },
		},
		seat = Vector3.new(0, 18, -27),
		head = Vector3.new(0, 24, -28),
		deckTop = TURTLE_DECK,
		slots = gridSlots(8, -12.8, 6.4, TURTLE_DECK),
		radius = 24,
	},
}

-- Elefante: cuerpo alto, orejas grandes, trompa y colmillos.
local ELEPHANT_DECK = 23
local Elephant: SpeciesDef = {
	displayName = "Elefante",
	traits = { "WideFeet", "Trunk" },
	palette = {
		primary = Color3.fromRGB(150, 160, 178),
		secondary = Color3.fromRGB(105, 115, 135),
		accent = Color3.fromRGB(248, 242, 228),
	},
	eggColor = Color3.fromRGB(165, 175, 195),
	body = {
		parts = join({
			{ name = "Body", size = Vector3.new(24, 12, 32), position = Vector3.new(0, 16, 0), role = "primary" },
			{
				name = "Deck",
				size = Vector3.new(22, 1, 28),
				position = Vector3.new(0, ELEPHANT_DECK - 0.5, 0),
				role = "deck",
			},
			{ name = "Head", size = Vector3.new(14, 12, 10), position = Vector3.new(0, 18, -21), role = "primary" },
			{ name = "Seat", size = Vector3.new(4, 1, 4), position = Vector3.new(0, 24.5, -21), role = "seat" },
			{
				name = "EarLeft",
				size = Vector3.new(2, 11, 9),
				position = Vector3.new(-8, 18, -18),
				role = "secondary",
				collide = false,
			},
			{
				name = "EarRight",
				size = Vector3.new(2, 11, 9),
				position = Vector3.new(8, 18, -18),
				role = "secondary",
				collide = false,
			},
			{
				name = "TrunkUpper",
				size = Vector3.new(4, 7, 4),
				position = Vector3.new(0, 11.5, -27.5),
				role = "primary",
				collide = false,
			},
			{
				name = "TrunkLower",
				size = Vector3.new(3, 6, 3),
				position = Vector3.new(0, 5.5, -28.5),
				role = "primary",
				collide = false,
			},
			{
				name = "TuskLeft",
				size = Vector3.new(1.5, 1.5, 5),
				position = Vector3.new(-4.5, 13, -27.5),
				role = "accent",
				collide = false,
			},
			{
				name = "TuskRight",
				size = Vector3.new(1.5, 1.5, 5),
				position = Vector3.new(4.5, 13, -27.5),
				role = "accent",
				collide = false,
			},
			{
				name = "Tail",
				size = Vector3.new(1.5, 6, 1.5),
				position = Vector3.new(0, 15, 16.75),
				role = "secondary",
				collide = false,
			},
		}, rims(22, 28, 24.25, 2.5), eyes(4, 20, -26.3, 2)),
		legs = {
			{ name = "LegFrontLeft", size = Vector3.new(7, 10, 7), position = Vector3.new(-8.5, 5, -10), phase = 0 },
			{ name = "LegFrontRight", size = Vector3.new(7, 10, 7), position = Vector3.new(8.5, 5, -10), phase = 0.5 },
			{ name = "LegBackLeft", size = Vector3.new(7, 10, 7), position = Vector3.new(-8.5, 5, 10), phase = 0.5 },
			{ name = "LegBackRight", size = Vector3.new(7, 10, 7), position = Vector3.new(8.5, 5, 10), phase = 0 },
		},
		seat = Vector3.new(0, 25, -21),
		head = Vector3.new(0, 31, -21),
		deckTop = ELEPHANT_DECK,
		slots = gridSlots(7, -11.2, 5.6, ELEPHANT_DECK),
		radius = 24,
	},
}

-- Jirafa: patas largas, cubierta estrecha y la cabeza en lo alto del cuello.
local GIRAFFE_DECK = 27
local Giraffe: SpeciesDef = {
	displayName = "Jirafa",
	traits = { "LongNeck", "Stride" },
	palette = {
		primary = Color3.fromRGB(246, 200, 80),
		secondary = Color3.fromRGB(165, 100, 50),
		accent = Color3.fromRGB(120, 70, 40),
	},
	eggColor = Color3.fromRGB(250, 210, 110),
	body = {
		parts = join({
			{ name = "Body", size = Vector3.new(16, 8, 24), position = Vector3.new(0, 22, 0), role = "primary" },
			{
				name = "Deck",
				size = Vector3.new(14, 1, 22),
				position = Vector3.new(0, GIRAFFE_DECK - 0.5, 0),
				role = "deck",
			},
			{ name = "Neck", size = Vector3.new(5, 24, 5), position = Vector3.new(0, 37, -13), role = "primary" },
			{ name = "Head", size = Vector3.new(7, 6, 10), position = Vector3.new(0, 50, -16), role = "primary" },
			{ name = "Seat", size = Vector3.new(4, 1, 4), position = Vector3.new(0, 53.5, -15), role = "seat" },
			{
				name = "HornLeft",
				size = Vector3.new(1, 2.5, 1),
				position = Vector3.new(-2.6, 54.25, -11.8),
				role = "accent",
				collide = false,
			},
			{
				name = "HornRight",
				size = Vector3.new(1, 2.5, 1),
				position = Vector3.new(2.6, 54.25, -11.8),
				role = "accent",
				collide = false,
			},
			{
				name = "SpotA",
				size = Vector3.new(0.4, 3, 4),
				position = Vector3.new(-8.2, 22, -4),
				role = "secondary",
				collide = false,
			},
			{
				name = "SpotB",
				size = Vector3.new(0.4, 3, 4),
				position = Vector3.new(8.2, 21, 5),
				role = "secondary",
				collide = false,
			},
			{
				name = "SpotC",
				size = Vector3.new(5.4, 3, 0.4),
				position = Vector3.new(0, 38, -15.7),
				role = "secondary",
				collide = false,
			},
			{
				name = "Tail",
				size = Vector3.new(1, 6, 1),
				position = Vector3.new(0, 21, 12.5),
				role = "secondary",
				collide = false,
			},
		}, rims(14, 22, 28.25, 2.5), eyes(2.6, 51, -21.2, 1.4)),
		legs = {
			{ name = "LegFrontLeft", size = Vector3.new(4, 18, 4), position = Vector3.new(-6, 9, -9), phase = 0 },
			{ name = "LegFrontRight", size = Vector3.new(4, 18, 4), position = Vector3.new(6, 9, -9), phase = 0.5 },
			{ name = "LegBackLeft", size = Vector3.new(4, 18, 4), position = Vector3.new(-6, 9, 9), phase = 0.5 },
			{ name = "LegBackRight", size = Vector3.new(4, 18, 4), position = Vector3.new(6, 9, 9), phase = 0 },
		},
		seat = Vector3.new(0, 54, -15),
		head = Vector3.new(0, 59, -16),
		deckTop = GIRAFFE_DECK,
		slots = gridSlots(4.5, -8.4, 4.2, GIRAFFE_DECK),
		radius = 20,
	},
}

local Species: { [string]: SpeciesDef } = {
	Turtle = Turtle,
	Elephant = Elephant,
	Giraffe = Giraffe,
}

return table.freeze(Species)
