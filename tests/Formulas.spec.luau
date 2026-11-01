--!strict
local Formulas = require("../src/shared/Formulas")

local tests: { [string]: () -> () } = {}

tests["la primera Sierra es gratis y las siguientes suben un 30 %"] = function()
	assert(Formulas.machinePrice(60, 0, true, 1.3) == 0, "Formulas.machinePrice(60, 0, true, 1.3) == 0")
	assert(Formulas.machinePrice(60, 1, true, 1.3) == 60, "Formulas.machinePrice(60, 1, true, 1.3) == 60")
	assert(Formulas.machinePrice(60, 2, true, 1.3) == 78, "Formulas.machinePrice(60, 2, true, 1.3) == 78")
	assert(Formulas.machinePrice(25, 0, false, 1.3) == 25, "Formulas.machinePrice(25, 0, false, 1.3) == 25")
	assert(Formulas.machinePrice(25, 1, false, 1.3) == 33, "Formulas.machinePrice(25, 1, false, 1.3) == 33")
end

tests["las mejoras cuestan x1,6 por nivel"] = function()
	assert(Formulas.upgradeCost(100, 1, 1.6) == 160, "Formulas.upgradeCost(100, 1, 1.6) == 160")
	assert(Formulas.upgradeCost(100, 2, 1.6) == 256, "Formulas.upgradeCost(100, 2, 1.6) == 256")
end

tests["capacidad del almacén"] = function()
	assert(Formulas.storageCapacity(100, {}, false) == 100, "Formulas.storageCapacity(100, {}, false) == 100")
	assert(
		Formulas.storageCapacity(100, { 100, 140 }, false) == 340,
		"Formulas.storageCapacity(100, { 100, 140 }, false) == 340"
	)
	assert(Formulas.storageCapacity(100, { 100 }, true) == 400, "Formulas.storageCapacity(100, { 100 }, true) == 400")
end

tests["crecimiento: sube varios niveles y se para en el adulto"] = function()
	local need = { 12, 30, 60 }
	local r = Formulas.applyGrowth(1, 0, 50, need)
	assert(r.level == 3 and r.growthFruit == 8 and r.levelsGained == 2, `{r.level} {r.growthFruit}`)
	local adult = Formulas.applyGrowth(3, 0, 1000, need)
	assert(adult.level == 4 and adult.growthFruit == 0, "adult.level == 4 and adult.growthFruit == 0")
end

tests["multiplicador de lo procesado"] = function()
	local base = {
		polishBonus = 0,
		glow = false,
		glowMultiplier = 1.1,
		generation = 1,
		generationBonus = 0.15,
		doubleCoins = false,
		socialBonus = 0,
	}
	assert(Formulas.processedMultiplier(base) == 1, "Formulas.processedMultiplier(base) == 1")
	local rich = table.clone(base)
	rich.generation = 3
	rich.doubleCoins = true
	assert(
		math.abs(Formulas.processedMultiplier(rich) - 2.6) < 1e-9,
		"math.abs(Formulas.processedMultiplier(rich) - 2.6) < 1e-9"
	)
end

tests["pastoreo nocturno con tope de 8 h"] = function()
	assert(
		Formulas.offlineCoins(3600, 10, 0.1, 8 * 3600) == 3600,
		"Formulas.offlineCoins(3600, 10, 0.1, 8 * 3600) == 3600"
	)
	assert(
		Formulas.offlineCoins(100 * 3600, 10, 0.1, 8 * 3600) == 28800,
		"Formulas.offlineCoins(100 * 3600, 10, 0.1, 8 * 3600) == 28800"
	)
end

tests["bonus de manada con tope"] = function()
	assert(
		math.abs(Formulas.herdBonus(2, 0.1, 0.4) - 0.2) < 1e-9,
		"math.abs(Formulas.herdBonus(2, 0.1, 0.4) - 0.2) < 1e-9"
	)
	assert(Formulas.herdBonus(9, 0.1, 0.4) == 0.4, "Formulas.herdBonus(9, 0.1, 0.4) == 0.4")
end

tests["clave del Libro de rasgos ordenada"] = function()
	assert(Formulas.traitBookKey("Turtle", { "ToughSkin", "Shell" }) == "Turtle:Shell+ToughSkin", "clave ordenada")
end

return tests
