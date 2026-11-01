--!strict
--[[
	GiantMath: cálculos puros del movimiento y la interpolación del gigante.
	Sin dependencias de Roblox (solo números) para poder probarlos con Lune:
	`lune run tests`.

	Convención de orientación (la de Roblox): con yaw = 0 el gigante mira a -Z.
	La dirección de avance para un yaw es (-sin(yaw), -cos(yaw)) en (x, z).
]]

local GiantMath = {}

local TAU = 2 * math.pi

export type SteerParams = {
	maxSpeed: number,
	acceleration: number,
	deceleration: number,
	turnRate: number,
	fullTurnAngle: number,
}

export type Snapshot = {
	t: number,
	x: number,
	y: number,
	z: number,
	yaw: number,
}

-- Diferencia angular más corta de `from` a `to`, en (-pi, pi].
function GiantMath.angleDelta(from: number, to: number): number
	local delta = (to - from) % TAU
	if delta > math.pi then
		delta -= TAU
	end
	return delta
end

function GiantMath.lerpAngle(a: number, b: number, t: number): number
	return a + GiantMath.angleDelta(a, b) * t
end

function GiantMath.moveToward(current: number, target: number, maxDelta: number): number
	if math.abs(target - current) <= maxDelta then
		return target
	end
	return current + math.sign(target - current) * maxDelta
end

-- Yaw que hace mirar en la dirección (dx, dz).
function GiantMath.yawFromDirection(dx: number, dz: number): number
	return math.atan2(-dx, -dz)
end

function GiantMath.forward(yaw: number): (number, number)
	return -math.sin(yaw), -math.cos(yaw)
end

--[[
	Un paso de dirección: el gigante gira hacia la entrada y avanza hacia delante.
	Cuanto mayor es el giro pendiente, más frena (gira casi parado si supera
	fullTurnAngle). Devuelve el nuevo yaw y la nueva velocidad hacia delante.
	(inputX, inputZ) es la dirección deseada en el mundo, de magnitud 0..1.
]]
function GiantMath.steer(
	yaw: number,
	speed: number,
	inputX: number,
	inputZ: number,
	dt: number,
	params: SteerParams
): (number, number)
	local magnitude = math.min(math.sqrt(inputX * inputX + inputZ * inputZ), 1)
	local targetSpeed = 0
	local newYaw = yaw

	if magnitude > 1e-3 then
		local desiredYaw = GiantMath.yawFromDirection(inputX, inputZ)
		local delta = GiantMath.angleDelta(yaw, desiredYaw)
		local maxTurn = params.turnRate * dt
		newYaw = yaw + math.clamp(delta, -maxTurn, maxTurn)

		local remaining = math.abs(GiantMath.angleDelta(newYaw, desiredYaw))
		local alignment = math.max(0, 1 - remaining / params.fullTurnAngle)
		targetSpeed = params.maxSpeed * magnitude * alignment
	end

	local rate = if targetSpeed > speed then params.acceleration else params.deceleration
	local newSpeed = GiantMath.moveToward(speed, targetSpeed, rate * dt)
	return newYaw % TAU, newSpeed
end

--[[
	Interpola una lista de instantáneas ordenadas por t (ascendente) en el
	instante `t`. Si `t` es posterior a la última, extrapola como mucho
	`maxExtrapolation` segundos con la velocidad de las dos últimas.
	Devuelve nil si no hay instantáneas.
]]
function GiantMath.sample(snapshots: { Snapshot }, t: number, maxExtrapolation: number): Snapshot?
	local count = #snapshots
	if count == 0 then
		return nil
	end

	local first = snapshots[1]
	if count == 1 or t <= first.t then
		return first
	end

	local last = snapshots[count]
	if t >= last.t then
		local previous = snapshots[count - 1]
		local span = last.t - previous.t
		if span <= 0 then
			return last
		end
		local ahead = math.min(t - last.t, maxExtrapolation)
		local k = ahead / span
		return {
			t = last.t + ahead,
			x = last.x + (last.x - previous.x) * k,
			y = last.y + (last.y - previous.y) * k,
			z = last.z + (last.z - previous.z) * k,
			yaw = last.yaw + GiantMath.angleDelta(previous.yaw, last.yaw) * k,
		}
	end

	for i = count - 1, 1, -1 do
		local a = snapshots[i]
		if a.t <= t then
			local b = snapshots[i + 1]
			local span = b.t - a.t
			local k = if span > 0 then (t - a.t) / span else 1
			return {
				t = t,
				x = a.x + (b.x - a.x) * k,
				y = a.y + (b.y - a.y) * k,
				z = a.z + (b.z - a.z) * k,
				yaw = GiantMath.lerpAngle(a.yaw, b.yaw, k),
			}
		end
	end

	return first
end

-- Fase (0..1) de cada pata en el ciclo de pasos y su altura de levantamiento (0..1).
function GiantMath.legLift(stepPhase: number, legPhase: number): number
	local p = (stepPhase + legPhase) % 1
	-- Medio ciclo en el aire (seno positivo), medio ciclo apoyada.
	return math.max(0, math.sin(p * TAU))
end

return GiantMath
