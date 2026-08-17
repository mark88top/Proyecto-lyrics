# CarLyrics

Letras sincronizadas de lo que estés escuchando en Spotify, en el iPhone y
en CarPlay. Gratis, sin anuncios, sostenida por donaciones.

> **Antes de tocar la parte de CarPlay, leé
> [docs/CARPLAY-ENTITLEMENT.md](docs/CARPLAY-ENTITLEMENT.md).** Investigación
> de agosto de 2026: el entitlement de CarPlay ya no es el bloqueo. Desde
> iOS 26 se llega a la pantalla del auto con un widget y una Live Activity,
> sin pedirle permiso a nadie, y es lo que hacen todas las apps del rubro
> incluida Musixmatch. El código de CarPlay que hay hoy en el repo
> (`CPListTemplate` y compañía) apunta al camino cerrado y hay que
> reorientarlo. El bloqueo real ahora es la ejecución en segundo plano.

---

## Qué hace

- Detecta qué canción estás reproduciendo en Spotify, en cualquier
  dispositivo de tu cuenta.
- Busca la letra sincronizada y la muestra avanzando línea por línea.
- **En CarPlay**: tres líneas grandes (anterior, actual, siguiente), nada
  tocable, refresco limitado. Pensado para una mirada corta, no para leer.
- Funciona sin señal si la letra ya se descargó antes.
- Ajuste fino de sincronía, por si tu auto o tus auriculares meten latencia.
- Tip jar opcional. No desbloquea nada: la app es completa desde el minuto
  cero y va a seguir siéndolo.

## Estado

Código completo y listo para compilar. **No fue compilado todavía**: se
escribió en un entorno Linux y iOS sólo compila en macOS con Xcode. El
primer `make build` en una Mac puede sacar algún ajuste menor; los tests
están escritos para verificar la lógica apenas puedas correrlos.

## Arranque rápido

Necesitás una Mac con Xcode 15 o superior.

```bash
git clone <este-repo>
cd Proyecto-lyrics
make bootstrap        # instala XcodeGen, crea Secrets.xcconfig, genera el proyecto
```

Después:

1. Editá `Configuration/Secrets.xcconfig` con tu **Team ID** y tu
   **Spotify Client ID** ([cómo obtenerlo](docs/SPOTIFY-SETUP.md)).
2. En el dashboard de Spotify, cargá `carlyrics://callback` como Redirect URI.
3. `make open`

```bash
make test     # tests unitarios
make build    # compila para el simulador
make help     # todos los comandos
```

### Probar sin cuenta de Spotify

El scheme trae la variable `CARLYRICS_SIMULATED_PLAYBACK=1`. Poniéndola en
`1` la app reproduce una canción de ejemplo y podés ver toda la UI —
incluida la de CarPlay — sin cuenta ni auto.

### Probar CarPlay

Simulador de iOS → menú **I/O → External Displays → CarPlay**. Requiere
descomentar el entitlement en `Sources/CarLyrics/Resources/CarLyrics.entitlements`
(en el simulador no se valida la firma). Volvé a comentarlo antes de subir a
App Store Connect.

## Cómo funciona

```
Spotify ──▶ PlaybackCoordinator ──▶ LyricsController ──┬──▶ SwiftUI (iPhone)
                    ▲                      │           └──▶ CarPlay
                    │                      ▼
              (App Remote o          LyricsRepository ──▶ LRCLIB
               Web API)              (caché + proveedores)
```

Una sola fuente de verdad para las dos pantallas. El detalle completo, con
las decisiones de diseño y por qué, está en
[docs/ARCHITECTURE.md](docs/ARCHITECTURE.md).

Dos piezas que vale la pena mirar si venís a tocar el código:

- **`PlaybackState.estimatedPosition(at:)`** — ninguna fuente informa la
  posición de forma continua, así que se interpola localmente y se recalibra
  con cada dato nuevo. Es lo que hace que la letra avance suave incluso con
  el polling de la Web API.
- **`CarPlayLyricsBoard.identity`** — huella del contenido visible. El
  coordinador la compara antes de repintar, así CarPlay recibe ~1
  actualización por línea de letra y no 10 por segundo.

## Documentación

| Documento | De qué trata |
|---|---|
| [CARPLAY-ENTITLEMENT.md](docs/CARPLAY-ENTITLEMENT.md) | **Leer primero.** El riesgo principal y el plan de fases |
| [SPOTIFY-SETUP.md](docs/SPOTIFY-SETUP.md) | Crear la app de Spotify, permisos, modo extendido |
| [APP-STORE-REVIEW.md](docs/APP-STORE-REVIEW.md) | Checklist ordenado por riesgo de rechazo |
| [DONATIONS.md](docs/DONATIONS.md) | Reglas de Apple sobre donaciones y cómo está implementado |
| [LEGAL.md](docs/LEGAL.md) | Derechos sobre las letras: escenarios y mitigaciones |
| [ARCHITECTURE.md](docs/ARCHITECTURE.md) | Diseño interno y decisiones |
| [PRIVACY.md](docs/PRIVACY.md) | Política de privacidad (publicar en una URL) |

## Camino a la publicación

1. **Primero que nada** — prototipo de ejecución en segundo plano: una Live
   Activity que se actualice cada pocos segundos con la app fuera de
   pantalla, sin declarar modos de audio falsos. Es el único punto que puede
   matar la parte del auto; conviene saberlo antes de escribir más código.
2. **Ahora** — configurar Spotify, compilar, probar en el iPhone.
3. **Semana 1** — pedir *Extended Quota Mode* en el dashboard de Spotify
   (tarda, conviene arrancarlo ya).
4. **Semana 1** — ícono de 1024×1024, capturas, política de privacidad
   publicada.
5. **Semana 2** — crear los tres IAP de propina en App Store Connect.
6. **Semana 2** — subir el build de teléfono y enviar a revisión. No depende
   de ninguna aprobación especial.
7. **Después** — sumar el widget y la Live Activity para el auto, en la misma
   base de código y sin trámite con Apple.

El checklist detallado está en [APP-STORE-REVIEW.md](docs/APP-STORE-REVIEW.md).

## Stack

- Swift 5.9, iOS 16+
- SwiftUI para el iPhone, framework `CarPlay` (plantillas) para el auto
- Ciclo de vida UIKit (`AppDelegate` + escenas), porque CarPlay lo requiere
- Spotify Web API + Spotify iOS SDK opcional
- [LRCLIB](https://lrclib.net) como fuente de letras
- StoreKit 2 para las propinas
- XcodeGen: el `.xcodeproj` se genera desde `project.yml` y no se versiona
  (menos conflictos de merge)

## Licencia

MIT para el código. Las letras son obra de terceros: ver
[docs/LEGAL.md](docs/LEGAL.md).

CarLyrics no está afiliada a Spotify AB ni a Apple Inc.
