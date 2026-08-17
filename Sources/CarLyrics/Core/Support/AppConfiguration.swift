import Foundation

/// Configuración inyectada desde los `.xcconfig` a través del Info.plist.
///
/// Nada de esto es secreto: el flujo de Spotify es Authorization Code + PKCE,
/// que está diseñado para clientes públicos y no usa client secret.
struct AppConfiguration {
    let spotifyClientID: String
    let spotifyRedirectURI: URL
    let lyricsAPIBaseURL: URL

    static let current: AppConfiguration = .fromBundle(.main)

    static func fromBundle(_ bundle: Bundle) -> AppConfiguration {
        func string(_ key: String) -> String {
            (bundle.object(forInfoDictionaryKey: key) as? String)?
                .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        }

        let redirect = URL(string: string("CLSpotifyRedirectURI")) ?? URL(string: "carlyrics://callback")!
        let lyricsBase = URL(string: string("CLLyricsAPIBaseURL")) ?? URL(string: "https://lrclib.net")!

        return AppConfiguration(
            spotifyClientID: string("CLSpotifyClientID"),
            spotifyRedirectURI: redirect,
            lyricsAPIBaseURL: lyricsBase
        )
    }

    /// `true` cuando falta el Client ID, es decir, el proyecto no fue
    /// configurado todavía. La UI lo usa para mostrar instrucciones en vez
    /// de fallar con un error críptico de OAuth.
    var isSpotifyConfigured: Bool { !spotifyClientID.isEmpty }

    var userAgent: String {
        let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "1.0"
        return "CarLyrics/\(version) (https://github.com/mark88top/proyecto-lyrics)"
    }
}
