--!strict
--[[
	ClientState: copia en el cliente del estado del jugador que envía el
	servidor (GetState al entrar y StateUpdate con lo que cambia).
	Solo es presentación: el servidor valida todo.

	ClientState.get("coins")
	ClientState.onChanged("coins", function(value, previous) ... end)
	ClientState.onAnyChange(function(changedKeys) ... end)
]]

export type ChangedCallback = (value: any, previous: any) -> ()
export type AnyCallback = (changed: { [string]: boolean }) -> ()

local ClientState = {}

local values: { [string]: any } = {}
local listeners: { [string]: { ChangedCallback } } = {}
local anyListeners: { AnyCallback } = {}
local loaded = false

function ClientState.get(key: string): any
	return values[key]
end

function ClientState.number(key: string): number
	local value = values[key]
	return if type(value) == "number" then value else 0
end

function ClientState.isLoaded(): boolean
	return loaded
end

function ClientState.apply(changes: { [string]: any })
	local changed: { [string]: boolean } = {}
	for key, value in changes do
		local previous = values[key]
		values[key] = value
		changed[key] = true
		local list = listeners[key]
		if list then
			for _, callback in list do
				task.spawn(callback, value, previous)
			end
		end
	end
	loaded = true
	for _, callback in anyListeners do
		task.spawn(callback, changed)
	end
end

function ClientState.onChanged(key: string, callback: ChangedCallback)
	local list = listeners[key]
	if not list then
		list = {}
		listeners[key] = list
	end
	table.insert(list, callback)
end

function ClientState.onAnyChange(callback: AnyCallback)
	table.insert(anyListeners, callback)
end

return ClientState
