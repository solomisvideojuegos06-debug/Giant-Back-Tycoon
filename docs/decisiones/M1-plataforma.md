# M1 · Plataforma móvil o plan B

**Estado:** plan A (plataforma móvil) implementado, **pendiente de probar en Studio**.
La decisión final se apunta al final de este documento cuando se compruebe el M1.

## Qué se ha implementado (plan A)

Tal y como propone el GDD (sección L, «Arquitectura del gigante»):

1. **Servidor (`GiantService`)**: el gigante es un estado de datos (posición en el suelo, orientación,
   velocidad, nivel). Se mueve en `Heartbeat` con la dirección validada de `DriveInput`. La altura sale
   de un raycast hacia abajo contra `Workspace.Map`, y los desniveles demasiado altos bloquean el paso.
   La posición se publica en `Workspace.Giants.<UserId>` (pieza invisible y anclada, el GiantRoot).
2. **Cliente (`GiantRenderController`)**: cada cliente dibuja su propia copia de bloques de cada gigante,
   la escala según el nivel y la interpola. Anima las patas y el rebote según la velocidad.
3. **Cliente (`PlatformController`)**: si el personaje pisa un gigante, se le aplica cada frame el mismo
   desplazamiento que al gigante (`nuevo * anterior:Inverse()`), también al cambiar de escala.
4. **Asiento de la cabeza**: el jugador aparece sentado. Saltar le levanta y el aviso «Conducir» (tecla E
   o tocarlo en el móvil) le vuelve a sentar. `DriveController` envía la dirección (máximo 20/s).

## Dos añadidos respecto al GDD

Ninguno cambia una decisión del GDD; los dos hacen falta para que el plan A funcione bien en red.

| Remoto | Tipo | Por qué |
| --- | --- | --- |
| `GiantSnapshot` | UnreliableRemoteEvent, servidor → clientes | El GiantRoot replicado no lleva marca de tiempo: interpolar «hacia» él da pequeños tirones cuando los paquetes llegan a destiempo. Con instantáneas a 20/s con la hora del servidor, todos los clientes dibujan el gigante con un ritmo uniforme. El GiantRoot se mantiene como referencia autoritativa. |
| `RiderUpdate` | UnreliableRemoteEvent, cliente → servidor → clientes | Cada cliente ve los gigantes con su propio retraso de red. Sin corrección, a los demás jugadores se les vería resbalar hacia atrás sobre un gigante en marcha (más cuanto más rápido va). Cada cliente envía su posición relativa al gigante que pisa y los demás le dibujan en esa posición sobre su copia del gigante. |

## Qué hay que probar

- Dirigir con WASD y con el joystick del emulador de móvil.
- Escribir `/pasear` en el chat (el gigante camina solo), bajarse del asiento (saltar) y caminar por el lomo
  con el gigante en marcha: sin caerse ni temblar.
- Con 2 jugadores: cada uno ve al otro bien colocado sobre su gigante, también en marcha.
- `/nivel 1` … `/nivel 10` en el chat: el gigante crece o encoge en 1 s y quien está encima sigue encima.

## Plan B (si el plan A falla)

Los jugadores sobre el lomo irían **anclados a puntos fijos**, como pasajeros sentados, y construirían solo
desde la interfaz. Se perdería caminar libremente por el lomo.

## Decisión

_Pendiente de la prueba en Studio._
