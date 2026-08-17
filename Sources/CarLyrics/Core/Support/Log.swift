import Foundation
import os

/// Logging centralizado. Usamos `OSLog` para que quede en el sistema sin
/// costo en release y sin filtrar datos del usuario (todo interpolado es
/// `public` sólo cuando no identifica a nadie).
enum Log {
    private static let subsystem = Bundle.main.bundleIdentifier ?? "com.carlyrics.app"

    static let playback = Logger(subsystem: subsystem, category: "playback")
    static let lyrics = Logger(subsystem: subsystem, category: "lyrics")
    static let carplay = Logger(subsystem: subsystem, category: "carplay")
    static let auth = Logger(subsystem: subsystem, category: "auth")
    static let network = Logger(subsystem: subsystem, category: "network")
    static let store = Logger(subsystem: subsystem, category: "store")
}
