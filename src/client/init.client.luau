--!strict
-- Punto de entrada del cliente: espera a los remotos y arranca los controllers.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- Espera a la réplica inicial para que los controllers puedan usar
-- ReplicatedStorage.Shared directamente.
if not game:IsLoaded() then
	game.Loaded:Wait()
end

local Shared = ReplicatedStorage:WaitForChild("Shared")

require(Shared:WaitForChild("Remotes"))

local Bootstrap = require(Shared:WaitForChild("Bootstrap"))

Bootstrap.run("Client", script:WaitForChild("controllers"))
