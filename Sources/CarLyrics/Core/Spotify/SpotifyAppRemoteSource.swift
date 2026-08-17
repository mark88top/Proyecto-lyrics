import Foundation

#if canImport(SpotifyiOS)
import SpotifyiOS
import UIKit

/// Fuente basada en el SDK nativo de Spotify (App Remote).
///
/// Ventaja frente al polling: Spotify empuja `playerStateDidChange` en el
/// instante en que cambia algo, lo que baja la latencia de sincronía de
/// ~2 s a ~50 ms. Es lo que hace que la letra se sienta "pegada" al audio.
///
/// Requiere: la app de Spotify instalada, un access token con el scope
/// `app-remote-control`, y el paquete SpotifyiOS enlazado (ver project.yml).
@MainActor
final class SpotifyAppRemoteSource: NSObject, PlaybackSource {
    let displayName = "Spotify (App Remote)"

    var onStateChange: ((PlaybackState) -> Void)?
    var onConnectionChange: ((PlaybackConnectionState) -> Void)?

    private let auth: SpotifyAuthManager
    private let configuration: AppConfiguration
    private var appRemote: SPTAppRemote?
    private var reconnectAttempts = 0

    init(auth: SpotifyAuthManager, configuration: AppConfiguration = .current) {
        self.auth = auth
        self.configuration = configuration
        super.init()
    }

    static var isAvailable: Bool {
        guard let url = URL(string: "spotify:") else { return false }
        return UIApplication.shared.canOpenURL(url)
    }

    func start() async {
        onConnectionChange?(.connecting)

        guard let token = try? await auth.validAccessToken() else {
            onConnectionChange?(.failed(message: L10n.errorNeedsLogin))
            return
        }

        let config = SPTConfiguration(
            clientID: configuration.spotifyClientID,
            redirectURL: configuration.spotifyRedirectURI
        )
        let remote = SPTAppRemote(configuration: config, logLevel: .error)
        remote.connectionParameters.accessToken = token
        remote.delegate = self
        appRemote = remote
        remote.connect()
    }

    func stop() {
        appRemote?.disconnect()
        appRemote = nil
        onConnectionChange?(.disconnected)
    }

    func refresh() async {
        guard let remote = appRemote, remote.isConnected else {
            await start()
            return
        }
        remote.playerAPI?.getPlayerState { [weak self] state, _ in
            guard let state = state as? SPTAppRemotePlayerState else { return }
            self?.publish(state)
        }
    }

    // MARK: - Interno

    private func publish(_ state: SPTAppRemotePlayerState) {
        let spotifyTrack = state.track
        let track = Track(
            id: spotifyTrack.uri,
            title: spotifyTrack.name,
            artist: spotifyTrack.artist.name,
            album: spotifyTrack.album.name,
            duration: TimeInterval(spotifyTrack.duration) / 1000,
            artworkURL: nil
        )

        onStateChange?(PlaybackState(
            track: track,
            isPlaying: !state.isPaused,
            position: TimeInterval(state.playbackPosition) / 1000,
            timestamp: ProcessInfo.processInfo.systemUptime
        ))
    }
}

extension SpotifyAppRemoteSource: SPTAppRemoteDelegate {
    func appRemoteDidEstablishConnection(_ appRemote: SPTAppRemote) {
        reconnectAttempts = 0
        onConnectionChange?(.connected(sourceName: displayName))

        appRemote.playerAPI?.delegate = self
        appRemote.playerAPI?.subscribe(toPlayerState: { _, error in
            if let error {
                Log.playback.error("Suscripción al player falló: \(error.localizedDescription, privacy: .public)")
            }
        })
        Task { await refresh() }
    }

    func appRemote(_ appRemote: SPTAppRemote, didFailConnectionAttemptWithError error: Error?) {
        Log.playback.error("App Remote no conectó: \(error?.localizedDescription ?? "sin detalle", privacy: .public)")
        onConnectionChange?(.failed(message: L10n.errorSpotifyNotRunning))
    }

    func appRemote(_ appRemote: SPTAppRemote, didDisconnectWithError error: Error?) {
        onConnectionChange?(.disconnected)

        // Spotify corta la conexión cuando su app pasa a background. Un par
        // de reintentos espaciados suele recuperarla sin molestar al usuario;
        // si no, el coordinador cae al polling de la Web API.
        guard reconnectAttempts < 3 else { return }
        reconnectAttempts += 1
        let delay = Double(reconnectAttempts) * 2

        Task { [weak self] in
            try? await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
            await self?.start()
        }
    }
}

extension SpotifyAppRemoteSource: SPTAppRemotePlayerStateDelegate {
    func playerStateDidChange(_ playerState: SPTAppRemotePlayerState) {
        publish(playerState)
    }
}
#endif
