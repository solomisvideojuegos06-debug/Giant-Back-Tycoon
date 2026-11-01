--!strict
-- Config/Mutations: probabilidad y lista de mutaciones raras (GDD, sección F).
-- Los efectos de cada mutación están en Config/Traits.

local Mutations = table.freeze({
	chance = 0.05, -- por cría, sustituye a uno de los rasgos
	list = table.freeze({ "Gigantism", "Glow", "DoubleStomach" }),
	-- Rasgos normales que pueden tener los gigantes salvajes.
	normalTraits = table.freeze({ "Shell", "ToughSkin", "WideFeet", "Trunk", "LongNeck", "Stride" }),
})

return Mutations
