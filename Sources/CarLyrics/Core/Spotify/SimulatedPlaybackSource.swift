import Foundation

/// Reproductor falso para el simulador, para desarrollar la UI de CarPlay
/// sin auto ni cuenta de Spotify, y para los tests.
///
/// Se activa con la variable de entorno `CARLYRICS_SIMULATED_PLAYBACK=1`
/// (ya está en el scheme) o desde Ajustes en builds Debug.
@MainActor
final class SimulatedPlaybackSource: PlaybackSource {
    let displayName = "Modo demo"

    var onStateChange: ((PlaybackState) -> Void)?
    var onConnectionChange: ((PlaybackConnectionState) -> Void)?

    private let track: Track
    private var timer: Timer?
    private var startedAt: TimeInterval = 0

    init(track: Track = SimulatedPlaybackSource.demoTrack) {
        self.track = track
    }

    static let demoTrack = Track(
        id: "demo:track:1",
        title: "Bohemian Rhapsody",
        artist: "Queen",
        album: "A Night at the Opera",
        duration: 354,
        artworkURL: nil
    )

    func start() async {
        startedAt = ProcessInfo.processInfo.systemUptime
        onConnectionChange?(.connected(sourceName: displayName))
        emit()

        let timer = Timer(timeInterval: 1, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.emit() }
        }
        RunLoop.main.add(timer, forMode: .common)
        self.timer = timer
    }

    func stop() {
        timer?.invalidate()
        timer = nil
        onConnectionChange?(.disconnected)
    }

    func refresh() async { emit() }

    private func emit() {
        let now = ProcessInfo.processInfo.systemUptime
        let position = (now - startedAt).truncatingRemainder(dividingBy: track.duration)
        onStateChange?(PlaybackState(
            track: track,
            isPlaying: true,
            position: position,
            timestamp: now
        ))
    }
}
