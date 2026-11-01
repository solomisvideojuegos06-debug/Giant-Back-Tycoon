--!strict
--[[
	GiantModel: construye el modelo de bloques provisional de una especie a
	escala 1, a partir de Config/Species.

	- El pivote del modelo (la pieza Root) es el punto de apoyo en el suelo,
	  así que Model:ScaleTo() hace crecer al gigante sin despegarlo del suelo.
	- Puntos de anclaje en Root: Attachment «HeadSeat» (asiento) y «Slot1..N»
	  (huecos de máquina). El arte final debe conservarlos.
]]

local Species = require(script.Parent.Config.Species)

export type Leg = {
	part: BasePart,
	def: Species.LegDef,
}

export type Built = {
	model: Model,
	root: BasePart,
	seatPart: BasePart?,
	legs: { Leg },
}

local GiantModel = {}

local function makePart(name: string, size: Vector3, position: Vector3, color: Color3): Part
	local part = Instance.new("Part")
	part.Name = name
	part.Size = size
	part.CFrame = CFrame.new(position)
	part.Color = color
	part.Material = Enum.Material.Plastic
	part.Anchored = true
	part.CanCollide = true
	part.CanTouch = false
	part.CanQuery = true
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	return part
end

function GiantModel.build(speciesName: string, ownerUserId: number): Built
	local species = Species[speciesName]
	assert(species, `Especie desconocida: {speciesName}`)
	local body = species.body

	local model = Instance.new("Model")
	model.Name = `Giant_{ownerUserId}`
	model:SetAttribute("OwnerUserId", ownerUserId)

	local root = makePart("Root", Vector3.one, Vector3.zero, Color3.new(1, 1, 1))
	root.Transparency = 1
	root.CanCollide = false
	root.CanQuery = false
	root.Parent = model
	model.PrimaryPart = root

	local seatPart: BasePart? = nil
	for _, def in body.parts do
		local part = makePart(def.name, def.size, def.position, def.color)
		part.Material = def.material or Enum.Material.Plastic
		part.CanCollide = def.collide ~= false
		part.Parent = model
		if def.name == "Seat" then
			seatPart = part
		end
	end

	local legs: { Leg } = {}
	for _, def in body.legs do
		local part = makePart(def.name, def.size, def.position, def.color)
		part.Parent = model
		table.insert(legs, { part = part, def = def })
	end

	local seat = Instance.new("Attachment")
	seat.Name = "HeadSeat"
	seat.Position = body.seat
	seat.Parent = root

	for index, position in body.slots do
		local slot = Instance.new("Attachment")
		slot.Name = `Slot{index}`
		slot.Position = position
		slot.Parent = root
	end

	return {
		model = model,
		root = root,
		seatPart = seatPart,
		legs = legs,
	}
end

return GiantModel
