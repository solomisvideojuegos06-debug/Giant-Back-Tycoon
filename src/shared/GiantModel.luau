--!strict
--[[
	GiantModel: construye el modelo de bloques de una especie a escala 1, a
	partir de Config/Species (y de una piel de Config/Skins, si la hay).

	- El pivote del modelo (la pieza Root) es el punto de apoyo en el suelo,
	  así que Model:ScaleTo() hace crecer al gigante sin despegarlo del suelo.
	- Puntos de anclaje en Root: Attachment «HeadSeat» (asiento) y «Slot1..N»
	  (huecos de máquina). El arte final debe conservarlos.
	- Lo usan el cliente (gigantes) y el servidor (estatuas del Salón del Linaje).
]]

local Skins = require(script.Parent.Config.Skins)
local Species = require(script.Parent.Config.Species)

export type Leg = {
	part: BasePart,
	def: Species.LegDef,
}

export type Built = {
	model: Model,
	root: BasePart,
	seatPart: BasePart?,
	headPart: BasePart?,
	legs: { Leg },
}

export type BuildOptions = {
	skin: string?,
	glow: boolean?, -- mutación Brillo
	statue: boolean?, -- todo de piedra, sin colisión (Salón del Linaje)
}

local FIXED_COLORS: { [string]: Color3 } = {
	deck = Color3.fromRGB(196, 140, 82),
	seat = Color3.fromRGB(170, 85, 40),
	eye = Color3.fromRGB(25, 25, 25),
	shine = Color3.fromRGB(255, 255, 255),
}
local STATUE_COLOR = Color3.fromRGB(175, 175, 168)
local GLOW_COLOR = Color3.fromRGB(255, 240, 150)

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

function GiantModel.build(speciesName: string, ownerId: number, options: BuildOptions?): Built
	local species = Species[speciesName] or Species.Turtle
	local body = species.body
	local opts: BuildOptions = options or {}
	local skin = if opts.skin then Skins[opts.skin] else nil

	local palette: { [string]: Color3 } = {
		primary = if skin then skin.primary else species.palette.primary,
		secondary = if skin then skin.secondary else species.palette.secondary,
		accent = if skin then skin.accent else species.palette.accent,
	}

	local function colorFor(role: string): Color3
		if opts.statue then
			return STATUE_COLOR
		end
		return palette[role] or FIXED_COLORS[role] or Color3.new(1, 1, 1)
	end

	local function materialFor(role: string): Enum.Material
		if opts.statue then
			return Enum.Material.Slate
		end
		if role == "deck" then
			return Enum.Material.WoodPlanks
		end
		if skin and skin.neonAccent and role == "accent" then
			return Enum.Material.Neon
		end
		if opts.glow and role == "accent" then
			return Enum.Material.Neon
		end
		if skin and skin.material and (role == "primary" or role == "secondary") then
			return skin.material
		end
		return Enum.Material.Plastic
	end

	local model = Instance.new("Model")
	model.Name = `Giant_{ownerId}`
	model:SetAttribute("OwnerUserId", ownerId)

	local root = makePart("Root", Vector3.one, Vector3.zero, Color3.new(1, 1, 1))
	root.Transparency = 1
	root.CanCollide = false
	root.CanQuery = false
	root.Parent = model
	model.PrimaryPart = root

	local seatPart: BasePart? = nil
	local headPart: BasePart? = nil
	for _, def in body.parts do
		local part = makePart(def.name, def.size, def.position, colorFor(def.role))
		part.Material = materialFor(def.role)
		part.CanCollide = def.collide ~= false and not opts.statue
		part.Parent = model
		if def.name == "Seat" then
			seatPart = part
		elseif def.name == "Head" then
			headPart = part
		end
	end

	local legs: { Leg } = {}
	for _, def in body.legs do
		local part = makePart(def.name, def.size, def.position, colorFor("primary"))
		part.Material = materialFor("primary")
		part.CanCollide = not opts.statue
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

	if opts.glow and not opts.statue then
		local light = Instance.new("PointLight")
		light.Color = GLOW_COLOR
		light.Range = 24
		light.Brightness = 2
		light.Parent = headPart or root
	end

	return {
		model = model,
		root = root,
		seatPart = seatPart,
		headPart = headPart,
		legs = legs,
	}
end

return GiantModel
