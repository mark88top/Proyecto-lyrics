import Foundation
import Combine
import UIKit

/// Elige la mejor fuente disponible y publica un único estado de
/// reproducción para toda la app (iPhone + CarPlay).
///
/// Orden de preferencia:
///   1. Modo demo, si está forzado por entorno.
///   2. App Remote (SDK nativo), si está enlazado y Spotify instalado.
///   3. Web API por polling.
///
/// Si la fuente elegida falla de forma persistente, degrada a la siguiente
/// en vez de dejar la pantalla vacía.
@MainActor
final class PlaybackCoordinator: ObservableObject {
    @Published private(set) var state: PlaybackState = .idle
    @Published private(set) var connection: PlaybackConnectionState = .disconnected

    private let auth: SpotifyAuthManager
    private var source: PlaybackSource?
    private var usedFallback = false
    private var observers: [NSObjectProtocol] = []

    /// Se dispara con cada estado nuevo. `LyricsController` se engancha acá.
    var onPlaybackUpdate: ((PlaybackState) -> Void)?

    init(auth: SpotifyAuthManager) {
        self.auth = auth
        observeAppLifecycle()
    }

    deinit {
        observers.forEach { NotificationCenter.default.removeObserver($0) }
    }

    func start() async {
        guard source == nil else {
            await source?.refresh()
            return
        }
        usedFallback = false
        await attach(makePrimarySource())
    }

    func stop() {
        source?.stop()
        source = nil
        connection = .disconnected
    }

    func restart() async {
        stop()
        await start()
    }

    // MARK: - Interno

    private func makePrimarySource() -> PlaybackSource {
        if ProcessInfo.processInfo.environment["CARLYRICS_SIMULATED_PLAYBACK"] == "1" {
            return SimulatedPlaybackSource()
        }

        #if canImport(SpotifyiOS)
        if SpotifyAppRemoteSource.isAvailable {
            return SpotifyAppRemoteSource(auth: auth)
        }
        #endif

        return SpotifyWebAPISource(auth: auth)
    }

    private func attach(_ newSource: PlaybackSource) async {
        source?.stop()
        source = newSource

        newSource.onStateChange = { [weak self] state in
            guard let self else { return }
            self.state = state
            self.onPlaybackUpdate?(state)
        }
        newSource.onConnectionChange = { [weak self] connection in
            guard let self else { return }
            self.connection = connection
            if case .failed = connection {
                self.degradeIfPossible()
            }
        }

        Log.playback.info("Fuente de reproducción: \(newSource.displayName, privacy: .public)")
        await newSource.start()
    }

    private func degradeIfPossible() {
        // Sólo degradamos una vez: si el polling de la Web API también falla,
        // es un problema de red o de sesión, no de la fuente.
        guard !usedFallback, !(source is SpotifyWebAPISource) else { return }
        usedFallback = true
        Log.playback.notice("Degradando a Spotify Web API")

        Task { await attach(SpotifyWebAPISource(auth: auth)) }
    }

    private func observeAppLifecycle() {
        let center = NotificationCenter.default

        // Al volver a primer plano, la posición guardada puede estar vieja
        // (el usuario pudo saltar de tema desde el auto o los auriculares).
        observers.append(center.addObserver(
            forName: UIApplication.didBecomeActiveNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in await self?.source?.refresh() }
        })
    }
}
