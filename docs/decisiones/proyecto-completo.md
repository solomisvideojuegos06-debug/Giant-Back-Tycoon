# Proyecto completo (M2–M10): qué se ha hecho y qué cambia respecto al GDD

El usuario pidió implementar de una vez todos los hitos que quedaban (M2 a M10) tras comprobar el M1.
Este documento recoge cómo se ha implementado cada uno, las decisiones que no venían cerradas en el GDD
y lo que queda pendiente. Todas las cifras siguen en `src/shared/Config`.

## Estado por hito

| Hito | Qué hay | Dónde |
| --- | --- | --- |
| M2 Recursos y pisadas | ~600 nodos en 4 zonas con rejilla espacial de 32 studs, pisada cada 1,2 s, reaparición a los 30 s, almacén lleno = no recoge. Polvo, números flotantes y recursos que vuelan al lomo. | `ResourceService`, `EffectsController` |
| M3 Máquinas y economía | 6 máquinas con 5 niveles, precios con las fórmulas del GDD, tick de producción por segundo, venta de Fruta, menú Construir por hueco. Peticiones falsas rechazadas en el servidor. | `EconomyService`, `MachineModel`, `UIController` |
| M4 Crecimiento | Alimentar, niveles 1–10, estirón en 2 s con destello y sacudida, huecos nuevos, bloqueo de zonas por nivel. | `GrowthService`, `GiantService` |
| M5 Guardado | ProfileStore (incluido en `src/server/vendor`), esquema versión 2 con migración desde la 1, pastoreo nocturno al 10 % (máx. 8 h). | `DataService`, `EconomyService` |
| M6 Zonas y piloto | Pradera, Bosque alto, Costa y Montañas construidas por código desde `Config/Zones`; agua y espinos que frenan sin el rasgo; piloto automático desde el nivel 3. | `MapService`, `GiantService` |
| M7 Linaje | 12 gigantes salvajes (3 por zona), criar con salvajes y con jugadores, huevo de 15 min (también desconectado), herencia con pruebas, retiro, Salón del Linaje con estatuas, Libro de rasgos. | `WildGiantService`, `LineageService`, `Inheritance` |
| M8 Social | Subirse como pasajero (+20 % a los dos), bonus de manada (+10 % por gigante cercano, máx. 40 %) visible en la interfaz. | `SocialService`, `PlatformController` |
| M9 Interfaz, tutorial y arte | HUD completo con iconos propios dibujados (sin emojis), menús, tutorial de 60 s, 3 especies de bloques, 6 máquinas animadas, 3 pieles. | `UIController`, `ui/`, `TutorialController`, `Config/Species` |
| M10 Monetización, analítica y rendimiento | ProcessReceipt idempotente, 6 productos y 7 pases, ofertas ligadas a momentos, embudo y eventos de economía, máquinas ocultas a más de 400 studs. | `MonetizationService`, `TelemetryService` |

## Decisiones tomadas (no venían cerradas en el GDD)

- **Esquema de datos versión 2.** `egg` pasa a ser una lista `eggs` (para el pase Nido doble) y las máquinas
  usan como clave el hueco en texto (`"1"`, `"2"`…), porque los DataStores no aceptan listas con huecos vacíos.
  `DataService` migra automáticamente los datos de la versión 1.
- **Remotos añadidos:** `GetState` (estado completo al entrar), `EquipSkin`, `DebugGrant` (solo Studio),
  `Notify` (avisos), `BreedPrompt` (petición de cría a otro jugador) y `FruitRain`. Los del M1
  (`GiantSnapshot`, `RiderUpdate`) se explican en `M1-plataforma.md`.
- **El mapa se construye por código** (`MapService`) a partir de `Config/Zones`, así las zonas, el bloqueo por
  nivel y los nodos salen de la misma tabla. En modo edición de Studio el mapa no se ve; aparece al darle a Play.
- **Gigantes salvajes:** pasean despacio por su zona con 2 rasgos normales al azar (no solo los de su especie),
  para que criar con ellos dé variedad.
- **Distancias entre gigantes** (criar a menos de 60, manada a menos de 80): se miden entre los cuerpos
  (de centro a centro menos los radios), porque un adulto mide más de 100 studs.
- **Nido doble:** al criar salen 2 huevos y se elige con cuál continuar.
- **Paquetes de monedas:** cantidades fijas (500 / 2.000 / 6.000); el GDD no las daba.
- **Pieles:** son pases (Dorada, Nocturna y Caramelo) y se conservan en la siguiente generación.
- **StreamingEnabled desactivado.** El mapa es pequeño y estático y así se evitan errores de carga parcial.
  Se puede activar más adelante si el rendimiento en móvil lo pide.

## Pendiente (no se puede hacer desde el código)

- **Crear los productos y pases** en el Creator Hub (Monetization) y poner sus ids en `Config/Products.luau`.
  Mientras sean 0, en Studio se conceden gratis para probar; publicado, el botón dice «Disponible muy pronto».
- **Guardado real:** publicar la experiencia y activar *Enable Studio Access to API Services* en Game Settings ›
  Security. Sin eso, ProfileStore usa un almacén simulado y los datos se pierden al cerrar la prueba.
- **Insignia de mutación:** crearla y poner su id en `Config/Economy.luau` (`breeding.mutationBadgeId`).
- **Sonidos y arte final:** se usan sonidos internos de Roblox y modelos de bloques generados por código.
- **Ajustar la curva** con jugadores reales (GDD, «Después del MVP»).

## Versión 2 (tras la primera prueba del usuario)

El usuario pidió mejor aspecto y un comienzo más claro:

- **Rancho:** cada jugador tiene una parcela en el oeste de la Pradera, con valla, el cartel «Rancho de …», el nido
  donde vive su gigante, una plataforma verde para montar y las estatuas de su Linaje (sustituye al Salón común).
  El jugador ya no aparece sentado: aparece junto a su plataforma y una flecha le indica dónde montar.
  Si el dueño no va encima durante 12 s, el gigante vuelve solo a su nido.
- **Arte de bloques con studs** (referencia del usuario: un animal hecho de piezas): gigantes, árboles, rocas y máquinas
  se generan con muchos cubos de varios tonos (`VoxelArt`), y el suelo es a cuadros con studs.
- **Interfaz:** iconos nuevos con degradado, contorno y brillo; botones gruesos con sombra; contadores oscuros con
  números blancos; ventanas con barra de título. Los botones aparecen cuando hacen falta (Construir con las primeras
  monedas, Piloto en el nivel 3, Linaje y Libro en el nivel 10). Etiquetas sobre los gigantes con nombre, especie,
  nivel y producción por segundo.
