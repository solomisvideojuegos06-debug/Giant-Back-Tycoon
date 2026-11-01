--!strict
local Inheritance = require("../src/shared/Inheritance")

local MUTATIONS = { "Gigantism", "Glow", "DoubleStomach" }
local TURTLE = { species = "Turtle", traits = { "Shell", "ToughSkin" } }
local GIRAFFE = { species = "Giraffe", traits = { "LongNeck", "Stride" } }
local MIXED = { species = "Elephant", traits = { "Shell", "Trunk" } }

local function isMutation(trait: string): boolean
	return table.find(MUTATIONS, trait) ~= nil
end

local tests: { [string]: () -> () } = {}

local function simulate(a, b, chance: number, runs: number, check: (any) -> ())
	math.randomseed(12345)
	local random = function()
		return math.random()
	end
	for _ = 1, runs do
		check(Inheritance.breed(a, b, chance, MUTATIONS, random))
	end
end

tests["la especie es la de uno de los padres, ~50 %"] = function()
	local turtles = 0
	simulate(TURTLE, GIRAFFE, 0, 10000, function(child)
		assert(child.species == "Turtle" or child.species == "Giraffe", "especie ajena")
		if child.species == "Turtle" then
			turtles += 1
		end
	end)
	assert(turtles > 4700 and turtles < 5300, `tortugas: {turtles}`)
end

tests["un rasgo de cada padre y sin repetidos"] = function()
	simulate(TURTLE, GIRAFFE, 0, 10000, function(child)
		assert(#child.traits == 2, "deben ser 2 rasgos")
		assert(table.find(TURTLE.traits, child.traits[1]), "el primero viene del padre A")
		assert(table.find(GIRAFFE.traits, child.traits[2]), "el segundo viene del padre B")
	end)
	-- Padres con un rasgo en común: nunca sale repetido.
	simulate(TURTLE, MIXED, 0, 10000, function(child)
		assert(child.traits[1] ~= child.traits[2], `repetido: {child.traits[1]}`)
	end)
end

tests["5 % de mutación en 10.000 tiradas"] = function()
	local mutated = 0
	simulate(TURTLE, GIRAFFE, 0.05, 10000, function(child)
		local count = 0
		for _, trait in child.traits do
			if isMutation(trait) then
				count += 1
			end
		end
		assert(count <= 1, "como mucho una mutación")
		assert(child.traits[1] ~= child.traits[2], "sin repetidos")
		if count == 1 then
			mutated += 1
		end
	end)
	assert(mutated > 400 and mutated < 600, `mutaciones: {mutated} (esperado ~500)`)
end

tests["no repite una mutación que ya tiene un padre"] = function()
	local glowParent = { species = "Turtle", traits = { "Glow", "Shell" } }
	simulate(glowParent, glowParent, 1, 2000, function(child)
		assert(child.traits[1] ~= child.traits[2], "sin repetidos")
	end)
end

return tests
