# Configurar Spotify

## 1. Crear la app en el dashboard

1. Entrá a <https://developer.spotify.com/dashboard> con tu cuenta.
2. **Create app**.
   - *App name*: CarLyrics
   - *Redirect URI*: `carlyrics://callback` — tiene que coincidir **exacto**
     con `SPOTIFY_REDIRECT_SCHEME` de `Configuration/Secrets.xcconfig`.
   - *Which API/SDKs are you planning to use?*: marcá **iOS** y **Web API**.
3. Copiá el **Client ID**.

No necesitás el Client Secret: usamos Authorization Code + PKCE, que está
diseñado para apps móviles justamente porque no pueden guardar un secreto.

## 2. Configurar el proyecto

```bash
cp Configuration/Secrets.example.xcconfig Configuration/Secrets.xcconfig
```

Editá el archivo:

```
DEVELOPMENT_TEAM = TU_TEAM_ID
APP_BUNDLE_ID    = com.tudominio.carlyrics
SPOTIFY_CLIENT_ID = el_client_id_que_copiaste
```

`Secrets.xcconfig` está en `.gitignore`. No lo commitees.

## 3. Modo de desarrollo y usuarios de prueba

Una app nueva de Spotify arranca en **Development mode**: sólo funciona con
las cuentas que cargues a mano.

Dashboard → tu app → **Settings → User Management** → agregá el mail de cada
cuenta de prueba (hasta 25).

Para publicar en la App Store necesitás pedir **Extended Quota Mode** en el
dashboard, si no cualquier usuario que baje la app recibe un error de
autorización. Ese trámite tarda; conviene arrancarlo temprano.

## 4. Las dos fuentes de reproducción

La app tiene dos formas de saber qué está sonando, y elige sola:

### Web API (por defecto, siempre disponible)

`GET /v1/me/player` por polling adaptativo: 1 s justo después de un cambio
de tema, 2 s reproduciendo, 8 s en reposo, con backoff exponencial ante
errores.

- Ventaja: funciona aunque Spotify suene en otro dispositivo (parlante,
  notebook) y no requiere tener la app de Spotify instalada.
- Desventaja: hasta ~2 s de latencia al detectar cambios. La posición de
  reproducción se interpola localmente entre sondeos (`estimatedPosition`),
  así que la letra igual avanza suave; lo que se nota es al saltar de tema.

### App Remote (SDK nativo, opcional)

Spotify empuja los cambios en el momento (~50 ms). Es notablemente mejor.

Para activarlo:

1. Descomentá el bloque `packages:` y la entrada `dependencies:` del target
   en `project.yml`.
2. `make generate`.

`SpotifyAppRemoteSource.swift` está entero dentro de `#if canImport(SpotifyiOS)`,
así que sin el paquete el proyecto compila igual y usa la Web API.

Requiere que el usuario tenga la app de Spotify instalada y **Premium**.
Si el App Remote falla o se desconecta, `PlaybackCoordinator` degrada solo a
la Web API.

## 5. Permisos que pedimos

```
user-read-playback-state      qué está sonando y en qué segundo
user-read-currently-playing   ídem
app-remote-control            necesario para el SDK nativo
```

Nada de escritura. La app no puede cambiar tu música ni ver tus playlists
privadas, y así está dicho en la pantalla de privacidad.

## 6. Términos de Spotify: verificar antes de publicar

Los Spotify Developer Terms y la Developer Policy tienen restricciones sobre
qué se puede hacer con los metadatos y sobre sincronizar contenido de
Spotify con medios visuales. **Antes de publicar, leé la versión vigente** de:

- <https://developer.spotify.com/terms>
- <https://developer.spotify.com/policy>

Prestá atención específicamente a: uso de metadatos fuera del contexto de
reproducción, requisitos de atribución a Spotify, y cualquier cláusula sobre
sincronización con contenido visual. Si algo no queda claro, se puede
consultar por el formulario de contacto para desarrolladores. Es mucho más
barato preguntar antes que tener la app publicada y recibir un reclamo.
