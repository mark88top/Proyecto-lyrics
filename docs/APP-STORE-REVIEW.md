# Checklist de App Review

Ordenado por probabilidad de causar rechazo.

## Riesgos altos

### 1. Modos de fondo declarados y no usados (guía 2.5.4)
Ver [CARPLAY-ENTITLEMENT.md](CARPLAY-ENTITLEMENT.md), sección "El problema
que sí queda". Declarar `UIBackgroundModes: audio` sin reproducir audio se
rechaza. Ya está fuera del Info.plist; si en algún momento se vuelve a
agregar para mantener viva la app, tiene que haber audio real detrás.

Nota: el **entitlement de CarPlay ya no es un riesgo**, porque no lo vamos a
pedir. El camino es widget + Live Activity, que no requiere aprobación.

### 2. Derechos sobre las letras (guía 5.2 — Propiedad intelectual)
Ver [LEGAL.md](LEGAL.md). Es el otro riesgo estructural. Apple puede pedir
que documentes qué derecho tenés a mostrar las letras.

### 3. Donaciones (guías 3.2.1 / 3.2.2)
Ver [DONATIONS.md](DONATIONS.md). Resumen: si la propina va a un
desarrollador, **tiene que ser compra in-app**. Linkear a PayPal, Ko-fi o
Mercado Pago desde la app es rechazo directo. La excepción de pago externo
es sólo para organizaciones sin fines de lucro registradas.

## Riesgos medios

### 4. "Login con servicio de terceros" (guía 4.0 / 5.1.1)
La app pide login de Spotify apenas abre. Dos cosas ayudan:

- El onboarding tiene un botón para **saltear** el login. Una app que no
  deja hacer nada sin cuenta se rechaza seguido.
- Los permisos que pedimos son de sólo lectura y están explicados en
  pantalla antes de pedirlos.

### 5. Funcionalidad mínima (guía 4.2)
Una app que "sólo muestra texto" puede leerse como demasiado simple. A favor
juegan: la sincronización línea a línea, el ajuste fino de sincronía, la
caché sin conexión y la integración con CarPlay.

Nota para el revisor sugerida:

> CarLyrics muestra, sincronizada al segundo, la letra de la canción que el
> usuario está reproduciendo en Spotify. Requiere una cuenta de Spotify
> (Premium para la integración nativa). Se adjuntan credenciales de prueba.

### 6. Cuenta de prueba para el revisor
**Obligatorio.** El revisor no puede evaluar la app sin una cuenta de
Spotify que ya esté cargada en el modo desarrollo de tu app de Spotify.

En App Store Connect → *App Review Information*:
- Usuario y contraseña de una cuenta de Spotify Premium de prueba.
- En las notas: *"Abrir Spotify, reproducir una canción, volver a CarLyrics."*
- Si CarPlay está incluido: instrucciones para el simulador de CarPlay.

Y en el dashboard de Spotify, agregá el mail de esa cuenta en *User
Management*, o el login del revisor va a fallar.

### 7. Modo demo para el revisor
El scheme trae `CARLYRICS_SIMULATED_PLAYBACK=1`, que muestra la app
funcionando con una canción de ejemplo sin necesidad de cuenta. Si el
revisor tiene problemas con Spotify, sirve de red de contención — mencionalo
en las notas de revisión.

## Riesgos bajos, pero revisables

### 8. Privacidad
- **Privacy Nutrition Label**: seleccioná *Data Not Collected*. Es cierto:
  no hay analítica, no hay backend propio, el token vive en el Llavero.
- **URL de política de privacidad**: obligatoria. Publicá el texto de
  `PrivacyScreen.swift` en una página web (GitHub Pages sirve).
- No usamos IDFA, así que no hace falta App Tracking Transparency.

### 9. Seguridad al volante
La app avisa explícitamente en el onboarding que no hay que leer la pantalla
manejando. En CarPlay ningún elemento es tocable y el texto se limita a
3 líneas. Documentalo en las notas de revisión: es exactamente lo que el
revisor de CarPlay va a buscar.

### 10. Metadatos de la ficha
- No pongas "Spotify" en el **nombre** de la app (uso de marca ajena).
- En la descripción: *"Funciona con Spotify"*, no *"Spotify Lyrics"*.
- Nada de capturas con el logo de Spotify como elemento principal.
- Si nombrás a Spotify, agregá la aclaración de que no hay afiliación.

### 11. Exportación / criptografía
`ITSAppUsesNonExemptEncryption = false` ya está en el Info.plist. Sólo usamos
HTTPS estándar, así que aplica la exención.

## Antes de subir el build

- [ ] `Secrets.xcconfig` con el Team ID y el Client ID reales
- [ ] Entitlement de CarPlay comentado (salvo que ya te lo hayan aprobado)
- [ ] `MARKETING_VERSION` y `CURRENT_PROJECT_VERSION` actualizados
- [ ] Ícono de app de 1024×1024 en el asset catalog (hoy está vacío)
- [ ] Los 3 productos de propina creados en App Store Connect con los IDs de
      `TipProduct.identifiers`, y **enviados a revisión junto con el build**
- [ ] Capturas para 6,7" y 6,5"
- [ ] Cuenta de prueba de Spotify cargada en ambos lados
- [ ] URL de política de privacidad publicada y accesible
- [ ] `make test` en verde
