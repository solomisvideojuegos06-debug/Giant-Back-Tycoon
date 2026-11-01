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

function World.zoneIndex(zoneId: string): number
	for index, zone in Zones.list do
		if zone.id == zoneId then
			return index
		end
	end
	return 0
end

return World
