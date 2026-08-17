# Letras y derechos: qué hay que saber

Esta sección no es asesoramiento legal. Es el mapa del terreno para que
sepas qué estás decidiendo.

## El punto de fondo

Las letras de canciones son obras protegidas. Los derechos pertenecen a los
autores y sus editoriales (Sony Music Publishing, UMPG, Warner Chappell,
etc.), y son **distintos** de los derechos sobre la grabación.

Las apps grandes que muestran letras (Spotify, Apple Music, Musixmatch)
pagan licencias por eso. Musixmatch, de hecho, existe en buena medida como
intermediario licenciado entre esas editoriales y las apps.

## De dónde saca CarLyrics las letras

De **LRCLIB** (<https://lrclib.net>): una base comunitaria, gratuita, sin
API key, donde usuarios suben letras sincronizadas. Es lo que hace viable el
modelo gratis: no hay costo por consulta.

Lo que LRCLIB no puede darte es una licencia sobre las letras. Es un
repositorio comunitario, no un licenciatario.

## Los escenarios reales

**Escenario A — no pasa nada.** Es lo más probable a escala chica. Hay
muchas apps de letras basadas en fuentes comunitarias en la App Store.

**Escenario B — Apple pide documentación.** Bajo la guía 5.2, App Review
puede pedirte que acredites tu derecho a usar contenido de terceros. Suele
pasar cuando la app crece o alguien reporta.

**Escenario C — reclamo de una editorial.** Un DMCA takedown, o directamente
a Apple. Poco frecuente para apps chicas, pero es el riesgo real.

## Qué reduce el riesgo (ya implementado)

1. **Atribución visible.** La app siempre muestra de dónde vino la letra
   (`LyricsSnapshot.sourceName`), en el teléfono y en CarPlay. No presentamos
   las letras como propias.
2. **Sin redistribución.** No tenemos servidor, no republicamos letras, no
   armamos una base propia. Cada dispositivo consulta y cachea localmente
   para su usuario.
3. **Sin monetizar la letra.** La app es gratis. Las propinas son por el
   software, y explícitamente no desbloquean nada. La diferencia importa: no
   estamos vendiendo acceso a letras.
4. **Arquitectura preparada para cambiar de fuente.** `LyricsProvider` es un
   protocolo; migrar a un proveedor licenciado (Musixmatch, por ejemplo)
   significa agregar una clase, no reescribir la app.

## Qué hacer si el proyecto crece

- Evaluar la **API de Musixmatch**, que tiene plan gratuito para desarrollo
  y planes comerciales con licencia incluida. Es el camino a un modelo con
  respaldo legal.
- Tener un canal de contacto visible para reclamos y un procedimiento de
  takedown. Responder rápido a un reclamo evita casi siempre que escale.
- Si en algún momento hay ingresos relevantes, hablar con alguien que sepa
  del tema antes de seguir creciendo.

## Marcas

- **Spotify** es marca registrada de Spotify AB. CarLyrics no está afiliada
  ni respaldada por Spotify. No uses el nombre ni el logo en el nombre de la
  app, el ícono ni las capturas principales.
- **CarPlay** es marca registrada de Apple Inc.

En la ficha de la App Store, la fórmula segura es *"Funciona con Spotify"*,
más una línea aclarando que no hay afiliación.
