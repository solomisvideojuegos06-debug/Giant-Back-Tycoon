--!strict
--[[
	MachineModel: máquinas del lomo en estilo bloques con studs, a escala 1.
	El pivote (pieza Root, invisible) está en el centro de la base, sobre la
	cubierta. Ocupan como mucho 4 x 4 studs para caber en cualquier hueco.

	Todas las piezas van soldadas a Root; las que se mueven (sierras, martillos,
	cristales) van con un Motor6D que GiantRenderController actualiza.
]]

local Machines = require(script.Parent.Config.Machines)

export type Animated = {
	motor: Motor6D,
	base: CFrame, -- posición relativa al pivote, a escala 1
	kind: "spin" | "pound",
	axis: Vector3, -- eje de giro (spin), en el espacio del pivote
	speed: number, -- vueltas por segundo (spin) o golpes por segundo (pound)
	amplitude: number, -- altura del golpe (pound), a escala 1
}

export type Built = {
	model: Model,
	root: BasePart,
	animated: { Animated },
}

local MachineModel = {}

local DARK = Color3.fromRGB(65, 65, 78)
local STEEL = Color3.fromRGB(205, 210, 220)
local WOOD = Color3.fromRGB(165, 110, 60)
local WOOD_DARK = Color3.fromRGB(125, 80, 45)
local RED = Color3.fromRGB(220, 60, 60)
local YELLOW = Color3.fromRGB(255, 200, 50)
local NEON = Color3.fromRGB(110, 240, 255)
local ROCK = Color3.fromRGB(150, 150, 160)

local function studs(part: BasePart)
	part.TopSurface = Enum.SurfaceType.Studs
	part.FrontSurface = Enum.SurfaceType.Studs
	part.BackSurface = Enum.SurfaceType.Studs
	part.LeftSurface = Enum.SurfaceType.Studs
	part.RightSurface = Enum.SurfaceType.Studs
	part.BottomSurface = Enum.SurfaceType.Inlet
end

function MachineModel.build(machineId: string): Built
	local def = Machines.byId[machineId]
	local color = if def then def.color else Color3.new(1, 1, 1)

	local model = Instance.new("Model")
	model.Name = machineId
	local root = Instance.new("Part")
	root.Name = "Root"
	root.Size = Vector3.one * 0.2
	root.Transparency = 1
	root.CanCollide = false
	root.CanQuery = false
	root.CanTouch = false
	root.Massless = true
	root.Parent = model
	model.PrimaryPart = root

	local animated: { Animated } = {}

	local function block(size: Vector3, cframe: CFrame, partColor: Color3, collide: boolean?): Part
		local part = Instance.new("Part")
		part.Size = size
		part.CFrame = cframe
		part.Color = partColor
		part.Material = Enum.Material.Plastic
		part.CanCollide = collide ~= false
		part.CanTouch = false
		part.Massless = true
		studs(part)
		local joint = Instance.new("Weld")
		joint.Part0 = root
		joint.Part1 = part
		joint.C0 = cframe
		joint.Parent = part
		part.Parent = model
		return part
	end

	local function moving(part: BasePart, kind: "spin" | "pound", axis: Vector3, speed: number, amplitude: number)
		local base = part.CFrame
		local weldJoint = part:FindFirstChildOfClass("Weld")
		if weldJoint then
			weldJoint:Destroy()
		end
		local motor = Instance.new("Motor6D")
		motor.Part0 = root
		motor.Part1 = part
		motor.C0 = base
		motor.Parent = part
		part.CanCollide = false
		table.insert(animated, {
			motor = motor,
			base = base,
			kind = kind,
			axis = axis,
			speed = speed,
			amplitude = amplitude,
		})
	end

	local function blade(cframe: CFrame, diameter: number, speed: number)
		local disc = block(Vector3.new(0.3, diameter, diameter), cframe, STEEL, false)
		disc.Shape = Enum.PartType.Cylinder
		disc.Material = Enum.Material.Metal
		moving(disc, "spin", Vector3.xAxis, speed, 0)
		local hub = block(Vector3.new(0.4, diameter * 0.3, diameter * 0.3), cframe, RED, false)
		hub.Shape = Enum.PartType.Cylinder
		moving(hub, "spin", Vector3.xAxis, speed, 0)
	end

	local function chimney(position: Vector3)
		block(Vector3.new(1, 2.4, 1), CFrame.new(position), DARK)
		local top = block(Vector3.new(1.3, 0.4, 1.3), CFrame.new(position + Vector3.new(0, 1.4, 0)), YELLOW)
		local smoke = Instance.new("Smoke")
		smoke.Color = Color3.fromRGB(230, 230, 230)
		smoke.Opacity = 0.15
		smoke.Size = 0.6
		smoke.RiseVelocity = 3
		smoke.Parent = top
	end

	if machineId == "Saw" or machineId == "IndustrialSaw" then
		local big = machineId == "IndustrialSaw"
		local h = if big then 2 else 1.6
		block(Vector3.new(4, h, 3.6), CFrame.new(0, h / 2, 0), color)
		block(Vector3.new(4, 0.4, 3.2), CFrame.new(0, h + 0.2, 0), WOOD_DARK)
		block(Vector3.new(1.3, 1.3, 3.2), CFrame.new(-1.2, h + 1.05, 0), WOOD)
		block(Vector3.new(1.2, 0.2, 1.2), CFrame.new(-1.2, h + 1.05, -1.65), Color3.fromRGB(230, 185, 120), false)
		if big then
			blade(CFrame.new(0.2, h + 1.3, -0.6), 2.8, 3)
			blade(CFrame.new(1.4, h + 1.3, 0.6), 2.8, 3)
			chimney(Vector3.new(1.4, h + 1.2, 1.4))
		else
			blade(CFrame.new(0.8, h + 1.1, 0), 2.4, 2)
		end
	elseif machineId == "Crusher" then
		block(Vector3.new(4, 2, 4), CFrame.new(0, 1, 0), color)
		block(Vector3.new(3, 0.6, 3), CFrame.new(0, 2.3, 0), DARK)
		block(Vector3.new(0.8, 0.8, 0.8), CFrame.new(-0.6, 2.9, 0.5), ROCK, false)
		block(Vector3.new(0.6, 0.6, 0.6), CFrame.new(0.7, 2.8, -0.4), ROCK, false)
		block(Vector3.new(0.6, 3.4, 0.6), CFrame.new(-1.7, 3.7, 0), YELLOW)
		block(Vector3.new(0.6, 3.4, 0.6), CFrame.new(1.7, 3.7, 0), YELLOW)
		block(Vector3.new(4, 0.6, 0.8), CFrame.new(0, 5.6, 0), DARK)
		local hammer = block(Vector3.new(2.2, 1.2, 2.2), CFrame.new(0, 3.6, 0), STEEL, false)
		hammer.Material = Enum.Material.Metal
		moving(hammer, "pound", Vector3.yAxis, 1.5, 1.1)
	elseif machineId == "RockMill" then
		block(Vector3.new(4, 2, 4), CFrame.new(0, 1, 0), color)
		block(Vector3.new(3.4, 0.5, 3.4), CFrame.new(0, 2.25, 0), DARK)
		local stone =
			block(Vector3.new(1, 3.4, 3.4), CFrame.new(0, 3, 0) * CFrame.Angles(0, 0, math.rad(90)), ROCK, false)
		stone.Shape = Enum.PartType.Cylinder
		moving(stone, "spin", Vector3.yAxis, 0.8, 0)
		local post = block(Vector3.new(0.6, 2, 0.6), CFrame.new(0, 4.4, 0), YELLOW, false)
		moving(post, "spin", Vector3.yAxis, 0.8, 0)
		chimney(Vector3.new(1.5, 3.4, 1.5))
	elseif machineId == "Storage" then
		block(Vector3.new(2.6, 2.6, 2.6), CFrame.new(-0.6, 1.3, -0.6), WOOD)
		block(Vector3.new(2.7, 0.4, 2.7), CFrame.new(-0.6, 1.3, -0.6), WOOD_DARK)
		block(Vector3.new(2, 2, 2), CFrame.new(1, 1, 1), color)
		block(Vector3.new(1.8, 1.8, 1.8), CFrame.new(-0.5, 3.5, -0.5), color)
		block(Vector3.new(1.9, 0.3, 1.9), CFrame.new(-0.5, 3.5, -0.5), WOOD_DARK)
	elseif machineId == "PolishWorkshop" then
		block(Vector3.new(4, 1.5, 4), CFrame.new(0, 0.75, 0), color)
		block(Vector3.new(1.8, 1, 1.8), CFrame.new(0, 2, 0), DARK)
		local crystal = block(
			Vector3.new(1.4, 2.4, 1.4),
			CFrame.new(0, 4, 0) * CFrame.Angles(0, math.rad(45), math.rad(45)),
			NEON,
			false
		)
		crystal.Material = Enum.Material.Neon
		moving(crystal, "spin", Vector3.yAxis, 0.5, 0)
		for _, corner in { Vector3.new(-1.6, 1.8, -1.6), Vector3.new(1.6, 1.8, 1.6) } do
			local spark = block(Vector3.new(0.5, 0.5, 0.5), CFrame.new(corner), YELLOW, false)
			spark.Material = Enum.Material.Neon
		end
	else
		block(Vector3.new(4, 2, 4), CFrame.new(0, 1, 0), color)
	end

	return { model = model, root = root, animated = animated }
end

-- C0 animado de una pieza en el instante `t`, a la escala indicada.
function MachineModel.animate(item: Animated, t: number, scale: number): CFrame
	if item.kind == "spin" then
		local angle = (t * item.speed % 1) * 2 * math.pi
		return CFrame.new(item.base.Position * scale) * CFrame.fromAxisAngle(item.axis, angle) * item.base.Rotation
	end
	local phase = (t * item.speed) % 1
	-- Sube despacio y cae de golpe.
	local lift = if phase < 0.8 then phase / 0.8 else 1 - (phase - 0.8) / 0.2
	return CFrame.new((item.base.Position + Vector3.new(0, lift * item.amplitude, 0)) * scale) * item.base.Rotation
end

return MachineModel
