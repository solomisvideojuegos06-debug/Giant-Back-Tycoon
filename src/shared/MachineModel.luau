--!strict
--[[
	MachineModel: modelos de bloques de las máquinas del lomo, a escala 1.
	El pivote (pieza Root) está en el centro de la base, sobre la cubierta.
	Ocupan como mucho 4 x 4 studs para caber en cualquier hueco.

	Cada modelo devuelve sus piezas animadas: «spin» gira sobre un eje y
	«pound» sube y baja (martillos). GiantRenderController las mueve.
]]

local Machines = require(script.Parent.Config.Machines)

export type Animated = {
	part: BasePart,
	base: CFrame, -- posición relativa al pivote, a escala 1
	kind: "spin" | "pound",
	axis: Vector3, -- eje de giro (spin)
	speed: number, -- vueltas por segundo (spin) o golpes por segundo (pound)
	amplitude: number, -- altura del golpe (pound), a escala 1
}

export type Built = {
	model: Model,
	animated: { Animated },
}

local MachineModel = {}

local DARK = Color3.fromRGB(70, 70, 80)
local STEEL = Color3.fromRGB(200, 205, 215)
local WOOD = Color3.fromRGB(150, 100, 55)
local NEON = Color3.fromRGB(110, 240, 255)

local function makePart(model: Model, name: string, size: Vector3, cframe: CFrame, color: Color3): Part
	local part = Instance.new("Part")
	part.Name = name
	part.Size = size
	part.CFrame = cframe
	part.Color = color
	part.Material = Enum.Material.Plastic
	part.Anchored = true
	part.CanCollide = true
	part.CanTouch = false
	part.CanQuery = true
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	part.Parent = model
	return part
end

local function cylinder(
	model: Model,
	name: string,
	length: number,
	diameter: number,
	cframe: CFrame,
	color: Color3
): Part
	local part = makePart(model, name, Vector3.new(length, diameter, diameter), cframe, color)
	part.Shape = Enum.PartType.Cylinder -- el eje del cilindro es X
	return part
end

function MachineModel.build(machineId: string): Built
	local def = Machines.byId[machineId]
	local color = if def then def.color else Color3.new(1, 1, 1)

	local model = Instance.new("Model")
	model.Name = machineId
	local root = makePart(model, "Root", Vector3.one * 0.2, CFrame.identity, color)
	root.Transparency = 1
	root.CanCollide = false
	root.CanQuery = false
	model.PrimaryPart = root

	local animated: { Animated } = {}
	local function spin(part: BasePart, axis: Vector3, speed: number)
		table.insert(animated, {
			part = part,
			base = part.CFrame,
			kind = "spin",
			axis = axis,
			speed = speed,
			amplitude = 0,
		})
	end
	local function pound(part: BasePart, speed: number, amplitude: number)
		table.insert(animated, {
			part = part,
			base = part.CFrame,
			kind = "pound",
			axis = Vector3.yAxis,
			speed = speed,
			amplitude = amplitude,
		})
	end

	if machineId == "Saw" or machineId == "IndustrialSaw" then
		local big = machineId == "IndustrialSaw"
		local height = if big then 2 else 1.5
		makePart(model, "Base", Vector3.new(4, height, 3.6), CFrame.new(0, height / 2, 0), color)
		makePart(model, "Table", Vector3.new(4, 0.3, 3), CFrame.new(0, height + 0.15, 0), DARK)
		makePart(model, "Log", Vector3.new(1.2, 1.2, 3.2), CFrame.new(-1.2, height + 0.9, 0), WOOD)
		local blades = if big then { -0.2, 1.2 } else { 0.6 }
		for index, x in blades do
			local blade =
				cylinder(model, `Blade{index}`, 0.25, if big then 2.8 else 2.4, CFrame.new(x, height + 1.1, 0), STEEL)
			blade.CanCollide = false
			spin(blade, Vector3.xAxis, if big then 3 else 2)
		end
	elseif machineId == "Crusher" or machineId == "RockMill" then
		local mill = machineId == "RockMill"
		makePart(model, "Base", Vector3.new(4, 2, 4), CFrame.new(0, 1, 0), color)
		makePart(model, "Bowl", Vector3.new(3, 0.6, 3), CFrame.new(0, 2.3, 0), DARK)
		if mill then
			local stone =
				cylinder(model, "Millstone", 1, 3.4, CFrame.new(0, 3.1, 0) * CFrame.Angles(0, 0, math.rad(90)), STEEL)
			stone.CanCollide = false
			spin(stone, Vector3.yAxis, 0.8)
			makePart(model, "Post", Vector3.new(0.6, 2, 0.6), CFrame.new(0, 4.4, 0), DARK)
		else
			makePart(model, "PillarL", Vector3.new(0.5, 3, 0.5), CFrame.new(-1.6, 3.5, 0), DARK)
			makePart(model, "PillarR", Vector3.new(0.5, 3, 0.5), CFrame.new(1.6, 3.5, 0), DARK)
			makePart(model, "Beam", Vector3.new(3.7, 0.5, 0.6), CFrame.new(0, 5.2, 0), DARK)
			local hammer = makePart(model, "Hammer", Vector3.new(2.2, 1.2, 2.2), CFrame.new(0, 3.6, 0), STEEL)
			hammer.CanCollide = false
			pound(hammer, 1.5, 1)
		end
	elseif machineId == "Storage" then
		makePart(model, "CrateA", Vector3.new(2.6, 2.6, 2.6), CFrame.new(-0.6, 1.3, -0.6), WOOD)
		makePart(model, "CrateB", Vector3.new(2, 2, 2), CFrame.new(1, 1, 1), color)
		makePart(model, "CrateC", Vector3.new(1.8, 1.8, 1.8), CFrame.new(-0.5, 3.5, -0.5), color)
		makePart(model, "Band", Vector3.new(2.7, 0.3, 2.7), CFrame.new(-0.6, 1.3, -0.6), DARK)
	elseif machineId == "PolishWorkshop" then
		makePart(model, "Base", Vector3.new(4, 1.5, 4), CFrame.new(0, 0.75, 0), color)
		makePart(model, "Plinth", Vector3.new(1.6, 1, 1.6), CFrame.new(0, 2, 0), DARK)
		local crystal = makePart(
			model,
			"Crystal",
			Vector3.new(1.4, 2.4, 1.4),
			CFrame.new(0, 4, 0) * CFrame.Angles(0, math.rad(45), math.rad(45)),
			NEON
		)
		crystal.Material = Enum.Material.Neon
		crystal.CanCollide = false
		spin(crystal, Vector3.yAxis, 0.5)
	else
		makePart(model, "Base", Vector3.new(4, 2, 4), CFrame.new(0, 1, 0), color)
	end

	return { model = model, animated = animated }
end

-- CFrame animado de una pieza en el instante `t`, relativa al pivote (escala 1).
function MachineModel.animate(item: Animated, t: number): CFrame
	if item.kind == "spin" then
		local angle = (t * item.speed % 1) * 2 * math.pi
		-- El eje está en el espacio del pivote (no en el de la pieza girada).
		return CFrame.new(item.base.Position) * CFrame.fromAxisAngle(item.axis, angle) * item.base.Rotation
	end
	local phase = (t * item.speed) % 1
	-- Sube despacio y cae de golpe.
	local lift = if phase < 0.8 then phase / 0.8 else 1 - (phase - 0.8) / 0.2
	return item.base + Vector3.new(0, lift * item.amplitude, 0)
end

return MachineModel
