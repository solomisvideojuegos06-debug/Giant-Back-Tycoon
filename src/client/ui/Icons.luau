--!strict
--[[
	Icons: dibuja los iconos propios de IconData con Frames (sin imágenes ni
	emojis): degradados, contornos oscuros y brillos, estilo simulador.

	Icons.make("coin", 40) devuelve un Frame cuadrado de 40 px.
]]

local IconData = require(script.Parent.IconData)
local Theme = require(script.Parent.Theme)

local Icons = {}

local OUTLINE = Color3.fromRGB(40, 28, 22)

local function color(rgb: { number }): Color3
	return Color3.fromRGB(rgb[1], rgb[2], rgb[3])
end

local function drawLayer(root: Frame, layer: IconData.Layer, size: number)
	local frame: GuiObject
	if layer.text then
		local label = Instance.new("TextLabel")
		label.BackgroundTransparency = 1
		label.Text = layer.text
		label.Font = Theme.font
		label.TextScaled = true
		label.TextColor3 = color(layer.c)
		local stroke = Instance.new("UIStroke")
		stroke.Color = OUTLINE
		stroke.Thickness = math.max(size / 40, 1)
		stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Contextual
		stroke.Parent = label
		frame = label
	else
		local box = Instance.new("Frame")
		box.BorderSizePixel = 0
		if layer.hollow then
			box.BackgroundTransparency = 1
		elseif layer.c2 then
			-- El degradado multiplica el color de fondo: fondo blanco y colores en el degradado.
			box.BackgroundColor3 = Color3.new(1, 1, 1)
			local gradient = Instance.new("UIGradient")
			gradient.Color = ColorSequence.new(color(layer.c), color(layer.c2))
			gradient.Rotation = 90
			gradient.Parent = box
		else
			box.BackgroundColor3 = color(layer.c)
		end
		if layer.a and not layer.hollow then
			box.BackgroundTransparency = layer.a
		end
		if layer.r and layer.r > 0 then
			local corner = Instance.new("UICorner")
			corner.CornerRadius = UDim.new(layer.r, 0)
			corner.Parent = box
		end
		if layer.s and layer.s > 0 then
			local stroke = Instance.new("UIStroke")
			stroke.Color = OUTLINE
			stroke.Thickness = math.max(layer.s * size / 100, 1)
			stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
			stroke.LineJoinMode = Enum.LineJoinMode.Round
			stroke.Parent = box
		end
		frame = box
	end
	frame.AnchorPoint = Vector2.new(0.5, 0.5)
	frame.Position = UDim2.fromScale(layer.x / 100, layer.y / 100)
	frame.Size = UDim2.fromScale(layer.w / 100, layer.h / 100)
	frame.Rotation = layer.rot or 0
	frame.Parent = root
end

function Icons.make(kind: string, size: number?): Frame
	local pixels = size or 40
	local root = Instance.new("Frame")
	root.Name = `Icon_{kind}`
	root.BackgroundTransparency = 1
	root.Size = UDim2.fromOffset(pixels, pixels)
	local layers = IconData[kind]
	if layers then
		for _, layer in layers do
			drawLayer(root, layer, pixels)
		end
	end
	return root
end

return Icons
