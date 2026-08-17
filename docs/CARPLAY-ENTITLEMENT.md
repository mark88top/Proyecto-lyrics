# CarPlay: el entitlement es el riesgo principal del proyecto

Leé esto antes que nada. No es un trámite: es lo que decide si la parte de
CarPlay se puede publicar o no.

## Cómo funciona CarPlay para apps de terceros

CarPlay no es "tu app en la pantalla del auto". Apple no permite dibujar
libremente: sólo se pueden usar plantillas del framework `CarPlay`
(`CPListTemplate`, `CPInformationTemplate`, `CPNowPlayingTemplate`, etc.),
y para usar cualquiera de ellas hace falta un **entitlement** que Apple
otorga a mano, por Team ID, tras revisar una solicitud.

Los entitlements de CarPlay se conceden por **categoría de app**, y la lista
es cerrada:

| Categoría | Entitlement | Ejemplo |
|---|---|---|
| Audio | `com.apple.developer.carplay-audio` | Spotify, podcasts, radio |
| Comunicación | `com.apple.developer.carplay-communication` | WhatsApp, Telegram |
| Navegación | `com.apple.developer.carplay-maps` | Waze, Google Maps |
| Carga de EV | `com.apple.developer.carplay-charging` | Redes de carga |
| Estacionamiento | `com.apple.developer.carplay-parking` | Apps de playas |
| Comida rápida | `com.apple.developer.carplay-quick-ordering` | Pedidos al paso |
| Tareas de conducción | `com.apple.developer.carplay-driving-task` | Apps de flota, peajes |

## El problema concreto

**"Mostrar la letra de lo que suena en Spotify" no encaja limpio en ninguna
de esas categorías.**

- No es una app de **audio**: no reproducimos nada. El entitlement de audio
  está pensado para apps que *son* la fuente de sonido.
- No es **navegación**, ni **comunicación**, ni las otras.
- **Driving task** es la categoría más amplia, pero Apple la define como
  tareas *relacionadas con la conducción del vehículo*. Leer letras no lo es.

Hay un segundo problema, independiente del primero: **distracción del
conductor**. Toda la guía de CarPlay gira alrededor de minimizar el tiempo
de mirada fuera de la ruta. Una pantalla cuyo propósito es que el conductor
lea texto que cambia todo el tiempo es, por definición, lo contrario.

**Conclusión honesta: la probabilidad de que Apple apruebe un entitlement de
CarPlay para una app de letras es baja.** No es imposible —el revisor mira
el caso concreto— pero conviene planificar asumiendo que la respuesta va a
ser que no.

Esto no invalida el proyecto. Lo que cambia es el orden de las cosas.

## Plan recomendado

### Fase 1 — Publicar la app de iPhone (sin bloqueo)

La app de iPhone no necesita ningún entitlement especial. Funciona completa:
conecta con Spotify, busca la letra, la sincroniza y la muestra. Sirve para
el teléfono en un soporte, para el pasajero, y para escuchar en casa.

Esta fase se puede publicar **ya**, y es la que valida el producto.

Para esto: dejá `com.apple.developer.carplay-audio` comentado en
`Sources/CarLyrics/Resources/CarLyrics.entitlements` (así viene) y la escena
de CarPlay declarada en el Info.plist simplemente nunca se activa.

### Fase 2 — Solicitar el entitlement en paralelo

Formulario: <https://developer.apple.com/contact/carplay/>

Qué mejora las chances, en orden de importancia:

1. **Pedir la categoría *audio*, no otra** — y para eso, que la app
   *reproduzca audio de verdad*. Ver "Cómo volverla elegible" abajo.
2. **Mostrar la mitigación de distracción, con capturas.** Este proyecto ya
   la implementa: 3 líneas como máximo, nada tocable en pantalla
   (`item.isEnabled = false`), refresco limitado a 0,4 s, y un ajuste para
   bajar a una sola línea. Adjuntá capturas del simulador de CarPlay.
3. **Explicar el caso de uso del pasajero**, no del conductor.
4. **Video corto** de la app funcionando en el simulador de CarPlay.

Guardá copia de lo que enviás: si te rechazan, la respuesta suele indicar
qué categoría creen que corresponde.

### Fase 3 — Si te lo aprueban

1. Descomentá la clave en `CarLyrics.entitlements`.
2. En el portal de desarrollador, regenerá el perfil de aprovisionamiento
   (el viejo no incluye el entitlement nuevo y la firma va a fallar).
3. En Xcode: *Signing & Capabilities* → refrescar.
4. Probá en un auto real o en un head unit compatible.

## Cómo volverla elegible para la categoría "audio"

Si querés maximizar las chances, el camino es que CarLyrics **sea** una app
de audio, no sólo un visor. La opción más limpia y honesta:

> Que CarLyrics reproduzca la música él mismo, en vez de leer lo que
> reproduce Spotify.

Con el **Spotify iOS SDK** y una cuenta Premium, la app puede controlar la
reproducción y presentarse como reproductor (`CPNowPlayingTemplate` +
`CPListTemplate` de contenido). Ahí sí encaja en "audio": el usuario elige
qué escuchar desde CarLyrics, CarLyrics reproduce, y la letra es una función
*de* ese reproductor —exactamente el mismo argumento que usa Spotify para
mostrar sus propias letras.

Eso es un cambio de alcance considerable (control de reproducción, colas,
navegación de biblioteca) y por eso no está en esta primera versión. La
arquitectura lo deja abierto: `PlaybackSource` ya abstrae la fuente, y
agregar un `SpotifyControllingSource` que además controle es incremental.

## Probar CarPlay sin el entitlement aprobado

Esto sí se puede hacer hoy, y conviene hacerlo antes de solicitar nada:

1. Descomentá `com.apple.developer.carplay-audio` en el archivo de
   entitlements.
2. Compilá **para el Simulador** (la firma no se valida ahí).
3. Simulador → menú **I/O → External Displays → CarPlay**.
4. Corré con la variable `CARLYRICS_SIMULATED_PLAYBACK=1` (ya está en el
   scheme) para tener una canción de ejemplo sin cuenta de Spotify.

De ahí salen las capturas para la solicitud.

Acordate de volver a comentar la clave antes de armar el archivo para App
Store Connect, o la subida va a fallar por entitlement no autorizado.
