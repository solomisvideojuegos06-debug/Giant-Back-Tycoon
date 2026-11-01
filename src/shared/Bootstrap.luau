--!strict
--[[
	Bootstrap
	Arranque común de services (servidor) y controllers (cliente).

	1. Carga todos los ModuleScript de una carpeta, ordenados por `priority`
	   (opcional, menor primero; por defecto 10) y después por nombre.
	2. Comprueba que cada uno expone init() y start().
	3. Llama a init() en todos (secuencial; si uno falla, se aborta el arranque).
	4. Llama a start() en todos, cada uno en su propio hilo para que un start()
	   que ceda no bloquee a los demás.
]]

local Types = require(script.Parent.Types)

type Lifecycle = Types.Lifecycle

local Bootstrap = {}

local DEFAULT_PRIORITY = 10

local function loadModules(folder: Instance): { { name: string, module: Lifecycle } }
	local children = folder:GetChildren()
	table.sort(children, function(a, b)
		return a.Name < b.Name
	end)

	local loaded: { { name: string, module: Lifecycle } } = {}
	for _, child in children do
		if child:IsA("ModuleScript") then
			local module = require(child) :: any
			assert(type(module) == "table", `{child.Name} debe devolver una tabla`)
			assert(type(module.init) == "function", `{child.Name} no expone init()`)
			assert(type(module.start) == "function", `{child.Name} no expone start()`)
			table.insert(loaded, { name = child.Name, module = module :: Lifecycle })
		end
	end
	-- Orden estable: prioridad (menor primero) y después nombre.
	table.sort(loaded, function(a, b)
		local pa = a.module.priority or DEFAULT_PRIORITY
		local pb = b.module.priority or DEFAULT_PRIORITY
		if pa ~= pb then
			return pa < pb
		end
		return a.name < b.name
	end)
	return loaded
end

function Bootstrap.run(label: string, folder: Instance)
	local modules = loadModules(folder)

	for _, entry in modules do
		local ok, err = pcall(entry.module.init)
		if not ok then
			error(`[{label}] {entry.name}.init() falló: {err}`, 0)
		end
	end

	for _, entry in modules do
		task.spawn(function()
			local ok, err = pcall(entry.module.start)
			if not ok then
				warn(`[{label}] {entry.name}.start() falló: {err}`)
			end
		end)
	end

	print(`[{label}] {#modules} módulos iniciados`)
end

return Bootstrap
