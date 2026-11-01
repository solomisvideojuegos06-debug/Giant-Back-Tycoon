--!strict
--[[
	Inheritance: herencia de especie, rasgos y mutaciones (GDD, sección F).
	Función pura, sin dependencias de Roblox. Pruebas en
	tests/Inheritance.spec.luau (`lune run tests`).

	- Especie: la de uno de los padres, al 50 %.
	- Rasgos: uno al azar de cada padre. Si salen repetidos, se vuelve a tirar
	  el segundo.
	- Mutación: con probabilidad `mutationChance`, sustituye uno de los dos
	  rasgos por una mutación rara que no tenga ya.
]]

export type Genome = {
	species: string,
	traits: { string },
}

-- random(): número en [0, 1)
export type Random = () -> number

local Inheritance = {}

local MAX_REROLLS = 32

local function pick<T>(list: { T }, random: Random): T
	local index = math.floor(random() * #list) + 1
	return list[math.clamp(index, 1, #list)]
end

local function without(list: { string }, value: string): { string }
	local result = {}
	for _, item in list do
		if item ~= value then
			table.insert(result, item)
		end
	end
	return result
end

function Inheritance.breed(
	parentA: Genome,
	parentB: Genome,
	mutationChance: number,
	mutations: { string },
	random: Random
): Genome
	local species = if random() < 0.5 then parentA.species else parentB.species

	local first = pick(parentA.traits, random)
	local second = pick(parentB.traits, random)
	local rerolls = 0
	while second == first and rerolls < MAX_REROLLS do
		second = pick(parentB.traits, random)
		rerolls += 1
	end
	if second == first then
		-- El segundo padre solo tiene ese rasgo: se toma otro del primero.
		local others = without(parentA.traits, first)
		second = if #others > 0 then pick(others, random) else first
	end

	local traits = { first, second }

	if #mutations > 0 and random() < mutationChance then
		local available = mutations
		for _, trait in traits do
			available = without(available, trait)
		end
		if #available > 0 then
			local slot = if random() < 0.5 then 1 else 2
			traits[slot] = pick(available, random)
		end
	end

	return { species = species, traits = traits }
end

return Inheritance
