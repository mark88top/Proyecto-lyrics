# CarLyrics

Letras sincronizadas de lo que estés escuchando en Spotify, en el iPhone y
en CarPlay.

> ### Estado: archivado, no publicado
>
> El código funciona y corre en el simulador y en el teléfono. **No va a
> publicarse en la App Store**, y la decisión fue de negocio, no técnica.
>
> El motivo está en **[docs/CONCLUSIONES.md](docs/CONCLUSIONES.md)**, que es
> lo más valioso que dejó el proyecto: la investigación de mercado y de
> plataforma. Resumen en tres líneas — la App Store no tiene descubrimiento
> para CarPlay, así que la integración es una función y no un canal; en estas
> categorías gana quien tiene el dato, y el nuestro (LRCLIB) no está
> licenciado; y "gratis" no es un diferencial defendible contra Musixmatch a
> USD 3 por mes con licencias en regla.
>
> Queda como pieza de portfolio y como base reusable para cualquier cosa que
> toque reproducción de música en iOS.

---

## Qué hace

- Detecta qué canción estás reproduciendo en Spotify, en cualquier
  dispositivo de tu cuenta.
- Busca la letra sincronizada y la muestra avanzando línea por línea.
- Funciona sin señal si la letra ya se descargó antes.
- Ajuste fino de sincronía, por si tu auto o tus auriculares meten latencia.
- En CarPlay: tres líneas grandes (anterior, actual, siguiente), nada
  tocable, refresco acotado.

## Correrlo

Necesitás una Mac con Xcode 15 o superior. El `.xcodeproj` no está
versionado: se genera con XcodeGen desde `project.yml`.

```bash
git clone https://github.com/mark88top/Proyecto-lyrics.git
cd Proyecto-lyrics
make bootstrap        # instala XcodeGen, crea Secrets.xcconfig, genera el proyecto
make open
```

Para conectar tu cuenta, editá `Configuration/Secrets.xcconfig` con tu Team
ID y tu Client ID de Spotify — ver [docs/SPOTIFY-SETUP.md](docs/SPOTIFY-SETUP.md).
En el dashboard de Spotify cargá `carlyrics://callback` como Redirect URI.

**Sin cuenta de Spotify:** poné la variable de entorno
`CARLYRICS_SIMULATED_PLAYBACK` en `1` (está en el scheme) y la app corre con
una canción de ejemplo. Alcanza para ver toda la UI, incluida la de CarPlay.

**CarPlay en el simulador:** menú **I/O → External Displays → CarPlay**. El
entitlement `com.apple.developer.carplay-audio` está habilitado en
`CarLyrics.entitlements` porque el simulador no lo valida contra Apple. Para
un build real haría falta que Apple lo apruebe, cosa que no va a pasar — ver
[docs/CARPLAY-ENTITLEMENT.md](docs/CARPLAY-ENTITLEMENT.md).

```bash
make test     # 10 suites de tests unitarios
make build    # compila para el simulador
make help     # todos los comandos
```

## Cómo funciona

```
Spotify ──▶ PlaybackCoordinator ──▶ LyricsController ──┬──▶ SwiftUI (iPhone)
                    ▲                      │           └──▶ CarPlay
                    │                      ▼
              (App Remote o          LyricsRepository ──▶ LRCLIB
               Web API)              (caché + proveedores)
```

Una sola fuente de verdad para las dos pantallas. El detalle está en
[docs/ARCHITECTURE.md](docs/ARCHITECTURE.md).

Dos piezas que vale la pena mirar si venís a reusar algo:

- **`PlaybackState.estimatedPosition(at:)`** — ninguna fuente informa la
  posición de forma continua, así que se interpola localmente y se recalibra
  con cada dato nuevo. Es lo que hace que la letra avance suave incluso con
  el polling de la Web API.
- **`CarPlayLyricsBoard.identity`** — huella del contenido visible. El
  coordinador la compara antes de repintar, así CarPlay recibe una
  actualización por línea de letra y no diez por segundo.

## Documentación

| Documento | De qué trata |
|---|---|
| [CONCLUSIONES.md](docs/CONCLUSIONES.md) | **Por qué no se publica.** La investigación de mercado y plataforma |
| [ARCHITECTURE.md](docs/ARCHITECTURE.md) | Diseño interno y las decisiones detrás |
| [CARPLAY-ENTITLEMENT.md](docs/CARPLAY-ENTITLEMENT.md) | Cómo se llega a la pantalla del auto, y el problema de segundo plano sin resolver |
| [SPOTIFY-SETUP.md](docs/SPOTIFY-SETUP.md) | Crear la app de Spotify, permisos, modo extendido |
| [LEGAL.md](docs/LEGAL.md) | Derechos sobre las letras: escenarios y mitigaciones |
| [APP-STORE-REVIEW.md](docs/APP-STORE-REVIEW.md) | Checklist de publicación — camino no tomado, queda como referencia |
| [DONATIONS.md](docs/DONATIONS.md) | Reglas de Apple sobre donaciones — ídem |
| [PRIVACY.md](docs/PRIVACY.md) | Política de privacidad — ídem |

## Si alguien retoma esto

Hay un problema técnico sin resolver que es lo primero a atacar: **cómo
actualizar una Live Activity línea por línea con la app en segundo plano**,
sin servidor propio y sin declarar un modo de audio que la app no usa
(rechazo seguro por la guía 2.5.4). Está desarrollado al final de
[CARPLAY-ENTITLEMENT.md](docs/CARPLAY-ENTITLEMENT.md).

Todo lo que no toca CarPlay — Spotify, sincronía, caché, parser de LRC — es
independiente y reusable tal cual.

## Stack

- Swift 5.9, iOS 16+
- SwiftUI para el iPhone, framework `CarPlay` (plantillas) para el auto
- Ciclo de vida UIKit (`AppDelegate` + escenas), porque CarPlay lo requiere
- Spotify Web API + Spotify iOS SDK opcional
- [LRCLIB](https://lrclib.net) como fuente de letras
- StoreKit 2 para las propinas
- XcodeGen: el `.xcodeproj` se genera desde `project.yml` y no se versiona

## Licencia

MIT para el código. Las letras son obra de terceros: ver
[docs/LEGAL.md](docs/LEGAL.md).

CarLyrics no está afiliada a Spotify AB ni a Apple Inc.
