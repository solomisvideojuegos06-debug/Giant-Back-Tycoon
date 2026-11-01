--!strict
--[[
	Formulas: costes, producción, capacidad y multiplicadores (GDD, sección E).
	Funciones puras, sin dependencias de Roblox: los services les pasan los
	valores de Config. Pruebas en tests/Formulas.spec.luau (`lune run tests`).
]]

local Formulas = {}

-- Precio de una máquina nueva sabiendo cuántas del mismo tipo tiene ya.
-- La primera de un tipo con firstFree es gratis; cada repetición, x repeatMultiplier.
function Formulas.machinePrice(basePrice: number, owned: number, firstFree: boolean, repeatMultiplier: number): number
	local paidBefore = if firstFree then owned - 1 else owned
	if paidBefore < 0 then
		return 0
	end
	return math.floor(basePrice * repeatMultiplier ^ paidBefore + 0.5)
end

-- Coste de subir una máquina de `level` a `level + 1`.
function Formulas.upgradeCost(basePrice: number, level: number, costMultiplier: number): number
	return math.floor(basePrice * costMultiplier ^ level + 0.5)
end

-- Factor de nivel: +perLevel por cada nivel por encima del 1.
function Formulas.levelFactor(level: number, perLevel: number): number
	return 1 + perLevel * (level - 1)
end

function Formulas.storageCapacity(base: number, storageExtras: { number }, bigStorage: boolean): number
	local total = base
	for _, extra in storageExtras do
		total += extra
	end
	return math.floor(total * (if bigStorage then 2 else 1))
end

-- Multiplicador de las monedas por generación del Linaje (acumulativo).
function Formulas.generationMultiplier(generation: number, bonusPerGeneration: number): number
	return 1 + bonusPerGeneration * math.max(generation - 1, 0)
end

export type CoinContext = {
	polishBonus: number, -- suma de los Talleres de pulido
	glow: boolean,
	glowMultiplier: number,
	generation: number,
	generationBonus: number,
	doubleCoins: boolean,
	socialBonus: number, -- manada + pasajeros
}

-- Multiplicador de todo lo procesado.
function Formulas.processedMultiplier(context: CoinContext): number
	local value = 1 + context.polishBonus
	if context.glow then
		value *= context.glowMultiplier
	end
	value *= Formulas.generationMultiplier(context.generation, context.generationBonus)
	if context.doubleCoins then
		value *= 2
	end
	return value * (1 + context.socialBonus)
end

-- Fruta que cuenta para crecer al dar `amount`.
function Formulas.feedValue(
	amount: number,
	feedMultiplier: number,
	generation: number,
	bonusPerGeneration: number
): number
	return amount * feedMultiplier * Formulas.generationMultiplier(generation, bonusPerGeneration)
end

export type GrowthResult = {
	level: number,
	growthFruit: number,
	levelsGained: number,
}

-- Aplica Fruta de crecimiento. fruitToNext[nivel] = nil en el nivel máximo.
function Formulas.applyGrowth(level: number, growthFruit: number, added: number, fruitToNext: { number }): GrowthResult
	local total = growthFruit + added
	local current = level
	local gained = 0
	while fruitToNext[current] ~= nil and total >= fruitToNext[current] do
		total -= fruitToNext[current]
		current += 1
		gained += 1
	end
	if fruitToNext[current] == nil then
		total = 0 -- adulto: no se acumula más
	end
	return { level = current, growthFruit = total, levelsGained = gained }
end

-- Monedas del pastoreo nocturno.
function Formulas.offlineCoins(seconds: number, coinsPerSecond: number, rate: number, maxSeconds: number): number
	local counted = math.clamp(seconds, 0, maxSeconds)
	return math.floor(counted * coinsPerSecond * rate)
end

-- Bonus de manada: +perGiant por cada gigante cercano, con un máximo.
function Formulas.herdBonus(nearbyGiants: number, perGiant: number, maxBonus: number): number
	return math.min(nearbyGiants * perGiant, maxBonus)
end

-- Clave del Libro de rasgos: "Especie:rasgoA+rasgoB" con los rasgos ordenados.
function Formulas.traitBookKey(species: string, traits: { string }): string
	local sorted = table.clone(traits)
	table.sort(sorted)
	return `{species}:{table.concat(sorted, "+")}`
end

return Formulas
