import Foundation

/// Lee el reproductor vía `GET /v1/me/player`.
///
/// Es el camino que siempre funciona, incluso si Spotify suena en otro
/// equipo (parlante, notebook). El costo es la latencia: la API no empuja
/// eventos, así que hacemos polling adaptativo — rápido justo después de un
/// cambio de canción, lento cuando el tema viene sonando estable.
@MainActor
final class SpotifyWebAPISource: PlaybackSource {
    let displayName = "Spotify Web API"

    var onStateChange: ((PlaybackState) -> Void)?
    var onConnectionChange: ((PlaybackConnectionState) -> Void)?

    private let auth: SpotifyAuthManager
    private let client: HTTPClient
    private var pollTask: Task<Void, Never>?
    private var lastTrackID: String?
    private var consecutiveFailures = 0

    /// Intervalos de polling. Spotify limita a ~180 req/min por usuario;
    /// 2 s de piso deja margen de sobra.
    private let fastInterval: TimeInterval = 2
    private let idleInterval: TimeInterval = 8

    init(auth: SpotifyAuthManager, client: HTTPClient = HTTPClient()) {
        self.auth = auth
        self.client = client
    }

    func start() async {
        guard pollTask == nil else { return }
        onConnectionChange?(.connecting)

        pollTask = Task { [weak self] in
            while !Task.isCancelled {
                guard let self else { return }
                let interval = await self.poll()
                try? await Task.sleep(nanoseconds: UInt64(interval * 1_000_000_000))
            }
        }
    }

    func stop() {
        pollTask?.cancel()
        pollTask = nil
        onConnectionChange?(.disconnected)
    }

    func refresh() async {
        _ = await poll()
    }

    // MARK: - Interno

    /// Devuelve cuántos segundos esperar hasta el próximo sondeo.
    private func poll() async -> TimeInterval {
        do {
            let token = try await auth.validAccessToken()
            let data = try await client.getData(
                url: URL(string: "https://api.spotify.com/v1/me/player")!,
                headers: ["Authorization": "Bearer \(token)"]
            )

            consecutiveFailures = 0

            // 204 = no hay reproductor activo; el cuerpo viene vacío.
            guard !data.isEmpty else {
                onConnectionChange?(.connected(sourceName: displayName))
                onStateChange?(.idle)
                lastTrackID = nil
                return idleInterval
            }

            let payload = try JSONDecoder().decode(PlayerPayload.self, from: data)
            guard let state = payload.playbackState() else {
                onStateChange?(.idle)
                return idleInterval
            }

            onConnectionChange?(.connected(sourceName: displayName))
            onStateChange?(state)

            let changed = state.track?.id != lastTrackID
            lastTrackID = state.track?.id

            if !state.isPlaying { return idleInterval }
            // Al cambiar de tema conviene re-sondear pronto: la posición
            // inicial es la que más impacta en la sincronía.
            return changed ? 1 : fastInterval
        } catch is CancellationError {
            return fastInterval
        } catch {
            consecutiveFailures += 1
            Log.playback.error("Polling falló: \(error.localizedDescription, privacy: .public)")

            if consecutiveFailures >= 3 {
                onConnectionChange?(.failed(message: L10n.errorSpotifyUnreachable))
            }
            // Backoff exponencial acotado, para no castigar la batería ni la
            // cuota de la API cuando no hay red.
            return min(30, fastInterval * pow(2, Double(min(consecutiveFailures, 4))))
        }
    }

    // MARK: - DTO

    private struct PlayerPayload: Decodable {
        struct Item: Decodable {
            struct Artist: Decodable { let name: String }
            struct Album: Decodable {
                struct Image: Decodable { let url: String; let width: Int? }
                let name: String
                let images: [Image]
            }
            let uri: String
            let name: String
            let duration_ms: Double
            let artists: [Artist]
            let album: Album
        }

        let is_playing: Bool
        let progress_ms: Double?
        let item: Item?

        func playbackState() -> PlaybackState? {
            guard let item else { return nil }

            let artwork = item.album.images
                .sorted { ($0.width ?? 0) > ($1.width ?? 0) }
                .first
                .flatMap { URL(string: $0.url) }

            let track = Track(
                id: item.uri,
                title: item.name,
                artist: item.artists.map(\.name).joined(separator: ", "),
                album: item.album.name,
                duration: item.duration_ms / 1000,
                artworkURL: artwork
            )

            return PlaybackState(
                track: track,
                isPlaying: is_playing,
                position: (progress_ms ?? 0) / 1000,
                timestamp: ProcessInfo.processInfo.systemUptime
            )
        }
    }
}
