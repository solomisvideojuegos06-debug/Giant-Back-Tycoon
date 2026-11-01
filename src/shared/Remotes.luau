--!strict
--[[
	Remotes
	Única fuente de verdad de la comunicación cliente-servidor (GDD, sección L).

	- En el servidor, crea las instancias en ReplicatedStorage.Remotes.
	- En el cliente, espera a que existan.

	El servidor debe requerir este módulo antes de arrancar los services
	(lo hace src/server/init.server.luau).

	Reglas de seguridad: el servidor nunca confía en cantidades ni precios del
	cliente, valida dinero, hueco, nivel y distancia, y limita la frecuencia.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local FOLDER_NAME = "Remotes"
local IS_SERVER = RunService:IsServer()

local folder: Instance
if IS_SERVER then
	local existing = ReplicatedStorage:FindFirstChild(FOLDER_NAME)
	if existing then
		folder = existing
	else
		local created = Instance.new("Folder")
		created.Name = FOLDER_NAME
		created.Parent = ReplicatedStorage
		folder = created
	end
else
	folder = ReplicatedStorage:WaitForChild(FOLDER_NAME)
end

local function get(name: string, className: string): Instance
	if IS_SERVER then
		local existing = folder:FindFirstChild(name)
		if existing then
			assert(existing.ClassName == className, `El remoto {name} debería ser {className}`)
			return existing
		end
		local created = Instance.new(className)
		created.Name = name
		created.Parent = folder
		return created
	end
	return folder:WaitForChild(name)
end

local function event(name: string): RemoteEvent
	return get(name, "RemoteEvent") :: RemoteEvent
end

local function unreliable(name: string): UnreliableRemoteEvent
	return get(name, "UnreliableRemoteEvent") :: UnreliableRemoteEvent
end

local function func(name: string): RemoteFunction
	return get(name, "RemoteFunction") :: RemoteFunction
end

local Remotes = {
	-- Cliente → servidor
	DriveInput = unreliable("DriveInput"), -- dirección (x, z), máx. 20/s
	SetAutopilot = event("SetAutopilot"), -- activado o no
	BuyMachine = func("BuyMachine"), -- hueco, id de máquina → éxito o error
	UpgradeMachine = func("UpgradeMachine"), -- hueco → éxito o error
	Feed = func("Feed"), -- cantidad de Fruta
	SellFruit = func("SellFruit"), -- cantidad
	RequestBreed = func("RequestBreed"), -- id del gigante pareja
	RespondBreed = event("RespondBreed"), -- aceptar o rechazar
	ContinueWithHatchling = func("ContinueWithHatchling"), -- confirmar retiro
	BoardGiant = func("BoardGiant"), -- subir como pasajero

	-- Cliente → servidor → otros clientes (no está en el GDD; ver docs/decisiones/M1-plataforma.md)
	-- Posición del personaje relativa al gigante que pisa, para dibujar bien
	-- a los demás jugadores sobre su gigante.
	RiderUpdate = unreliable("RiderUpdate"),

	-- Servidor → cliente(s)
	-- Instantáneas con hora del servidor para interpolar los gigantes
	-- (no está en el GDD; ver docs/decisiones/M1-plataforma.md).
	GiantSnapshot = unreliable("GiantSnapshot"),
	StateUpdate = event("StateUpdate"), -- solo lo que cambia
	Stomp = unreliable("Stomp"), -- gigante, posición, recursos recogidos
	GrowthSpurt = event("GrowthSpurt"), -- efectos visuales del estirón
	Hatch = event("Hatch"), -- efectos visuales de la eclosión
}

return Remotes
