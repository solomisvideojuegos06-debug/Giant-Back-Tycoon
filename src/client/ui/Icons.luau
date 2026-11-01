--!strict
--[[
	Icons: iconos propios dibujados con Frames (sin imágenes ni emojis), en el
	mismo estilo redondeado de la interfaz. Icons.make("coin", 40) devuelve un
	Frame cuadrado de 40 px listo para colocar.
]]

local Theme = require(script.Parent.Theme)

local Icons = {}

local function shape(parent: Instance, size: UDim2, position: UDim2, color: Color3, round: number?): Frame
	local frame = Instance.new("Frame")
	frame.Size = size
	frame.Position = position
	frame.AnchorPoint = Vector2.new(0.5, 0.5)
	frame.BackgroundColor3 = color
	frame.BorderSizePixel = 0
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(round or 0.5, 0)
	corner.Parent = frame
	frame.Parent = parent
	return frame
end

local function outline(frame: Frame, thickness: number?)
	local stroke = Instance.new("UIStroke")
	stroke.Color = Theme.stroke
	stroke.Thickness = thickness or 2
	stroke.Parent = frame
end

local function s(x: number, y: number): UDim2
	return UDim2.fromScale(x, y)
end

local DRAW: { [string]: (Frame) -> () } = {}

DRAW.coin = function(root: Frame)
	local outer = shape(root, s(0.9, 0.9), s(0.5, 0.5), Theme.gold)
	outline(outer)
	shape(root, s(0.6, 0.6), s(0.5, 0.5), Color3.fromRGB(235, 165, 20))
	shape(root, s(0.14, 0.4), s(0.5, 0.5), Theme.gold, 0.4)
end

DRAW.wood = function(root: Frame)
	local log = shape(root, s(0.92, 0.5), s(0.5, 0.55), Theme.wood, 0.4)
	outline(log)
	local endCap = shape(root, s(0.42, 0.42), s(0.78, 0.55), Color3.fromRGB(230, 180, 110))
	outline(endCap, 1.5)
	shape(root, s(0.18, 0.18), s(0.78, 0.55), Color3.fromRGB(190, 130, 70))
end

DRAW.stone = function(root: Frame)
	local rock = shape(root, s(0.68, 0.68), s(0.5, 0.52), Theme.stone, 0.25)
	rock.Rotation = 45
	outline(rock)
	local shine = shape(root, s(0.2, 0.2), s(0.38, 0.38), Color3.fromRGB(200, 205, 215), 0.3)
	shine.Rotation = 45
end

DRAW.fruit = function(root: Frame)
	local body = shape(root, s(0.8, 0.78), s(0.5, 0.58), Theme.fruit)
	outline(body)
	shape(root, s(0.08, 0.22), s(0.5, 0.17), Color3.fromRGB(110, 70, 40), 0.3)
	local leaf = shape(root, s(0.32, 0.16), s(0.66, 0.18), Theme.leaf)
	leaf.Rotation = -25
	shape(root, s(0.16, 0.16), s(0.34, 0.45), Color3.fromRGB(255, 160, 160))
end

DRAW.feed = function(root: Frame)
	DRAW.fruit(root)
	local plus = shape(root, s(0.36, 0.36), s(0.82, 0.82), Theme.green)
	outline(plus, 1.5)
	shape(plus, s(0.6, 0.18), s(0.5, 0.5), Theme.textLight, 0.3)
	shape(plus, s(0.18, 0.6), s(0.5, 0.5), Theme.textLight, 0.3)
end

DRAW.build = function(root: Frame)
	local handle = shape(root, s(0.16, 0.8), s(0.52, 0.55), Theme.wood, 0.3)
	handle.Rotation = 35
	outline(handle, 1.5)
	local head = shape(root, s(0.62, 0.26), s(0.38, 0.32), Color3.fromRGB(150, 155, 170), 0.25)
	head.Rotation = 35
	outline(head)
end

DRAW.pilot = function(root: Frame)
	local ring = shape(root, s(0.86, 0.86), s(0.5, 0.5), Color3.fromRGB(0, 0, 0))
	ring.BackgroundTransparency = 1
	local stroke = Instance.new("UIStroke")
	stroke.Color = Theme.stroke
	stroke.Thickness = 6
	stroke.Parent = ring
	shape(root, s(0.8, 0.12), s(0.5, 0.5), Theme.stroke, 0.3)
	shape(root, s(0.12, 0.44), s(0.5, 0.7), Theme.stroke, 0.3)
	shape(root, s(0.3, 0.3), s(0.5, 0.5), Theme.orange)
end

DRAW.egg = function(root: Frame)
	local egg = shape(root, s(0.62, 0.85), s(0.5, 0.52), Color3.fromRGB(250, 240, 215), 0.5)
	outline(egg)
	shape(egg, s(0.25, 0.18), s(0.35, 0.45), Theme.green)
	shape(egg, s(0.2, 0.15), s(0.68, 0.62), Theme.orange)
end

DRAW.book = function(root: Frame)
	local cover = shape(root, s(0.72, 0.86), s(0.52, 0.5), Theme.purple, 0.15)
	outline(cover)
	shape(root, s(0.12, 0.86), s(0.2, 0.5), Color3.fromRGB(120, 60, 180), 0.15)
	shape(cover, s(0.5, 0.12), s(0.55, 0.3), Theme.panel, 0.3)
end

DRAW.shop = function(root: Frame)
	local gem = shape(root, s(0.62, 0.62), s(0.5, 0.52), Theme.green, 0.2)
	gem.Rotation = 45
	outline(gem)
	local shine = shape(root, s(0.2, 0.2), s(0.4, 0.4), Color3.fromRGB(200, 255, 200), 0.3)
	shine.Rotation = 45
end

DRAW.heart = function(root: Frame)
	local left = shape(root, s(0.46, 0.46), s(0.36, 0.38), Theme.red)
	local right = shape(root, s(0.46, 0.46), s(0.64, 0.38), Theme.red)
	local bottom = shape(root, s(0.5, 0.5), s(0.5, 0.58), Theme.red, 0.1)
	bottom.Rotation = 45
	outline(left, 1.5)
	outline(right, 1.5)
end

DRAW.herd = function(root: Frame)
	for i, x in { 0.25, 0.5, 0.75 } do
		local dot = shape(root, s(0.3, 0.3), s(x, if i == 2 then 0.4 else 0.6), Theme.green)
		outline(dot, 1.5)
	end
end

DRAW.sell = function(root: Frame)
	DRAW.coin(root)
	local arrow = shape(root, s(0.34, 0.34), s(0.82, 0.82), Theme.orange)
	outline(arrow, 1.5)
	shape(arrow, s(0.6, 0.18), s(0.5, 0.5), Theme.textLight, 0.3)
end

DRAW.home = function(root: Frame)
	local base = shape(root, s(0.64, 0.46), s(0.5, 0.66), Theme.orange, 0.15)
	outline(base)
	local roof = shape(root, s(0.5, 0.5), s(0.5, 0.42), Theme.red, 0.1)
	roof.Rotation = 45
	outline(roof)
end

DRAW.close = function(root: Frame)
	local a = shape(root, s(0.8, 0.18), s(0.5, 0.5), Theme.textLight, 0.4)
	a.Rotation = 45
	local b = shape(root, s(0.8, 0.18), s(0.5, 0.5), Theme.textLight, 0.4)
	b.Rotation = -45
end

DRAW.lock = function(root: Frame)
	local shackle = shape(root, s(0.5, 0.5), s(0.5, 0.36), Theme.gray)
	shackle.BackgroundTransparency = 1
	local stroke = Instance.new("UIStroke")
	stroke.Color = Theme.stroke
	stroke.Thickness = 4
	stroke.Parent = shackle
	local body = shape(root, s(0.7, 0.5), s(0.5, 0.66), Theme.gold, 0.2)
	outline(body)
end

function Icons.make(kind: string, size: number?): Frame
	local root = Instance.new("Frame")
	root.Name = `Icon_{kind}`
	root.BackgroundTransparency = 1
	root.Size = UDim2.fromOffset(size or 40, size or 40)
	local aspect = Instance.new("UIAspectRatioConstraint")
	aspect.AspectRatio = 1
	aspect.Parent = root
	local draw = DRAW[kind]
	if draw then
		draw(root)
	end
	return root
end

return Icons
