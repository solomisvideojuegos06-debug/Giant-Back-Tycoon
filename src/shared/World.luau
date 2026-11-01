--!strict
-- World: consultas sobre las zonas del mapa (servidor y cliente).

local Zones = require(script.Parent.Config.Zones)

type ZoneDef = Zones.ZoneDef
type SlowArea = Zones.SlowArea
type Rect = Zones.Rect

local World = {}

function World.inRect(rect: Rect, x: number, z: number): boolean
	return x >= rect.minX and x <= rect.maxX and z >= rect.minZ and z <= rect.maxZ
end

function World.zoneAt(x: number, z: number): ZoneDef?
	for _, zone in Zones.list do
		if World.inRect(zone.rect, x, z) then
			return zone
		end
	end
	return nil
end

function World.slowAreaAt(x: number, z: number): SlowArea?
	local zone = World.zoneAt(x, z)
	if not zone then
		return nil
	end
	for _, area in zone.slowAreas do
		if World.inRect(area.rect, x, z) then
			return area
		end
	end
	return nil
end

-- Centro de la parcela del rancho número `slot` (1..count).
function World.plotCenter(slot: number): Vector3
	local ranch = Zones.ranch
	return Vector3.new(ranch.centerX, 0, ranch.firstZ + (slot - 1) * ranch.spacing)
end

-- ¿Está (x, z) dentro de la zona del rancho (con su entrada)?
function World.inRanch(x: number, z: number): boolean
	local ranch = Zones.ranch
	local half = ranch.size / 2
	local lastZ = ranch.firstZ + (ranch.count - 1) * ranch.spacing
	return x <= ranch.centerX + half + 30 and z >= ranch.firstZ - half - 10 and z <= lastZ + half + 10
end

function World.zoneIndex(zoneId: string): number
	for index, zone in Zones.list do
		if zone.id == zoneId then
			return index
		end
	end
	return 0
end

return World
