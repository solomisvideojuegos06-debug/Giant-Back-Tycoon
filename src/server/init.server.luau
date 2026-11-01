--!strict
-- Punto de entrada del servidor: crea los remotos y arranca los services.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")

-- Los remotos deben existir antes de que los clientes los esperen.
require(Shared:WaitForChild("Remotes"))

local Bootstrap = require(Shared:WaitForChild("Bootstrap"))

Bootstrap.run("Server", script:WaitForChild("services"))
