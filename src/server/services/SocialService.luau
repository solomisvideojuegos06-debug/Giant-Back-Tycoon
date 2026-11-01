--!strict
--[[
	SocialService
	Juego con amigos (GDD, sección G):
	- Pasajeros: subirse al gigante de otro jugador (BoardGiant). Pasajero y
	  anfitrión ganan +20 % mientras van juntos.
	- Manada: +10 % por cada gigante de jugador a menos de 80 studs (máx. +40 %).
	Criar con amigos está en LineageService.

	Sobre qué gigante va cada jugador lo sabe GiantService por RiderUpdate.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local Economy = require(Shared.Config.Economy)
local Formulas = require(Shared.Formulas)
local Remotes = require(Shared.Remotes)
local RateLimiter = require(script.Parent.Parent.RateLimiter)
local DataService = require(script.Parent.DataService)
local GiantService = require(script.Parent.GiantService)

local SOCIAL = Economy.social

type SocialState = {
	herd: number, -- gigantes de jugadores cercanos
	passengerOf: number?, -- UserId del anfitrión
	passengers: number, -- pasajeros en mi gigante
	bonus: number,
}

local SocialService = {}

local states: { [Player]: SocialState } = {}
local boardLimiter = RateLimiter.new(1, 2)

function SocialService.getBonus(player: Player): number
	local state = states[player]
	return if state then state.bonus else 0
end

local function update()
	local giants = GiantService.getAll()
	local riders = GiantService.getRiders()

	local passengerCount: { [number]: number } = {}
	for userId, giantId in riders do
		if giantId > 0 and giantId ~= userId then
			passengerCount[giantId] = (passengerCount[giantId] or 0) + 1
		end
	end

	for _, player in Players:GetPlayers() do
		local own = giants[player.UserId]
		if own and DataService.isLoaded(player) then
			local herd = 0
			for id, other in giants do
				if id > 0 and id ~= player.UserId and GiantService.bodyDistance(own, other) <= SOCIAL.herdDistance then
					herd += 1
				end
			end

			local riding = riders[player.UserId]
			local passengerOf = if riding and riding > 0 and riding ~= player.UserId then riding else nil
			local passengers = passengerCount[player.UserId] or 0

			local bonus = Formulas.herdBonus(herd, SOCIAL.herdBonusPerGiant, SOCIAL.herdBonusMax)
			if passengerOf or passengers > 0 then
				bonus += SOCIAL.passengerBonus
			end

			local previous = states[player]
			if
				not previous
				or previous.herd ~= herd
				or previous.passengerOf ~= passengerOf
				or previous.passengers ~= passengers
			then
				DataService.setView(player, "herd", herd)
				DataService.setView(player, "passengerOf", passengerOf or 0)
				DataService.setView(player, "passengers", passengers)
				DataService.setView(player, "socialBonus", bonus)
			end
			states[player] = { herd = herd, passengerOf = passengerOf, passengers = passengers, bonus = bonus }
		end
	end
end

local function onBoardGiant(player: Player, ownerId: unknown): (boolean, string?)
	if not boardLimiter.allow(player.UserId) then
		return false, "Demasiado rápido"
	end
	if type(ownerId) ~= "number" or ownerId == player.UserId or ownerId <= 0 then
		return false, "No puedes subirte a ese gigante"
	end
	local target = GiantService.get(ownerId)
	if not target or not target.player then
		return false, "Ese gigante ya no está"
	end
	local character = player.Character
	local rootPart = character and character:FindFirstChild("HumanoidRootPart")
	if not rootPart or not rootPart:IsA("BasePart") then
		return false, nil
	end
	local delta = rootPart.Position - target.position
	local distance = Vector3.new(delta.X, 0, delta.Z).Magnitude - GiantService.bodyRadius(target)
	if distance > SOCIAL.boardDistance then
		return false, "Acércate más a ese gigante"
	end
	Remotes.Notify:FireClient(target.player, `{player.DisplayName} se ha subido a tu gigante (+20 %)`)
	return true, nil
end

function SocialService.init()
	DataService.registerView(function(player: Player)
		local state = states[player]
		return {
			herd = if state then state.herd else 0,
			passengerOf = if state and state.passengerOf then state.passengerOf else 0,
			passengers = if state then state.passengers else 0,
			socialBonus = if state then state.bonus else 0,
		}
	end)
end

function SocialService.start()
	Remotes.BoardGiant.OnServerInvoke = onBoardGiant
	Players.PlayerRemoving:Connect(function(player)
		states[player] = nil
		boardLimiter.forget(player.UserId)
	end)
	task.spawn(function()
		while true do
			task.wait(SOCIAL.updateInterval)
			update()
		end
	end)
	print("[SocialService] iniciado")
end

return SocialService
