--!strict
-- Theme: colores y tipografía de la interfaz (estilo simulador, saturado y cálido).

local Theme = table.freeze({
	font = Enum.Font.FredokaOne,
	fontBody = Enum.Font.GothamBold,

	panel = Color3.fromRGB(255, 250, 238),
	panelBottom = Color3.fromRGB(244, 228, 196),
	panelDark = Color3.fromRGB(240, 222, 188),
	hud = Color3.fromRGB(34, 40, 72), -- píldoras del HUD
	stroke = Color3.fromRGB(40, 28, 22),
	shadow = Color3.fromRGB(0, 0, 0),
	text = Color3.fromRGB(70, 45, 25),
	textLight = Color3.fromRGB(255, 255, 255),
	muted = Color3.fromRGB(140, 115, 90),

	orange = Color3.fromRGB(255, 160, 40),
	green = Color3.fromRGB(80, 205, 90),
	blue = Color3.fromRGB(60, 160, 245),
	red = Color3.fromRGB(240, 75, 75),
	purple = Color3.fromRGB(165, 95, 235),
	gold = Color3.fromRGB(255, 210, 60),
	gray = Color3.fromRGB(160, 160, 165),
	moneyGreen = Color3.fromRGB(90, 255, 110),

	wood = Color3.fromRGB(205, 130, 70),
	stone = Color3.fromRGB(175, 180, 200),
	fruit = Color3.fromRGB(255, 90, 95),
	leaf = Color3.fromRGB(70, 180, 70),

	corner = 16,
	strokeWidth = 3,
	designSize = Vector2.new(1280, 720), -- la interfaz se escala desde este tamaño
})

return Theme
