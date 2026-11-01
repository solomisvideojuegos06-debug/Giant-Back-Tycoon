--!strict
--[[
	DataService
	Carga y guarda los datos del jugador con ProfileStore (sesión bloqueada,
	sin pérdida de datos) y migra versiones antiguas (GDD, sección L).

	- onLoaded(fn): se llama con (player, data, offlineSeconds) cuando el
	  perfil está listo. Los demás services crean ahí lo suyo.
	- onRemoving(fn): antes de cerrar la sesión, para escribir lo último.
	- setView(player, clave, valor): cambia un dato que ve el cliente. Los
	  cambios se agrupan y se envían una vez por frame por StateUpdate.
	- registerView(fn): aporta claves al estado completo de GetState.

	En Studio sin acceso a la API de DataStores, ProfileStore usa un
	almacén simulado: los datos no se conservan al cerrar la prueba.
]]

local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage.Shared
local Machines = require(Shared.Config.Machines)
local Remotes = require(Shared.Remotes)
local Types = require(Shared.Types)
local ProfileStore = require(script.Parent.Parent.vendor.ProfileStore) :: any
local RateLimiter = require(script.Parent.Parent.RateLimiter)

type PlayerData = Types.PlayerData

export type LoadedCallback = (player: Player, data: PlayerData, offlineSeconds: number) -> ()
export type RemovingCallback = (player: Player, data: PlayerData) -> ()
export type ViewProvider = (player: Player, data: PlayerData) -> { [string]: any }

local CURRENT_VERSION = 2
local STORE_NAME = "PlayerData"

local DataService = {
	priority = 1,
}

local TEMPLATE: PlayerData = {
	version = CURRENT_VERSION,
	coins = 0,
	resources = { wood = 0, stone = 0, fruit = 0 },
	giant = {
		species = "Turtle",
		traits = { "Shell", "ToughSkin" },
		level = 1,
		growthFruit = 0,
		machines = { ["1"] = { id = Machines.starting, level = 1 } },
		skin = nil,
	},
	eggs = {},
	lineage = { generation = 1, ancestors = {} },
	traitBook = {},
	lastLogout = 0,
	passes = {},
	purchaseHistory = {},
	autopilot = false,
	funnel = {},
}

local store: any = nil
local profiles: { [Player]: any } = {}
local loadedCallbacks: { LoadedCallback } = {}
local removingCallbacks: { RemovingCallback } = {}
local viewProviders: { ViewProvider } = {}
local pendingViews: { [Player]: { [string]: any } } = {}
local stateLimiter = RateLimiter.new(2, 3)

-- Migraciones: cada función pasa de la versión N a la N + 1.
local MIGRATIONS: { [number]: (data: { [string]: any }) -> () } = {
	[1] = function(data)
		-- v1 → v2: egg → eggs; máquinas con clave de texto; autopilot y funnel.
		local eggs = {}
		if type(data.egg) == "table" then
			table.insert(eggs, data.egg)
		end
		data.eggs = eggs
		data.egg = nil
		local giant = data.giant
		if type(giant) == "table" and type(giant.machines) == "table" then
			local converted = {}
			for slot, machine in giant.machines do
				converted[tostring(slot)] = machine
			end
			giant.machines = converted
		end
		data.autopilot = data.autopilot == true
		data.funnel = if type(data.funnel) == "table" then data.funnel else {}
	end,
}

local function migrate(data: { [string]: any })
	local version = if type(data.version) == "number" then data.version else 1
	while version < CURRENT_VERSION do
		local step = MIGRATIONS[version]
		if step then
			step(data)
		end
		version += 1
	end
	data.version = CURRENT_VERSION
end

local function onPlayerAdded(player: Player)
	if not store then
		return
	end
	local profile = store:StartSessionAsync(`Player_{player.UserId}`, {
		Cancel = function()
			return player.Parent ~= Players
		end,
	})
	if profile == nil then
		if player.Parent == Players then
			player:Kick("No se han podido cargar tus datos. Vuelve a entrar en un momento.")
		end
		return
	end

	profile:AddUserId(player.UserId)
	migrate(profile.Data)
	profile:Reconcile()

	profile.OnSessionEnd:Connect(function()
		profiles[player] = nil
		if player.Parent == Players then
			player:Kick("Tu partida se ha abierto en otro servidor.")
		end
	end)

	if player.Parent ~= Players then
		profile:EndSession()
		return
	end

	profiles[player] = profile
	local data = profile.Data :: PlayerData
	local offlineSeconds = if data.lastLogout > 0 then math.max(os.time() - data.lastLogout, 0) else 0

	for _, callback in loadedCallbacks do
		task.spawn(callback, player, data, offlineSeconds)
	end
end

local function onPlayerRemoving(player: Player)
	pendingViews[player] = nil
	local profile = profiles[player]
	if not profile then
		return
	end
	local data = profile.Data :: PlayerData
	for _, callback in removingCallbacks do
		local ok, err = pcall(callback, player, data)
		if not ok then
			warn(`[DataService] onRemoving: {err}`)
		end
	end
	data.lastLogout = os.time()
	profiles[player] = nil
	profile:EndSession()
end

local function flushViews()
	for player, changes in pendingViews do
		if player.Parent == Players then
			Remotes.StateUpdate:FireClient(player, changes)
		end
	end
	table.clear(pendingViews)
end

function DataService.get(player: Player): PlayerData?
	local profile = profiles[player]
	return if profile then profile.Data :: PlayerData else nil
end

function DataService.isLoaded(player: Player): boolean
	return profiles[player] ~= nil
end

function DataService.onLoaded(callback: LoadedCallback)
	table.insert(loadedCallbacks, callback)
end

function DataService.onRemoving(callback: RemovingCallback)
	table.insert(removingCallbacks, callback)
end

function DataService.registerView(provider: ViewProvider)
	table.insert(viewProviders, provider)
end

function DataService.setView(player: Player, key: string, value: any)
	local pending = pendingViews[player]
	if not pending then
		pending = {}
		pendingViews[player] = pending
	end
	pending[key] = value
end

function DataService.fullView(player: Player): { [string]: any }?
	local data = DataService.get(player)
	if not data then
		return nil
	end
	local view: { [string]: any } = {}
	for _, provider in viewProviders do
		local ok, values = pcall(provider, player, data)
		if ok then
			for key, value in values do
				view[key] = value
			end
		else
			warn(`[DataService] registerView: {values}`)
		end
	end
	return view
end

-- Copia profunda serializable (para enviar tablas de datos al cliente).
function DataService.copy<T>(value: T): T
	return HttpService:JSONDecode(HttpService:JSONEncode(value))
end

function DataService.init()
	store = ProfileStore.New(STORE_NAME, TEMPLATE)
end

function DataService.start()
	Remotes.GetState.OnServerInvoke = function(player: Player)
		if not stateLimiter.allow(player.UserId) then
			return nil
		end
		return DataService.fullView(player)
	end

	Players.PlayerAdded:Connect(onPlayerAdded)
	Players.PlayerRemoving:Connect(onPlayerRemoving)
	for _, player in Players:GetPlayers() do
		task.spawn(onPlayerAdded, player)
	end
	RunService.Heartbeat:Connect(flushViews)

	print("[DataService] iniciado")
end

return DataService
