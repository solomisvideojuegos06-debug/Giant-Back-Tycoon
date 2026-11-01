--!strict
--[[
	WildGiantService
	Gigantes salvajes NPC (GDD, sección F): en cada zona pasean adultos de las
	3 especies con 2 rasgos al azar, visibles sobre su cabeza. Sirven de
	pareja para criar. GiantService los mueve (no salen de su zona).
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local Economy = require(Shared.Config.Economy)
local Mutations = require(Shared.Config.Mutations)
local World = require(Shared.World)
local Zones = require(Shared.Config.Zones)
local GiantService = require(script.Parent.GiantService)

local SPECIES_ORDER = { "Turtle", "Elephant", "Giraffe" }
local MARGIN = 120

local WildGiantService = {}

local random = Random.new()

local function randomTraits(): { string }
	local pool = table.clone(Mutations.normalTraits)
	local first = table.remove(pool, random:NextInteger(1, #pool)) :: string
	local second = pool[random:NextInteger(1, #pool)]
	return { first, second }
end

function WildGiantService.init() end

function WildGiantService.start()
	local nextId = -1
	for _, zone in Zones.list do
		for i = 1, Economy.wildGiantsPerZone do
			local species = SPECIES_ORDER[(i - 1) % #SPECIES_ORDER + 1]
			local rect = zone.rect
			local position = Vector3.zero
			for _ = 1, 20 do
				position = Vector3.new(
					random:NextNumber(rect.minX + MARGIN, rect.maxX - MARGIN),
					0,
					random:NextNumber(rect.minZ + MARGIN, rect.maxZ - MARGIN)
				)
				-- Lejos del rancho (y de sus estatuas).
				if not World.inRanch(position.X - 120, position.Z) then
					break
				end
			end
			GiantService.createWild(nextId, species, randomTraits(), zone.id, position)
			nextId -= 1
		end
	end
	print(`[WildGiantService] iniciado ({-nextId - 1} gigantes salvajes)`)
end

return WildGiantService
