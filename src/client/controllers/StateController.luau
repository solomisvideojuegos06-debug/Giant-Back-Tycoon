--!strict
-- StateController: pide el estado completo al servidor y aplica StateUpdate.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local Remotes = require(Shared.Remotes)
local ClientState = require(script.Parent.Parent.ClientState)

local StateController = {
	priority = 1,
}

function StateController.init() end

function StateController.start()
	Remotes.StateUpdate.OnClientEvent:Connect(function(changes: { [string]: any })
		if type(changes) == "table" then
			ClientState.apply(changes)
		end
	end)

	-- El perfil tarda un poco en cargarse: se reintenta hasta tener estado.
	task.spawn(function()
		for _ = 1, 60 do
			local ok, view = pcall(function()
				return Remotes.GetState:InvokeServer()
			end)
			if ok and type(view) == "table" then
				ClientState.apply(view)
				return
			end
			task.wait(0.5)
		end
	end)

	print("[StateController] iniciado")
end

return StateController
