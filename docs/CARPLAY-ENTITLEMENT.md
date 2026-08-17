# Cómo se llega a la pantalla del auto

> **Revisado en agosto de 2026.** La versión anterior de este documento decía
> que el entitlement de CarPlay era el riesgo principal del proyecto. Eso era
> correcto hasta iOS 26 y ya no lo es: existe un camino sancionado que no
> requiere entitlement, y es el que usan todas las apps del rubro, incluida
> Musixmatch. El bloqueo real se corrió a otro lado — ver
> "El problema que sí queda" al final.

## Los dos caminos

Desde iOS 26 hay dos formas de que contenido de una app de terceros aparezca
en CarPlay, y sólo una de ellas pasa por el framework `CarPlay`.

### Camino A — Widget + Live Activity (abierto)

- Un widget de la familia `systemSmall` aparece en el Dashboard de CarPlay
  **automáticamente**, sin trabajo adicional y **sin ningún entitlement**.
- Las Live Activities también llegan al Dashboard, con el tamaño
  `activityFamilySmall`. Son de sólo lectura en el auto.
- El usuario elige qué widgets ver en Ajustes → General → CarPlay.

Fuente: [Turbocharge your app for CarPlay, WWDC25](https://developer.apple.com/videos/play/wwdc2025/216/)
y [Adding StandBy and CarPlay support to your widget](https://developer.apple.com/documentation/widgetkit/adding-standby-and-carplay-support-to-your-widget).

### Camino B — App de CarPlay (cerrado para nosotros)

Plantillas `CPListTemplate`, `CPNowPlayingTemplate`, etc. Requiere que Apple
otorgue a mano un entitlement por Team ID, y sólo para una lista cerrada de
categorías: audio, comunicación, navegación, carga de EV, estacionamiento,
comida rápida y tareas de conducción.

"Mostrar letras" no encaja en ninguna. No somos una app de audio porque no
reproducimos nada.

**No vale la pena pedirlo.** No es que sea difícil: es que no existe la
categoría bajo la cual pedirlo.

## Widget y Live Activity no son lo mismo

Esta distinción es la que la prensa mezcla y es la que define la
implementación:

| | Widget (`systemSmall`) | Live Activity (`activityFamilySmall`) |
|---|---|---|
| Refresco | 40–70 por día; entradas separadas ~5 min | Tiempo real |
| Sirve para | Estado en reposo del Dashboard | **La letra que avanza línea por línea** |
| Requiere | Nada | `NSSupportsLiveActivitiesFrequentUpdates` en el Info.plist |

Un widget de WidgetKit no puede seguir una canción: el presupuesto diario no
da. La letra viva sale de la **Live Activity**, que además es la misma pieza
que alimenta el Dynamic Island en el teléfono.

Musixmatch lo confirma por descarte: sus letras llegan a CarPlay como Live
Activity y explícitamente **no** se pueden ver dentro de su app en CarPlay.

## Qué implica para este código

El núcleo de la app no cambia. Lo que cambia es la capa de presentación:

**Se conserva** — `PlaybackCoordinator`, `LyricsRepository`, `LRCParser`,
`LyricsSynchronizer`, `LyricsCache`, `Track.searchTitle`, el login PKCE.

**Se reemplaza** — `CarPlaySceneDelegate`, `CarPlayCoordinator` y
`CarPlayLyricsBoard` implementan el camino B. Van a:
- una extensión de WidgetKit con `systemSmall`, y
- una Live Activity con `activityFamilySmall` para el auto más las vistas
  compactas del Dynamic Island para el teléfono.

**Se agrega** — un App Group para compartir estado entre la app y las
extensiones, y `NSSupportsLiveActivitiesFrequentUpdates` en el Info.plist.

**Se saca** — el entitlement de CarPlay y la escena
`CPTemplateApplicationSceneSessionRoleApplication` del Info.plist.

> El código del camino B sigue en el repo a propósito, sin borrar. Es una
> referencia útil de cómo se arma una app de CarPlay por plantillas, y la
> lógica de `CarPlayLyricsBoard` (qué líneas mostrar, cuándo repintar) se
> traslada casi tal cual a la Live Activity.

## El problema que sí queda

**Ejecución en segundo plano.** Para actualizar la Live Activity línea por
línea con la app fuera de pantalla hay que estar corriendo.

- Sin servidor propio no hay push, y montar uno rompe el modelo gratuito.
- Declarar `UIBackgroundModes: audio` sin reproducir audio es causa de
  rechazo. **Ya lo saqué del Info.plist**, justamente por eso.
- Vibe declara públicamente que no usa servidores, así que existe una
  solución local. Averiguar cuál es la primera tarea técnica del proyecto.

Hipótesis a probar, en orden: mantener viva la conexión del SDK de Spotify
(App Remote), y ver hasta dónde llega `NSSupportsLiveActivitiesFrequentUpdates`
con actualizaciones locales.

**Hacé este prototipo antes de escribir más código.** Una Live Activity que
se actualice cada pocos segundos con la app en background, sin trucos de
audio. Si eso funciona, el resto es trabajo conocido; si no funciona, no hay
producto en el auto y conviene saberlo temprano.

## Riesgo de política a futuro

La guía de Apple sobre `disfavoredLocations` dice que los widgets que
dependen de **texto de alta densidad** o de información irrelevante para
conducir deberían marcarse como no aptos para CarPlay. Una letra de canción
es exactamente eso.

Hoy nadie aplica ese criterio y hay una decena de apps publicadas. Si mañana
se aplica, cae todo el rubro junto.

Mitigación: que la app valga la pena en el teléfono por sí sola —pantalla
bloqueada, Dynamic Island, widgets, StandBy—, de modo que la parte del auto
sea un extra y no el producto entero.

## Probar sin auto

Widgets y Live Activities de CarPlay se prueban con el **CarPlay Simulator
para macOS**, que viene en "Additional Tools for Xcode" (descarga aparte
desde developer.apple.com/download/all).
