import Foundation

/// Instantánea del reproductor. `position` es el valor reportado por la
/// fuente en `timestamp`; para saber dónde va la canción *ahora* hay que
/// interpolar (ver `PlaybackClock`).
struct PlaybackState: Equatable {
    var track: Track?
    var isPlaying: Bool
    /// Posición reportada, en segundos desde el inicio del tema.
    var position: TimeInterval
    /// Momento monotónico en el que se recibió `position`.
    var timestamp: TimeInterval

    static let idle = PlaybackState(track: nil, isPlaying: false, position: 0, timestamp: 0)

    /// Posición estimada en `now`, avanzando el reloj si está reproduciendo.
    func estimatedPosition(at now: TimeInterval) -> TimeInterval {
        guard isPlaying else { return position }
        let elapsed = max(0, now - timestamp)
        let estimated = position + elapsed
        guard let duration = track?.duration, duration > 0 else { return estimated }
        return min(estimated, duration)
    }
}

/// Estado del vínculo con Spotify, para que la UI sepa qué mostrar.
enum PlaybackConnectionState: Equatable {
    case disconnected
    case connecting
    case connected(sourceName: String)
    case failed(message: String)

    var isConnected: Bool {
        if case .connected = self { return true }
        return false
    }
}
