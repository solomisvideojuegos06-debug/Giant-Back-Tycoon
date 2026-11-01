--!strict
--[[
	Config/Species: especies de gigante.

	Hito M1: solo el cuerpo de bloques de la Tortuga (modelo provisional).
	Los rasgos, el Elefante y la Jirafa se añaden en el hito M7.

	Medidas a escala 1, en studs, relativas al punto de apoyo del gigante:
	el centro del suelo bajo el cuerpo. El gigante mira hacia -Z.
	El arte final (M9) debe respetar el asiento, la cubierta y los huecos.
]]

export type PartDef = {
	name: string,
	size: Vector3,
	position: Vector3,
	color: Color3,
	material: Enum.Material?,
	collide: boolean?, -- por defecto true
}

export type LegDef = {
	name: string,
	size: Vector3,
	position: Vector3,
	phase: number, -- 0 o 0.5: las patas en diagonal pisan a la vez
	color: Color3,
}

export type BodyDef = {
	parts: { PartDef },
	legs: { LegDef },
	seat: Vector3, -- superficie del asiento de la cabeza
	deckTop: number, -- altura de la cubierta donde van las máquinas
	slots: { Vector3 }, -- huecos de máquina (superficie de la cubierta), en orden
	radius: number, -- radio horizontal aproximado del gigante
}

export type SpeciesDef = {
	displayName: string,
	body: BodyDef,
}

local GREEN = Color3.fromRGB(88, 196, 72)
local DARK_GREEN = Color3.fromRGB(46, 125, 50)
local BELLY = Color3.fromRGB(240, 200, 110)
local WOOD = Color3.fromRGB(196, 140, 82)
local SEAT = Color3.fromRGB(170, 85, 40)
local EYE = Color3.fromRGB(25, 25, 25)
local EYE_SHINE = Color3.fromRGB(255, 255, 255)

local DECK_TOP = 12

-- Huecos en rejilla de 3 columnas sobre la cubierta (24 x 32), de delante atrás.
-- 14 huecos: 12 del nivel adulto + 2 del rasgo Caparazón.
local turtleSlots: { Vector3 } = {}
for row = 0, 4 do
	for column = -1, 1 do
		if #turtleSlots < 14 then
			table.insert(turtleSlots, Vector3.new(column * 8, DECK_TOP, -12.8 + row * 6.4))
		end
	end
end

local Turtle: SpeciesDef = {
	displayName = "Tortuga",
	body = {
		parts = {
			{ name = "Belly", size = Vector3.new(26, 3, 34), position = Vector3.new(0, 9.5, 0), color = BELLY },
			{
				name = "Deck",
				size = Vector3.new(24, 1, 32),
				position = Vector3.new(0, DECK_TOP - 0.5, 0),
				color = WOOD,
				material = Enum.Material.WoodPlanks,
			},
			-- Borde del caparazón: impide caerse sin querer (se puede saltar).
			{
				name = "RimFront",
				size = Vector3.new(27, 3, 1.5),
				position = Vector3.new(0, 13.5, -16.75),
				color = DARK_GREEN,
			},
			{
				name = "RimBack",
				size = Vector3.new(27, 3, 1.5),
				position = Vector3.new(0, 13.5, 16.75),
				color = DARK_GREEN,
			},
			{
				name = "RimLeft",
				size = Vector3.new(1.5, 3, 32),
				position = Vector3.new(-12.75, 13.5, 0),
				color = DARK_GREEN,
			},
			{
				name = "RimRight",
				size = Vector3.new(1.5, 3, 32),
				position = Vector3.new(12.75, 13.5, 0),
				color = DARK_GREEN,
			},
			{ name = "Neck", size = Vector3.new(8, 5, 6), position = Vector3.new(0, 12.5, -20), color = GREEN },
			{ name = "Head", size = Vector3.new(12, 7, 11), position = Vector3.new(0, 13.5, -28), color = GREEN },
			{ name = "Seat", size = Vector3.new(4, 1, 4), position = Vector3.new(0, 17.5, -27), color = SEAT },
			{
				name = "EyeLeft",
				size = Vector3.new(2.5, 2.5, 0.5),
				position = Vector3.new(-3.5, 14.5, -33.6),
				color = EYE,
				collide = false,
			},
			{
				name = "EyeRight",
				size = Vector3.new(2.5, 2.5, 0.5),
				position = Vector3.new(3.5, 14.5, -33.6),
				color = EYE,
				collide = false,
			},
			{
				name = "ShineLeft",
				size = Vector3.new(0.8, 0.8, 0.3),
				position = Vector3.new(-3.0, 15.1, -33.9),
				color = EYE_SHINE,
				collide = false,
			},
			{
				name = "ShineRight",
				size = Vector3.new(0.8, 0.8, 0.3),
				position = Vector3.new(4.0, 15.1, -33.9),
				color = EYE_SHINE,
				collide = false,
			},
			{ name = "Tail", size = Vector3.new(3, 2, 4), position = Vector3.new(0, 9, 19), color = GREEN },
		},
		legs = {
			{
				name = "LegFrontLeft",
				size = Vector3.new(6, 9, 6),
				position = Vector3.new(-10, 4.5, -11),
				phase = 0,
				color = GREEN,
			},
			{
				name = "LegFrontRight",
				size = Vector3.new(6, 9, 6),
				position = Vector3.new(10, 4.5, -11),
				phase = 0.5,
				color = GREEN,
			},
			{
				name = "LegBackLeft",
				size = Vector3.new(6, 9, 6),
				position = Vector3.new(-10, 4.5, 11),
				phase = 0.5,
				color = GREEN,
			},
			{
				name = "LegBackRight",
				size = Vector3.new(6, 9, 6),
				position = Vector3.new(10, 4.5, 11),
				phase = 0,
				color = GREEN,
			},
		},
		seat = Vector3.new(0, 18, -27),
		deckTop = DECK_TOP,
		slots = turtleSlots,
		radius = 24,
	},
}

local Species: { [string]: SpeciesDef } = {
	Turtle = Turtle,
}

return table.freeze(Species)
