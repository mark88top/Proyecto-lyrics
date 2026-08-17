# Arquitectura

## Idea general

```
        ┌──────────────┐         ┌──────────────────┐
        │   Spotify    │         │      LRCLIB      │
        │ (App Remote  │         │  (letras .lrc)   │
        │  o Web API)  │         └────────┬─────────┘
        └──────┬───────┘                  │
               │ PlaybackState            │ Lyrics
               ▼                          ▼
     ┌───────────────────┐      ┌────────────────────┐
     │ PlaybackCoordinator│─────▶│  LyricsController  │
     └───────────────────┘      └─────────┬──────────┘
                                          │ LyricsSnapshot
                        ┌─────────────────┴─────────────────┐
                        ▼                                   ▼
              ┌──────────────────┐              ┌────────────────────┐
              │  SwiftUI (iPhone)│              │ CarPlay (plantillas)│
              └──────────────────┘              └────────────────────┘
```

Una sola fuente de verdad (`AppEnvironment.shared`), dos superficies de UI.
Es deliberado: iPhone y CarPlay son escenas distintas de la misma app y
tienen que mostrar exactamente lo mismo. Duplicar los servicios significaría
dos conexiones a Spotify y dos búsquedas de letra por canción.

## Recorrido de una canción

1. La fuente de reproducción emite un `PlaybackState` (canción, si suena,
   posición, marca de tiempo).
2. `PlaybackCoordinator` lo publica y se lo pasa a `LyricsController`.
3. Si cambió la canción, `LyricsController` pide la letra a
   `LyricsRepository`.
4. `LyricsRepository` mira la caché; si no está, recorre los proveedores en
   orden y guarda el resultado.
5. Con la letra en mano, `LyricsController` construye un `LyricsSynchronizer`
   y arranca un timer de 10 Hz.
6. En cada tick estima la posición actual y busca por bisección qué línea
   corresponde. **Sólo publica si la línea activa cambió.**
7. La UI del iPhone hace scroll a esa línea; CarPlay repinta su ventana de
   3 líneas, con un piso de 0,4 s entre repintados.

## Decisiones que vale la pena entender

### Interpolación de la posición

Ninguna fuente informa la posición de forma continua: la Web API se consulta
cada 1-8 s y el App Remote empuja sólo cuando algo cambia. Si mostráramos el
último valor recibido, la letra se quedaría clavada entre actualizaciones.

`PlaybackState.estimatedPosition(at:)` avanza el reloj localmente desde la
última medición, con tope en la duración del tema. Cada dato nuevo de la
fuente recalibra. Por eso la letra avanza suave aun con la Web API.

Se usa `ProcessInfo.systemUptime` y no `Date()`: es monotónico, así que un
ajuste de reloj del sistema no produce saltos.

### Por qué no se repinta a 10 Hz en CarPlay

El timer corre a 10 Hz porque necesitamos precisión para *decidir* cuándo
cambia la línea. Pero cada `updateSections` de CarPlay cruza IPC hasta la
pantalla del auto. Entonces:

- `LyricsController` sólo publica un estado nuevo si cambió `activeIndex`.
- `CarPlayLyricsBoard.identity` es una huella del contenido visible;
  `CarPlayCoordinator` compara antes de repintar.
- Además hay un piso de 0,4 s con coalescing de cambios en ráfaga.

En la práctica: ~1 repintado por línea de letra, no 10 por segundo.

### Degradación en cascada

`PlaybackCoordinator` elige la mejor fuente disponible (demo → App Remote →
Web API). Si la elegida falla de forma persistente, baja un escalón en vez
de dejar la pantalla vacía. Sólo degrada una vez: si la Web API también
falla, el problema es la red o la sesión, no la fuente.

### Caché con TTL asimétrico

Las letras encontradas se guardan 60 días; los "no encontrado", 3 días. La
base de LRCLIB es comunitaria y crece: una canción sin letra hoy puede
tenerla el mes que viene. Y un "no encontrado" causado por un error de red
**no se cachea nunca** — se distingue mirando si algún proveedor lanzó.

### Deduplicación de búsquedas

`LyricsRepository` guarda las búsquedas en vuelo por clave de canción. Al
cambiar de tema, iPhone y CarPlay piden la letra casi simultáneamente; sin
esto serían dos requests idénticos.

### Normalización de títulos

Spotify devuelve `"Bohemian Rhapsody - Remastered 2011"`. LRCLIB indexa
`"Bohemian Rhapsody"`. `Track.searchTitle` saca sufijos de edición y
paréntesis de colaboración, pero **sólo cuando reconoce ruido**: `"Stop -
Time"` y `"Everything (I Do) I Do It for You"` quedan intactos. Hay tests
para ambos lados.

En la búsqueda difusa se prefiere el candidato sincronizado y con duración
parecida, y se descarta el que difiera demasiado: mejor no mostrar letra que
mostrar la equivocada.

## Mapa de archivos

```
Sources/CarLyrics/
├── App/                    Arranque, escenas, contenedor de dependencias
│   ├── AppDelegate.swift          Ciclo de vida UIKit (CarPlay lo necesita)
│   ├── PhoneSceneDelegate.swift   Escena del iPhone, hospeda SwiftUI
│   ├── AppEnvironment.swift       Servicios compartidos (singleton)
│   ├── RootView.swift             Tabs
│   └── Theme.swift
├── CarPlay/
│   ├── CarPlaySceneDelegate.swift Entrada de la escena de CarPlay
│   ├── CarPlayCoordinator.swift   Observación + presupuesto de refresco
│   └── CarPlayLyricsBoard.swift   Armado de plantillas (puro, testeable)
├── Core/
│   ├── Models/             Track, PlaybackState, Lyrics
│   ├── Networking/         HTTPClient con sesión inyectable
│   ├── Spotify/            OAuth PKCE, tokens, fuentes de reproducción
│   ├── Lyrics/             Parser LRC, proveedores, repositorio, sincronía
│   ├── Storage/            Keychain, preferencias, caché en disco
│   ├── Donations/          Tip jar con StoreKit 2
│   └── Support/            Config, logging, textos
├── Features/               Pantallas SwiftUI
└── Resources/              Info.plist, entitlements, assets, traducciones
```

## Qué es testeable y qué no

Los tests cubren la lógica que no depende de UIKit ni de la red:

- `LRCParserTests` — formatos de LRC, incluidos los raros
- `LyricsSynchronizerTests` — mapeo posición → línea, offsets, bordes
- `TrackNormalizationTests` — limpieza de títulos y artistas
- `PlaybackStateTests` — interpolación del reloj
- `LRCLIBProviderTests` — con `StubHTTPSession`, sin red
- `LyricsRepositoryTests` — cascada, caché, deduplicación
- `LyricsCacheTests` — persistencia y TTL
- `CarPlayLyricsBoardTests` — qué se ve en el auto (lo más caro de probar a
  mano, por eso está aislado en un struct puro)
- `PKCETests` — incluye el vector del RFC 7636

Sin cubrir: las vistas SwiftUI y los delegates de escena. Para eso está el
modo demo (`CARLYRICS_SIMULATED_PLAYBACK=1`).
