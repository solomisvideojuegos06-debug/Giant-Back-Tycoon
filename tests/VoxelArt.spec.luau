--!strict
local VoxelArt = require("../src/shared/VoxelArt")

local PALETTE = { primary = { 100, 200, 80 }, secondary = { 50, 120, 50 }, accent = { 240, 200, 110 } }

local tests: { [string]: () -> () } = {}

tests["las tres especies tienen cuerpo, 4 patas, asiento, cubierta y 14 huecos"] = function()
	for _, species in { "Turtle", "Elephant", "Giraffe" } do
		local rig = VoxelArt.giant(species, PALETTE)
		assert(#rig.boxes > 50 and #rig.boxes < 450, `{species}: {#rig.boxes} piezas`)
		assert(#rig.legs == 4, `{species}: patas`)
		assert(#rig.slots == 14, `{species}: huecos`)
		local named = {}
		for _, box in rig.boxes do
			if box.name then
				named[box.name] = true
			end
			assert(box.sx > 0 and box.sy > 0 and box.sz > 0, "tamaño positivo")
			assert(box.color[1] >= 0 and box.color[1] <= 255, "color válido")
		end
		assert(named.Seat and named.Deck, `{species}: faltan Seat o Deck`)
		assert(rig.seat[2] > rig.deckTop, `{species}: el asiento debe estar por encima de la cubierta`)
		for _, slot in rig.slots do
			assert(slot[2] == rig.deckTop, "los huecos están sobre la cubierta")
			assert(
				math.abs(slot[1]) <= rig.deckSize[1] / 2 and math.abs(slot[3]) <= rig.deckSize[2] / 2,
				"hueco dentro"
			)
		end
	end
end

tests["las piezas de las patas cuelgan de su cadera"] = function()
	local rig = VoxelArt.giant("Elephant", PALETTE)
	local hips = {}
	for _, leg in rig.legs do
		hips[leg.group] = leg.hip
	end
	for _, box in rig.boxes do
		local hip = hips[box.group]
		if hip then
			assert(box.y <= hip[2], "la pata está por debajo de la cadera")
			assert(math.abs(box.x - hip[1]) < 4 and math.abs(box.z - hip[3]) < 5, "la pata está bajo su cadera")
		end
	end
end

tests["las estatuas son de piedra gris"] = function()
	local rig = VoxelArt.statue("Turtle")
	for _, box in rig.boxes do
		assert(box.color[1] == box.color[2] or math.abs(box.color[1] - box.color[3]) < 12, "gris")
	end
end

tests["todos los nodos tienen piezas"] = function()
	for _, nodeType in { "Tree", "Palm", "Rock", "Coral", "Crystal", "Bush", "TallFruitTree" } do
		assert(#VoxelArt.node(nodeType, 0.5) >= 3, nodeType)
	end
end

return tests
