# Por qué este proyecto no se publica

Cierre de agosto de 2026. Este documento es el resultado más valioso del
proyecto: la investigación de mercado y de plataforma que llevó a no
publicarlo. El código quedó funcionando; la decisión fue de negocio.

## Qué se quería construir

Una app de iPhone que mostrara, sincronizada al segundo, la letra de la
canción que estuviera sonando en Spotify, con foco en la pantalla de
CarPlay. Gratuita, sin anuncios, sostenida con propinas.

## Los tres hallazgos que cambiaron la decisión

### 1. El entitlement de CarPlay no era el bloqueo, pero tampoco había ventaja

La primera lectura fue que el riesgo estaba en el entitlement de CarPlay,
que Apple otorga a mano y sólo para una lista cerrada de categorías donde
"mostrar letras" no entra.

Resultó que desde iOS 26 hay un camino que no lo necesita: un widget
`systemSmall` y una Live Activity `activityFamilySmall` llegan al Dashboard
de CarPlay sin ningún permiso especial. Es lo que hacen todas las apps del
rubro, incluida Musixmatch. Detalle técnico: la letra que avanza línea por
línea sale de la Live Activity, no del widget — el presupuesto de refresco
de WidgetKit (40 a 70 por día) no permite seguir una canción.

El detalle completo está en [CARPLAY-ENTITLEMENT.md](CARPLAY-ENTITLEMENT.md).

Pero al abrirse ese camino apareció el problema real: **la App Store no
tiene ninguna superficie de descubrimiento para CarPlay.** No hay categoría,
no hay filtro, no hay sección. El soporte de CarPlay es una función que el
usuario descubre después de instalar, no un canal por el que llegue.

Espacio de pantalla vacío al que nadie puede llegar por búsqueda no es una
oportunidad de mercado.

### 2. En estas categorías gana quien tiene el dato

Al relevar quién ocupa cada casillero del Dashboard de CarPlay, el patrón es
consistente:

| Categoría | Quién la tiene | Qué la protege |
|---|---|---|
| Clima, Fotos, Casa, Música, Calendario | Apple | Es su sistema operativo |
| Vuelos | Flighty | Datos de aviación pagos |
| Deportes | FotMob, NBA, MLB | Derechos de datos en vivo |
| Delivery y viajes | Uber, DoorDash, Lyft | El dato son ellos |
| Carga EV y estacionamiento | ChargePoint, PlugShare, SpotHero | Redes físicas |
| Letras | Musixmatch, con licencias | Las licencias |

Las letras no son la excepción del rubro: son el único caso donde el dato se
podía tomar sin permiso. Por eso ahí hay más de doce apps casi idénticas y
en los demás casilleros no hay ninguna.

Nuestra fuente de letras era LRCLIB — comunitaria, gratuita y **sin
licencias**, que es exactamente la parte que Musixmatch sí tiene resuelta.
Ver [LEGAL.md](LEGAL.md).

### 3. El diferencial elegido no era defendible

El plan era competir con precio: gratis contra apps que cobran entre USD 30
y USD 90 por año.

- "Gratis" es un precio, no un diferencial. Cualquiera lo copia, y Musixmatch
  puede regalar la función sin despeinarse porque su negocio es otro.
- Las donaciones en una app utilitaria recaudan prácticamente cero. Es un
  modelo para sostener un proyecto propio, no para construir algo.
- El canal de descubrimiento está saturado: buscar "lyrics carplay" en la
  App Store devuelve una pared de clones con el mismo nombre. Ganar ahí
  requiere presupuesto de marketing.

A eso se suma que Musixmatch entró a CarPlay en mayo de 2026 a USD 2,99 por
mes, con licencias en regla — hundiendo el techo de precio del rubro y
poniendo en el mercado a alguien con capacidad e incentivo para reclamar
sobre fuentes de letras sin licenciar.

## Lo que quedó pendiente y no se resolvió

Un problema técnico real que nunca llegamos a probar: **cómo actualizar la
Live Activity línea por línea con la app en segundo plano**, sin servidor
propio y sin declarar un modo de audio que no usamos (causa de rechazo por
la guía 2.5.4). Vibe declara públicamente que no usa servidores, así que
existe una solución local, pero no la encontramos documentada.

Si alguien retoma esto, ese prototipo es el primer paso — antes de escribir
una línea más.

## La conclusión transferible

El error de partida fue buscar un hueco en una pantalla en vez de partir de
una ventaja propia. El filtro correcto para el próximo proyecto no es "qué
casillero está vacío", sino **"dónde tengo yo un dato, un acceso o un canal
que otro no tiene"**.

Todo lo demás — que el código esté bien escrito, que la sincronía sea buena,
que la app sea gratis — no compensa no tener ninguna de esas tres cosas.

## Qué se hizo bien y sirve para reusar

- El núcleo es agnóstico del auto y está probado: `PlaybackCoordinator`
  (elección de fuente con degradación en cascada), `LyricsRepository`
  (caché de dos niveles, TTL asimétrico, deduplicación de búsquedas),
  `LRCParser`, `LyricsSynchronizer`, `Track.searchTitle`, y el login de
  Spotify con Authorization Code + PKCE.
- 10 suites de tests sobre la lógica que no depende de UIKit ni de la red.
- La arquitectura de una sola fuente de verdad para dos superficies de UI
  (teléfono y auto) — ver [ARCHITECTURE.md](ARCHITECTURE.md).

Cualquier cosa que toque reproducción de música en iOS puede partir de acá.
