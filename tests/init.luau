--!strict
-- Pruebas de las funciones puras (sin Roblox). Ejecutar con: lune run tests

local suites = {
	require("@self/GiantMath.spec"),
}

local passed, failed = 0, 0
for _, suite in suites do
	for name, test in suite do
		local ok, err = pcall(test)
		if ok then
			passed += 1
		else
			failed += 1
			print(`FALLO  {name}: {err}`)
		end
	end
end

print(`{passed} pruebas correctas, {failed} fallidas`)
if failed > 0 then
	error("Hay pruebas fallidas", 0)
end
