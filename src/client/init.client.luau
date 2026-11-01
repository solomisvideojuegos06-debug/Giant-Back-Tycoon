--!strict
-- Punto de entrada del cliente: espera a los remotos y arranca los controllers.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")

require(Shared:WaitForChild("Remotes"))

local Bootstrap = require(Shared:WaitForChild("Bootstrap"))

Bootstrap.run("Client", script:WaitForChild("controllers"))
