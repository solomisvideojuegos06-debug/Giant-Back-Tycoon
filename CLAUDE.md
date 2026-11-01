# Giant Back Tycoon

Juego de Roblox. El diseño completo está en docs/GDD.md; léelo antes de cada tarea.

## Cómo trabajamos
- Implementa SOLO el hito que te pida (sección M del GDD). No adelantes hitos.
- Al terminar un hito, enumera los criterios de aceptación y cómo comprobarlos en Studio.
- Si una decisión del GDD no se puede implementar tal cual, para y explica el problema y las alternativas antes de cambiarla.

## Stack
- Rojo (default.project.json), Luau con --!strict en todos los archivos.
- Wally para paquetes (ProfileStore).
- StyLua para formato y Selene para lint: el código debe pasar ambos.

## Arquitectura
- src/server/services: lógica autoritativa. src/client/controllers: presentación y entrada. src/shared: config, tipos, fórmulas, remotos.
- Cada service/controller expone init() y start().
- El servidor nunca confía en el cliente: valida dinero, nivel, hueco, distancia y frecuencia en cada remoto.
- Todos los números de diseño en src/shared/Config. Nada de números mágicos en services.
- Funciones puras (Formulas.luau, Inheritance.luau) sin dependencias de Roblox, con pruebas.
- Los datos del jugador siguen el tipo PlayerData del GDD; cualquier cambio sube la versión y añade migración.

## Estilo del juego
- Mundo de bloques con textura de studs, colores saturados.
- Interfaz de simulador cuidada con iconos propios; nunca emojis estándar en la interfaz.
- Pensado primero para móvil: botones grandes, controles táctiles.

## Modelos
- Mientras no haya arte final, crea modelos de bloques simples por código o como .rbxm en assets/, con las mismas medidas y puntos de anclaje que tendrá el modelo final (huecos de máquina, asiento de la cabeza).

## Comandos
- `rokit install`: instala Rojo, Wally, StyLua y Selene en las versiones de rokit.toml.
- `wally install`: descarga ProfileStore en ServerPackages/.
- `rojo serve`: sincroniza con Roblox Studio (plugin de Rojo → Connect).
- `stylua --check src` y `selene src`: deben pasar sin errores antes de cada commit.

## Notas de implementación
- Los services y controllers se cargan solos desde su carpeta (src/shared/Bootstrap.luau): basta con añadir un ModuleScript con init() y start().
- Los remotos se declaran solo en src/shared/Remotes.luau; el servidor los crea y el cliente los espera.
