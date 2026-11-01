# Giant Back Tycoon

Juego de Roblox. El diseño completo está en docs/GDD.md; léelo antes de cada tarea.

## Cómo trabajamos
- Todos los hitos del MVP (M0–M10) están implementados (ver docs/decisiones/proyecto-completo.md). Ahora se trabaja arreglando lo que el usuario reporte tras probar, sin añadir sistemas que no pida.
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

## Modelos y arte
- Estilo elegido por el usuario: bloques con studs y varios tonos (como un animal hecho de piezas).
- Gigantes y nodos salen de src/shared/VoxelArt.luau (función pura). Config/Species lee de ahí las medidas (asiento, cubierta, huecos); no las dupliques.
- GiantModel suelda todo a una raíz anclada (mover = un CFrame) y las patas van con Motor6D.
- Iconos: src/client/ui/IconData.luau (capas con degradado y contorno), dibujados por Icons.luau.
- Antes de entregar cambios visuales, renderiza una vista previa (Lune exporta VoxelArt/IconData a JSON y three.js/HTML en Chromium con Playwright) y revísala.

## Entrega al usuario (importante)
- El usuario NO usa Rojo, Wally ni la terminal. Trabaja directamente en Roblox Studio.
- Primera entrega o cuando cambie el mapa (Workspace): un archivo `.rbxl` completo que abre con doble clic.
- Actualizaciones: 3 archivos `.rbxm` (Server, Shared, Client). Borra las carpetas viejas en Studio y arrastra las nuevas:
  - `Server.rbxm` → ServerScriptService
  - `Shared.rbxm` → ReplicatedStorage
  - `Client.rbxm` → StarterPlayer › StarterPlayerScripts
- Se generan con `rojo build` (ver «Comandos») y se envían como archivos adjuntos. El código sigue en GitHub como copia.
- Explica los pasos en español sencillo, sin dar por sabido nada técnico.

## Comandos (para Claude, no para el usuario)
- `rojo build -o dist/GiantBackTycoon.rbxl default.project.json`: place completa.
- `rojo build -o dist/Server.rbxm builds/server.project.json` (igual con `shared` y `client`): actualizaciones.
- `stylua --check src tests` y `selene src tests`: deben pasar sin errores antes de cada commit.
- `lune run tests`: pruebas de las funciones puras (GiantMath, Formulas, Inheritance).
- ProfileStore está incluido en src/server/vendor (licencia en licenses/); no hace falta Wally.
- Comprobaciones extra sin Studio: rojo build + Lune (`@lune/roblox`) para revisar la place y las propiedades usadas.

## Notas de implementación
- Los services y controllers se cargan solos desde su carpeta (src/shared/Bootstrap.luau): basta con añadir un ModuleScript con init() y start().
- Los remotos se declaran solo en src/shared/Remotes.luau; el servidor los crea y el cliente los espera.
- Arranque: los módulos pueden declarar `priority` (MapService 0, DataService 1, TelemetryService 2, GiantService 5; resto 10).
- Estado del cliente: DataService.setView en el servidor → StateUpdate → src/client/ClientState.luau.
- El gigante: estado lógico en GiantService, copia visual por cliente en GiantRenderController, plataforma móvil en PlatformController. Ver docs/decisiones/M1-plataforma.md.
- Solo en Studio, comandos de chat de prueba: `/nivel N` cambia el nivel del gigante; `/pasear` lo hace caminar solo en círculos.
- Rancho (RanchService): el jugador aparece en su parcela y se monta en la plataforma verde; si el dueño no va encima, el gigante vuelve solo a su nido.
