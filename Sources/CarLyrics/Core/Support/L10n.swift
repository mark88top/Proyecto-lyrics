import Foundation

/// Todas las cadenas visibles en un solo lugar, para que traducir sea
/// agregar un `.lproj` y nada más.
enum L10n {
    private static func t(_ key: String, _ fallback: String) -> String {
        NSLocalizedString(key, value: fallback, comment: "")
    }

    // Generales
    static var appName: String { t("app.name", "CarLyrics") }
    static var tabLyrics: String { t("tab.lyrics", "Letra") }
    static var tabSettings: String { t("tab.settings", "Ajustes") }
    static var tabSupport: String { t("tab.support", "Apoyar") }
    static var retry: String { t("action.retry", "Reintentar") }
    static var close: String { t("action.close", "Cerrar") }
    static var done: String { t("action.done", "Listo") }

    // Onboarding
    static var onboardingTitle: String { t("onboarding.title", "La letra de lo que estás escuchando") }
    static var onboardingSubtitle: String { t("onboarding.subtitle", "Gratis, sin anuncios, sin cuenta propia. Sostenida por donaciones.") }
    static var onboardingStepSpotify: String { t("onboarding.step.spotify", "Conectá tu cuenta de Spotify") }
    static var onboardingStepSpotifyDetail: String { t("onboarding.step.spotify.detail", "Sólo pedimos permiso de lectura para saber qué canción suena. No podemos cambiar tu música ni ver tus playlists privadas.") }
    static var onboardingStepCarPlay: String { t("onboarding.step.carplay", "Enchufá el teléfono al auto") }
    static var onboardingStepCarPlayDetail: String { t("onboarding.step.carplay.detail", "Si tu auto tiene CarPlay, CarLyrics aparece como una app más. La letra se muestra en pocas líneas grandes, pensadas para una mirada corta.") }
    static var onboardingStepSafety: String { t("onboarding.step.safety", "Primero, manejar") }
    static var onboardingStepSafetyDetail: String { t("onboarding.step.safety.detail", "No leas la pantalla mientras conducís. Si vas manejando, mirá la ruta: la letra puede esperar.") }
    static var onboardingContinue: String { t("onboarding.continue", "Continuar") }
    static var onboardingConnect: String { t("onboarding.connect", "Conectar con Spotify") }

    // Now playing
    static var nowPlayingNothing: String { t("nowplaying.nothing", "No hay nada sonando") }
    static var nowPlayingNothingDetail: String { t("nowplaying.nothing.detail", "Poné una canción en Spotify y volvé acá.") }
    static var nowPlayingOpenSpotify: String { t("nowplaying.openSpotify", "Abrir Spotify") }
    static var lyricsSearching: String { t("lyrics.searching", "Buscando la letra…") }
    static var lyricsNotFound: String { t("lyrics.notFound", "No encontramos la letra de este tema") }
    static var lyricsNotFoundDetail: String { t("lyrics.notFound.detail", "La base de letras es comunitaria y va creciendo. Probá de nuevo más adelante.") }
    static var lyricsInstrumental: String { t("lyrics.instrumental", "Instrumental") }
    static var lyricsInstrumentalDetail: String { t("lyrics.instrumental.detail", "Este tema no tiene letra.") }
    static var lyricsUnsynced: String { t("lyrics.unsynced", "Letra sin sincronizar") }
    static func lyricsSource(_ name: String) -> String {
        String(format: t("lyrics.source", "Letra de %@"), name)
    }

    // Errores
    static var errorOffline: String { t("error.offline", "Sin conexión. Reintentamos cuando vuelva.") }
    static var errorRateLimited: String { t("error.rateLimited", "Demasiadas consultas seguidas. Esperá unos segundos.") }
    static var errorGeneric: String { t("error.generic", "Algo salió mal buscando la letra.") }
    static var errorNotConfigured: String { t("error.notConfigured", "Falta configurar el Client ID de Spotify.") }
    static var errorLoginCancelled: String { t("error.login.cancelled", "Cancelaste el inicio de sesión.") }
    static var errorLoginInvalid: String { t("error.login.invalid", "La respuesta de Spotify no fue válida.") }
    static var errorNeedsLogin: String { t("error.needsLogin", "Conectá tu cuenta de Spotify para empezar.") }
    static var errorSpotifyUnreachable: String { t("error.spotifyUnreachable", "No podemos hablar con Spotify ahora mismo.") }
    static var errorSpotifyNotRunning: String { t("error.spotifyNotRunning", "Abrí Spotify y poné play para conectar.") }

    // Ajustes
    static var settingsTitle: String { t("settings.title", "Ajustes") }
    static var settingsAccount: String { t("settings.account", "Cuenta") }
    static var settingsConnected: String { t("settings.connected", "Spotify conectado") }
    static var settingsDisconnect: String { t("settings.disconnect", "Desconectar") }
    static var settingsConnect: String { t("settings.connect", "Conectar con Spotify") }
    static var settingsSync: String { t("settings.sync", "Sincronía") }
    static var settingsOffset: String { t("settings.offset", "Ajuste fino") }
    static var settingsOffsetDetail: String { t("settings.offset.detail", "Si la letra va adelantada, movelo a la derecha. Si va atrasada, a la izquierda.") }
    static var settingsDisplay: String { t("settings.display", "Pantalla") }
    static var settingsFontSize: String { t("settings.fontSize", "Tamaño del texto") }
    static var settingsCarPlay: String { t("settings.carplay", "CarPlay") }
    static var settingsCarPlayLines: String { t("settings.carplay.lines", "Líneas visibles") }
    static var settingsCarPlayLinesDetail: String { t("settings.carplay.lines.detail", "Menos líneas es menos texto para leer al volante. Recomendamos 3.") }
    static var settingsKeepAwake: String { t("settings.keepAwake", "Mantener pantalla encendida") }
    static var settingsData: String { t("settings.data", "Datos") }
    static var settingsClearCache: String { t("settings.clearCache", "Borrar letras guardadas") }
    static func settingsCacheSize(_ size: String) -> String {
        String(format: t("settings.cacheSize", "Ocupan %@"), size)
    }
    static var settingsAbout: String { t("settings.about", "Acerca de") }
    static var settingsPrivacy: String { t("settings.privacy", "Privacidad") }
    static var settingsVersion: String { t("settings.version", "Versión") }

    // Donaciones
    static var tipsTitle: String { t("tips.title", "Apoyá el proyecto") }
    static var tipsHeadline: String { t("tips.headline", "CarLyrics es gratis y va a seguir siéndolo") }
    static var tipsBody: String { t("tips.body", "No hay anuncios, no hay funciones pagas, no vendemos datos. Si te resulta útil y querés que siga creciendo, podés dejar una propina. Es totalmente opcional: nada de la app se desbloquea al donar.") }
    static var tipsUnavailable: String { t("tips.unavailable", "Las propinas no están disponibles en este momento.") }
    static var tipsThankYou: String { t("tips.thankYou", "¡Gracias! De verdad.") }
    static var tipsAlreadyTipped: String { t("tips.alreadyTipped", "Ya nos invitaste algo. Gracias 💚") }

    // CarPlay
    static var carPlayTabLyrics: String { t("carplay.tab.lyrics", "Letra") }
    static var carPlayTabNowPlaying: String { t("carplay.tab.nowPlaying", "Reproduciendo") }
    static var carPlayNoLyrics: String { t("carplay.noLyrics", "Sin letra disponible") }
    static var carPlayConnect: String { t("carplay.connect", "Abrí CarLyrics en el teléfono para conectar Spotify") }
    static var carPlaySafetyNotice: String { t("carplay.safetyNotice", "No leas mientras manejás") }
}
