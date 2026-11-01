--!strict
-- Theme: colores y tipografía de la interfaz (estilo simulador, saturado y cálido).

local Theme = table.freeze({
	font = Enum.Font.FredokaOne,
	fontBody = Enum.Font.GothamBold,

	panel = Color3.fromRGB(255, 248, 230),
	panelDark = Color3.fromRGB(245, 230, 200),
	stroke = Color3.fromRGB(70, 45, 25),
	text = Color3.fromRGB(70, 45, 25),
	textLight = Color3.fromRGB(255, 255, 255),
	muted = Color3.fromRGB(150, 130, 110),

	orange = Color3.fromRGB(255, 160, 40),
	green = Color3.fromRGB(90, 200, 90),
	blue = Color3.fromRGB(70, 160, 240),
	red = Color3.fromRGB(240, 80, 80),
	purple = Color3.fromRGB(170, 100, 230),
	gold = Color3.fromRGB(255, 205, 50),
	gray = Color3.fromRGB(170, 170, 170),

	wood = Color3.fromRGB(170, 105, 55),
	stone = Color3.fromRGB(140, 145, 160),
	fruit = Color3.fromRGB(235, 60, 70),
	leaf = Color3.fromRGB(70, 180, 70),

	corner = 14,
	strokeWidth = 3,
	designSize = Vector2.new(1280, 720), -- la interfaz se escala desde este tamaño
})

return Theme
