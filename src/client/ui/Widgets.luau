--!strict
--[[
	Widgets: piezas de interfaz reutilizables con el estilo del juego:
	botones gruesos con degradado, sombra y brillo; paneles crema con borde
	oscuro; textos blancos con contorno.
]]

local TweenService = game:GetService("TweenService")

local Icons = require(script.Parent.Icons)
local Theme = require(script.Parent.Theme)

local Widgets = {}

export type Button = {
	instance: TextButton,
	label: TextLabel,
	setText: (text: string) -> (),
	setEnabled: (enabled: boolean) -> (),
	setColor: (color: Color3) -> (),
	setHighlight: (on: boolean) -> (),
}

local SHADOW_DEPTH = 5

function Widgets.lighten(color: Color3, amount: number): Color3
	return color:Lerp(Color3.new(1, 1, 1), amount)
end

function Widgets.darken(color: Color3, amount: number): Color3
	return color:Lerp(Color3.new(0, 0, 0), amount)
end

function Widgets.corner(parent: Instance, radius: number?)
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, radius or Theme.corner)
	corner.Parent = parent
end

function Widgets.stroke(parent: Instance, thickness: number?, color: Color3?): UIStroke
	local stroke = Instance.new("UIStroke")
	stroke.Thickness = thickness or Theme.strokeWidth
	stroke.Color = color or Theme.stroke
	stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	stroke.LineJoinMode = Enum.LineJoinMode.Round
	stroke.Parent = parent
	return stroke
end

-- Degradado vertical: el fondo se pone blanco y los colores van en el degradado.
function Widgets.gradient(frame: GuiObject, top: Color3, bottom: Color3): UIGradient
	frame.BackgroundColor3 = Color3.new(1, 1, 1)
	local gradient = frame:FindFirstChildOfClass("UIGradient") or Instance.new("UIGradient")
	gradient.Color = ColorSequence.new(top, bottom)
	gradient.Rotation = 90
	gradient.Parent = frame
	return gradient
end

function Widgets.padding(parent: Instance, pixels: number)
	local padding = Instance.new("UIPadding")
	padding.PaddingLeft = UDim.new(0, pixels)
	padding.PaddingRight = UDim.new(0, pixels)
	padding.PaddingTop = UDim.new(0, pixels)
	padding.PaddingBottom = UDim.new(0, pixels)
	padding.Parent = parent
end

function Widgets.list(
	parent: Instance,
	direction: Enum.FillDirection,
	spacing: number,
	align: Enum.HorizontalAlignment?
): UIListLayout
	local layout = Instance.new("UIListLayout")
	layout.FillDirection = direction
	layout.Padding = UDim.new(0, spacing)
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.HorizontalAlignment = align or Enum.HorizontalAlignment.Left
	layout.VerticalAlignment = Enum.VerticalAlignment.Center
	layout.Parent = parent
	return layout
end

-- Panel crema con borde oscuro (o del color indicado).
function Widgets.panel(parent: Instance, size: UDim2, position: UDim2, anchor: Vector2?, color: Color3?): Frame
	local frame = Instance.new("Frame")
	frame.Size = size
	frame.Position = position
	frame.AnchorPoint = anchor or Vector2.zero
	frame.BorderSizePixel = 0
	if color then
		Widgets.gradient(frame, Widgets.lighten(color, 0.08), Widgets.darken(color, 0.05))
	else
		Widgets.gradient(frame, Theme.panel, Theme.panelBottom)
	end
	Widgets.corner(frame)
	Widgets.stroke(frame, 4)
	frame.Parent = parent
	return frame
end

-- Píldora oscura semitransparente (contadores del HUD).
function Widgets.darkPanel(parent: Instance, size: UDim2, position: UDim2, anchor: Vector2?): Frame
	local frame = Instance.new("Frame")
	frame.Size = size
	frame.Position = position
	frame.AnchorPoint = anchor or Vector2.zero
	frame.BorderSizePixel = 0
	frame.BackgroundColor3 = Theme.hud
	frame.BackgroundTransparency = 0.2
	Widgets.corner(frame, 14)
	Widgets.stroke(frame, 3)
	frame.Parent = parent
	return frame
end

-- Contorno oscuro para textos claros.
function Widgets.outlined(label: TextLabel, thickness: number?)
	local stroke = Instance.new("UIStroke")
	stroke.Color = Theme.stroke
	stroke.Thickness = thickness or 2.5
	stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Contextual
	stroke.LineJoinMode = Enum.LineJoinMode.Round
	stroke.Parent = label
end

function Widgets.label(parent: Instance, text: string, textSize: number, color: Color3?, font: Enum.Font?): TextLabel
	local label = Instance.new("TextLabel")
	label.BackgroundTransparency = 1
	label.Text = text
	label.TextSize = textSize
	label.TextColor3 = color or Theme.text
	label.Font = font or Theme.font
	label.TextWrapped = true
	label.Size = UDim2.new(1, 0, 0, textSize + 6)
	label.Parent = parent
	return label
end

-- Texto blanco con contorno (títulos, números del HUD, botones).
function Widgets.title(parent: Instance, text: string, textSize: number, color: Color3?): TextLabel
	local label = Widgets.label(parent, text, textSize, color or Theme.textLight)
	Widgets.outlined(label, math.max(textSize / 9, 2))
	return label
end

--[[
	Botón grueso estilo simulador: cara con degradado, brillo arriba, sombra
	debajo y texto blanco con contorno. Se hunde al pulsarlo.
	options: text, icon (clave de IconData), color, size, textSize, onClick
]]
function Widgets.button(
	parent: Instance,
	options: {
		text: string,
		icon: string?,
		color: Color3?,
		size: UDim2?,
		textSize: number?,
		onClick: (() -> ())?,
	}
): Button
	local color = options.color or Theme.orange
	local size = options.size or UDim2.fromOffset(160, 56)

	local button = Instance.new("TextButton")
	button.AutoButtonColor = false
	button.Text = ""
	button.BackgroundTransparency = 1
	button.Size = size

	local shadow = Instance.new("Frame")
	shadow.Name = "Shadow"
	shadow.BorderSizePixel = 0
	shadow.Size = UDim2.new(1, 0, 1, 0)
	shadow.Position = UDim2.fromOffset(0, SHADOW_DEPTH)
	shadow.BackgroundColor3 = Widgets.darken(color, 0.5)
	Widgets.corner(shadow)
	shadow.Parent = button

	local face = Instance.new("Frame")
	face.Name = "Face"
	face.BorderSizePixel = 0
	face.Size = UDim2.new(1, 0, 1, 0)
	Widgets.corner(face)
	local stroke = Widgets.stroke(face, Theme.strokeWidth)
	local gradient = Widgets.gradient(face, Widgets.lighten(color, 0.18), Widgets.darken(color, 0.12))
	face.Parent = button

	local shine = Instance.new("Frame")
	shine.Name = "Shine"
	shine.BorderSizePixel = 0
	shine.BackgroundColor3 = Color3.new(1, 1, 1)
	shine.BackgroundTransparency = 0.75
	shine.Size = UDim2.new(1, -14, 0.32, 0)
	shine.Position = UDim2.fromOffset(7, 5)
	Widgets.corner(shine, 10)
	shine.Parent = face

	local width, height = size.X.Offset, size.Y.Offset
	local textSize = options.textSize or 22
	local label: TextLabel
	if options.icon then
		local tall = height >= width * 0.8
		local iconSize = if tall then math.floor(height * 0.56) else math.floor(height * 0.74)
		local icon = Icons.make(options.icon, iconSize)
		if tall then
			icon.AnchorPoint = Vector2.new(0.5, 0)
			icon.Position = UDim2.new(0.5, 0, 0, 4)
		else
			icon.AnchorPoint = Vector2.new(0, 0.5)
			icon.Position = UDim2.new(0, 6, 0.5, 0)
		end
		icon.Parent = face
		label = Widgets.title(face, options.text, textSize)
		if tall then
			label.AnchorPoint = Vector2.new(0.5, 1)
			label.Position = UDim2.new(0.5, 0, 1, -3)
			label.Size = UDim2.new(1, -6, 0, textSize + 4)
		else
			label.Position = UDim2.new(0, iconSize + 10, 0, 0)
			label.Size = UDim2.new(1, -iconSize - 16, 1, 0)
			label.TextXAlignment = Enum.TextXAlignment.Left
		end
	else
		label = Widgets.title(face, options.text, textSize)
		label.Size = UDim2.new(1, -10, 1, 0)
		label.Position = UDim2.fromOffset(5, 0)
	end
	button.Parent = parent

	local enabled = true
	local baseColor = color
	local pulse: Tween? = nil

	local function paint()
		local c = if enabled then baseColor else Theme.gray
		gradient.Color = ColorSequence.new(Widgets.lighten(c, 0.18), Widgets.darken(c, 0.12))
		shadow.BackgroundColor3 = Widgets.darken(c, 0.5)
		label.TextTransparency = if enabled then 0 else 0.25
	end

	local function press(down: boolean)
		local offset = if down and enabled then SHADOW_DEPTH - 1 else 0
		TweenService:Create(face, TweenInfo.new(0.06), { Position = UDim2.fromOffset(0, offset) }):Play()
	end

	button.MouseButton1Down:Connect(function()
		press(true)
	end)
	button.MouseButton1Up:Connect(function()
		press(false)
	end)
	button.MouseLeave:Connect(function()
		press(false)
	end)
	button.Activated:Connect(function()
		if enabled and options.onClick then
			options.onClick()
		end
	end)

	local api: Button = {
		instance = button,
		label = label,
		setText = function(text: string)
			label.Text = text
		end,
		setEnabled = function(on: boolean)
			enabled = on
			paint()
		end,
		setColor = function(newColor: Color3)
			baseColor = newColor
			paint()
		end,
		setHighlight = function(on: boolean)
			if pulse then
				pulse:Cancel()
				pulse = nil
			end
			stroke.Color = if on then Theme.gold else Theme.stroke
			stroke.Thickness = Theme.strokeWidth
			if on then
				pulse = TweenService:Create(
					stroke,
					TweenInfo.new(0.45, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true),
					{ Thickness = Theme.strokeWidth + 5 }
				)
				pulse:Play()
			end
		end,
	}
	return api
end

-- 1234 → "1.234"; 12345 → "12,3 K"; 1234567 → "1,23 M".
function Widgets.formatNumber(value: number): string
	local n = math.floor(value)
	local function decimal(x: number, digits: number): string
		return (string.gsub(string.format(`%.{digits}f`, x), "%.", ","))
	end
	if n >= 1e9 then
		return decimal(n / 1e9, 2) .. " B"
	elseif n >= 1e6 then
		return decimal(n / 1e6, 2) .. " M"
	elseif n >= 1e4 then
		return decimal(n / 1e3, 1) .. " K"
	elseif n >= 1000 then
		return `{math.floor(n / 1000)}.{string.format("%03d", n % 1000)}`
	end
	return tostring(n)
end

function Widgets.formatTime(seconds: number): string
	local s = math.max(math.floor(seconds), 0)
	return string.format("%d:%02d", math.floor(s / 60), s % 60)
end

return Widgets
