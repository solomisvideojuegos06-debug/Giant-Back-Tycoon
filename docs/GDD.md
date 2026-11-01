# Giant Back Tycoon: documento de diseño

Nov 1, 2026 · @Chechu

## Resumen

**Giant Back Tycoon** es un tycoon en el que tu base está construida sobre la espalda de un gigante que camina por el mapa y que tú diriges. Sus pisadas recogen recursos, las máquinas de su lomo los convierten en dinero y la fruta lo hace crecer. De adulto tiene una cría que hereda rasgos de sus padres y pasa a ser tu nueva base: el **Linaje**.

Este documento tiene dos partes:

- **Diseño (A–K):** qué es el juego y por qué funciona.
- **Construcción (L–P):** cómo programarlo, en qué orden y cómo comprobar cada paso. Está pensado para que Claude Code lo lea y lo implemente hito a hito.

### Cómo usarlo con Claude Code

1. Exporta este documento como **Markdown** y guárdalo en el repositorio como `docs/GDD.md`.
2. Crea un archivo `CLAUDE.md` en la raíz con el contenido de la sección P.
3. Pide a Claude Code los hitos **de uno en uno** (sección M), empezando por el M0. No pases al siguiente hasta comprobar en Roblox Studio que se cumplen sus criterios de aceptación.

Todas las cifras de economía y precios son **hipótesis de partida**. Están en archivos de configuración para poder ajustarlas sin tocar código.

## A. La idea

- **Nombre provisional:** Giant Back Tycoon.
- **Género:** tycoon de movimiento y recolección con progresión generacional.
- **En una frase:** *Construye tu fábrica en la espalda de un gigante, guíalo por el mundo y cría una nueva generación más poderosa.*

### Cómo funciona

- Cada jugador tiene un **gigante** (al empezar, una cría del tamaño de una casa).
- El jugador se sienta en el **asiento de la cabeza** y lo dirige con el joystick. Cada **pisada** aplasta árboles, rocas y arbustos cercanos y recoge **Madera, Piedra y Fruta**.
- En el **lomo** hay huecos donde se compran **máquinas** que convierten Madera y Piedra en monedas.
- La **Fruta** sirve para dos cosas: venderla o **dársela al gigante** para que crezca. Esa decisión es central.
- Al crecer, el gigante es más grande, tiene más huecos y da pasos más largos, y puede entrar en **zonas** nuevas.
- De adulto puede tener una **cría** con un gigante salvaje o con el de un amigo. La cría hereda rasgos y pasa a ser la nueva base (sección F).

### Qué lo hace diferente

Los tycoons tienen la base quieta en una parcela. Aquí **la base se mueve, crece y tiene descendencia**. No se encontró ningún juego de Roblox con este planteamiento; los más cercanos son los de «alimenta al gigante», en los que el gigante es un objetivo inmóvil y no tu base.

La frase para el jugador: **«Tu base está viva: llévala adonde quieras y haz que su hija sea mejor que ella.»**

## B. El gancho principal

El gancho tiene dos tiempos:

1. **Cada pocos segundos, la pisada.** El gigante pisa, el suelo tiembla, los árboles saltan en pedazos y los recursos vuelan hacia su lomo con números flotantes. Es el equivalente a «pulsar un botón y ver la recompensa», pero en grande y en movimiento.
2. **Cada pocos minutos, el estirón.** Al llenar la barra de crecimiento, el gigante crece delante de todo el servidor con una animación, un rugido y una sacudida de cámara. Su espalda se ensancha y aparecen huecos nuevos. Es el momento de progreso más visible que puede tener un tycoon.

### La decisión que lo hace interesante

La Fruta se puede vender ahora (dinero para máquinas) o dar de comer al gigante (crecimiento). Vender da progreso inmediato; alimentar da un salto más grande después. El juego no te obliga: los jugadores impacientes y los estrategas juegan distinto.

### Ejemplo de una sesión (minuto 12)

Tu tortuga está en nivel 4. Llevas el gigante al borde del Bosque alto, donde los árboles dan el doble de Madera, pero tu tortuga no llega a la fruta de las copas. Ves pasar la jirafa de otro jugador cosechando las copas. Decides que tu próxima cría será con una jirafa. Mientras tanto, compras una segunda Sierra en el lomo y das 30 de Fruta al gigante: estirón a nivel 5, que te deja cruzar a la Costa.

## C. El bucle de juego

1. **Dirigir** el gigante hacia una zona con recursos.
2. **Pisar**: cada paso recoge los recursos que hay en el radio de la pisada.
3. **Procesar**: las máquinas del lomo convierten Madera y Piedra en monedas cada segundo.
4. **Decidir la Fruta**: venderla o alimentar al gigante.
5. **Comprar** máquinas y mejoras en los huecos del lomo.
6. **Crecer**: más tamaño, más huecos, zonas nuevas.
7. **Criar** (de adulto): huevo, cría con rasgos nuevos, la cría pasa a ser la base.

### Cómo evoluciona en 15 minutos

| Momento | Qué tiene el jugador | Qué siente | Siguiente objetivo visible |
| --- | --- | --- | --- |
| 10 s | Cría de nivel 1, una Sierra gratis | «Lo dirijo, pisa, recoge» | Comprar la Trituradora |
| 1 min | Sierra y Trituradora funcionando | Dinero entrando solo | Dar 20 de Fruta: primer estirón |
| 5 min | Nivel 3, 4 máquinas, piloto automático básico | Puede bajar a construir mientras el gigante camina solo | Nivel 5 para cruzar a la Costa |
| 15 min | Nivel 5, 6-7 máquinas, primera visita a la Costa | Ve gigantes adultos de otros y quiere el suyo | Llegar a adulto (nivel 10) y criar |

El **piloto automático** (desde el nivel 3) hace que el gigante pasee solo por la zona actual a velocidad reducida. Así el jugador puede bajarse a construir sin perder producción, y dirigir a mano sigue rindiendo más porque se eligen los recursos.

## D. Los primeros 60 segundos

| Segundo | Qué pasa |
| --- | --- |
| 0-3 | El jugador aparece **ya sentado en la cabeza** de su cría de tortuga, en la Pradera. Una flecha señala el joystick (móvil) o WASD (ordenador). |
| 3-10 | Mueve el gigante. Primera pisada sobre un árbol: el árbol salta, «+5 Madera» vuela al lomo. |
| 10-20 | La Sierra del lomo (regalada) se ilumina y escupe monedas: «+10». El contador de dinero sube. |
| 20-35 | Pisa un arbusto: «+3 Fruta». Aparece la barra de crecimiento sobre la cabeza del gigante y un botón «Alimentar». |
| 35-45 | Con 25 monedas, un hueco del lomo parpadea: «Trituradora — 25». Un botón en pantalla («Construir») lo compra sin tener que bajarse. |
| 45-60 | Alimenta con la Fruta reunida y la barra se llena: **primer estirón** a nivel 2, con rugido y sacudida de cámara. Aparece el objetivo: «Nivel 3: piloto automático». |

Reglas de diseño:

- La Pradera inicial está llena de recursos cerca del punto de aparición: nada de caminar 30 segundos sin recompensa.
- El primer estirón está calibrado para llegar en menos de un minuto.
- Sin ventanas de texto ni ofertas de pago antes del minuto 5.

## E. Progresión y economía

Todas las cifras son hipótesis iniciales y viven en módulos de configuración (sección L).

### Recursos

| Recurso | Cómo se consigue | Para qué sirve |
| --- | --- | --- |
| Madera | Pisar árboles | La procesan Sierras → monedas |
| Piedra | Pisar rocas | La procesan Trituradoras → monedas |
| Fruta | Pisar arbustos y árboles frutales | Alimentar al gigante (crecer) o vender (1,5 monedas/u) |
| Monedas | Máquinas y venta de Fruta | Comprar y mejorar máquinas |

Los recursos se guardan en el **Almacén del lomo** (capacidad inicial 100 de cada uno). Si está lleno, las pisadas no recogen ese recurso: así las máquinas y el almacén importan.

**Nodos de recursos:** cada nodo tiene un rendimiento y reaparece a los 30 s en el mismo sitio. Pradera: árbol 5 Madera, roca 4 Piedra, arbusto 3 Fruta. Cada zona superior multiplica el rendimiento (x2, x4, x8).

### Pisada

Cada paso del gigante recoge todos los nodos dentro de un **radio de pisada** = 10 studs × escala del gigante. Intervalo entre pasos: 1,2 s (fijo; el gigante grande da pasos más largos y avanza más rápido).

### Máquinas del lomo

| Máquina | Efecto (nivel 1) | Precio (monedas) |
| --- | --- | --- |
| Sierra | 1 Madera/s → 2 monedas cada una | Gratis la primera, 60 las siguientes |
| Trituradora | 1 Piedra/s → 3 monedas cada una | 25 |
| Almacén | +100 de capacidad por recurso | 150 |
| Sierra industrial | 3 Madera/s → 2 monedas cada una | 800 |
| Molino de roca | 3 Piedra/s → 3 monedas cada una | 1.500 |
| Taller de pulido | +25 % al valor de todo lo procesado | 4.000 |

Cada máquina sube de nivel del 1 al 5: +40 % de velocidad por nivel, coste x1,6 por nivel. Cada máquina nueva del mismo tipo cuesta un 30 % más que la anterior. Ritmo objetivo: una compra cada 20-40 s al principio, cada 1-2 min hacia el minuto 15.

### Crecimiento

| Nivel | Fruta para subir al siguiente | Escala del gigante | Huecos de máquina | Desbloquea |
| --- | --- | --- | --- | --- |
| 1 | 12 | 1,0 | 2 | — |
| 2 | 30 | 1,2 | 3 | — |
| 3 | 60 | 1,4 | 4 | Piloto automático, Bosque alto |
| 4 | 110 | 1,6 | 5 | — |
| 5 | 200 | 1,8 | 6 | Costa |
| 6 | 350 | 2,0 | 7 | — |
| 7 | 600 | 2,25 | 8 | Montañas |
| 8 | 1.000 | 2,5 | 9 | — |
| 9 | 1.600 | 2,75 | 10 | Volcán (después del MVP) |
| 10 (adulto) | — | 3,0 | 12 | Criar (sección F) |

Tiempo objetivo hasta adulto en la primera generación: 60-90 minutos de juego. Las generaciones siguientes van más rápido gracias a los bonus del Linaje.

### Zonas

El mapa es un continente compartido por los 6 jugadores del servidor. Las zonas están separadas por obstáculos naturales que solo se cruzan a partir de cierto nivel (el gigante es demasiado pequeño para el río, la ladera, etc.).

1. **Pradera** (nivel 1): recursos básicos abundantes.
2. **Bosque alto** (nivel 3): x2 de Madera; los **árboles frutales altos** (15 Fruta) solo los recoge un gigante con *Cuello largo* o de nivel 8+.
3. **Costa** (nivel 5): rocas de coral (x4 Piedra); el agua poco profunda frena a los gigantes sin *Patas anchas*.
4. **Montañas** (nivel 7): cristales (x8 Piedra); laderas de espinos que dañan el ritmo de los gigantes sin *Piel dura*.
5. **Volcán** (nivel 9, después del MVP).

Los rasgos no bloquean el avance, pero abren atajos y recursos extra. Así cada combinación de rasgos juega distinto.

## F. El Linaje

El Linaje sustituye al renacimiento clásico. En lugar de «perderlo todo a cambio de un multiplicador», el jugador **gana una criatura nueva que él ha diseñado**. Es el sistema que da objetivos a largo plazo, motivos para volver otro día y motivos para jugar con amigos.

### Especies y rasgos (MVP)

Cada gigante tiene una **especie** (define su cuerpo) y **2 rasgos**.

| Especie | Rasgo 1 | Rasgo 2 |
| --- | --- | --- |
| Tortuga | **Caparazón**: +2 huecos de máquina | **Piel dura**: las laderas de espinos no la frenan |
| Elefante | **Patas anchas**: radio de pisada +40 %; el agua no lo frena | **Trompa**: recoge la Fruta hasta 10 studs más allá de la pisada |
| Jirafa | **Cuello largo**: recoge los árboles frutales altos | **Zancada**: +25 % de velocidad |

**Mutaciones raras** (5 % de probabilidad por cría, sustituyen a uno de los rasgos):

- **Gigantismo**: nace en nivel 2 y con +10 % de escala.
- **Brillo**: el gigante brilla y todo lo procesado vale +10 %.
- **Doble estómago**: cada Fruta dada cuenta como 1,5.

El jugador empieza con una cría de Tortuga con Caparazón y Piel dura.

### Cómo se cría

1. El gigante debe ser **adulto** (nivel 10).
2. Necesita una **pareja** adulta cerca (menos de 60 studs):
   - un **gigante salvaje** (cada zona tiene NPC adultos de las 3 especies con rasgos visibles sobre su cabeza), o
   - el **gigante de otro jugador**: los dos pulsan «Criar» y aceptan. **Ambos** reciben un huevo y ninguno pierde nada.
3. Aparece un **huevo** en el lomo. Tarda **15 minutos reales** en eclosionar, jugando o desconectado.

### Herencia

- **Especie de la cría:** la de uno de los padres, al 50 %.
- **Rasgos:** uno al azar de cada padre. Si salen repetidos, se vuelve a tirar el segundo.
- **Mutación:** 5 % de probabilidad de sustituir un rasgo por una mutación rara.
- Antes de eclosionar, el huevo muestra **pistas** (color de la cáscara = especie; dibujos = rasgos), para que abrirlo sea una pequeña sorpresa sin ser pura suerte.

### Retiro y nueva generación

Cuando el huevo eclosiona, el jugador decide si **continuar con la cría** ahora o más tarde. Al hacerlo:

- El adulto se retira y queda como **estatua en el Salón del Linaje**, cerca del punto de aparición, visible para todo el servidor mientras el jugador esté conectado.
- **Se pierden:** monedas, recursos, máquinas y nivel.
- **Se conservan:** el Linaje (número de generación), el Libro de rasgos, los cosméticos y los pases.
- **Bonus permanente por generación:** +15 % monedas y +10 % al valor de la Fruta como alimento (acumulativos).

### Libro de rasgos

Una colección de todas las combinaciones de especie + rasgos que el jugador ha criado. Cada combinación nueva da una recompensa pequeña de monedas y las mutaciones dan una insignia. Es la colección del juego, basada en decisiones (con quién crías) y no solo en suerte.

## G. Retención y juego con amigos

Roblox recomienda más los juegos con buena retención, más días jugados por usuario y más días de juego con amigos ([Roblox: Discovery FAQ](https://create.roblox.com/docs/en-us/discovery-faq.md)). Cada sistema de esta sección apunta a una de esas señales.

### Razones para volver otro día

- **El huevo:** eclosiona en 15 minutos aunque estés desconectado. Volver para ver qué ha salido es el principal motivo para abrir el juego al día siguiente.
- **Gigante salvaje del día:** cada día aparece en algún lugar del mapa un gigante salvaje con una **mutación garantizada**. Criar con él es la forma más fiable de conseguir mutaciones.
- **Pastoreo nocturno:** al salir, el gigante sigue pastando a un 10 % de rendimiento durante un máximo de 8 horas.

### Juego con amigos

- **Criar con amigos:** «cruza tu gigante con el mío» es una invitación natural, y los dos ganan un huevo.
- **Subirse al gigante de otro:** puedes ir de pasajero en el gigante de un amigo y ayudarle a construir; ambos ganáis +20 % mientras vais juntos.
- **Manada:** si 2 o más gigantes caminan a menos de 80 studs unos de otros, todos ganan +10 % por gigante cercano (máximo +40 %).
- **Eventos de servidor (después del MVP):** una tormenta o una lluvia de meteoritos cada 15 minutos; los gigantes deben juntarse para resistirla y repartirse un premio.

### Lanzamiento frente a más adelante

| En el MVP | Después, según los datos |
| --- | --- |
| 3 especies, 6 rasgos, 3 mutaciones, huevo, retiro, Libro | Especies nuevas en cada actualización (Dragón con *Alas*, Ballena con *Branquias*, Mamut, Robot) |
| Criar con salvajes y con amigos, pasajeros, manada | Eventos de servidor, Volcán, gigante salvaje del día con mutación |
| Pastoreo nocturno | Aspectos de temporada (gigantes de Halloween, de Navidad) |

Regla para actualizar: cada especie nueva trae un rasgo que cambia cómo se juega, no solo un número mayor.

## H. Monetización

Cada compra nace de un deseo que crea el juego: avanzar más rápido, presumir de gigante o criar mejor. Nunca se venden huevos ni crías aleatorias de pago. Precios en Robux = hipótesis.

### Developer Products (consumibles)

| Producto | Precio | Qué deseo satisface | Cuándo ofrecerlo |
| --- | --- | --- | --- |
| **Banquete** (+50 % de la Fruta que falta para el siguiente nivel) | 29 R$ | Llegar ya al próximo estirón | Cuando la barra de crecimiento está por encima del 60 % |
| **Eclosión inmediata** | 49 R$ | Ver ya qué ha salido del huevo | Con el huevo incubándose, solo si el jugador está conectado |
| **Lluvia de fruta** (10 min de x2 Fruta para todo el servidor, se anuncia tu nombre) | 99 R$ | Ser el héroe del servidor | Con 3+ jugadores |
| **Paquete de monedas** | 49 / 149 / 399 R$ | Llegar a la siguiente máquina | Cuando falta menos de 2 minutos para ella |

### Game Passes (permanentes)

| Pase | Precio | Qué aporta | Por qué no rompe el juego gratis |
| --- | --- | --- | --- |
| **x2 Monedas** | 249 R$ | Todo lo procesado vale el doble | La curva base está calibrada sin él |
| **Piloto experto** | 149 R$ | El piloto automático va a velocidad completa y busca los recursos más valiosos | El piloto gratuito existe desde el nivel 3 |
| **Nido doble** | 199 R$ | Incuba 2 huevos a la vez y elige con cuál continuar | Con un huevo se juega completo |
| **Almacén gigante** | 99 R$ | +100 % de capacidad de almacén | Los almacenes se compran con monedas |
| **Pieles de gigante** (patrones, colores, sombreros, sillas de montar) | 49-199 R$ | Presumir: es el cosmético más visible posible | Puro cosmético; la piel se puede heredar a la cría |

### Reglas para no estropear el juego

- Si un jugador gratuito tarda más de 3 minutos en su siguiente compra, se ajusta la curva, no se añade una oferta.
- Las mutaciones se consiguen jugando (gigante salvaje del día, crías con amigos); no se venden.
- La Lluvia de fruta beneficia a todo el servidor, así que los jugadores gratuitos la celebran.

## I. Identidad visual e interfaz

### Estilo

- **Mundo de bloques con textura de studs**, colores saturados y cálidos, estilo simulador clásico de Roblox. Nada de realismo.
- **Gigantes de bloques** grandes y redondeados, con ojos expresivos y animaciones exageradas (pisotón con rebote, rugido al crecer). Un único rig por especie que se escala con el nivel.
- **Máquinas del lomo** con piezas móviles visibles (sierras que giran, trituradoras que golpean) y humo o chispas al producir.
- El mapa nunca parece vacío: muchos nodos de recursos, gigantes salvajes paseando y los gigantes de los otros jugadores visibles a distancia.

### Interfaz

- **Interfaz de simulador cuidada**, con iconos propios dibujados en el mismo estilo, **sin emojis estándar**.
- Arriba a la derecha: monedas, Madera, Piedra y Fruta, con su capacidad de almacén.
- Sobre la cabeza del gigante: **barra de crecimiento** con el nivel.
- Abajo a la derecha (pulgar en móvil): botones grandes **Alimentar**, **Construir** y **Piloto**.
- Arriba a la izquierda: barra con **un solo objetivo** («Nivel 3: piloto automático»).
- Menús: Tienda de máquinas (por hueco), Libro de rasgos, Linaje (huevo y generación).

### Efectos

- Pisada: polvo, sacudida suave de cámara, objetos que saltan y números flotantes («+5 Madera»).
- Estirón: el gigante crece en 2 s con un rugido, destello y sacudida fuerte; las máquinas se recolocan en el lomo ampliado.
- Eclosión: el huevo se agrieta, luz del color de la especie y aparece la cría con un estornudo cómico.
- Límite de partículas en móvil.

### Miniatura ideal

Una tortuga colosal caminando entre montañas con una fábrica humeante en el caparazón, un avatar diminuto saludando desde su cabeza y, al lado, un huevo brillante a punto de romperse. Debe entenderse a 150 px: **gigante + base encima + huevo**.

## J. Viralidad

**Momentos más compartibles:**

- **La eclosión de una mutación rara** o de una combinación que nadie del servidor tenía. Genera la pregunta «¿con quién lo has cruzado?».
- **El estirón a adulto:** un gigante que pasa a ser más alto que las montañas delante de todo el servidor.
- **La manada:** cinco o seis gigantes caminando juntos con sus fábricas humeando. Es la imagen del juego.
- **El Salón del Linaje:** una fila de estatuas de todas las generaciones de un jugador, de la cría de tortuga del principio a la tortudragón brillante de la generación 12.

**Por qué invitar a un amigo:** criar juntos da un huevo a cada uno y abre combinaciones que no puedes conseguir con los salvajes; ir en manada da más dinero.

### Qué tendría que mejorar para crecer

1. Que el jugador mueva el gigante en los primeros 3 segundos y vea el primer estirón antes del minuto 1.
2. Que la primera sesión llegue al menos a la Costa (nivel 5).
3. Que vuelva al día siguiente a abrir su huevo.
4. Que juegue con amigos (criar, pasajeros, manada).

El nombre final debe explicar el juego solo; alternativas a probar: *Giant Back Tycoon*, *Build on a Giant*, *Raise a Giant Base*.

## K. Alcance del MVP

El MVP responde a dos preguntas: **¿es divertido mover el gigante, pisar y construir durante 15 minutos?** y **¿la gente vuelve para abrir su huevo?**

### Entra

- Servidores de 6 jugadores, un mapa con **Pradera, Bosque alto, Costa y Montañas**.
- 3 especies (Tortuga, Elefante, Jirafa), 6 rasgos, 3 mutaciones.
- Movimiento del gigante (manual y piloto automático), pisada, nodos de recursos con reaparición.
- 6 máquinas con 5 niveles cada una, almacén.
- Crecimiento del nivel 1 al 10 con estirones.
- Linaje completo: gigantes salvajes, criar con salvajes y con amigos, huevo de 15 minutos, herencia, retiro, Salón del Linaje, Libro de rasgos.
- Pasajeros y bonus de manada.
- Pastoreo nocturno.
- Guardado de datos, interfaz para móvil y ordenador, tutorial de 60 s.
- Monetización mínima: x2 Monedas, Banquete, Eclosión inmediata y 2-3 pieles.
- Eventos de analítica para medir el embudo (sección L).

### No entra todavía

Volcán, eventos de servidor, especies extra, gigante salvaje del día, aspectos de temporada, intercambio entre jugadores (nunca en el MVP: añade estafas y complejidad).

## L. Especificación técnica

Esta sección es para Claude Code. Las decisiones marcadas como **riesgo** se validan en el hito M1 antes de construir nada encima.

### Herramientas

- **Rojo** para sincronizar los archivos del repositorio con Roblox Studio (el código vive en GitHub, no dentro del .rbxl).
- **Luau con `--!strict`** en todos los módulos.
- **ProfileStore** para guardar datos de jugador (sesiones bloqueadas, sin pérdida de datos).
- **Wally** como gestor de paquetes (para ProfileStore y poco más).
- **StyLua** y **Selene** para formato y errores comunes.
- Sin frameworks pesados: patrón simple de *services* (servidor) y *controllers* (cliente), cada uno con `init()` y `start()`.

### Estructura del repositorio

```text
giant-back-tycoon/
├─ default.project.json      (mapa de Rojo)
├─ wally.toml
├─ stylua.toml · selene.toml
├─ CLAUDE.md
├─ docs/GDD.md               (este documento)
├─ assets/                   (modelos .rbxm: gigantes, máquinas, nodos, mapa)
└─ src/
   ├─ server/                → ServerScriptService
   │  ├─ init.server.luau
   │  └─ services/
   │     ├─ DataService        (ProfileStore, carga/guardado, migraciones)
   │     ├─ GiantService       (estado lógico y movimiento de cada gigante)
   │     ├─ ResourceService    (nodos, pisadas, reaparición)
   │     ├─ EconomyService     (almacén, máquinas, tick de producción, compras)
   │     ├─ GrowthService      (alimentar, niveles, estirón)
   │     ├─ LineageService     (criar, huevo, herencia, retiro, Libro)
   │     ├─ WildGiantService   (gigantes salvajes NPC)
   │     ├─ SocialService      (pasajeros, manada, criar con amigos)
   │     ├─ MonetizationService (ProcessReceipt, pases)
   │     └─ TelemetryService   (eventos de analítica)
   ├─ client/                → StarterPlayer.StarterPlayerScripts
   │  ├─ init.client.luau
   │  └─ controllers/
   │     ├─ GiantRenderController (dibuja e interpola los gigantes)
   │     ├─ PlatformController    (mantiene al jugador sobre el gigante en movimiento)
   │     ├─ DriveController       (entrada de dirección)
   │     ├─ EffectsController     (pisadas, estirones, números flotantes)
   │     ├─ UIController          (HUD, tiendas, Libro, Linaje)
   │     └─ TutorialController    (primeros 60 s)
   └─ shared/                → ReplicatedStorage.Shared
      ├─ Config/  (Species, Traits, Mutations, Machines, Levels, Zones, Nodes, Economy, Products)
      ├─ Types.luau
      ├─ Remotes.luau
      ├─ Formulas.luau        (costes, producción, escala)
      └─ Inheritance.luau     (función pura de herencia, testeable)
```

### Arquitectura del gigante (decisión crítica)

El problema: los jugadores deben caminar sobre algo enorme que se mueve, sin tirones ni caídas, también en móvil.

**Solución propuesta: gigante lógico en servidor + gigante visual en cada cliente.**

1. **Servidor (GiantService):** cada gigante es un estado de datos: posición en el suelo, orientación, velocidad, nivel, especie, rasgos y máquinas. El servidor lo mueve en `Heartbeat` según la entrada del conductor o el piloto automático, calcula la altura del suelo con un raycast hacia abajo y bloquea el paso a zonas sin nivel suficiente. Publica la posición en una pieza raíz invisible y anclada (`GiantRoot`) en `Workspace.Giants`, y el resto del estado como atributos.
2. **Cliente (GiantRenderController):** clona el modelo visual de la especie desde `ReplicatedStorage.Assets`, lo escala según el nivel, coloca las máquinas en sus huecos y lo **interpola suavemente** hacia el `GiantRoot` replicado. La animación de caminar se sincroniza con la velocidad.
3. **Cliente (PlatformController):** cada `RenderStepped`, si un raycast desde los pies del jugador local toca su gigante visual, se aplica al `HumanoidRootPart` el **desplazamiento del gigante desde el frame anterior** (`nuevoCFrame * anteriorCFrame:Inverse()`). Es la técnica clásica de plataforma móvil. Como el personaje lo simula su propio cliente, colisiona con la copia local del gigante sin problemas.
4. **Asiento de la cabeza:** al sentarse, el `DriveController` envía la dirección del joystick (máximo 20 veces por segundo) por un `UnreliableRemoteEvent`. El servidor la valida y la aplica.

**Riesgo y plan B:** si la plataforma móvil da problemas (caídas, tirones en móvil), el plan B es que los jugadores sobre el lomo vayan **anclados a puntos fijos** (como pasajeros sentados) y construyan solo desde la interfaz. Esto se decide al final del hito M1.

### Recursos y pisadas

- Los nodos se guardan en el servidor como datos (posición, tipo, zona, agotado hasta), indexados en una **rejilla espacial** de celdas de 32 studs. La pisada no usa física: consulta las celdas cercanas y recoge los nodos dentro del radio.
- Visualmente, cada nodo es un modelo anclado en `Workspace.Nodes`; al agotarse, el servidor pone el atributo `Depleted = true` y los clientes reproducen la animación de romperse y ocultan el modelo hasta que reaparece.
- Una pisada cada 1,2 s por gigante en el servidor; el evento se replica a los clientes cercanos para los efectos.

### Datos guardados (esquema, versión 1)

```lua
export type PlayerData = {
    version: number,
    coins: number,
    resources: { wood: number, stone: number, fruit: number },
    giant: {
        species: string,          -- "Turtle" | "Elephant" | "Giraffe"
        traits: { string },        -- 2 rasgos o mutaciones
        level: number,             -- 1..10
        growthFruit: number,       -- Fruta acumulada hacia el siguiente nivel
        machines: { [number]: { id: string, level: number } }, -- por hueco
        skin: string?,
    },
    egg: { species: string, traits: { string }, hatchAt: number }?, -- os.time()
    lineage: { generation: number, ancestors: { { species: string, traits: { string } } } },
    traitBook: { [string]: boolean }, -- clave "Especie:rasgoA+rasgoB"
    lastLogout: number,
    passes: { [string]: boolean },
    purchaseHistory: { [string]: boolean }, -- ReceiptId ya procesados
}
```

`DataService` debe incluir una función de **migración** por versión desde el primer día.

### Comunicación cliente-servidor (`shared/Remotes.luau`)

| Remoto | Tipo | Dirección | Contenido |
| --- | --- | --- | --- |
| DriveInput | UnreliableRemoteEvent | Cliente → servidor | Vector de dirección (x, z) |
| SetAutopilot | RemoteEvent | Cliente → servidor | Activado o no |
| BuyMachine | RemoteFunction | Cliente → servidor | Hueco, id de máquina → éxito o error |
| UpgradeMachine | RemoteFunction | Cliente → servidor | Hueco → éxito o error |
| Feed | RemoteFunction | Cliente → servidor | Cantidad de Fruta |
| SellFruit | RemoteFunction | Cliente → servidor | Cantidad |
| RequestBreed | RemoteFunction | Cliente → servidor | Id del gigante pareja (salvaje o jugador) |
| RespondBreed | RemoteEvent | Cliente → servidor | Aceptar o rechazar una petición |
| ContinueWithHatchling | RemoteFunction | Cliente → servidor | Confirmar retiro |
| BoardGiant | RemoteFunction | Cliente → servidor | Subir como pasajero al gigante de otro |
| StateUpdate | RemoteEvent | Servidor → cliente | Monedas, recursos, nivel, huevo (solo lo que cambia) |
| Stomp | UnreliableRemoteEvent | Servidor → clientes cercanos | Gigante, posición, recursos recogidos |
| GrowthSpurt / Hatch | RemoteEvent | Servidor → todos | Para los efectos visuales |

**Reglas de seguridad:** el servidor nunca confía en cantidades ni precios enviados por el cliente; comprueba dinero, hueco libre, nivel y distancia en cada petición; limita la frecuencia de cada remoto por jugador.

### Configuración

Todo número de diseño (precios, rendimientos, curvas, probabilidades, tiempos) vive en `shared/Config/*.luau` como tablas tipadas. **Ningún número mágico en los servicios.** Las fórmulas (coste por nivel, escala, producción) van en `shared/Formulas.luau`.

### Monetización

`MonetizationService` implementa `MarketplaceService.ProcessReceipt` de forma **idempotente** (guarda el `PurchaseId` en `purchaseHistory` antes de confirmar) y comprueba los pases al entrar y con `PromptGamePassPurchaseFinished`. Los ids de productos y pases están en `Config/Products.luau`.

### Rendimiento

- `StreamingEnabled` activado; los nodos y gigantes lejanos se cargan por zonas.
- Gigantes lejanos con modelo simplificado (sin máquinas) a más de 400 studs.
- Objetivo: 60 FPS en un móvil de gama media con 6 gigantes en pantalla; máximo de partículas por efecto.

### Analítica

`TelemetryService` registra con el `AnalyticsService` de Roblox un **embudo de incorporación** (movió el gigante, primera pisada, primera compra, primer estirón, nivel 3, nivel 5, primer huevo, primera eclosión) y eventos de **economía** (fuentes y gastos de monedas) para ajustar la curva con datos reales.

## M. Plan de desarrollo por hitos

Pide a Claude Code **un hito cada vez**. Cada hito termina con una lista de comprobación que haces tú en Roblox Studio (servidor local con 2 jugadores cuando haga falta). Los modelos se pueden empezar con bloques simples; el arte final llega en el M9.

### M0. Proyecto base

Repositorio con Rojo, Wally (ProfileStore), StyLua, Selene, estructura de carpetas de la sección L, `Remotes.luau`, módulos de configuración vacíos y arranque de services y controllers.

- [ ] `rojo serve` conecta con Studio y el juego arranca sin errores en la consola.
- [ ] Cada service y controller imprime que se ha iniciado.

### M1. El gigante que camina (riesgo principal)

GiantService (estado lógico, movimiento, altura del suelo), GiantRenderController (modelo de bloques escalable, interpolación), PlatformController, asiento de la cabeza y DriveController. Un gigante por jugador al entrar.

- [ ] Se dirige con joystick (móvil emulado) y WASD.
- [ ] Puedes bajarte del asiento y caminar por el lomo mientras se mueve sin caerte ni temblar.
- [ ] Con 2 jugadores, cada uno ve al otro moverse correctamente sobre su gigante.
- [ ] Cambiar la escala (nivel 1 a 10) no rompe nada.
- [ ] **Decisión documentada:** plataforma móvil o plan B.

### M2. Recursos y pisadas

ResourceService con rejilla espacial, nodos de la Pradera, pisada cada 1,2 s, reaparición y efectos.

- [ ] Cada pisada recoge los nodos del radio y los muestra con números flotantes.
- [ ] Los nodos reaparecen a los 30 s.
- [ ] El almacén lleno deja de recoger ese recurso.

### M3. Máquinas y economía

EconomyService: huecos, compra y mejora de las 6 máquinas, tick de producción, venta de Fruta. Interfaz mínima de tienda.

- [ ] Las máquinas aparecen en su hueco del lomo y producen monedas cada segundo.
- [ ] Los precios salen de la configuración y suben según las fórmulas.
- [ ] Peticiones falsas (sin dinero, hueco ocupado) se rechazan en el servidor.

### M4. Crecimiento

GrowthService: alimentar, niveles 1-10, estirón (escala, huecos nuevos, recolocación de máquinas) y bloqueo de zonas por nivel.

- [ ] El estirón se ve en todos los clientes con su animación.
- [ ] Las máquinas siguen en su sitio tras crecer.

### M5. Guardado

DataService con ProfileStore, esquema versión 1, migraciones, pastoreo nocturno al volver.

- [ ] Al salir y volver se conserva todo (monedas, máquinas, nivel, gigante).
- [ ] Al volver tras un rato, se recibe la producción nocturna (máximo 8 h).

### M6. Zonas y piloto automático

Mapa con Pradera, Bosque alto, Costa y Montañas; nodos especiales; efectos de los rasgos sobre el terreno; piloto automático.

- [ ] No se puede entrar en una zona sin el nivel necesario.
- [ ] El piloto automático pasea por la zona actual y recoge recursos.

### M7. El Linaje

WildGiantService, LineageService (criar, huevo de 15 min, `Inheritance.luau`, retiro, Salón del Linaje, Libro de rasgos) y criar con otro jugador.

- [ ] `Inheritance.luau` tiene pruebas: misma especie de un padre, un rasgo de cada padre, sin repetidos, 5 % de mutación en 10.000 tiradas simuladas.
- [ ] El huevo eclosiona aunque el jugador se desconecte.
- [ ] Al continuar con la cría se reinicia lo correcto y se conserva lo correcto (sección F).
- [ ] Dos jugadores pueden criar juntos y ambos reciben huevo.

### M8. Social

SocialService: pasajeros, bonus de manada.

- [ ] Un jugador puede subirse al gigante de otro y ambos reciben el bonus.
- [ ] El bonus de manada aparece en la interfaz cuando hay gigantes cerca.

### M9. Interfaz final, tutorial y arte

HUD completo con iconos propios, menús, TutorialController (primeros 60 s de la sección D), modelos finales de especies y máquinas, efectos.

- [ ] Un jugador nuevo mueve el gigante en menos de 5 s y hace el primer estirón antes de 60 s sin leer texto.
- [ ] Todo es usable en pantalla de móvil.

### M10. Monetización, analítica y rendimiento

MonetizationService, productos y pases del MVP, TelemetryService, optimización.

- [ ] Las compras de prueba en Studio funcionan y no se duplican.
- [ ] Los eventos del embudo aparecen en la analítica.
- [ ] 60 FPS con 6 gigantes en un móvil de gama media (o el emulador de Studio).

### Después del MVP

1. **Pruebas con 20-50 jugadores:** ajustar la curva hasta que la mayoría llegue a la Costa en la primera sesión.
2. **Lanzamiento:** 2-3 miniaturas a comparar, campaña pequeña de anuncios, vídeos cortos de estirones y eclosiones.
3. **Actualizaciones cada 1-2 semanas** según los datos: primero arreglar el principio si la retención del día 1 es baja; si es buena, especies nuevas, gigante salvaje del día, eventos de servidor y Volcán.

## N. Riesgos

| # | Riesgo | Por qué podría pasar | Cómo reducirlo |
| --- | --- | --- | --- |
| 1 | **Caminar sobre el gigante en movimiento da problemas** | Las plataformas móviles son delicadas en Roblox, sobre todo en móvil | Hito M1 dedicado solo a esto; gigante lento; plan B de pasajeros anclados |
| 2 | **Al principio no hay suficiente acción** | Dirigir un gigante pequeño puede sentirse lento | Pradera llena de nodos junto al punto de aparición; primer estirón antes de 60 s; pisadas con mucho efecto |
| 3 | **El retiro se siente como perder** | Reiniciar monedas y máquinas siempre duele | Bonus por generación visibles antes de decidir; el jugador elige cuándo; la cría empieza con ventajas claras |
| 4 | **La economía se descompensa** con los bonus del Linaje | Los multiplicadores acumulados crecen rápido | Todo en configuración; simular 10 generaciones en una hoja de cálculo; analítica de economía desde el MVP |
| 5 | **Nadie lo descubre** | Sin jugadores no hay señales para el algoritmo | Miniatura muy clara, anuncios pequeños al lanzar, vídeos cortos de eclosiones y estirones, criar con amigos como motivo para invitar |

Si funciona, saldrán copias. La defensa es el ritmo de especies nuevas y el apego al propio Linaje, que no se puede copiar.

## O. Evaluación final

| Criterio | Nota (1-10) | Justificación |
| --- | --- | --- |
| Originalidad | 8 | No se encontró ningún tycoon con la base sobre un gigante que caminas y crías |
| Claridad | 8 | La miniatura se entiende al instante; el Linaje se descubre jugando |
| Retención | 8 | Estirones a corto plazo, huevo a medio, Linaje y Libro a largo; huevo como motivo para volver |
| Monetización | 7 | Pieles muy visibles y compras ligadas a momentos claros; sin venta de azar |
| Viralidad | 8 | Estirones, eclosiones raras y manadas de gigantes son muy de vídeo corto |
| Viabilidad técnica | 6 | El gigante móvil es el reto; el resto es un tycoon estándar con datos bien organizados |

**Qué tendría que ocurrir para que funcione:** que el hito M1 salga bien, que los primeros 60 segundos enganchen sin explicación, y que la primera eclosión haga que la gente vuelva al día siguiente. Nada de esto garantiza jugadores ni ingresos; las pruebas con jugadores reales son las que lo dirán.

## P. Instrucciones para Claude Code

Copia este bloque en un archivo `CLAUDE.md` en la raíz del repositorio.

```markdown
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
```

### Primer mensaje a Claude Code

> Lee CLAUDE.md y docs/GDD.md. Implementa el hito M0 y dime cómo comprobarlo.

Después, cuando lo hayas comprobado en Studio: «M0 comprobado, implementa el M1». El M1 es el más importante: pruébalo bien en el emulador de móvil antes de seguir.
