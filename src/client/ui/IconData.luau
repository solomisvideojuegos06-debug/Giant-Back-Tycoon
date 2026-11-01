--!strict
--[[
	IconData: los iconos propios del juego, como datos (sin imágenes ni emojis).

	Cada icono es una lista de capas dibujadas en un lienzo de 100 x 100:
	  x, y      centro de la capa
	  w, h      tamaño
	  c, c2     color (y color inferior si lleva degradado vertical)
	  r         redondeo de las esquinas (0 = recto, 0.5 = círculo)
	  rot       giro en grados
	  s         grosor del contorno oscuro (0 = sin contorno)
	  a         transparencia (0 = opaco)
	  text      si la capa es un texto
	  hollow    solo contorno, sin relleno
	Icons.luau las convierte en Frames; la vista previa de herramientas las
	dibuja en HTML. Función pura: sin dependencias de Roblox.
]]

export type RGB = { number }

export type Layer = {
	x: number,
	y: number,
	w: number,
	h: number,
	c: RGB,
	c2: RGB?,
	r: number?,
	rot: number?,
	s: number?,
	a: number?,
	text: string?,
	hollow: boolean?, -- solo el contorno (sin relleno)
}

local OUT: RGB = { 40, 28, 22 }
local WHITE: RGB = { 255, 255, 255 }

local function L(x: number, y: number, w: number, h: number, c: RGB, opts: { [string]: any }?): Layer
	local layer: Layer = { x = x, y = y, w = w, h = h, c = c }
	if opts then
		for key, value in opts do
			(layer :: any)[key] = value
		end
	end
	return layer
end

-- Silueta oscura un poco más grande debajo: contorno limpio para formas compuestas.
local function under(x: number, y: number, w: number, h: number, opts: { [string]: any }?): Layer
	local layer = L(x, y, w + 9, h + 9, OUT, opts)
	return layer
end

local function shine(x: number, y: number, w: number, h: number, rot: number?): Layer
	return L(x, y, w, h, WHITE, { r = 0.5, a = 0.45, rot = rot or -25 })
end

local GOLD = { 255, 222, 85 }
local GOLD_DARK = { 232, 158, 22 }
local RED = { 255, 92, 92 }
local RED_DARK = { 200, 30, 48 }
local GREEN = { 120, 230, 110 }
local GREEN_DARK = { 40, 160, 70 }
local WOOD = { 196, 128, 70 }
local WOOD_DARK = { 140, 84, 44 }
local WOOD_END = { 245, 200, 135 }
local STONE = { 185, 190, 205 }
local STONE_DARK = { 115, 120, 138 }

local function coin(scale: number, cx: number, cy: number): { Layer }
	local k = scale
	return {
		L(cx, cy, 86 * k, 86 * k, GOLD, { c2 = GOLD_DARK, r = 0.5, s = 5 }),
		L(cx, cy, 60 * k, 60 * k, GOLD_DARK, { c2 = GOLD, r = 0.5 }),
		L(cx, cy + 1 * k, 50 * k, 62 * k, { 255, 244, 175 }, { text = "$" }),
		shine(cx - 18 * k, cy - 20 * k, 13 * k, 22 * k),
	}
end

local function apple(scale: number, cx: number, cy: number): { Layer }
	local k = scale
	return {
		L(cx + 2 * k, cy - 34 * k, 8 * k, 22 * k, WOOD_DARK, { r = 0.4, rot = 12, s = 3 }),
		L(cx, cy, 86 * k, 76 * k, RED, { c2 = RED_DARK, r = 0.5, s = 5 }),
		L(cx + 18 * k, cy - 38 * k, 32 * k, 16 * k, GREEN, { c2 = GREEN_DARK, r = 0.5, rot = -25, s = 3 }),
		shine(cx - 20 * k, cy - 12 * k, 14 * k, 24 * k, 20),
	}
end

local function badge(color: RGB, colorDark: RGB, symbol: string): { Layer }
	return {
		L(76, 76, 42, 42, color, { c2 = colorDark, r = 0.5, s = 4 }),
		L(76, 77, 34, 36, WHITE, { text = symbol }),
	}
end

local function join(...: { Layer }): { Layer }
	local result: { Layer } = {}
	for _, list in { ... } do
		for _, layer in list do
			table.insert(result, layer)
		end
	end
	return result
end

local function log(cx: number, cy: number, w: number, h: number): { Layer }
	return {
		L(cx, cy, w, h, WOOD, { c2 = WOOD_DARK, r = 0.45, s = 5 }),
		L(cx - w * 0.1, cy - h * 0.18, w * 0.6, h * 0.12, { 225, 160, 100 }, { r = 0.5, a = 0.3 }),
		L(cx + w / 2 - h / 2, cy, h, h, WOOD_END, { c2 = { 220, 165, 100 }, r = 0.5, s = 4 }),
		L(cx + w / 2 - h / 2, cy, h * 0.45, h * 0.45, { 200, 140, 80 }, { r = 0.5 }),
	}
end

local IconData: { [string]: { Layer } } = {
	coin = coin(1, 50, 52),

	wood = join(log(48, 66, 84, 30), log(44, 38, 70, 28)),

	stone = {
		L(50, 58, 80, 62, STONE, { c2 = STONE_DARK, r = 0.3, rot = 6, s = 5 }),
		L(38, 44, 34, 24, { 215, 220, 232 }, { r = 0.35, rot = -12 }),
		L(66, 70, 30, 16, { 105, 110, 128 }, { r = 0.4, rot = 8 }),
		shine(30, 40, 10, 16),
	},

	fruit = apple(1, 50, 60),

	feed = join(apple(0.82, 44, 54), badge(GREEN, GREEN_DARK, "+")),

	sell = join(coin(0.8, 44, 46), badge({ 255, 175, 60 }, { 230, 120, 20 }, ">")),

	build = {
		L(44, 60, 15, 72, WOOD, { c2 = WOOD_DARK, r = 0.4, rot = 40, s = 4 }),
		L(62, 34, 60, 28, { 215, 220, 230 }, { c2 = { 130, 135, 150 }, r = 0.2, rot = 40, s = 5 }),
		L(56, 40, 10, 28, { 100, 104, 120 }, { r = 0.2, rot = 40 }),
		shine(70, 26, 8, 16, 40),
	},

	pilot = {
		L(50, 50, 88, 88, WOOD, { c2 = WOOD_DARK, r = 0.5, s = 5 }),
		L(50, 50, 60, 60, { 120, 80, 50 }, { r = 0.5 }),
		L(50, 50, 9, 62, WOOD, { r = 0.3 }),
		L(50, 50, 9, 62, WOOD, { r = 0.3, rot = 60 }),
		L(50, 50, 9, 62, WOOD, { r = 0.3, rot = 120 }),
		L(50, 50, 26, 26, GOLD, { c2 = GOLD_DARK, r = 0.5, s = 4 }),
		shine(30, 28, 10, 18, -40),
	},

	egg = {
		L(50, 54, 64, 86, { 255, 251, 238 }, { c2 = { 232, 215, 182 }, r = 0.5, s = 5 }),
		L(38, 46, 17, 15, { 110, 205, 100 }, { r = 0.5 }),
		L(62, 66, 19, 16, { 255, 165, 60 }, { r = 0.5 }),
		L(60, 32, 11, 10, { 95, 165, 245 }, { r = 0.5 }),
		shine(35, 30, 10, 20, -15),
	},

	book = {
		L(54, 52, 68, 84, { 185, 115, 245 }, { c2 = { 120, 60, 195 }, r = 0.12, s = 5 }),
		L(24, 52, 14, 84, { 100, 45, 165 }, { r = 0.15, s = 5 }),
		L(56, 34, 38, 14, { 255, 248, 225 }, { r = 0.3 }),
		L(56, 52, 30, 6, { 255, 248, 225 }, { r = 0.3, a = 0.4 }),
		L(72, 92, 9, 18, RED, { r = 0.1 }),
	},

	shop = {
		L(50, 52, 64, 64, { 125, 240, 150 }, { c2 = { 35, 165, 85 }, r = 0.15, rot = 45, s = 5 }),
		L(50, 40, 30, 30, { 200, 255, 210 }, { r = 0.15, rot = 45, a = 0.35 }),
		shine(38, 36, 8, 16, 45),
	},

	heart = {
		under(36, 40, 40, 40, { r = 0.5 }),
		under(64, 40, 40, 40, { r = 0.5 }),
		under(50, 56, 46, 46, { r = 0.12, rot = 45 }),
		L(36, 40, 40, 40, RED, { c2 = RED_DARK, r = 0.5 }),
		L(64, 40, 40, 40, RED, { c2 = RED_DARK, r = 0.5 }),
		L(50, 56, 46, 46, RED_DARK, { c2 = RED_DARK, r = 0.12, rot = 45 }),
		L(50, 42, 30, 22, RED, { r = 0.4 }),
		shine(32, 34, 10, 16, -30),
	},

	paw = {
		under(50, 66, 48, 40, { r = 0.5 }),
		under(24, 42, 18, 22, { r = 0.5 }),
		under(40, 24, 18, 22, { r = 0.5 }),
		under(60, 24, 18, 22, { r = 0.5 }),
		under(76, 42, 18, 22, { r = 0.5 }),
		L(50, 66, 48, 40, { 255, 190, 120 }, { c2 = { 230, 135, 70 }, r = 0.5 }),
		L(24, 42, 18, 22, { 255, 190, 120 }, { c2 = { 230, 135, 70 }, r = 0.5 }),
		L(40, 24, 18, 22, { 255, 190, 120 }, { c2 = { 230, 135, 70 }, r = 0.5 }),
		L(60, 24, 18, 22, { 255, 190, 120 }, { c2 = { 230, 135, 70 }, r = 0.5 }),
		L(76, 42, 18, 22, { 255, 190, 120 }, { c2 = { 230, 135, 70 }, r = 0.5 }),
		shine(40, 58, 10, 12, -30),
	},

	home = {
		under(50, 36, 56, 56, { r = 0.1, rot = 45 }),
		under(50, 64, 64, 46, { r = 0.1 }),
		L(50, 36, 56, 56, RED, { c2 = RED_DARK, r = 0.1, rot = 45 }),
		L(50, 64, 64, 46, { 255, 225, 160 }, { c2 = { 235, 185, 110 }, r = 0.1 }),
		L(50, 72, 18, 30, WOOD_DARK, { r = 0.2, s = 3 }),
	},

	target = {
		L(50, 50, 88, 88, RED, { c2 = RED_DARK, r = 0.5, s = 5 }),
		L(50, 50, 60, 60, WHITE, { r = 0.5 }),
		L(50, 50, 34, 34, RED, { r = 0.5 }),
		L(50, 50, 12, 12, WHITE, { r = 0.5 }),
	},

	close = {
		L(50, 50, 78, 20, WHITE, { r = 0.5, rot = 45, s = 4 }),
		L(50, 50, 78, 20, WHITE, { r = 0.5, rot = -45, s = 4 }),
	},

	herd = {
		L(28, 60, 34, 34, GREEN, { c2 = GREEN_DARK, r = 0.5, s = 4 }),
		L(72, 60, 34, 34, GREEN, { c2 = GREEN_DARK, r = 0.5, s = 4 }),
		L(50, 40, 38, 38, { 140, 245, 130 }, { c2 = GREEN_DARK, r = 0.5, s = 4 }),
	},

	lock = {
		L(50, 36, 44, 44, WHITE, { r = 0.5, hollow = true, s = 9 }),
		L(50, 64, 70, 52, GOLD, { c2 = GOLD_DARK, r = 0.2, s = 5 }),
		L(50, 62, 12, 20, OUT, { r = 0.5 }),
	},
}

return IconData
