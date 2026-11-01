--!strict
--[[
	RanchService
	El rancho: una parcela por jugador en el oeste de la Pradera.

	Cada parcela tiene valla con puerta al este, un arco con el cartel
	«Rancho de …», el nido donde descansa el gigante, la plataforma «Montar»
	(junto a la puerta) y las estatuas de las generaciones anteriores
	(el Salón del Linaje de cada jugador).

	El jugador aparece junto a su plataforma (GiantService) y su gigante vive
	en el nido. La plataforma lleva el atributo OwnerUserId para que el
	cliente sepa cuál es la suya.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage.Shared
local GiantMath = require(Shared.GiantMath)
local GiantModel = require(Shared.GiantModel)
local Species = require(Shared.Config.Species)
local World = require(Shared.World)
local Zones = require(Shared.Config.Zones)
local DataService = require(script.Parent.DataService)
local GiantService = require(script.Parent.GiantService)

local RANCH = Zones.ranch

type Plot = {
	slot: number,
	center: Vector3,
	folder: Folder,
	signLabels: { TextLabel },
	statues: Folder,
	pad: BasePart,
	owner: Player?,
}

local RanchService = {}

local WOOD = Color3.fromRGB(160, 105, 60)
local WOOD_DARK = Color3.fromRGB(120, 78, 42)
local STRAW = Color3.fromRGB(245, 205, 95)
local STRAW_DARK = Color3.fromRGB(215, 170, 70)
local YARD = Color3.fromRGB(150, 215, 95)
local PATH = Color3.fromRGB(225, 195, 140)
local PAD = Color3.fromRGB(90, 230, 120)

local ranchFolder: Folder
local plots: { Plot } = {}

local function studs(part: BasePart)
	part.TopSurface = Enum.SurfaceType.Studs
	part.FrontSurface = Enum.SurfaceType.Studs
	part.BackSurface = Enum.SurfaceType.Studs
	part.LeftSurface = Enum.SurfaceType.Studs
	part.RightSurface = Enum.SurfaceType.Studs
	part.BottomSurface = Enum.SurfaceType.Inlet
end

local function block(
	parent: Instance,
	name: string,
	size: Vector3,
	cframe: CFrame,
	color: Color3,
	collide: boolean?
): Part
	local part = Instance.new("Part")
	part.Name = name
	part.Anchored = true
	part.Size = size
	part.CFrame = cframe
	part.Color = color
	part.Material = Enum.Material.Plastic
	part.CanCollide = collide == true
	part.CanQuery = false
	part.CanTouch = false
	studs(part)
	part.Parent = parent
	return part
end

local function fenceLine(parent: Instance, from: Vector3, to: Vector3)
	local delta = to - from
	local length = delta.Magnitude
	if length < 1 then
		return
	end
	local direction = delta.Unit
	local cframe = CFrame.lookAt(from + delta / 2, to)
	for _, y in { 2, 4 } do
		block(parent, "Rail", Vector3.new(0.6, 0.6, length), cframe + Vector3.new(0, y, 0), WOOD, true)
	end
	local posts = math.max(math.floor(length / 14), 1)
	for i = 0, posts do
		local position = from + direction * (length * i / posts)
		block(
			parent,
			"Post",
			Vector3.new(1.4, 5.4, 1.4),
			CFrame.new(position + Vector3.new(0, 2.7, 0)),
			WOOD_DARK,
			true
		)
	end
end

local function signText(gui: SurfaceGui, text: string): TextLabel
	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.FredokaOne
	label.TextScaled = true
	label.TextColor3 = Color3.fromRGB(255, 255, 255)
	label.TextStrokeColor3 = Color3.fromRGB(60, 35, 20)
	label.TextStrokeTransparency = 0
	label.Text = text
	label.Parent = gui
	return label
end

local function buildPlot(slot: number): Plot
	local center = World.plotCenter(slot)
	local half = RANCH.size / 2
	local folder = Instance.new("Folder")
	folder.Name = `Plot{slot}`
	folder:SetAttribute("Slot", slot)
	folder:SetAttribute("OwnerUserId", 0)
	folder.Parent = ranchFolder

	-- Suelo del patio y camino hasta la plataforma.
	block(folder, "Yard", Vector3.new(RANCH.size, 0.4, RANCH.size), CFrame.new(center + Vector3.new(0, 0.2, 0)), YARD)
	block(folder, "Path", Vector3.new(60, 0.5, 22), CFrame.new(center + Vector3.new(half + 10, 0.25, 0)), PATH)

	-- Valla con la puerta al este.
	local nw = center + Vector3.new(-half, 0, -half)
	local ne = center + Vector3.new(half, 0, -half)
	local sw = center + Vector3.new(-half, 0, half)
	local se = center + Vector3.new(half, 0, half)
	fenceLine(folder, nw, ne)
	fenceLine(folder, sw, se)
	fenceLine(folder, nw, sw)
	local gateHalf = RANCH.gateWidth / 2
	fenceLine(folder, ne, center + Vector3.new(half, 0, -gateHalf))
	fenceLine(folder, center + Vector3.new(half, 0, gateHalf), se)

	-- Arco de la puerta con el cartel.
	for _, side in { -1, 1 } do
		block(
			folder,
			"GatePost",
			Vector3.new(2.4, 16, 2.4),
			CFrame.new(center + Vector3.new(half, 8, side * gateHalf)),
			WOOD_DARK,
			true
		)
	end
	local board = block(
		folder,
		"Sign",
		Vector3.new(1.2, 6, RANCH.gateWidth + 4),
		CFrame.new(center + Vector3.new(half, 15, 0)),
		WOOD
	)
	local labels = {}
	for _, face in { Enum.NormalId.Right, Enum.NormalId.Left } do
		local gui = Instance.new("SurfaceGui")
		gui.Face = face
		gui.CanvasSize = Vector2.new(640, 100)
		gui.LightInfluence = 0
		gui.Parent = board
		table.insert(labels, signText(gui, "Rancho libre"))
	end

	-- Nido de paja: la casa del gigante.
	for i = 0, 15 do
		local angle = i / 16 * math.pi * 2
		local position = center + Vector3.new(math.cos(angle) * 30, 1.5, math.sin(angle) * 30)
		block(
			folder,
			"Straw",
			Vector3.new(9, 3, 9),
			CFrame.new(position) * CFrame.Angles(0, -angle, 0),
			if i % 2 == 0 then STRAW else STRAW_DARK
		)
	end
	block(folder, "NestFloor", Vector3.new(54, 0.6, 54), CFrame.new(center + Vector3.new(0, 0.3, 0)), STRAW_DARK)

	-- Plataforma para montar (fuera, junto a la puerta).
	local padPosition = center + RANCH.padOffset
	local pad = Instance.new("Part")
	pad.Name = "MountPad"
	pad.Shape = Enum.PartType.Cylinder
	pad.Size = Vector3.new(0.8, 16, 16)
	pad.CFrame = CFrame.new(padPosition + Vector3.new(0, 0.4, 0)) * CFrame.Angles(0, 0, math.rad(90))
	pad.Color = PAD
	pad.Material = Enum.Material.Neon
	pad.Anchored = true
	pad.CanCollide = true
	pad.CanQuery = false
	pad.CanTouch = true
	pad:SetAttribute("Slot", slot)
	pad:SetAttribute("OwnerUserId", 0)
	pad.Parent = folder
	local padRim = block(
		folder,
		"PadRim",
		Vector3.new(18, 0.6, 18),
		CFrame.new(padPosition + Vector3.new(0, 0.3, 0)),
		Color3.fromRGB(255, 255, 255)
	)
	padRim.Transparency = 0.2

	local statues = Instance.new("Folder")
	statues.Name = "Statues"
	statues.Parent = folder

	return {
		slot = slot,
		center = center,
		folder = folder,
		signLabels = labels,
		statues = statues,
		pad = pad,
		owner = nil,
	}
end

local function setOwner(plot: Plot, player: Player?)
	plot.owner = player
	local id = if player then player.UserId else 0
	plot.folder:SetAttribute("OwnerUserId", id)
	plot.pad:SetAttribute("OwnerUserId", id)
	for _, label in plot.signLabels do
		label.Text = if player then `Rancho de {player.DisplayName}` else "Rancho libre"
	end
	if not player then
		plot.statues:ClearAllChildren()
	end
end

-- Estatuas de las últimas generaciones junto a la valla oeste.
function RanchService.refreshStatues(player: Player)
	local data = DataService.get(player)
	local state = GiantService.get(player.UserId)
	local plot = state and plots[state.spawnSlot]
	if not data or not plot then
		return
	end
	plot.statues:ClearAllChildren()
	local ancestors = data.lineage.ancestors
	local first = math.max(#ancestors - RANCH.statuesShown + 1, 1)
	local facing = GiantMath.yawFromDirection(1, 0)
	for index = first, #ancestors do
		local ancestor = ancestors[index]
		local offset = (index - first) - (RANCH.statuesShown - 1) / 2
		local position = plot.center + Vector3.new(RANCH.statueX, 0.4, offset * RANCH.statueSpacing)
		local built = GiantModel.build(ancestor.species, -index, { statue = true })
		built.model:ScaleTo(RANCH.statueScale)
		built.model:PivotTo(CFrame.new(position) * CFrame.Angles(0, facing, 0))
		built.model.Name = `Gen{index}`
		block(
			built.model,
			"Plinth",
			Vector3.new(14, 0.8, 14),
			CFrame.new(position - Vector3.new(0, 0.2, 0)),
			Color3.fromRGB(200, 195, 185)
		)

		local gui = Instance.new("BillboardGui")
		gui.Size = UDim2.fromOffset(170, 46)
		gui.StudsOffsetWorldSpace = Vector3.new(0, 2, 0)
		gui.MaxDistance = 250
		gui.Parent = built.headPart
		local label = Instance.new("TextLabel")
		label.Size = UDim2.fromScale(1, 1)
		label.BackgroundTransparency = 1
		label.Font = Enum.Font.FredokaOne
		label.TextScaled = true
		label.TextColor3 = Color3.fromRGB(255, 255, 255)
		label.TextStrokeTransparency = 0
		local speciesDef = Species[ancestor.species]
		label.Text = `Gen {index}\n{if speciesDef then speciesDef.displayName else ancestor.species}`
		label.Parent = gui

		built.model.Parent = plot.statues
	end
end

function RanchService.init()
	local old = Workspace:FindFirstChild("Ranch")
	if old then
		old:Destroy()
	end
	ranchFolder = Instance.new("Folder")
	ranchFolder.Name = "Ranch"
	ranchFolder.Parent = Workspace
	for slot = 1, RANCH.count do
		plots[slot] = buildPlot(slot)
	end
end

function RanchService.start()
	GiantService.onCreated(function(state)
		local player = state.player
		local plot = plots[state.spawnSlot]
		if player and plot then
			setOwner(plot, player)
			-- Las estatuas necesitan los datos: ya están cargados cuando existe el gigante.
			RanchService.refreshStatues(player)
		end
	end)
	GiantService.onRemoved(function(state)
		local plot = plots[state.spawnSlot]
		if state.player and plot and plot.owner == state.player then
			setOwner(plot, nil)
		end
	end)
	Players.PlayerRemoving:Connect(function(player)
		for _, plot in plots do
			if plot.owner == player then
				setOwner(plot, nil)
			end
		end
	end)
	print("[RanchService] iniciado")
end

return RanchService
