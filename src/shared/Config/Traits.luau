--!strict
-- Config/Traits: rasgos y mutaciones (GDD, sección F).
-- Los efectos son multiplicadores o sumas; los aplican los services.

export type TraitDef = {
	displayName: string,
	description: string,
	isMutation: boolean,
	color: Color3, -- color del dibujo en el huevo y de la etiqueta
	extraSlots: number?, -- Caparazón
	ignoresThorns: boolean?, -- Piel dura
	ignoresWater: boolean?, -- Patas anchas
	stompRadiusMultiplier: number?, -- Patas anchas
	fruitReach: number?, -- Trompa: studs extra para la Fruta
	reachesTallTrees: boolean?, -- Cuello largo
	speedMultiplier: number?, -- Zancada
	startLevel: number?, -- Gigantismo
	scaleMultiplier: number?, -- Gigantismo
	valueMultiplier: number?, -- Brillo
	feedMultiplier: number?, -- Doble estómago
}

local Traits: { [string]: TraitDef } = {
	Shell = {
		displayName = "Caparazón",
		description = "+2 huecos de máquina",
		isMutation = false,
		color = Color3.fromRGB(46, 125, 50),
		extraSlots = 2,
	},
	ToughSkin = {
		displayName = "Piel dura",
		description = "Los espinos no la frenan",
		isMutation = false,
		color = Color3.fromRGB(140, 90, 60),
		ignoresThorns = true,
	},
	WideFeet = {
		displayName = "Patas anchas",
		description = "Pisada +40 %; el agua no lo frena",
		isMutation = false,
		color = Color3.fromRGB(90, 140, 220),
		ignoresWater = true,
		stompRadiusMultiplier = 1.4,
	},
	Trunk = {
		displayName = "Trompa",
		description = "Recoge Fruta 10 studs más allá",
		isMutation = false,
		color = Color3.fromRGB(150, 160, 175),
		fruitReach = 10,
	},
	LongNeck = {
		displayName = "Cuello largo",
		description = "Recoge los árboles frutales altos",
		isMutation = false,
		color = Color3.fromRGB(245, 190, 60),
		reachesTallTrees = true,
	},
	Stride = {
		displayName = "Zancada",
		description = "+25 % de velocidad",
		isMutation = false,
		color = Color3.fromRGB(230, 120, 60),
		speedMultiplier = 1.25,
	},

	-- Mutaciones raras
	Gigantism = {
		displayName = "Gigantismo",
		description = "Nace en nivel 2 y con +10 % de escala",
		isMutation = true,
		color = Color3.fromRGB(200, 60, 200),
		startLevel = 2,
		scaleMultiplier = 1.1,
	},
	Glow = {
		displayName = "Brillo",
		description = "Brilla y todo lo procesado vale +10 %",
		isMutation = true,
		color = Color3.fromRGB(255, 240, 120),
		valueMultiplier = 1.1,
	},
	DoubleStomach = {
		displayName = "Doble estómago",
		description = "Cada Fruta dada cuenta como 1,5",
		isMutation = true,
		color = Color3.fromRGB(240, 90, 110),
		feedMultiplier = 1.5,
	},
}

return table.freeze(Traits)
