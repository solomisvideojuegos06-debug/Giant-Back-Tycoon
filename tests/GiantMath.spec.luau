--!strict
local GiantMath = require("../src/shared/GiantMath")

local EPS = 1e-6

local function near(a: number, b: number, eps: number?)
	assert(math.abs(a - b) <= (eps or EPS), `esperado {b}, obtenido {a}`)
end

local tests: { [string]: () -> () } = {}

tests["angleDelta toma el camino corto"] = function()
	near(GiantMath.angleDelta(0, math.pi / 2), math.pi / 2)
	near(GiantMath.angleDelta(math.rad(350), math.rad(10)), math.rad(20))
	near(GiantMath.angleDelta(math.rad(10), math.rad(350)), math.rad(-20))
end

tests["yawFromDirection y forward son inversas"] = function()
	for _, dir in { { 1, 0 }, { 0, 1 }, { -1, 0 }, { 0, -1 }, { 0.6, -0.8 } } do
		local yaw = GiantMath.yawFromDirection(dir[1], dir[2])
		local fx, fz = GiantMath.forward(yaw)
		near(fx, dir[1])
		near(fz, dir[2])
	end
	-- Convención de Roblox: yaw 0 mira a -Z.
	local fx, fz = GiantMath.forward(0)
	near(fx, 0)
	near(fz, -1)
end

local PARAMS = {
	maxSpeed = 10,
	acceleration = 8,
	deceleration = 14,
	turnRate = math.rad(75),
	fullTurnAngle = math.rad(100),
}

tests["steer acelera hacia delante sin pasarse de la velocidad máxima"] = function()
	local yaw, speed = 0, 0
	for _ = 1, 600 do
		yaw, speed = GiantMath.steer(yaw, speed, 0, -1, 1 / 60, PARAMS)
	end
	near(yaw, 0)
	near(speed, PARAMS.maxSpeed)
end

tests["steer frena sin entrada"] = function()
	local yaw, speed = 0, 10
	for _ = 1, 120 do
		yaw, speed = GiantMath.steer(yaw, speed, 0, 0, 1 / 60, PARAMS)
	end
	near(speed, 0)
end

tests["steer gira hacia la entrada y apenas avanza en un giro cerrado"] = function()
	-- Mira a -Z y se le pide ir a +Z (180°): debe girar casi parado.
	local yaw, speed = GiantMath.steer(0, 0, 0, 1, 1 / 60, PARAMS)
	near(speed, 0)
	near(math.abs(GiantMath.angleDelta(0, yaw)), PARAMS.turnRate / 60)
	-- Tras suficiente tiempo acaba mirando a +Z.
	for _ = 1, 600 do
		yaw, speed = GiantMath.steer(yaw, speed, 0, 1, 1 / 60, PARAMS)
	end
	local fx, fz = GiantMath.forward(yaw)
	near(fx, 0, 1e-3)
	near(fz, 1, 1e-3)
end

tests["sample interpola entre instantáneas"] = function()
	local snaps = {
		{ t = 0, x = 0, y = 0, z = 0, yaw = 0 },
		{ t = 1, x = 10, y = 2, z = -10, yaw = math.rad(90) },
	}
	local s = GiantMath.sample(snaps, 0.5, 0.25)
	assert(s, "sin muestra")
	near(s.x, 5)
	near(s.y, 1)
	near(s.z, -5)
	near(s.yaw, math.rad(45))
end

tests["sample interpola el ángulo por el camino corto"] = function()
	local snaps = {
		{ t = 0, x = 0, y = 0, z = 0, yaw = math.rad(350) },
		{ t = 1, x = 0, y = 0, z = 0, yaw = math.rad(10) },
	}
	local s = GiantMath.sample(snaps, 0.5, 0.25)
	assert(s, "sin muestra")
	near(GiantMath.angleDelta(0, s.yaw), 0)
end

tests["sample extrapola como mucho maxExtrapolation"] = function()
	local snaps = {
		{ t = 0, x = 0, y = 0, z = 0, yaw = 0 },
		{ t = 1, x = 10, y = 0, z = 0, yaw = 0 },
	}
	local s = GiantMath.sample(snaps, 5, 0.25)
	assert(s, "sin muestra")
	near(s.x, 12.5)
end

tests["sample antes de la primera o con una sola instantánea"] = function()
	local snaps = { { t = 2, x = 3, y = 0, z = 0, yaw = 0 } }
	local s = GiantMath.sample(snaps, 10, 0.25)
	assert(s and s.x == 3, "una sola instantánea")
	assert(GiantMath.sample({}, 0, 0.25) == nil, "lista vacía")
	table.insert(snaps, { t = 3, x = 4, y = 0, z = 0, yaw = 0 })
	local before = GiantMath.sample(snaps, 0, 0.25)
	assert(before and before.x == 3, "antes de la primera")
end

tests["legLift: patas opuestas no se levantan a la vez"] = function()
	for i = 0, 99 do
		local phase = i / 100
		local a = GiantMath.legLift(phase, 0)
		local b = GiantMath.legLift(phase, 0.5)
		assert(a >= 0 and a <= 1 and b >= 0 and b <= 1, "fuera de rango")
		assert(a == 0 or b == 0, `ambas en el aire en {phase}`)
	end
end

return tests
