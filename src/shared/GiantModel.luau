--!strict
--[[
	GiantModel: convierte el arte de bloques de VoxelArt en un Model de Roblox.

	- Root: pieza invisible y anclada en el punto de apoyo (pivote del modelo).
	  Todo lo demás va soldado a ella, así que mover el gigante es escribir un
	  solo CFrame, y Model:ScaleTo() lo hace crecer sin despegarlo del suelo.
	- Cada pata cuelga de una cadera (Motor6D): GiantRenderController la mueve.
	- Piezas con nombre: Seat (asiento, aviso «Conducir»), Deck (cubierta,
	  aviso «Subir») y HeadAnchor (etiqueta).
	- Estatuas (Salón del Linaje del rancho): todo de piedra, anclado y quieto.
	Lo usan el cliente (gigantes) y el servidor (estatuas).
]]

local Skins = require(script.Parent.Config.Skins)
local Species = require(script.Parent.Config.Species)
local VoxelArt = require(script.Parent.VoxelArt)

export type Leg = {
	motor: Motor6D,
	hip: Vector3, -- a escala 1
	phase: number,
}

export type Built = {
	model: Model,
	root: BasePart,
	seatPart: BasePart?,
	deckPart: BasePart?,
	headPart: BasePart,
	legs: { Leg },
}

export type BuildOptions = {
	skin: string?,
	glow: boolean?, -- mutación Brillo
	statue: boolean?,
}

local GLOW_COLOR = Color3.fromRGB(255, 240, 150)

local GiantModel = {}

local function rgb(color: Color3): { number }
	return { math.floor(color.R * 255 + 0.5), math.floor(color.G * 255 + 0.5), math.floor(color.B * 255 + 0.5) }
end

local function studs(part: BasePart)
	part.TopSurface = Enum.SurfaceType.Studs
	part.FrontSurface = Enum.SurfaceType.Studs
	part.BackSurface = Enum.SurfaceType.Studs
	part.LeftSurface = Enum.SurfaceType.Studs
	part.RightSurface = Enum.SurfaceType.Studs
	part.BottomSurface = Enum.SurfaceType.Inlet
end

local function weld(part0: BasePart, part1: BasePart)
	local joint = Instance.new("Weld")
	joint.Part0 = part0
	joint.Part1 = part1
	joint.C0 = part0.CFrame:ToObjectSpace(part1.CFrame)
	joint.Parent = part1
end

local function invisible(name: string, cframe: CFrame, size: Vector3): Part
	local part = Instance.new("Part")
	part.Name = name
	part.Size = size
	part.CFrame = cframe
	part.Transparency = 1
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.Massless = true
	part.Anchored = false
	return part
end

function GiantModel.build(speciesName: string, ownerId: number, options: BuildOptions?): Built
	local opts: BuildOptions = options or {}
	local species = Species[speciesName] or Species.Turtle
	local skin = if opts.skin then Skins[opts.skin] else nil
	local palette = {
		primary = rgb(if skin then skin.primary else species.palette.primary),
		secondary = rgb(if skin then skin.secondary else species.palette.secondary),
		accent = rgb(if skin then skin.accent else species.palette.accent),
	}
	local rig = if opts.statue then VoxelArt.statue(speciesName) else VoxelArt.giant(speciesName, palette)
	local anchored = opts.statue == true

	local model = Instance.new("Model")
	model.Name = `Giant_{ownerId}`
	model:SetAttribute("OwnerUserId", ownerId)

	local root = invisible("Root", CFrame.identity, Vector3.one)
	root.Anchored = true
	root.Parent = model
	model.PrimaryPart = root

	-- Caderas de las patas.
	local hips: { [string]: BasePart } = {}
	local legs: { Leg } = {}
	for _, leg in rig.legs do
		local hip = Vector3.new(leg.hip[1], leg.hip[2], leg.hip[3])
		local hipPart = invisible(`Hip_{leg.group}`, CFrame.new(hip), Vector3.one * 0.4)
		hipPart.Anchored = anchored
		hipPart.Parent = model
		hips[leg.group] = hipPart
		if not anchored then
			local motor = Instance.new("Motor6D")
			motor.Name = leg.group
			motor.Part0 = root
			motor.Part1 = hipPart
			motor.C0 = CFrame.new(hip)
			motor.Parent = hipPart
			table.insert(legs, { motor = motor, hip = hip, phase = leg.phase })
		end
	end

	local seatPart: BasePart? = nil
	local deckPart: BasePart? = nil
	local material = if skin and skin.material then skin.material else Enum.Material.Plastic

	for _, item in rig.boxes do
		local part = Instance.new("Part")
		part.Size = Vector3.new(item.sx, item.sy, item.sz)
		local cframe = CFrame.new(item.x, item.y, item.z)
		if item.rot then
			cframe *= CFrame.fromEulerAnglesYXZ(math.rad(item.rot[1]), math.rad(item.rot[2]), math.rad(item.rot[3]))
		end
		part.CFrame = cframe
		part.Color = Color3.fromRGB(item.color[1], item.color[2], item.color[3])
		part.Material = material
		part.Anchored = anchored
		part.Massless = true
		part.CanTouch = false
		part.CanCollide = item.collide and not anchored
		part.CastShadow = item.sx * item.sy * item.sz > 2
		studs(part)

		if item.name then
			part.Name = item.name
			part.Transparency = 1
			part.CanCollide = false
			part.CanQuery = false
			if item.name == "Seat" then
				seatPart = part
			elseif item.name == "Deck" then
				deckPart = part
			end
		else
			part.Name = item.key
			local glowing = opts.glow and string.sub(item.key, 1, 6) == "accent"
			local neonSkin = skin and skin.neonAccent and string.sub(item.key, 1, 6) == "accent"
			if glowing or neonSkin then
				part.Material = Enum.Material.Neon
			end
		end

		part.Parent = model
		if not anchored then
			weld(hips[item.group] or root, part)
		end
	end

	local headPart = invisible("HeadAnchor", CFrame.new(rig.head[1], rig.head[2], rig.head[3]), Vector3.one * 0.4)
	headPart.Anchored = anchored
	headPart.Parent = model
	if not anchored then
		weld(root, headPart)
	end

	if opts.glow and not anchored then
		local light = Instance.new("PointLight")
		light.Color = GLOW_COLOR
		light.Range = 28
		light.Brightness = 2
		light.Parent = headPart
	end

	return {
		model = model,
		root = root,
		seatPart = seatPart,
		deckPart = deckPart,
		headPart = headPart,
		legs = legs,
	}
end

return GiantModel
