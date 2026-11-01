--!strict
-- Config/Machines: máquinas del lomo: precios, producción y niveles.
-- Vacío en el hito M0; se rellena en el hito M3 con las cifras del GDD.
-- Todos los números de diseño viven aquí: nada de números mágicos en los services.

local Machines = {}

return table.freeze(Machines)
