--!strict
--[[
	RateLimiter: cubo de fichas por jugador para limitar la frecuencia de cada
	remoto (CLAUDE.md: «limita la frecuencia de cada remoto por jugador»).

	local limiter = RateLimiter.new(20, 5) -- 20 por segundo, ráfagas de 5
	if not limiter.allow(player.UserId) then return end
]]

export type Limiter = {
	allow: (key: number) -> boolean,
	forget: (key: number) -> (),
}

type Bucket = {
	tokens: number,
	updatedAt: number,
}

local RateLimiter = {}

function RateLimiter.new(ratePerSecond: number, burst: number): Limiter
	local buckets: { [number]: Bucket } = {}

	local function allow(key: number): boolean
		local now = os.clock()
		local bucket = buckets[key]
		if not bucket then
			bucket = { tokens = burst, updatedAt = now }
			buckets[key] = bucket
		end
		bucket.tokens = math.min(burst, bucket.tokens + (now - bucket.updatedAt) * ratePerSecond)
		bucket.updatedAt = now
		if bucket.tokens < 1 then
			return false
		end
		bucket.tokens -= 1
		return true
	end

	local function forget(key: number)
		buckets[key] = nil
	end

	return {
		allow = allow,
		forget = forget,
	}
end

return RateLimiter
