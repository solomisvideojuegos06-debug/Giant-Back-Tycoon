--!strict
-- Widgets: piezas de interfaz reutilizables (paneles, botones, etiquetas).

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
	stroke.Parent = parent
	return stroke
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

function Widgets.panel(parent: Instance, size: UDim2, position: UDim2, anchor: Vector2?, color: Color3?): Frame
	local frame = Instance.new("Frame")
	frame.Size = size
	frame.Position = position
	frame.AnchorPoint = anchor or Vector2.zero
	frame.BackgroundColor3 = color or Theme.panel
	frame.BorderSizePixel = 0
	Widgets.corner(frame)
	Widgets.stroke(frame)
	frame.Parent = parent
	return frame
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

-- Etiqueta con contorno, para escribir sobre el mundo.
function Widgets.outlined(label: TextLabel)
	local stroke = Instance.new("UIStroke")
	stroke.Color = Theme.stroke
	stroke.Thickness = 2
	stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Contextual
	stroke.Parent = label
end

local function darken(color: Color3, amount: number): Color3
	local h, sat, v = color:ToHSV()
	return Color3.fromHSV(h, sat, math.max(v - amount, 0))
end

--[[
	Botón grande y redondeado, pensado para el pulgar.
	options: text, icon (clave de Icons), color, size, textSize, onClick
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
	local button = Instance.new("TextButton")
	button.AutoButtonColor = false
	button.Text = ""
	button.Size = options.size or UDim2.fromOffset(160, 56)
	button.BackgroundColor3 = color
	button.BorderSizePixel = 0
	Widgets.corner(button)
	local stroke = Widgets.stroke(button)

	local shade = Instance.new("Frame")
	shade.Name = "Shade"
	shade.BackgroundColor3 = darken(color, 0.18)
	shade.BorderSizePixel = 0
	shade.Size = UDim2.new(1, 0, 0.35, 0)
	shade.Position = UDim2.fromScale(0, 0.65)
	shade.ZIndex = 0
	Widgets.corner(shade)
	shade.Parent = button

	local content = Instance.new("Frame")
	content.BackgroundTransparency = 1
	content.Size = UDim2.fromScale(1, 1)
	content.ZIndex = 2
	content.Parent = button

	local textSize = options.textSize or 22
	local label: TextLabel
	if options.icon then
		local isTall = button.Size.Y.Offset >= button.Size.X.Offset * 0.8
		local iconSize = if isTall
			then math.floor(button.Size.Y.Offset * 0.5)
			else math.floor(button.Size.Y.Offset * 0.7)
		local icon = Icons.make(options.icon, iconSize)
		icon.ZIndex = 3
		if isTall then
			icon.AnchorPoint = Vector2.new(0.5, 0)
			icon.Position = UDim2.new(0.5, 0, 0, 6)
		else
			icon.AnchorPoint = Vector2.new(0, 0.5)
			icon.Position = UDim2.new(0, 8, 0.5, 0)
		end
		icon.Parent = content
		label = Widgets.label(content, options.text, textSize, Theme.textLight)
		if isTall then
			label.AnchorPoint = Vector2.new(0.5, 1)
			label.Position = UDim2.new(0.5, 0, 1, -4)
			label.Size = UDim2.new(1, -6, 0, textSize + 4)
		else
			label.Position = UDim2.new(0, iconSize + 12, 0, 0)
			label.Size = UDim2.new(1, -iconSize - 18, 1, 0)
			label.TextXAlignment = Enum.TextXAlignment.Left
		end
	else
		label = Widgets.label(content, options.text, textSize, Theme.textLight)
		label.Size = UDim2.new(1, -10, 1, 0)
		label.Position = UDim2.fromOffset(5, 0)
	end
	label.TextScaled = false
	label.ZIndex = 3
	Widgets.outlined(label)
	button.Parent = parent

	local enabled = true
	local baseColor = color
	local pulse: Tween? = nil

	button.MouseButton1Down:Connect(function()
		if enabled then
			TweenService:Create(button, TweenInfo.new(0.06), { BackgroundColor3 = darken(baseColor, 0.12) }):Play()
		end
	end)
	button.MouseButton1Up:Connect(function()
		TweenService
			:Create(button, TweenInfo.new(0.1), { BackgroundColor3 = if enabled then baseColor else Theme.gray })
			:Play()
	end)
	button.MouseLeave:Connect(function()
		button.BackgroundColor3 = if enabled then baseColor else Theme.gray
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
			button.BackgroundColor3 = if on then baseColor else Theme.gray
			shade.BackgroundColor3 = darken(if on then baseColor else Theme.gray, 0.18)
		end,
		setColor = function(newColor: Color3)
			baseColor = newColor
			if enabled then
				button.BackgroundColor3 = newColor
				shade.BackgroundColor3 = darken(newColor, 0.18)
			end
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
					TweenInfo.new(0.5, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true),
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
