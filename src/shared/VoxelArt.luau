--!strict
--[[
	VoxelArt: el arte de bloques del juego (gigantes y nodos), estilo «hecho
	con piezas con studs»: muchos cubos de varios tonos.

	Es una función pura (solo números): devuelve una lista de cajas con su
	color. GiantModel y ResourceService las convierten en Parts; los scripts
	de vista previa (Lune) las exportan para revisarlas fuera de Roblox.

	Coordenadas en studs a escala 1, relativas al punto de apoyo en el suelo.
	El gigante mira hacia -Z. Los vóxeles de los gigantes miden V = 2 studs y
	se agrupan en cajas grandes (greedy meshing) para usar pocas piezas.
]]

export type RGB = { number }

export type Box = {
	group: string, -- "body" o el nombre de una pata
	name: string?, -- piezas con nombre: Deck, Seat…
	key: string, -- clave de color (decide también el material: accent → Neon con Brillo)
	x: number,
	y: number,
	z: number,
	sx: number,
	sy: number,
	sz: number,
	color: RGB,
	collide: boolean,
	rot: { number }?, -- giro en grados (x, y, z), solo detalles
}

export type Leg = {
	group: string,
	hip: { number }, -- punto de giro de la pata (x, y, z)
	phase: number, -- 0 o 0.5: las patas en diagonal pisan a la vez
}

export type Rig = {
	boxes: { Box },
	legs: { Leg },
	seat: { number }, -- superficie del asiento de la cabeza
	head: { number }, -- donde va la etiqueta
	deckTop: number,
	deckSize: { number }, -- ancho (x) y largo (z) de la cubierta
	slots: { { number } }, -- huecos de máquina, sobre la cubierta
	radius: number,
}

export type Palette = {
	primary: RGB,
	secondary: RGB,
	accent: RGB,
}

local VoxelArt = {}

local V = 2

-- Colores ----------------------------------------------------------------

local function scaleColor(color: RGB, factor: number): RGB
	return {
		math.clamp(math.floor(color[1] * factor + 0.5), 0, 255),
		math.clamp(math.floor(color[2] * factor + 0.5), 0, 255),
		math.clamp(math.floor(color[3] * factor + 0.5), 0, 255),
	}
end

local FIXED: { [string]: RGB } = {
	eyeWhite = { 248, 248, 250 },
	eyeBlack = { 25, 25, 35 },
	mouth = { 90, 35, 40 },
	pink = { 245, 150, 170 },
	deck = { 205, 150, 90 },
	deckDark = { 165, 110, 65 },
	seat = { 215, 55, 55 },
	seatDark = { 160, 35, 40 },
	ivory = { 250, 245, 228 },
	hoof = { 75, 60, 50 },
	nail = { 240, 232, 210 },
	stone = { 175, 175, 170 },
}

local function buildColors(palette: Palette): { [string]: RGB }
	local colors: { [string]: RGB } = table.clone(FIXED)
	for _, name in { "primary", "secondary", "accent" } do
		local base = (palette :: any)[name] :: RGB
		colors[name] = base
		colors[name .. "Light"] = scaleColor(base, 1.13)
		colors[name .. "Dark"] = scaleColor(base, 0.82)
	end
	return colors
end

-- Ruido estable para variar los tonos por zonas (como piezas de distintos lotes).
local function hash(a: number, b: number, c: number): number
	return bit32.bxor(a * 73856093, b * 19349663, c * 83492791) % 100
end

local function varied(key: string, ix: number, iy: number, iz: number): string
	if key ~= "primary" and key ~= "secondary" then
		return key
	end
	local h = hash(math.floor(ix / 2), math.floor(iy / 2), math.floor(iz / 2))
	if h < 18 then
		return key .. "Dark"
	elseif h < 40 then
		return key .. "Light"
	end
	return key
end

-- Rejilla de vóxeles ------------------------------------------------------

type Cell = { key: string, group: string, collide: boolean }
type Paint = string | (ix: number, iy: number, iz: number, x: number, y: number, z: number) -> string?

type Grid = {
	cells: { [number]: Cell },
	extras: { Box },
}

local function cellKey(ix: number, iy: number, iz: number): number
	return (ix + 256) * 262144 + (iy + 256) * 512 + (iz + 256)
end

local function center(ix: number, iy: number, iz: number): (number, number, number)
	return ix * V, iy * V + V / 2, iz * V
end

local function newGrid(): Grid
	return { cells = {}, extras = {} }
end

local function resolve(paint: Paint, ix: number, iy: number, iz: number): string?
	if type(paint) == "string" then
		return paint
	end
	local x, y, z = center(ix, iy, iz)
	return paint(ix, iy, iz, x, y, z)
end

local function set(grid: Grid, ix: number, iy: number, iz: number, paint: Paint, group: string, collide: boolean?)
	local key = resolve(paint, ix, iy, iz)
	if key then
		grid.cells[cellKey(ix, iy, iz)] = { key = key, group = group, collide = collide ~= false }
	end
end

-- Caja: incluye los vóxeles cuyo centro está dentro de [min, max] (studs).
local function box(
	grid: Grid,
	x0: number,
	x1: number,
	y0: number,
	y1: number,
	z0: number,
	z1: number,
	paint: Paint,
	group: string,
	collide: boolean?
)
	for ix = math.ceil(x0 / V), math.floor(x1 / V) do
		for iy = math.ceil((y0 - V / 2) / V), math.floor((y1 - V / 2) / V) do
			for iz = math.ceil(z0 / V), math.floor(z1 / V) do
				set(grid, ix, iy, iz, paint, group, collide)
			end
		end
	end
end

local function ellipsoid(
	grid: Grid,
	cx: number,
	cy: number,
	cz: number,
	rx: number,
	ry: number,
	rz: number,
	paint: Paint,
	group: string,
	maxY: number?,
	collide: boolean?
)
	for ix = math.floor((cx - rx) / V), math.ceil((cx + rx) / V) do
		for iy = math.floor((cy - ry) / V) - 1, math.ceil((cy + ry) / V) do
			for iz = math.floor((cz - rz) / V), math.ceil((cz + rz) / V) do
				local x, y, z = center(ix, iy, iz)
				local d = ((x - cx) / rx) ^ 2 + ((y - cy) / ry) ^ 2 + ((z - cz) / rz) ^ 2
				if d <= 1 and y >= 0 and (maxY == nil or y <= maxY) then
					set(grid, ix, iy, iz, paint, group, collide)
				end
			end
		end
	end
end

-- Z de la cara delantera en (x, y): para pegar detalles (ojos) a la cabeza.
local function frontZ(grid: Grid, x: number, y: number): number
	local iy = math.floor((y - V / 2) / V + 0.5)
	local start = math.floor(x / V + 0.5)
	-- Si la columna está vacía, se busca hacia el centro de la cara.
	local stepX = if start > 0 then -1 else 1
	for ix = start, 0, stepX do
		for iz = -80, 80 do
			if grid.cells[cellKey(ix, iy, iz)] then
				return iz * V - V / 2
			end
		end
	end
	return 0
end

local function extra(
	grid: Grid,
	group: string,
	key: string,
	x: number,
	y: number,
	z: number,
	sx: number,
	sy: number,
	sz: number,
	rot: { number }?,
	name: string?,
	collide: boolean?
)
	table.insert(grid.extras, {
		group = group,
		name = name,
		key = key,
		x = x,
		y = y,
		z = z,
		sx = sx,
		sy = sy,
		sz = sz,
		color = { 0, 0, 0 },
		collide = collide == true,
		rot = rot,
	})
end

-- Ojos grandes y brillantes, pegados a la cara delantera.
local function eyes(grid: Grid, x: number, y: number, size: number)
	for _, side in { -1, 1 } do
		local ex = x * side
		local z = frontZ(grid, ex, y)
		extra(grid, "body", "eyeWhite", ex, y, z - 0.25, size, size * 1.15, 0.6)
		extra(grid, "body", "eyeBlack", ex + side * size * 0.12, y - size * 0.1, z - 0.5, size * 0.55, size * 0.7, 0.4)
		extra(grid, "body", "eyeWhite", ex + side * size * 0.2, y + size * 0.12, z - 0.68, size * 0.2, size * 0.2, 0.2)
	end
end

-- Uñas o pezuñas en la parte delantera de una pata.
local function toes(grid: Grid, group: string, x: number, z: number, width: number, key: string)
	for _, dx in { -width / 3, 0, width / 3 } do
		extra(grid, group, key, x + dx, 0.5, z - 0.15, width / 4, 1, 0.5)
	end
end

-- Agrupa vóxeles iguales en cajas grandes (greedy meshing en 3D).
local function mesh(grid: Grid, colors: { [string]: RGB }, ranges: { number }): { Box }
	local cells = grid.cells
	local visited: { [number]: boolean } = {}
	local boxes: { Box } = {}
	local minX, maxX, minY, maxY, minZ, maxZ = table.unpack(ranges)

	local function same(ix: number, iy: number, iz: number, ref: Cell): boolean
		local k = cellKey(ix, iy, iz)
		local cell = cells[k]
		return cell ~= nil
			and not visited[k]
			and cell.key == ref.key
			and cell.group == ref.group
			and cell.collide == ref.collide
	end

	for iy = minY, maxY do
		for iz = minZ, maxZ do
			for ix = minX, maxX do
				local k = cellKey(ix, iy, iz)
				local ref = cells[k]
				if ref and not visited[k] then
					local x1 = ix
					while x1 < maxX and same(x1 + 1, iy, iz, ref) do
						x1 += 1
					end
					local z1 = iz
					while z1 < maxZ do
						local ok = true
						for x = ix, x1 do
							if not same(x, iy, z1 + 1, ref) then
								ok = false
								break
							end
						end
						if not ok then
							break
						end
						z1 += 1
					end
					local y1 = iy
					while y1 < maxY do
						local ok = true
						for x = ix, x1 do
							for z = iz, z1 do
								if not same(x, y1 + 1, z, ref) then
									ok = false
									break
								end
							end
							if not ok then
								break
							end
						end
						if not ok then
							break
						end
						y1 += 1
					end
					for x = ix, x1 do
						for y = iy, y1 do
							for z = iz, z1 do
								visited[cellKey(x, y, z)] = true
							end
						end
					end
					local cx0, cy0, cz0 = center(ix, iy, iz)
					local cx1, cy1, cz1 = center(x1, y1, z1)
					table.insert(boxes, {
						group = ref.group,
						key = ref.key,
						x = (cx0 + cx1) / 2,
						y = (cy0 + cy1) / 2,
						z = (cz0 + cz1) / 2,
						sx = (x1 - ix + 1) * V,
						sy = (y1 - iy + 1) * V,
						sz = (z1 - iz + 1) * V,
						color = colors[ref.key] or { 255, 0, 255 },
						collide = ref.collide,
					})
				end
			end
		end
	end

	for _, item in grid.extras do
		item.color = colors[item.key] or { 255, 0, 255 }
		table.insert(boxes, item)
	end
	return boxes
end

-- Aplica la variación de tonos y devuelve las cajas.
local function finish(grid: Grid, palette: Palette): { Box }
	local colors = buildColors(palette)
	local minX, maxX, minY, maxY, minZ, maxZ = math.huge, -math.huge, math.huge, -math.huge, math.huge, -math.huge
	for k, cell in grid.cells do
		local ix = math.floor(k / 262144) - 256
		local iy = math.floor((k % 262144) / 512) - 256
		local iz = k % 512 - 256
		cell.key = varied(cell.key, ix, iy, iz)
		minX, maxX = math.min(minX, ix), math.max(maxX, ix)
		minY, maxY = math.min(minY, iy), math.max(maxY, iy)
		minZ, maxZ = math.min(minZ, iz), math.max(maxZ, iz)
	end
	return mesh(grid, colors, { minX, maxX, minY, maxY, minZ, maxZ })
end

-- Cubierta de madera con tablones, borde y asiento.
local function deck(grid: Grid, halfW: number, halfL: number, y: number)
	box(grid, -halfW, halfW, y, y, -halfL, halfL, function(_ix, _iy, iz)
		return if math.floor(iz / 2) % 2 == 0 then "deck" else "deckDark"
	end, "body")
	-- Pieza invisible con nombre: superficie de la cubierta (aviso «Subir»).
	extra(grid, "body", "deck", 0, y + V / 2 + 0.1, 0, halfW * 2 + V, 0.2, halfL * 2 + V, nil, "Deck")
	-- Barandilla de madera: postes y un pasamanos fino (se puede saltar).
	local top = y + V / 2
	local w, l = halfW + V / 2, halfL + V / 2
	local railY = top + 2
	extra(grid, "body", "deckDark", 0, railY, -l + 0.3, w * 2, 0.6, 0.6, nil, nil, true)
	extra(grid, "body", "deckDark", 0, railY, l - 0.3, w * 2, 0.6, 0.6, nil, nil, true)
	extra(grid, "body", "deckDark", -w + 0.3, railY, 0, 0.6, 0.6, l * 2, nil, nil, true)
	extra(grid, "body", "deckDark", w - 0.3, railY, 0, 0.6, 0.6, l * 2, nil, nil, true)
	for _, px in { -w + 0.4, w - 0.4 } do
		for _, pz in { -l + 0.4, 0, l - 0.4 } do
			extra(grid, "body", "deckDark", px, top + 1.2, pz, 0.8, 2.4, 0.8, nil, nil, true)
		end
	end
	for _, pz in { -l + 0.4, l - 0.4 } do
		extra(grid, "body", "deckDark", 0, top + 1.2, pz, 0.8, 2.4, 0.8, nil, nil, true)
	end
end

local function seat(grid: Grid, y: number, z: number)
	box(grid, -2, 2, y, y, z - 2, z + 2, "seat", "body")
	extra(grid, "body", "seatDark", 0, y + 1.6, z + 2.6, 6, 1.2, 1, nil, nil)
	-- Pieza invisible con nombre: aquí se engancha el aviso «Conducir».
	extra(grid, "body", "seat", 0, y, z, 6, 2, 6, nil, "Seat")
end

local function gridSlots(columnSpacing: number, firstRow: number, rowStep: number, deckTop: number): { { number } }
	local slots = {}
	for row = 0, 4 do
		for column = -1, 1 do
			if #slots < 14 then
				table.insert(slots, { column * columnSpacing, deckTop, firstRow + row * rowStep })
			end
		end
	end
	return slots
end

-- Especies ---------------------------------------------------------------------

local function legColumn(grid: Grid, group: string, x: number, z: number, halfW: number, top: number, footKey: string)
	box(grid, x - halfW, x + halfW, 1, top - 1, z - halfW, z + halfW, function(_ix, iy)
		if iy == 0 then
			return footKey
		end
		return "primary"
	end, group)
end

local function turtle(palette: Palette): Rig
	local grid = newGrid()
	local legs: { Leg } = {}
	for _, spec in
		{
			{ "LegFrontLeft", -12, -10, 0 },
			{ "LegFrontRight", 12, -10, 0.5 },
			{ "LegBackLeft", -12, 10, 0.5 },
			{ "LegBackRight", 12, 10, 0 },
		}
	do
		local name, x, z, phase = spec[1] :: string, spec[2] :: number, spec[3] :: number, spec[4] :: number
		legColumn(grid, name, x, z, 2, 8, "primaryDark")
		toes(grid, name, x, z - 3, 6, "nail")
		table.insert(legs, { group = name, hip = { x, 8, z }, phase = phase })
	end

	-- Caparazón: cúpula baja con placas y un ribete claro.
	ellipsoid(grid, 0, 8, 0, 15, 6.5, 19, function(ix, iy, iz)
		if iy <= 2 then
			return "accent"
		end
		if ix % 3 == 0 or iz % 4 == 0 then
			return "secondaryDark"
		end
		return "secondary"
	end, "body", 11)
	box(grid, -10, 10, 2, 3, -14, 14, "accent", "body")
	deck(grid, 10, 14, 13)

	-- Cuello, cabeza, boca y cola.
	box(grid, -2, 2, 7, 11, -20, -16, "primary", "body")
	ellipsoid(grid, 0, 13, -26, 6.6, 5.6, 6.6, "primary", "body")
	-- Sonrisa fina y mejillas.
	local mouthZ = frontZ(grid, 0, 10)
	extra(grid, "body", "mouth", 0, 10.2, mouthZ - 0.15, 4, 0.6, 0.3)
	for _, side in { -1, 1 } do
		extra(grid, "body", "mouth", side * 2.3, 10.7, mouthZ - 0.1, 0.8, 1.2, 0.3)
		extra(grid, "body", "pink", side * 4.4, 11.4, frontZ(grid, side * 4, 11) - 0.15, 1.8, 1, 0.3)
	end
	eyes(grid, 3.4, 14.4, 3.2)
	seat(grid, 19, -26)
	box(grid, 0, 0, 5, 5, 16, 18, "primary", "body")

	return {
		boxes = finish(grid, palette),
		legs = legs,
		seat = { 0, 20, -26 },
		head = { 0, 25, -26 },
		deckTop = 14,
		deckSize = { 22, 30 },
		slots = gridSlots(7, -12, 6, 14),
		radius = 24,
	}
end

local function elephant(palette: Palette): Rig
	local grid = newGrid()
	local legs: { Leg } = {}
	for _, spec in
		{
			{ "LegFrontLeft", -8, -10, 0 },
			{ "LegFrontRight", 8, -10, 0.5 },
			{ "LegBackLeft", -8, 10, 0.5 },
			{ "LegBackRight", 8, 10, 0 },
		}
	do
		local name, x, z, phase = spec[1] :: string, spec[2] :: number, spec[3] :: number, spec[4] :: number
		legColumn(grid, name, x, z, 2, 10, "primaryDark")
		toes(grid, name, x, z - 3, 6, "nail")
		table.insert(legs, { group = name, hip = { x, 10, z }, phase = phase })
	end

	-- Cuerpo con manta de colores y ribete dorado.
	ellipsoid(grid, 0, 14, 0, 11.5, 7.5, 15.5, function(ix, iy, iz)
		if iy >= 7 and math.abs(iz) <= 6 then
			if iy == 7 then
				return "accent"
			end
			return if (ix + iz) % 4 == 0 and iy == 8 then "accent" else "secondary"
		end
		return "primary"
	end, "body", 19)
	deck(grid, 10, 12, 21)

	-- Cabeza, orejas grandes, trompa y cola.
	ellipsoid(grid, 0, 17, -18, 7.2, 7.2, 6.2, "primary", "body")
	for _, side in { -1, 1 } do
		ellipsoid(grid, side * 10, 18, -16, 5.2, 6.8, 1.2, "primaryDark", "body")
	end
	for index, segment in { { 12, -24 }, { 8, -26 }, { 4, -28 }, { 1, -30 } } do
		box(
			grid,
			-2,
			2,
			segment[1] - 1,
			segment[1] + 1,
			segment[2],
			segment[2],
			if index % 2 == 0 then "primaryDark" else "primary",
			"body",
			false
		)
	end
	for _, side in { -1, 1 } do
		extra(grid, "body", "ivory", side * 4.2, 11.5, -26, 1.4, 1.4, 5, { -20, 0, 0 })
	end
	eyes(grid, 4.4, 19.5, 2.6)
	seat(grid, 25, -18)
	box(grid, 0, 0, 11, 15, 16, 16, "primaryDark", "body", false)

	return {
		boxes = finish(grid, palette),
		legs = legs,
		seat = { 0, 26, -18 },
		head = { 0, 31, -18 },
		deckTop = 22,
		deckSize = { 22, 26 },
		slots = gridSlots(7, -10, 5, 22),
		radius = 24,
	}
end

local function giraffe(palette: Palette): Rig
	local grid = newGrid()
	local spotted = function(ix: number, iy: number, iz: number): string?
		if hash(math.floor(ix / 2) + 7, math.floor(iy / 2), math.floor(iz / 2)) < 26 then
			return "secondary"
		end
		return "primary"
	end
	local legs: { Leg } = {}
	for _, spec in
		{
			{ "LegFrontLeft", -5, -9, 0 },
			{ "LegFrontRight", 5, -9, 0.5 },
			{ "LegBackLeft", -5, 9, 0.5 },
			{ "LegBackRight", 5, 9, 0 },
		}
	do
		local name, x, z, phase = spec[1] :: string, spec[2] :: number, spec[3] :: number, spec[4] :: number
		box(grid, x - 1, x + 1, 1, 17, z - 1, z + 1, function(_ix, iy, iz)
			if iy == 0 then
				return "hoof"
			elseif iy == 4 then
				return "primaryDark"
			end
			return spotted(_ix, iy, iz)
		end, name)
		table.insert(legs, { group = name, hip = { x, 18, z }, phase = phase })
	end

	ellipsoid(grid, 0, 22, 0, 8.5, 5.5, 12.5, spotted, "body", 25)
	deck(grid, 6, 10, 27)

	-- Cuello largo hacia delante, con crin.
	for y = 25, 47, 2 do
		local zc = -10 - math.floor((y - 25) / 4) * 2
		box(grid, -2, 2, y, y, zc - 2, zc + 2, spotted, "body")
		box(grid, 0, 0, y, y, zc + 4, zc + 4, "secondaryDark", "body", false)
	end

	-- Cabeza con hocico claro y osiconos.
	ellipsoid(grid, 0, 49, -22, 4.4, 3.8, 6.4, function(_ix, _iy, iz)
		return if iz <= -13 then "primaryLight" else "primary"
	end, "body")
	for _, side in { -1, 1 } do
		box(grid, side * 2, side * 2, 53, 55, -16, -16, "accent", "body", false)
		extra(grid, "body", "accentDark", side * 2, 56.3, -16, 2.4, 1.4, 2.4)
		extra(grid, "body", "primaryDark", side * 4.6, 51, -19, 2.6, 1.2, 1.6, { 0, 0, side * 25 })
	end
	eyes(grid, 2.6, 50.4, 2.2)
	seat(grid, 53, -21)
	box(grid, 0, 0, 17, 23, 12, 12, "primaryDark", "body", false)

	return {
		boxes = finish(grid, palette),
		legs = legs,
		seat = { 0, 54, -21 },
		head = { 0, 59, -22 },
		deckTop = 28,
		deckSize = { 14, 22 },
		slots = gridSlots(4.5, -8, 4, 28),
		radius = 20,
	}
end

local BUILDERS: { [string]: (Palette) -> Rig } = {
	Turtle = turtle,
	Elephant = elephant,
	Giraffe = giraffe,
}

function VoxelArt.giant(species: string, palette: Palette): Rig
	local builder = BUILDERS[species] or turtle
	return builder(palette)
end

-- Estatua: el mismo gigante, todo de piedra.
function VoxelArt.statue(species: string): Rig
	local stone = FIXED.stone
	local rig = VoxelArt.giant(species, { primary = stone, secondary = stone, accent = stone })
	for _, item in rig.boxes do
		local shadeFactor = if item.key:find("Dark") then 0.88 elseif item.key:find("Light") then 1.06 else 1
		item.color = scaleColor(stone, shadeFactor)
	end
	return rig
end

-- Nodos de recursos (árboles, rocas, arbustos…) -------------------------------

local function nodeBox(
	list: { Box },
	color: RGB,
	x: number,
	y: number,
	z: number,
	sx: number,
	sy: number,
	sz: number,
	rot: { number }?
)
	table.insert(list, {
		group = "node",
		key = "node",
		x = x,
		y = y,
		z = z,
		sx = sx,
		sy = sy,
		sz = sz,
		color = color,
		collide = false,
		rot = rot,
	})
end

local NODE_BUILDERS: { [string]: (list: { Box }, v: number) -> () } = {
	Tree = function(list, v)
		local leaf = { 70, 175 + v * 10, 60 }
		nodeBox(list, { 130, 85, 45 }, 0, 3, 0, 2, 6, 2)
		nodeBox(list, { 110, 70, 38 }, 0, 0.5, 0, 3, 1, 3)
		nodeBox(list, leaf, 0, 8, 0, 7, 4, 7)
		nodeBox(list, scaleColor(leaf, 1.12), 0, 10.5, 0, 5, 2, 5)
		nodeBox(list, scaleColor(leaf, 0.85), 2.5, 7.5, 1.5, 3, 3, 3)
		nodeBox(list, scaleColor(leaf, 0.92), -2.5, 8.5, -2, 3, 3, 3)
	end,
	Palm = function(list, v)
		local trunk = { 200, 160, 100 }
		nodeBox(list, trunk, 0, 1.5, 0, 1.8, 3, 1.8)
		nodeBox(list, scaleColor(trunk, 0.9), 0.4, 4.5, 0, 1.6, 3, 1.6)
		nodeBox(list, trunk, 0.8, 7.5, 0, 1.5, 3, 1.5)
		local leaf = { 60, 185 + v * 8, 70 }
		for i = 0, 3 do
			nodeBox(list, scaleColor(leaf, 0.9 + i * 0.05), 0.8, 9.2, 0, 7, 0.8, 2, { 0, i * 45, -12 })
		end
		nodeBox(list, { 120, 80, 40 }, 1.6, 8.4, 0.8, 1.2, 1.2, 1.2)
		nodeBox(list, { 120, 80, 40 }, 0.2, 8.4, -0.8, 1.2, 1.2, 1.2)
	end,
	Rock = function(list, v)
		local gray = { 150 + v * 6, 150 + v * 6, 160 }
		nodeBox(list, gray, 0, 1.5, 0, 4, 3, 3.5)
		nodeBox(list, scaleColor(gray, 0.85), 1.8, 1, 1.2, 2.4, 2, 2.4)
		nodeBox(list, scaleColor(gray, 1.12), -0.6, 3.3, -0.4, 2.2, 0.8, 2)
	end,
	Coral = function(list)
		nodeBox(list, { 255, 110, 150 }, 0, 2, 0, 1.6, 4, 1.6)
		nodeBox(list, { 255, 110, 150 }, 0, 4.4, 0.9, 1.2, 1.2, 2)
		nodeBox(list, { 255, 170, 80 }, 1.6, 1.5, 0.4, 1.2, 3, 1.2)
		nodeBox(list, { 255, 140, 200 }, -1.4, 1.25, -0.6, 1.2, 2.5, 1.2)
		nodeBox(list, { 255, 170, 80 }, -1.4, 2.9, -0.6, 2, 0.8, 0.8)
	end,
	Crystal = function(list)
		nodeBox(list, { 110, 230, 255 }, 0, 2.5, 0, 1.6, 5, 1.6, { 0, 0, 12 })
		nodeBox(list, { 180, 120, 255 }, 1.4, 1.6, 0.6, 1.1, 3.2, 1.1, { 15, 0, -20 })
		nodeBox(list, { 130, 255, 230 }, -1.2, 1.3, -0.4, 1, 2.6, 1, { -10, 0, 22 })
		nodeBox(list, { 120, 120, 135 }, 0, 0.3, 0, 4, 0.6, 3.4)
	end,
	Bush = function(list, v)
		local green = { 55, 165 + v * 8, 70 }
		nodeBox(list, green, 0, 1.5, 0, 4, 3, 4)
		nodeBox(list, scaleColor(green, 1.12), 0.8, 3.3, 0.4, 2.6, 1.2, 2.6)
		nodeBox(list, scaleColor(green, 0.86), -1.6, 1.2, 1, 2, 2.2, 2)
		for i, offset in { { 1.6, 2.4, -2.05 }, { -1.2, 1.6, -2.05 }, { 2.05, 1.2, 0.8 } } do
			nodeBox(
				list,
				if i == 2 then { 240, 60, 80 } else { 225, 35, 55 },
				offset[1],
				offset[2],
				offset[3],
				0.9,
				0.9,
				0.9
			)
		end
	end,
	TallFruitTree = function(list)
		nodeBox(list, { 120, 80, 40 }, 0, 10, 0, 2, 20, 2)
		nodeBox(list, { 45, 140, 55 }, 0, 21.5, 0, 9, 3, 9)
		nodeBox(list, { 60, 160, 65 }, 0, 24, 0, 6, 2, 6)
		for i = 0, 3 do
			local angle = i * math.pi / 2
			nodeBox(list, { 255, 150, 30 }, math.cos(angle) * 3.6, 19.6, math.sin(angle) * 3.6, 1.4, 1.4, 1.4)
		end
	end,
}

-- variant: 0..1, para variar un poco el color entre nodos del mismo tipo.
function VoxelArt.node(nodeType: string, variant: number): { Box }
	local list: { Box } = {}
	local builder = NODE_BUILDERS[nodeType]
	if builder then
		builder(list, variant)
	end
	return list
end

return VoxelArt
