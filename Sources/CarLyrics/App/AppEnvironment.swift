import Foundation
import Combine
import UIKit

/// Contenedor de servicios compartidos.
///
/// Es un singleton a propósito: la escena del iPhone y la de CarPlay son dos
/// procesos de UI distintos dentro de la misma app, y ambas tienen que leer
/// exactamente el mismo estado de reproducción y la misma letra. Duplicar
/// los servicios significaría dos conexiones a Spotify y dos búsquedas de
/// letra por canción.
@MainActor
final class AppEnvironment: ObservableObject {
    static let shared = AppEnvironment()

    let configuration: AppConfiguration
    let settings: UserSettings
    let auth: SpotifyAuthManager
    let playback: PlaybackCoordinator
    let lyrics: LyricsController
    let repository: LyricsRepository
    let tipJar: TipJar

    @Published private(set) var isRunning = false

    private var cancellables = Set<AnyCancellable>()

    private init() {
        let configuration = AppConfiguration.current
        let settings = UserSettings.shared
        let auth = SpotifyAuthManager(configuration: configuration)
        let repository = LyricsRepository()

        self.configuration = configuration
        self.settings = settings
        self.auth = auth
        self.repository = repository
        self.playback = PlaybackCoordinator(auth: auth)
        self.lyrics = LyricsController(repository: repository, settings: settings)
        self.tipJar = TipJar(settings: settings)

        wireUp()
    }

    /// Arranca la captura de reproducción. Idempotente: la llaman tanto la
    /// escena del iPhone como la de CarPlay, y cualquiera de las dos puede
    /// ser la primera en aparecer (se puede enchufar el auto con el teléfono
    /// bloqueado y la app nunca abierta en esta sesión).
    func startIfNeeded() {
        guard auth.isAuthorized || isSimulated else { return }
        guard !isRunning else { return }
        isRunning = true
        Task { await playback.start() }
    }

    func stop() {
        isRunning = false
        playback.stop()
    }

    func signOut() {
        auth.signOut()
        stop()
        lyrics.apply(.idle)
    }

    func signIn() async {
        do {
            try await auth.signIn()
            startIfNeeded()
        } catch SpotifyAuthError.cancelled {
            // Cancelar no es un error que valga la pena mostrar.
        } catch {
            Log.auth.error("Login falló: \(error.localizedDescription, privacy: .public)")
        }
    }

    var isSimulated: Bool {
        ProcessInfo.processInfo.environment["CARLYRICS_SIMULATED_PLAYBACK"] == "1"
    }

    /// Abre la app de Spotify (o el App Store si no está instalada).
    func openSpotify() {
        let appURL = URL(string: "spotify:")!
        if UIApplication.shared.canOpenURL(appURL) {
            UIApplication.shared.open(appURL)
        } else if let storeURL = URL(string: "https://apps.apple.com/app/id324684580") {
            UIApplication.shared.open(storeURL)
        }
    }

    // MARK: - Interno

    private func wireUp() {
        // El coordinador de reproducción alimenta al controlador de letras.
        playback.onPlaybackUpdate = { [weak self] state in
            self?.lyrics.apply(state)
        }

        // Si el usuario se loguea desde cualquier pantalla, arrancamos.
        auth.$isAuthorized
            .removeDuplicates()
            .sink { [weak self] authorized in
                guard let self else { return }
                if authorized {
                    self.startIfNeeded()
                } else {
                    self.stop()
                }
            }
            .store(in: &cancellables)
    }
}
