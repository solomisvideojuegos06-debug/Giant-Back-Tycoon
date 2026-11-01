--!strict
--[[
	MapService
	Construye el continente al arrancar el servidor a partir de Config/Zones:
	suelo de cada zona, franjas entre zonas (río, dunas, ladera), agua poco
	profunda, espinos, rocas grandes, carteles y
	la iluminación. El rancho lo construye RanchService.
	Se inicia antes que ningún otro service (priority = 0).

	Solo el suelo (Workspace.Map, piezas con CanQuery) cuenta para la altura de
	los gigantes; lo decorativo lleva CanQuery = false.
]]

local Lighting = game:GetService("Lighting")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage.Shared
local Zones = require(Shared.Config.Zones)

local MapService = {
	priority = 0,
}

local GROUND_THICKNESS = 20
local WATER_COLOR = Color3.fromRGB(70, 160, 230)
local THORN_GROUND = Color3.fromRGB(120, 80, 70)
local THORN_COLOR = Color3.fromRGB(90, 40, 40)
local ROCK_COLOR = Color3.fromRGB(120, 118, 125)
local SIGN_POST = Color3.fromRGB(120, 80, 45)

local mapFolder: Folder
local decorFolder: Folder

local function part(
	parent: Instance,
	name: string,
	size: Vector3,
	cframe: CFrame,
	color: Color3,
	material: Enum.Material
): Part
	local p = Instance.new("Part")
	p.Name = name
	p.Anchored = true
	p.Size = size
	p.CFrame = cframe
	p.Color = color
	p.Material = material
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.CanTouch = false
	p.Parent = parent
	return p
end

local function decor(name: string, size: Vector3, cframe: CFrame, color: Color3, material: Enum.Material): Part
	local p = part(decorFolder, name, size, cframe, color, material)
	p.CanQuery = false
	p.CanCollide = false
	return p
end

local function rectCenter(rect: Zones.Rect, y: number): Vector3
	return Vector3.new((rect.minX + rect.maxX) / 2, y, (rect.minZ + rect.maxZ) / 2)
end

local function rectSize(rect: Zones.Rect, height: number): Vector3
	return Vector3.new(rect.maxX - rect.minX, height, rect.maxZ - rect.minZ)
end

local function sign(position: Vector3, title: string, subtitle: string)
	decor("SignPost", Vector3.new(2, 18, 2), CFrame.new(position + Vector3.new(0, 9, 0)), SIGN_POST, Enum.Material.Wood)
	local board = decor(
		"SignBoard",
		Vector3.new(14, 6, 1),
		CFrame.new(position + Vector3.new(0, 19, 0)),
		Color3.fromRGB(240, 225, 190),
		Enum.Material.WoodPlanks
	)
	local gui = Instance.new("BillboardGui")
	gui.Size = UDim2.fromScale(16, 7)
	gui.StudsOffset = Vector3.new(0, 0, 0)
	gui.LightInfluence = 0
	gui.MaxDistance = 600
	gui.Parent = board
	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.FredokaOne
	label.TextScaled = true
	label.TextColor3 = Color3.fromRGB(70, 45, 25)
	label.Text = `{title}\n{subtitle}`
	label.Parent = gui
end

local function buildZones()
	local random = Random.new(7)
	for index, zone in Zones.list do
		-- Suelo a cuadros de dos tonos, con studs (cuenta para la altura de los gigantes).
		local tile = Zones.tileSize
		local h, sat, v = zone.groundColor:ToHSV()
		local light = Color3.fromHSV(h, sat, math.min(v * 1.06, 1))
		local dark = Color3.fromHSV(h, math.min(sat * 1.05, 1), v * 0.9)
		local rect = zone.rect
		local columns = math.ceil((rect.maxX - rect.minX) / tile)
		local rows = math.ceil((rect.maxZ - rect.minZ) / tile)
		for column = 0, columns - 1 do
			for row = 0, rows - 1 do
				local x0 = rect.minX + column * tile
				local z0 = rect.minZ + row * tile
				local w = math.min(tile, rect.maxX - x0)
				local d = math.min(tile, rect.maxZ - z0)
				local ground = part(
					mapFolder,
					"Ground",
					Vector3.new(w, GROUND_THICKNESS, d),
					CFrame.new(x0 + w / 2, -GROUND_THICKNESS / 2, z0 + d / 2),
					if (column + row) % 2 == 0 then light else dark,
					Enum.Material.Plastic
				)
				ground.TopSurface = Enum.SurfaceType.Studs
				ground:SetAttribute("Zone", zone.id)
			end
		end

		if index > 1 then
			-- Franja entre zonas (decorativa) y carteles con el nivel necesario.
			local x = zone.rect.minX
			decor(
				`Border_{zone.id}`,
				Vector3.new(Zones.borderWidth, 0.4, zone.rect.maxZ - zone.rect.minZ),
				CFrame.new(x, 0.15, (zone.rect.minZ + zone.rect.maxZ) / 2),
				zone.borderColor,
				if index == 2 then Enum.Material.Glass else Enum.Material.Ground
			)
			for _, z in { -380, 0, 380 } do
				sign(Vector3.new(x - Zones.borderWidth, 0, z), zone.displayName, `Nivel {zone.minLevel}`)
			end
		end

		for _, area in zone.slowAreas do
			if area.kind == "water" then
				local water = decor(
					"ShallowWater",
					rectSize(area.rect, 0.6),
					CFrame.new(rectCenter(area.rect, 0.3)),
					WATER_COLOR,
					Enum.Material.Glass
				)
				water.Transparency = 0.35
			else
				decor(
					"ThornGround",
					rectSize(area.rect, 0.3),
					CFrame.new(rectCenter(area.rect, 0.1)),
					THORN_GROUND,
					Enum.Material.Ground
				)
				for _ = 1, 40 do
					local x = random:NextNumber(area.rect.minX + 5, area.rect.maxX - 5)
					local z = random:NextNumber(area.rect.minZ + 5, area.rect.maxZ - 5)
					local height = random:NextNumber(2, 4)
					local thorn = Instance.new("WedgePart")
					thorn.Name = "Thorn"
					thorn.Anchored = true
					thorn.CanCollide = false
					thorn.CanQuery = false
					thorn.CanTouch = false
					thorn.Size = Vector3.new(1.2, height, 1.5)
					thorn.CFrame = CFrame.new(x, height / 2, z) * CFrame.Angles(0, random:NextNumber(0, math.pi * 2), 0)
					thorn.Color = THORN_COLOR
					thorn.Parent = decorFolder
				end
			end
		end
	end

	-- Rocas grandes en las Montañas: obstáculos que los gigantes rodean.
	local mountains = Zones.byId.Mountains
	if mountains then
		for i = 1, 10 do
			local x = random:NextNumber(mountains.rect.minX + 60, mountains.rect.maxX - 40)
			local z = if i % 2 == 0 then random:NextNumber(-480, -420) else random:NextNumber(420, 480)
			local height = random:NextNumber(40, 90)
			part(
				mapFolder,
				"Crag",
				Vector3.new(random:NextNumber(30, 60), height, random:NextNumber(30, 60)),
				CFrame.new(x, height / 2, z),
				ROCK_COLOR,
				Enum.Material.Slate
			)
		end
	end
end

local function setupLighting()
	Lighting.ClockTime = 14
	Lighting.Brightness = 3
	Lighting.Ambient = Color3.fromRGB(110, 110, 120)
	Lighting.OutdoorAmbient = Color3.fromRGB(165, 165, 175)
	Lighting.GlobalShadows = true
	if not Lighting:FindFirstChildOfClass("ColorCorrectionEffect") then
		local correction = Instance.new("ColorCorrectionEffect")
		correction.Saturation = 0.2
		correction.Contrast = 0.06
		correction.Parent = Lighting
	end
	if not Lighting:FindFirstChildOfClass("Atmosphere") then
		local atmosphere = Instance.new("Atmosphere")
		atmosphere.Density = 0.22
		atmosphere.Haze = 0.6
		atmosphere.Color = Color3.fromRGB(200, 220, 255)
		atmosphere.Parent = Lighting
	end
end

function MapService.init()
	-- Si la place trae un mapa anterior (por ejemplo el de pruebas del M1), se sustituye.
	for _, name in { "Map", "MapDecor", "Hall", "Baseplate" } do
		local old = Workspace:FindFirstChild(name)
		if old then
			old:Destroy()
		end
	end

	mapFolder = Instance.new("Folder")
	mapFolder.Name = "Map"
	mapFolder.Parent = Workspace
	decorFolder = Instance.new("Folder")
	decorFolder.Name = "MapDecor"
	decorFolder.Parent = Workspace

	buildZones()
	setupLighting()
end

function MapService.start()
	print("[MapService] iniciado")
end

return MapService
