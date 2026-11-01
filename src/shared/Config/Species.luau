--!strict
--[[
	Config/Species: especies de gigante (GDD, sección F).

	El cuerpo de bloques se genera en VoxelArt; aquí se leen de él las medidas
	que usa el juego (asiento, cubierta, huecos de máquina, radio) para que el
	modelo y la lógica nunca se desajusten. Medidas a escala 1, en studs,
	relativas al punto de apoyo del gigante; el gigante mira hacia -Z.
]]

local VoxelArt = require(script.Parent.Parent.VoxelArt)

export type BodyDef = {
	seat: Vector3, -- superficie del asiento de la cabeza
	head: Vector3, -- donde va la etiqueta (encima de la cabeza)
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

local function vector(values: { number }): Vector3
	return Vector3.new(values[1], values[2], values[3])
end

local function rgb(color: Color3): { number }
	return { math.floor(color.R * 255 + 0.5), math.floor(color.G * 255 + 0.5), math.floor(color.B * 255 + 0.5) }
end

local function define(
	id: string,
	displayName: string,
	traits: { string },
	palette: { primary: Color3, secondary: Color3, accent: Color3 },
	eggColor: Color3
): SpeciesDef
	local rig = VoxelArt.giant(id, {
		primary = rgb(palette.primary),
		secondary = rgb(palette.secondary),
		accent = rgb(palette.accent),
	})
	local slots: { Vector3 } = {}
	for _, slot in rig.slots do
		table.insert(slots, vector(slot))
	end
	return {
		displayName = displayName,
		traits = traits,
		palette = palette,
		eggColor = eggColor,
		body = {
			seat = vector(rig.seat),
			head = vector(rig.head),
			deckTop = rig.deckTop,
			slots = slots,
			radius = rig.radius,
		},
	}
end

local Species: { [string]: SpeciesDef } = {
	Turtle = define("Turtle", "Tortuga", { "Shell", "ToughSkin" }, {
		primary = Color3.fromRGB(88, 196, 72),
		secondary = Color3.fromRGB(46, 125, 50),
		accent = Color3.fromRGB(240, 200, 110),
	}, Color3.fromRGB(120, 210, 100)),

	Elephant = define("Elephant", "Elefante", { "WideFeet", "Trunk" }, {
		primary = Color3.fromRGB(150, 160, 178),
		secondary = Color3.fromRGB(210, 60, 70),
		accent = Color3.fromRGB(255, 205, 60),
	}, Color3.fromRGB(165, 175, 195)),

	Giraffe = define("Giraffe", "Jirafa", { "LongNeck", "Stride" }, {
		primary = Color3.fromRGB(246, 200, 80),
		secondary = Color3.fromRGB(165, 100, 50),
		accent = Color3.fromRGB(120, 70, 40),
	}, Color3.fromRGB(250, 210, 110)),
}

return table.freeze(Species)
