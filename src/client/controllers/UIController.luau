--!strict
--[[
	UIController
	Interfaz completa (GDD, sección I): pensada primero para móvil.

	- Arriba a la derecha: monedas, Madera, Piedra y Fruta con su capacidad.
	- Arriba a la izquierda: un solo objetivo; debajo, manada y lluvia de fruta.
	- Derecha (pulgar): Alimentar, Construir, Piloto y Vender.
	- Izquierda: Linaje, Libro, Tienda, y Volver / Criar cuando toca.
	- Menús: tienda de máquinas por hueco, Linaje (huevo y generación),
	  Libro de rasgos y Tienda (Robux).
	- Avisos, peticiones de cría, eclosión y ofertas (nunca antes del minuto 5).
	Todo lo que se pide al servidor se valida allí.
]]

local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage.Shared
local Economy = require(Shared.Config.Economy)
local Formulas = require(Shared.Formulas)
local Levels = require(Shared.Config.Levels)
local Machines = require(Shared.Config.Machines)
local Products = require(Shared.Config.Products)
local Remotes = require(Shared.Remotes)
local Skins = require(Shared.Config.Skins)
local Species = require(Shared.Config.Species)
local Traits = require(Shared.Config.Traits)
local World = require(Shared.World)
local ClientState = require(script.Parent.Parent.ClientState)
local Icons = require(script.Parent.Parent.ui.Icons)
local Theme = require(script.Parent.Parent.ui.Theme)
local Widgets = require(script.Parent.Parent.ui.Widgets)
local GiantRenderController = require(script.Parent.GiantRenderController)
local PlatformController = require(script.Parent.PlatformController)

type Button = Widgets.Button

local UIController = {}

local player = Players.LocalPlayer
local gui: ScreenGui
local buttons: { [string]: Button } = {}
local openWindow: Frame? = nil
local openWindowName: string? = nil
local refreshers: { [string]: () -> () } = {}
local sessionStart = os.clock()
local lastOfferAt = 0
local fruitRain = { name = "", endsAt = 0 }

local RESOURCE_NAMES = { wood = "Madera", stone = "Piedra", fruit = "Fruta" }
local TOTAL_COMBINATIONS = 108 -- 3 especies x 36 parejas de 9 rasgos

-- Utilidades -------------------------------------------------------------------

local function number(key: string): number
	return ClientState.number(key)
end

local function tableOf(key: string): { [any]: any }
	local value = ClientState.get(key)
	return if type(value) == "table" then value else {}
end

local function serverNow(): number
	return Workspace:GetServerTimeNow()
end

local function traitNames(traits: { string }): string
	local names = {}
	for _, trait in traits do
		local def = Traits[trait]
		table.insert(names, if def then def.displayName else trait)
	end
	return table.concat(names, " · ")
end

local function speciesName(id: string): string
	local def = Species[id]
	return if def then def.displayName else id
end

local function ownedCount(machineId: string): number
	local count = 0
	for _, machine in tableOf("machines") do
		if type(machine) == "table" and machine.id == machineId then
			count += 1
		end
	end
	return count
end

local function machinePrice(machineId: string): number
	local def = Machines.byId[machineId]
	return Formulas.machinePrice(def.price, ownedCount(machineId), def.firstFree == true, Machines.repeatCostMultiplier)
end

local function emptySlot(): number?
	local machines = tableOf("machines")
	for slot = 1, number("slots") do
		if not machines[tostring(slot)] then
			return slot
		end
	end
	return nil
end

-- Avisos -------------------------------------------------------------------------

local toastList: Frame

function UIController.toast(message: string, color: Color3?)
	local toast = Widgets.panel(toastList, UDim2.fromOffset(520, 46), UDim2.new(), nil, color or Theme.panel)
	local label = Widgets.label(toast, message, 20)
	label.Size = UDim2.new(1, -16, 1, 0)
	label.Position = UDim2.fromOffset(8, 0)
	task.delay(3.2, function()
		local fade = TweenService:Create(toast, TweenInfo.new(0.3), { BackgroundTransparency = 1 })
		TweenService:Create(label, TweenInfo.new(0.3), { TextTransparency = 1 }):Play()
		fade.Completed:Connect(function()
			toast:Destroy()
		end)
		fade:Play()
	end)
	local children = toastList:GetChildren()
	local frames = 0
	for _, child in children do
		if child:IsA("Frame") then
			frames += 1
		end
	end
	if frames > 4 then
		for _, child in children do
			if child:IsA("Frame") and child ~= toast then
				child:Destroy()
				break
			end
		end
	end
end

local function reply(ok: boolean, message: string?)
	if message then
		UIController.toast(message, if ok then Theme.panel else Color3.fromRGB(255, 220, 210))
	end
end

local function invoke(remote: RemoteFunction, ...: any): (boolean, string?)
	local args = table.pack(...)
	local ok, success, message = pcall(function()
		return remote:InvokeServer(table.unpack(args, 1, args.n))
	end)
	if not ok then
		return false, "No se ha podido conectar con el servidor"
	end
	return success == true, if type(message) == "string" then message else nil
end

-- Ventanas -------------------------------------------------------------------------

local function closeWindow()
	if openWindow then
		openWindow:Destroy()
		openWindow = nil
		openWindowName = nil
	end
end

local function window(name: string, title: string, size: Vector2): (Frame, Frame)
	closeWindow()
	local frame = Widgets.panel(gui, UDim2.fromOffset(size.X, size.Y), UDim2.fromScale(0.5, 0.5), Vector2.new(0.5, 0.5))
	frame.ZIndex = 20
	-- Barra de título de color con el nombre en blanco.
	local bar = Instance.new("Frame")
	bar.BorderSizePixel = 0
	bar.Size = UDim2.new(1, 0, 0, 58)
	Widgets.gradient(bar, Widgets.lighten(Theme.orange, 0.15), Widgets.darken(Theme.orange, 0.1))
	Widgets.corner(bar)
	bar.Parent = frame
	local barBottom = Instance.new("Frame")
	barBottom.BorderSizePixel = 0
	barBottom.Size = UDim2.new(1, 0, 0, 16)
	barBottom.Position = UDim2.new(0, 0, 1, -16)
	Widgets.gradient(barBottom, Widgets.darken(Theme.orange, 0.05), Widgets.darken(Theme.orange, 0.1))
	barBottom.Parent = bar
	local header = Widgets.title(bar, title, 34)
	header.Size = UDim2.new(1, -80, 1, 0)
	header.Position = UDim2.fromOffset(20, 0)
	header.TextXAlignment = Enum.TextXAlignment.Left

	local close = Widgets.button(frame, {
		text = "",
		icon = "close",
		color = Theme.red,
		size = UDim2.fromOffset(52, 52),
		onClick = closeWindow,
	})
	close.instance.AnchorPoint = Vector2.new(1, 0)
	close.instance.Position = UDim2.new(1, -8, 0, 2)
	close.label.Visible = false
	local closeIcon = close.instance:FindFirstChild("Icon_close", true)
	if closeIcon and closeIcon:IsA("GuiObject") then
		closeIcon.AnchorPoint = Vector2.new(0.5, 0.5)
		closeIcon.Position = UDim2.fromScale(0.5, 0.5)
	end

	local content = Instance.new("Frame")
	content.BackgroundTransparency = 1
	content.Size = UDim2.new(1, -30, 1, -82)
	content.Position = UDim2.fromOffset(15, 70)
	content.Parent = frame

	openWindow = frame
	openWindowName = name
	return frame, content
end

local function scrolling(parent: Instance, size: UDim2, position: UDim2): ScrollingFrame
	local scroll = Instance.new("ScrollingFrame")
	scroll.BackgroundTransparency = 1
	scroll.BorderSizePixel = 0
	scroll.Size = size
	scroll.Position = position
	scroll.ScrollBarThickness = 8
	scroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
	scroll.CanvasSize = UDim2.new()
	scroll.Parent = parent
	return scroll
end

-- Menú Construir ------------------------------------------------------------------

local selectedSlot = 1

local function renderBuild(content: Frame)
	content:ClearAllChildren()
	local machines = tableOf("machines")
	local slots = number("slots")
	selectedSlot = math.clamp(selectedSlot, 1, math.max(slots, 1))

	local grid = scrolling(content, UDim2.new(0.42, 0, 1, 0), UDim2.new())
	local layout = Instance.new("UIGridLayout")
	layout.CellSize = UDim2.fromOffset(140, 96)
	layout.CellPadding = UDim2.fromOffset(10, 10)
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Parent = grid

	for slot = 1, slots do
		local machine = machines[tostring(slot)]
		local def = if type(machine) == "table" then Machines.byId[machine.id] else nil
		local card = Widgets.button(grid, {
			text = if def then `{def.displayName}\nNv {machine.level}` else `Hueco {slot}\nVacío`,
			color = if slot == selectedSlot then Theme.orange elseif def then def.color else Theme.gray,
			textSize = 18,
			onClick = function()
				selectedSlot = slot
				renderBuild(content)
			end,
		})
		card.instance.LayoutOrder = slot
	end

	local detail = Instance.new("Frame")
	detail.BackgroundTransparency = 1
	detail.Size = UDim2.new(0.56, 0, 1, 0)
	detail.Position = UDim2.fromScale(0.44, 0)
	detail.Parent = content

	local machine = machines[tostring(selectedSlot)]
	if type(machine) == "table" and Machines.byId[machine.id] then
		local def = Machines.byId[machine.id]
		local title = Widgets.label(detail, `{def.displayName} · Nivel {machine.level}`, 28)
		title.TextXAlignment = Enum.TextXAlignment.Left
		local description = Widgets.label(detail, def.description, 20, Theme.muted, Theme.fontBody)
		description.Position = UDim2.fromOffset(0, 40)
		description.TextXAlignment = Enum.TextXAlignment.Left
		local bonus = Widgets.label(
			detail,
			`+{math.floor(Machines.speedPerLevel * 100)} % por nivel (máximo {Machines.maxLevel})`,
			18,
			Theme.muted,
			Theme.fontBody
		)
		bonus.Position = UDim2.fromOffset(0, 70)
		bonus.TextXAlignment = Enum.TextXAlignment.Left
		if machine.level < Machines.maxLevel then
			local cost = Formulas.upgradeCost(def.price, machine.level, Machines.upgradeCostMultiplier)
			local upgrade = Widgets.button(detail, {
				text = `Mejorar: {Widgets.formatNumber(cost)}`,
				icon = "coin",
				color = Theme.green,
				size = UDim2.fromOffset(300, 64),
				onClick = function()
					reply(invoke(Remotes.UpgradeMachine, selectedSlot))
				end,
			})
			upgrade.instance.Position = UDim2.fromOffset(0, 120)
			upgrade.setEnabled(number("coins") >= cost)
		else
			local maxed = Widgets.label(detail, "Nivel máximo", 24, Theme.green)
			maxed.Position = UDim2.fromOffset(0, 130)
			maxed.TextXAlignment = Enum.TextXAlignment.Left
		end
		return
	end

	local list = scrolling(detail, UDim2.fromScale(1, 1), UDim2.new())
	Widgets.list(list, Enum.FillDirection.Vertical, 8)
	for order, def in Machines.list do
		local price = machinePrice(def.id)
		local row = Widgets.panel(list, UDim2.new(1, -14, 0, 74), UDim2.new(), nil, Theme.panelDark)
		row.LayoutOrder = order
		local name = Widgets.label(row, def.displayName, 22)
		name.Size = UDim2.new(0.6, 0, 0, 28)
		name.Position = UDim2.fromOffset(12, 6)
		name.TextXAlignment = Enum.TextXAlignment.Left
		local description = Widgets.label(row, def.description, 15, Theme.muted, Theme.fontBody)
		description.Size = UDim2.new(0.6, 0, 0, 32)
		description.Position = UDim2.fromOffset(12, 36)
		description.TextXAlignment = Enum.TextXAlignment.Left
		local buy = Widgets.button(row, {
			text = if price == 0 then "Gratis" else Widgets.formatNumber(price),
			icon = "coin",
			color = Theme.green,
			size = UDim2.fromOffset(150, 54),
			textSize = 20,
			onClick = function()
				reply(invoke(Remotes.BuyMachine, selectedSlot, def.id))
			end,
		})
		buy.instance.AnchorPoint = Vector2.new(1, 0.5)
		buy.instance.Position = UDim2.new(1, -10, 0.5, 0)
		buy.setEnabled(number("coins") >= price)
	end
end

local function openBuild()
	local _, content = window("build", "Construir", Vector2.new(820, 500))
	local slot = emptySlot()
	if slot then
		selectedSlot = slot
	end
	renderBuild(content)
	refreshers.build = function()
		renderBuild(content)
	end
end

-- Linaje ------------------------------------------------------------------------

local function findPartner(): (number?, string?)
	local own = GiantRenderController.getGiant(player.UserId)
	if not own or number("level") < Economy.breeding.adultLevel then
		return nil, nil
	end
	local best: number? = nil
	local bestName: string? = nil
	local bestDistance = math.huge
	for id, giant in GiantRenderController.getGiants() do
		local level = giant.root:GetAttribute("Level")
		if id ~= player.UserId and type(level) == "number" and level >= Economy.breeding.adultLevel then
			local distance = GiantRenderController.bodyDistance(own, giant)
			if distance <= Economy.breeding.maxDistance and distance < bestDistance then
				bestDistance = distance
				best = id
				local name = giant.root:GetAttribute("DisplayName")
				bestName = if type(name) == "string" then name else "Gigante"
			end
		end
	end
	return best, bestName
end

local function requestBreed()
	local partner = findPartner()
	if not partner then
		UIController.toast("Acércate a un gigante adulto (menos de 60 studs)")
		return
	end
	reply(invoke(Remotes.RequestBreed, partner))
end

local function eggDrawing(parent: Instance, egg: { [string]: any }, size: number): Frame
	local species = Species[egg.species]
	local frame = Instance.new("Frame")
	frame.Size = UDim2.fromOffset(size * 0.75, size)
	frame.BackgroundColor3 = if species then species.eggColor else Theme.panel
	frame.BorderSizePixel = 0
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0.5, 0)
	corner.Parent = frame
	Widgets.stroke(frame)
	-- Dibujos de la cáscara: un color por rasgo (pista de lo que saldrá).
	local positions = { Vector2.new(0.3, 0.35), Vector2.new(0.68, 0.55), Vector2.new(0.4, 0.75) }
	for index, trait in egg.traits or {} do
		local def = Traits[trait]
		local spot = Instance.new("Frame")
		spot.Size = UDim2.fromScale(0.26, 0.2)
		spot.AnchorPoint = Vector2.new(0.5, 0.5)
		local p = positions[index] or Vector2.new(0.5, 0.5)
		spot.Position = UDim2.fromScale(p.X, p.Y)
		spot.BackgroundColor3 = if def then def.color else Theme.gray
		spot.BorderSizePixel = 0
		local spotCorner = Instance.new("UICorner")
		spotCorner.CornerRadius = UDim.new(0.5, 0)
		spotCorner.Parent = spot
		spot.Parent = frame
	end
	frame.Parent = parent
	return frame
end

local function renderLineage(content: Frame)
	content:ClearAllChildren()
	local generation = math.max(number("generation"), 1)
	local coinBonus = math.floor(Economy.lineage.coinBonusPerGeneration * (generation - 1) * 100 + 0.5)
	local feedBonus = math.floor(Economy.lineage.feedBonusPerGeneration * (generation - 1) * 100 + 0.5)

	local header =
		Widgets.label(content, `Generación {generation} · +{coinBonus} % monedas · +{feedBonus} % alimento`, 22)
	header.TextXAlignment = Enum.TextXAlignment.Left
	local current = Widgets.label(
		content,
		`Tu gigante: {speciesName(ClientState.get("species") or "Turtle")} · {traitNames(tableOf("traits"))}`,
		20,
		Theme.muted,
		Theme.fontBody
	)
	current.Position = UDim2.fromOffset(0, 32)
	current.TextXAlignment = Enum.TextXAlignment.Left

	local area = Instance.new("Frame")
	area.BackgroundTransparency = 1
	area.Size = UDim2.new(1, 0, 1, -70)
	area.Position = UDim2.fromOffset(0, 70)
	area.Parent = content

	local eggs = tableOf("eggs")
	if #eggs == 0 then
		local adult = number("level") >= Economy.breeding.adultLevel
		local text = if adult
			then "Acércate a un gigante adulto (salvaje o de un amigo) a menos de 60 studs y cría. La cría heredará un rasgo de cada padre."
			else `Tu gigante podrá criar cuando sea adulto (nivel {Economy.breeding.adultLevel}). Ahora: nivel {number(
				"level"
			)}.`
		local info = Widgets.label(area, text, 22, Theme.text, Theme.fontBody)
		info.Size = UDim2.new(1, 0, 0, 90)
		if adult then
			local partner, partnerName = findPartner()
			local breed = Widgets.button(area, {
				text = if partner then `Criar con {partnerName}` else "No hay pareja cerca",
				icon = "heart",
				color = Theme.red,
				size = UDim2.fromOffset(420, 70),
				onClick = requestBreed,
			})
			breed.instance.Position = UDim2.fromOffset(0, 110)
			breed.setEnabled(partner ~= nil)
		end
		return
	end

	local now = serverNow()
	local width = math.floor(760 / #eggs)
	for index, egg in eggs do
		local column = Instance.new("Frame")
		column.BackgroundTransparency = 1
		column.Size = UDim2.new(1 / #eggs, -10, 1, 0)
		column.Position = UDim2.new((index - 1) / #eggs, 0, 0, 0)
		column.Parent = area
		local drawing = eggDrawing(column, egg, 120)
		drawing.Position = UDim2.fromOffset(10, 0)

		local remaining = egg.hatchAt - now
		local textX = 120
		if remaining > 0 then
			local wait = Widgets.label(column, `Eclosiona en {Widgets.formatTime(remaining)}`, 24)
			wait.Position = UDim2.fromOffset(textX, 10)
			wait.Size = UDim2.new(1, -textX, 0, 30)
			wait.TextXAlignment = Enum.TextXAlignment.Left
			local hint = Widgets.label(
				column,
				"Color de la cáscara: la especie. Manchas: los rasgos.",
				16,
				Theme.muted,
				Theme.fontBody
			)
			hint.Position = UDim2.fromOffset(textX, 46)
			hint.Size = UDim2.new(1, -textX, 0, 40)
			hint.TextXAlignment = Enum.TextXAlignment.Left
			if index == 1 then
				local hatch = Widgets.button(column, {
					text = `Eclosión inmediata · {Products.products.InstantHatch.robux} R$`,
					icon = "egg",
					color = Theme.purple,
					size = UDim2.fromOffset(math.min(width - 20, 380), 56),
					textSize = 18,
					onClick = function()
						UIController.buyProduct("InstantHatch")
					end,
				})
				hatch.instance.Position = UDim2.fromOffset(0, 140)
			end
		else
			local born = Widgets.label(column, `¡Ha nacido! {speciesName(egg.species)}`, 24, Theme.green)
			born.Position = UDim2.fromOffset(textX, 6)
			born.Size = UDim2.new(1, -textX, 0, 30)
			born.TextXAlignment = Enum.TextXAlignment.Left
			local traits = Widgets.label(column, traitNames(egg.traits), 18, Theme.text, Theme.fontBody)
			traits.Position = UDim2.fromOffset(textX, 40)
			traits.Size = UDim2.new(1, -textX, 0, 44)
			traits.TextXAlignment = Enum.TextXAlignment.Left
			local continue = Widgets.button(column, {
				text = if #eggs > 1 then "Elegir esta cría" else "Continuar con la cría",
				icon = "egg",
				color = Theme.green,
				size = UDim2.fromOffset(math.min(width - 20, 380), 60),
				onClick = function()
					local ok, message = invoke(Remotes.ContinueWithHatchling, index)
					reply(ok, message or (if ok then "¡Nueva generación!" else nil))
					if ok then
						closeWindow()
					end
				end,
			})
			continue.instance.Position = UDim2.fromOffset(0, 136)
			local warning = Widgets.label(
				column,
				`Tu gigante se retira al Salón del Linaje. Pierdes monedas, recursos, máquinas y nivel; ganas +{math.floor(
					Economy.lineage.coinBonusPerGeneration * 100
				)} % monedas y +{math.floor(Economy.lineage.feedBonusPerGeneration * 100)} % alimento para siempre.`,
				15,
				Theme.muted,
				Theme.fontBody
			)
			warning.Position = UDim2.fromOffset(0, 204)
			warning.Size = UDim2.new(1, -10, 0, 60)
			warning.TextXAlignment = Enum.TextXAlignment.Left
		end
	end
end

local function openLineage()
	local _, content = window("lineage", "Linaje", Vector2.new(820, 520))
	renderLineage(content)
	refreshers.lineage = function()
		renderLineage(content)
	end
end

-- Libro de rasgos -----------------------------------------------------------------

local function openBook()
	local _, content = window("book", "Libro de rasgos", Vector2.new(700, 500))
	local function render()
		content:ClearAllChildren()
		local book = tableOf("traitBook")
		local keys = {}
		for key in book do
			table.insert(keys, key)
		end
		table.sort(keys)
		local header = Widgets.label(content, `Combinaciones descubiertas: {#keys} / {TOTAL_COMBINATIONS}`, 24)
		header.TextXAlignment = Enum.TextXAlignment.Left
		local list = scrolling(content, UDim2.new(1, 0, 1, -40), UDim2.fromOffset(0, 40))
		Widgets.list(list, Enum.FillDirection.Vertical, 6)
		for order, key in keys do
			local speciesId, rest = string.match(key, "^(%w+):(.*)$")
			local traits = if rest then string.split(rest, "+") else {}
			local hasMutation = false
			for _, trait in traits do
				local def = Traits[trait]
				if def and def.isMutation then
					hasMutation = true
				end
			end
			local row = Widgets.panel(
				list,
				UDim2.new(1, -14, 0, 48),
				UDim2.new(),
				nil,
				if hasMutation then Color3.fromRGB(255, 235, 160) else Theme.panelDark
			)
			row.LayoutOrder = order
			local label = Widgets.label(row, `{speciesName(speciesId or "?")} · {traitNames(traits)}`, 20)
			label.Size = UDim2.new(1, -20, 1, 0)
			label.Position = UDim2.fromOffset(12, 0)
			label.TextXAlignment = Enum.TextXAlignment.Left
		end
	end
	render()
	refreshers.book = render
end

-- Tienda -------------------------------------------------------------------------

function UIController.buyProduct(key: string)
	local def = Products.products[key]
	if not def then
		return
	end
	if def.id == 0 then
		if ClientState.get("isStudio") == true then
			reply(invoke(Remotes.DebugGrant, "product", key))
		else
			UIController.toast("Disponible muy pronto")
		end
		return
	end
	MarketplaceService:PromptProductPurchase(player, def.id)
end

local function buyPass(key: string)
	local def = Products.passes[key]
	if not def then
		return
	end
	if def.id == 0 then
		if ClientState.get("isStudio") == true then
			reply(invoke(Remotes.DebugGrant, "pass", key))
		else
			UIController.toast("Disponible muy pronto")
		end
		return
	end
	MarketplaceService:PromptGamePassPurchase(player, def.id)
end

local function shopRow(list: Instance, order: number, title: string, description: string, action: Button?)
	local row = Widgets.panel(list, UDim2.new(1, -14, 0, 78), UDim2.new(), nil, Theme.panelDark)
	row.LayoutOrder = order
	local name = Widgets.label(row, title, 22)
	name.Size = UDim2.new(0.62, 0, 0, 28)
	name.Position = UDim2.fromOffset(12, 6)
	name.TextXAlignment = Enum.TextXAlignment.Left
	local text = Widgets.label(row, description, 15, Theme.muted, Theme.fontBody)
	text.Size = UDim2.new(0.62, 0, 0, 36)
	text.Position = UDim2.fromOffset(12, 36)
	text.TextXAlignment = Enum.TextXAlignment.Left
	if action then
		action.instance.AnchorPoint = Vector2.new(1, 0.5)
		action.instance.Position = UDim2.new(1, -10, 0.5, 0)
		action.instance.Parent = row
	end
end

local function openShop()
	local _, content = window("shop", "Tienda", Vector2.new(760, 540))
	local function render()
		content:ClearAllChildren()
		local passes = tableOf("passes")
		local list = scrolling(content, UDim2.fromScale(1, 1), UDim2.new())
		Widgets.list(list, Enum.FillDirection.Vertical, 8)
		local order = 0
		local function section(title: string)
			order += 1
			local label = Widgets.label(list, title, 24, Theme.orange)
			label.LayoutOrder = order
			label.TextXAlignment = Enum.TextXAlignment.Left
		end

		section("Ventajas permanentes")
		for _, key in { "DoubleCoins", "ExpertPilot", "DoubleNest", "BigStorage" } do
			local def = Products.passes[key]
			order += 1
			local owned = passes[key] == true
			local action = Widgets.button(list, {
				text = if owned then "Tuyo" else `{def.robux} R$`,
				color = if owned then Theme.gray else Theme.green,
				size = UDim2.fromOffset(150, 54),
				onClick = function()
					if not owned then
						buyPass(key)
					end
				end,
			})
			action.setEnabled(not owned)
			shopRow(list, order, def.displayName, def.description, action)
		end

		section("Ayudas")
		for _, key in { "Banquet", "InstantHatch", "FruitRain", "CoinsSmall", "CoinsMedium", "CoinsLarge" } do
			local def = Products.products[key]
			order += 1
			local description = if def.coins then `+{Widgets.formatNumber(def.coins)} monedas` else def.description
			local action = Widgets.button(list, {
				text = `{def.robux} R$`,
				color = Theme.blue,
				size = UDim2.fromOffset(150, 54),
				onClick = function()
					UIController.buyProduct(key)
				end,
			})
			shopRow(list, order, def.displayName, description, action)
		end

		section("Pieles de gigante")
		local equipped = ClientState.get("skin") or ""
		for key, def in Products.passes do
			if def.skin and Skins[def.skin] then
				order += 1
				local owned = passes[key] == true
				local skin = def.skin :: string
				local isOn = equipped == skin
				local action = Widgets.button(list, {
					text = if not owned then `{def.robux} R$` elseif isOn then "Quitar" else "Ponerla",
					color = if not owned then Theme.green elseif isOn then Theme.gray else Theme.orange,
					size = UDim2.fromOffset(150, 54),
					onClick = function()
						if not owned then
							buyPass(key)
						else
							reply(invoke(Remotes.EquipSkin, if isOn then "" else skin))
						end
					end,
				})
				shopRow(list, order, def.displayName, def.description, action)
			end
		end
	end
	render()
	refreshers.shop = render
end

-- HUD ---------------------------------------------------------------------------

local resourceLabels: { [string]: TextLabel } = {}
local perSecondLabel: TextLabel
local objectiveLabel: TextLabel
local statusLabel: TextLabel
local statusPanel: Frame

-- Contador del HUD: píldora oscura con el icono asomando por la izquierda.
local function pill(parent: Instance, icon: string, order: number): TextLabel
	local holder = Instance.new("Frame")
	holder.BackgroundTransparency = 1
	holder.Size = UDim2.fromOffset(168, 54)
	holder.LayoutOrder = order
	holder.Parent = parent
	local frame = Widgets.darkPanel(holder, UDim2.new(1, -14, 0, 42), UDim2.new(0, 14, 0.5, 0), Vector2.new(0, 0.5))
	local iconFrame = Icons.make(icon, 54)
	iconFrame.Position = UDim2.fromOffset(-6, 0)
	iconFrame.Parent = holder
	local label = Widgets.title(frame, "0", 26)
	label.Size = UDim2.new(1, -48, 1, 0)
	label.Position = UDim2.fromOffset(42, 0)
	label.TextXAlignment = Enum.TextXAlignment.Left
	label.TextScaled = true
	local constraint = Instance.new("UITextSizeConstraint")
	constraint.MaxTextSize = 26
	constraint.Parent = label
	return label
end

local function updateResources()
	local capacity = number("capacity")
	resourceLabels.coins.Text = Widgets.formatNumber(number("coins"))
	for _, key in { "wood", "stone", "fruit" } do
		local value = number(key)
		local label = resourceLabels[key]
		label.Text = `{Widgets.formatNumber(value)}/{Widgets.formatNumber(capacity)}`
		label.TextColor3 = if capacity > 0 and value >= capacity then Theme.red else Theme.textLight
	end
	perSecondLabel.Text = `+{Widgets.formatNumber(number("perSecond"))}/s`
end

local function objectiveText(): string
	local level = number("level")
	local eggs = tableOf("eggs")
	local onOwnGiant = PlatformController.isSeated() or PlatformController.getAttachedTo() == player.UserId
	if not onOwnGiant and level <= 1 and number("coins") < 1 then
		return "Pisa la plataforma verde para montar en tu gigante"
	end
	if level <= 1 and ownedCount("Crusher") == 0 then
		local price = machinePrice("Crusher")
		return if number("coins") >= price
			then `Compra la Trituradora ({price}) en Construir`
			else "Pisa árboles: la Sierra los convierte en monedas"
	end
	if level < 2 then
		return "Pisa arbustos y alimenta al gigante: ¡primer estirón!"
	end
	for target = level + 1, #Levels do
		local unlocks = Levels[target].unlocks
		if unlocks then
			return `Nivel {target}: {unlocks}`
		end
	end
	if #eggs == 0 then
		return "Cría con un gigante adulto (salvaje o de un amigo)"
	end
	local remaining = eggs[1].hatchAt - serverNow()
	if remaining > 0 then
		return `Tu huevo eclosiona en {Widgets.formatTime(remaining)}`
	end
	return "¡Ha eclosionado! Abre el Linaje y continúa con la cría"
end

local function updateStatus()
	local parts = {}
	local herd = number("herd")
	if herd > 0 then
		table.insert(parts, `Manada de {herd + 1}: +{math.floor(math.min(herd * 10, 40))} %`)
	end
	if number("passengerOf") > 0 then
		table.insert(parts, "Pasajero: +20 %")
	elseif number("passengers") > 0 then
		table.insert(parts, `{number("passengers")} pasajero(s): +20 %`)
	end
	local rainLeft = fruitRain.endsAt - serverNow()
	if rainLeft > 0 then
		table.insert(parts, `Lluvia de fruta de {fruitRain.name}: x2 ({Widgets.formatTime(rainLeft)})`)
	end
	local own = GiantRenderController.getGiant(player.UserId)
	if own then
		local zone = World.zoneAt(own.cframe.Position.X, own.cframe.Position.Z)
		if zone then
			table.insert(parts, 1, zone.displayName)
		end
	end
	statusLabel.Text = table.concat(parts, "   ·   ")
	statusPanel.Visible = #parts > 0
end

-- Los botones aparecen cuando hacen falta, para no abrumar al empezar.
local unlocked: { [string]: boolean } = {}
local function reveal(key: string, condition: boolean)
	if condition and not unlocked[key] then
		unlocked[key] = true
		local button = buttons[key]
		if button then
			button.instance.Visible = true
			local scale = Instance.new("UIScale")
			scale.Scale = 0.3
			scale.Parent = button.instance
			local tween = TweenService:Create(scale, TweenInfo.new(0.35, Enum.EasingStyle.Back), { Scale = 1 })
			tween.Completed:Connect(function()
				scale:Destroy()
			end)
			tween:Play()
		end
	end
end

local function updateButtons()
	local level = number("level")
	local generation = number("generation")
	local veteran = level >= 2 or generation > 1
	reveal("feed", veteran or number("fruit") >= 1)
	reveal("sell", veteran or number("fruit") >= 1)
	reveal("build", veteran or number("coins") >= 1)
	reveal("pilot", level >= Economy.autopilot.minLevel)
	reveal("lineage", level >= Economy.breeding.adultLevel or generation > 1 or #tableOf("eggs") > 0)
	reveal("book", generation > 1 or level >= Economy.breeding.adultLevel)
	for key in buttons do
		if not unlocked[key] and key ~= "shop" and key ~= "home" and key ~= "breed" then
			buttons[key].instance.Visible = false
		end
	end

	local pilot = buttons.pilot
	if level < Economy.autopilot.minLevel then
		pilot.setText(`Nv {Economy.autopilot.minLevel}`)
		pilot.setEnabled(false)
	else
		pilot.setEnabled(true)
		pilot.setText(if ClientState.get("autopilot") == true then "Piloto: Sí" else "Piloto: No")
		pilot.setColor(if ClientState.get("autopilot") == true then Theme.green else Theme.blue)
	end
	buttons.feed.setEnabled(number("fruit") >= 1 and number("fruitToNext") > 0)
	buttons.sell.setEnabled(number("fruit") >= 1)

	local onOwnGiant = PlatformController.isSeated() or PlatformController.getAttachedTo() == player.UserId
	buttons.home.instance.Visible = not onOwnGiant and GiantRenderController.getGiant(player.UserId) ~= nil

	local canBreed = level >= Economy.breeding.adultLevel and #tableOf("eggs") == 0 and findPartner() ~= nil
	buttons.breed.instance.Visible = canBreed

	local eggs = tableOf("eggs")
	buttons.lineage.setHighlight(#eggs > 0 and eggs[1].hatchAt <= serverNow())
end

local function buildHud()
	-- Recursos (arriba a la derecha).
	local resources = Instance.new("Frame")
	resources.BackgroundTransparency = 1
	resources.AnchorPoint = Vector2.new(1, 0)
	resources.Position = UDim2.new(1, -12, 0, 8)
	resources.Size = UDim2.fromOffset(700, 54)
	resources.Parent = gui
	Widgets.list(resources, Enum.FillDirection.Horizontal, 8, Enum.HorizontalAlignment.Right)
	resourceLabels.coins = pill(resources, "coin", 1)
	resourceLabels.wood = pill(resources, "wood", 2)
	resourceLabels.stone = pill(resources, "stone", 3)
	resourceLabels.fruit = pill(resources, "fruit", 4)

	perSecondLabel = Widgets.label(gui, "", 20, Theme.moneyGreen)
	perSecondLabel.AnchorPoint = Vector2.new(0, 0)
	perSecondLabel.Position = UDim2.new(1, -670, 0, 62)
	perSecondLabel.Size = UDim2.fromOffset(170, 24)
	Widgets.outlined(perSecondLabel)

	-- Objetivo (arriba a la izquierda).
	local objective = Widgets.panel(gui, UDim2.fromOffset(400, 56), UDim2.fromOffset(12, 8))
	local target = Icons.make("target", 40)
	target.Position = UDim2.fromOffset(8, 8)
	target.Parent = objective
	objectiveLabel = Widgets.label(objective, "", 18)
	objectiveLabel.Size = UDim2.new(1, -62, 1, 0)
	objectiveLabel.Position = UDim2.fromOffset(56, 0)
	objectiveLabel.TextXAlignment = Enum.TextXAlignment.Left

	statusPanel = Widgets.panel(gui, UDim2.fromOffset(400, 36), UDim2.fromOffset(12, 70), nil, Theme.panelDark)
	statusLabel = Widgets.label(statusPanel, "", 16, Theme.text, Theme.fontBody)
	statusLabel.Size = UDim2.new(1, -16, 1, 0)
	statusLabel.Position = UDim2.fromOffset(8, 0)
	statusLabel.TextXAlignment = Enum.TextXAlignment.Left

	-- Botones de acción (derecha, al alcance del pulgar y por encima del salto).
	local actions = Instance.new("Frame")
	actions.BackgroundTransparency = 1
	actions.AnchorPoint = Vector2.new(1, 1)
	actions.Position = UDim2.new(1, -14, 1, -170)
	actions.Size = UDim2.fromOffset(240, 340)
	actions.Parent = gui
	local grid = Instance.new("UIGridLayout")
	grid.CellSize = UDim2.fromOffset(112, 104)
	grid.CellPadding = UDim2.fromOffset(10, 10)
	grid.HorizontalAlignment = Enum.HorizontalAlignment.Right
	grid.VerticalAlignment = Enum.VerticalAlignment.Bottom
	grid.SortOrder = Enum.SortOrder.LayoutOrder
	grid.Parent = actions

	buttons.feed = Widgets.button(actions, {
		text = "Alimentar",
		icon = "feed",
		color = Theme.green,
		size = UDim2.fromOffset(112, 104),
		textSize = 19,
		onClick = function()
			reply(invoke(Remotes.Feed, number("fruit")))
		end,
	})
	buttons.sell = Widgets.button(actions, {
		text = "Vender",
		icon = "sell",
		color = Theme.orange,
		size = UDim2.fromOffset(112, 104),
		textSize = 19,
		onClick = function()
			local fruit = math.floor(number("fruit"))
			local ok, message = invoke(Remotes.SellFruit, fruit)
			reply(ok, message or (if ok then `Has vendido {fruit} de Fruta` else nil))
		end,
	})
	buttons.build = Widgets.button(actions, {
		text = "Construir",
		icon = "build",
		color = Theme.orange,
		size = UDim2.fromOffset(112, 104),
		textSize = 19,
		onClick = function()
			if openWindowName == "build" then
				closeWindow()
			else
				openBuild()
			end
		end,
	})
	buttons.pilot = Widgets.button(actions, {
		text = "Piloto",
		icon = "pilot",
		color = Theme.blue,
		size = UDim2.fromOffset(112, 104),
		textSize = 17,
		onClick = function()
			Remotes.SetAutopilot:FireServer(ClientState.get("autopilot") ~= true)
		end,
	})
	buttons.feed.instance.LayoutOrder = 1
	buttons.sell.instance.LayoutOrder = 2
	buttons.build.instance.LayoutOrder = 3
	buttons.pilot.instance.LayoutOrder = 4

	-- Menús (izquierda).
	local menus = Instance.new("Frame")
	menus.BackgroundTransparency = 1
	menus.AnchorPoint = Vector2.new(0, 0.5)
	menus.Position = UDim2.new(0, 12, 0.5, 10)
	menus.Size = UDim2.fromOffset(96, 470)
	menus.Parent = gui
	Widgets.list(menus, Enum.FillDirection.Vertical, 10)
	local function menuButton(key: string, text: string, icon: string, color: Color3, order: number, onClick: () -> ())
		local button = Widgets.button(menus, {
			text = text,
			icon = icon,
			color = color,
			size = UDim2.fromOffset(92, 84),
			textSize = 16,
			onClick = onClick,
		})
		button.instance.LayoutOrder = order
		buttons[key] = button
	end
	local function toggle(name: string, open: () -> ()): () -> ()
		return function()
			if openWindowName == name then
				closeWindow()
			else
				open()
			end
		end
	end
	menuButton("lineage", "Linaje", "egg", Theme.purple, 1, toggle("lineage", openLineage))
	menuButton("book", "Libro", "book", Theme.purple, 2, toggle("book", openBook))
	menuButton("shop", "Tienda", "shop", Theme.green, 3, toggle("shop", openShop))
	menuButton("breed", "Criar", "heart", Theme.red, 4, requestBreed)
	menuButton("home", "Montar", "paw", Theme.green, 5, function()
		PlatformController.returnHome()
	end)

	-- Avisos (arriba en el centro).
	toastList = Instance.new("Frame")
	toastList.BackgroundTransparency = 1
	toastList.AnchorPoint = Vector2.new(0.5, 0)
	toastList.Position = UDim2.new(0.5, 0, 0, 120)
	toastList.Size = UDim2.fromOffset(520, 260)
	toastList.ZIndex = 30
	toastList.Parent = gui
	Widgets.list(toastList, Enum.FillDirection.Vertical, 6, Enum.HorizontalAlignment.Center).VerticalAlignment =
		Enum.VerticalAlignment.Top
end

-- Monedas que entran: «+N» junto al contador -------------------------------------

local pendingCoins = 0
local function coinPopups()
	while true do
		task.wait(1.5)
		if pendingCoins >= 1 then
			local amount = pendingCoins
			pendingCoins = 0
			local label = Widgets.label(gui, `+{Widgets.formatNumber(amount)}`, 26, Theme.gold)
			label.Position = UDim2.new(1, -600, 0, 66)
			label.Size = UDim2.fromOffset(150, 30)
			Widgets.outlined(label)
			TweenService
				:Create(label, TweenInfo.new(1), { Position = UDim2.new(1, -600, 0, 106), TextTransparency = 1 })
				:Play()
			task.delay(1.1, function()
				label:Destroy()
			end)
		end
	end
end

-- Peticiones de cría, eclosión y ofertas ----------------------------------------------

local function showBreedPrompt(fromUserId: number, name: string, speciesId: string, traits: { string })
	local card = Widgets.panel(gui, UDim2.fromOffset(520, 170), UDim2.new(0.5, 0, 0, 120), Vector2.new(0.5, 0))
	card.ZIndex = 40
	local title = Widgets.label(card, `{name} quiere criar contigo`, 26)
	title.Position = UDim2.fromOffset(0, 10)
	local info =
		Widgets.label(card, `{speciesName(speciesId)} · {traitNames(traits)}`, 18, Theme.muted, Theme.fontBody)
	info.Position = UDim2.fromOffset(0, 46)
	local function respond(accept: boolean)
		Remotes.RespondBreed:FireServer(fromUserId, accept)
		card:Destroy()
	end
	local yes = Widgets.button(card, {
		text = "Aceptar",
		color = Theme.green,
		size = UDim2.fromOffset(200, 56),
		onClick = function()
			respond(true)
		end,
	})
	yes.instance.Position = UDim2.new(0.5, -210, 1, -70)
	local no = Widgets.button(card, {
		text = "Rechazar",
		color = Theme.red,
		size = UDim2.fromOffset(200, 56),
		onClick = function()
			respond(false)
		end,
	})
	no.instance.Position = UDim2.new(0.5, 10, 1, -70)
	task.delay(Economy.breeding.requestTimeout, function()
		if card.Parent then
			card:Destroy()
		end
	end)
end

local function showHatch(speciesId: string, traits: { string })
	local card = Widgets.panel(gui, UDim2.fromOffset(460, 360), UDim2.fromScale(0.5, 0.5), Vector2.new(0.5, 0.5))
	card.ZIndex = 50
	local egg = eggDrawing(card, { species = speciesId, traits = traits }, 150)
	egg.AnchorPoint = Vector2.new(0.5, 0)
	egg.Position = UDim2.new(0.5, 0, 0, 20)
	-- El huevo tiembla y se agrieta.
	TweenService:Create(egg, TweenInfo.new(0.08, Enum.EasingStyle.Linear, Enum.EasingDirection.InOut, 10, true), {
		Rotation = 12,
	}):Play()
	task.delay(1, function()
		if not card.Parent then
			return
		end
		egg.Rotation = 0
		local species = Species[speciesId]
		TweenService
			:Create(
				egg,
				TweenInfo.new(0.4),
				{ BackgroundColor3 = Color3.new(1, 1, 1), Size = UDim2.fromOffset(170, 170) }
			)
			:Play()
		local title = Widgets.label(card, `¡Ha nacido: {speciesName(speciesId)}!`, 28, Theme.green)
		title.Position = UDim2.fromOffset(0, 190)
		local info = Widgets.label(card, traitNames(traits), 20, Theme.text, Theme.fontBody)
		info.Position = UDim2.fromOffset(0, 228)
		if species then
			egg.BackgroundColor3 = species.eggColor
		end
		local view = Widgets.button(card, {
			text = "Ver en el Linaje",
			icon = "egg",
			color = Theme.purple,
			size = UDim2.fromOffset(300, 60),
			onClick = function()
				card:Destroy()
				openLineage()
			end,
		})
		view.instance.AnchorPoint = Vector2.new(0.5, 1)
		view.instance.Position = UDim2.new(0.5, 0, 1, -14)
	end)
	task.delay(20, function()
		if card.Parent then
			card:Destroy()
		end
	end)
end

local function showOffer(key: string)
	local def = Products.products[key]
	if not def then
		return
	end
	lastOfferAt = os.clock()
	local card = Widgets.panel(gui, UDim2.fromOffset(470, 104), UDim2.new(0.5, 0, 1, -16), Vector2.new(0.5, 1))
	card.ZIndex = 35
	local title = Widgets.label(card, def.displayName, 24)
	title.Size = UDim2.new(0.6, 0, 0, 30)
	title.Position = UDim2.fromOffset(14, 10)
	title.TextXAlignment = Enum.TextXAlignment.Left
	local description = Widgets.label(
		card,
		if def.coins then `+{Widgets.formatNumber(def.coins)} monedas` else def.description,
		15,
		Theme.muted,
		Theme.fontBody
	)
	description.Size = UDim2.new(0.6, 0, 0, 44)
	description.Position = UDim2.fromOffset(14, 44)
	description.TextXAlignment = Enum.TextXAlignment.Left
	local buy = Widgets.button(card, {
		text = `{def.robux} R$`,
		color = Theme.green,
		size = UDim2.fromOffset(120, 54),
		onClick = function()
			card:Destroy()
			UIController.buyProduct(key)
		end,
	})
	buy.instance.AnchorPoint = Vector2.new(1, 0.5)
	buy.instance.Position = UDim2.new(1, -70, 0.5, 0)
	local close = Widgets.button(card, {
		text = "",
		icon = "close",
		color = Theme.gray,
		size = UDim2.fromOffset(46, 46),
		onClick = function()
			card:Destroy()
		end,
	})
	close.instance.AnchorPoint = Vector2.new(1, 0.5)
	close.instance.Position = UDim2.new(1, -12, 0.5, 0)
	task.delay(12, function()
		if card.Parent then
			card:Destroy()
		end
	end)
end

-- Ofertas ligadas a momentos (GDD, sección H). Nunca antes del minuto 5.
local function checkOffers()
	local offers = Economy.offers
	if os.clock() - sessionStart < offers.minSessionTime or os.clock() - lastOfferAt < 180 or openWindow then
		return
	end
	local need = number("fruitToNext")
	if need > 0 and number("growthFruit") / need >= offers.banquetMinProgress then
		showOffer("Banquet")
		return
	end
	local eggs = tableOf("eggs")
	if #eggs > 0 and eggs[1].hatchAt > serverNow() then
		showOffer("InstantHatch")
		return
	end
	if #Players:GetPlayers() >= offers.fruitRainMinPlayers and fruitRain.endsAt < serverNow() then
		showOffer("FruitRain")
		return
	end
	local slot = emptySlot()
	local perSecond = number("perSecond")
	if slot and perSecond > 0 then
		local cheapest = math.huge
		for _, def in Machines.list do
			cheapest = math.min(cheapest, machinePrice(def.id))
		end
		local wait = (cheapest - number("coins")) / perSecond
		if wait > 0 and wait < offers.coinPackMaxWait then
			showOffer("CoinsSmall")
		end
	end
end

-- API para TutorialController -----------------------------------------------------

function UIController.getButton(name: string): Button?
	return buttons[name]
end

function UIController.getGui(): ScreenGui
	return gui
end

function UIController.init() end

function UIController.start()
	local playerGui = player:WaitForChild("PlayerGui")
	gui = Instance.new("ScreenGui")
	gui.Name = "GiantHUD"
	gui.ResetOnSpawn = false
	gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	gui.Parent = playerGui

	-- Escala la interfaz desde el tamaño de diseño (1280x720).
	local scale = Instance.new("UIScale")
	scale.Parent = gui
	local function rescale()
		local camera = Workspace.CurrentCamera
		if camera then
			local size = camera.ViewportSize
			scale.Scale = math.clamp(math.min(size.X / Theme.designSize.X, size.Y / Theme.designSize.Y), 0.5, 1.4)
		end
	end
	rescale()
	if Workspace.CurrentCamera then
		Workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(rescale)
	end

	buildHud()

	ClientState.onAnyChange(function(changed)
		updateResources()
		updateButtons()
		if changed.coins or changed.machines or changed.slots then
			if refreshers.build and openWindowName == "build" then
				refreshers.build()
			end
		end
		if changed.eggs or changed.level or changed.generation or changed.species then
			if refreshers.lineage and openWindowName == "lineage" then
				refreshers.lineage()
			end
		end
		if changed.traitBook and refreshers.book and openWindowName == "book" then
			refreshers.book()
		end
		if (changed.passes or changed.skin) and refreshers.shop and openWindowName == "shop" then
			refreshers.shop()
		end
	end)
	ClientState.onChanged("coins", function(value, previous)
		if type(value) == "number" and type(previous) == "number" and value > previous then
			pendingCoins += value - previous
		end
	end)

	local lastFull: { [string]: number } = {}
	ClientState.onChanged("storageFull", function(resource)
		if type(resource) == "string" and os.clock() - (lastFull[resource] or 0) > 15 then
			lastFull[resource] = os.clock()
			UIController.toast(
				`Almacén de {RESOURCE_NAMES[resource] or resource} lleno: procésalo con máquinas o compra un Almacén`
			)
		end
	end)

	Remotes.Notify.OnClientEvent:Connect(function(message: string)
		if type(message) == "string" then
			UIController.toast(message)
		end
	end)
	Remotes.BreedPrompt.OnClientEvent:Connect(showBreedPrompt)
	Remotes.Hatch.OnClientEvent:Connect(function(userId: number, speciesId: string, traits: { string })
		if userId == player.UserId then
			showHatch(speciesId, traits)
		end
	end)
	Remotes.FruitRain.OnClientEvent:Connect(function(name: string, endsAt: number)
		fruitRain.name = name
		fruitRain.endsAt = endsAt
		UIController.toast(
			`¡{name} ha traído una Lluvia de fruta para todo el servidor!`,
			Color3.fromRGB(255, 230, 230)
		)
	end)

	task.spawn(coinPopups)
	task.spawn(function()
		while true do
			objectiveLabel.Text = objectiveText()
			updateStatus()
			updateButtons()
			if openWindowName == "lineage" and refreshers.lineage then
				refreshers.lineage()
			end
			checkOffers()
			task.wait(1)
		end
	end)

	updateResources()
	print("[UIController] iniciado")
end

return UIController
