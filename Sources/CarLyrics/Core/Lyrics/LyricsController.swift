import Foundation
import Combine

/// Estado de la letra tal como lo consume la UI.
enum LyricsViewState: Equatable {
    case idle
    case loading
    case ready(LyricsSnapshot)
    case notFound
    case instrumental
    case failed(String)
}

/// Instantánea inmutable: qué líneas hay, cuál está activa y de dónde salió
/// la letra. Tanto el iPhone como CarPlay renderizan desde acá, así que las
/// dos pantallas nunca se desincronizan entre sí.
struct LyricsSnapshot: Equatable {
    var lines: [LyricLine]
    var activeIndex: Int?
    var isSynced: Bool
    var sourceName: String
    var sourceURL: URL?

    static let empty = LyricsSnapshot(lines: [], activeIndex: nil, isSynced: false, sourceName: "", sourceURL: nil)
}

/// Une reproducción + letras: escucha el tema actual, busca la letra y
/// publica qué línea corresponde a cada instante.
///
/// Es la única pieza que corre un timer, y lo hace a 10 Hz sólo cuando hay
/// letra sincronizada y algo sonando: en CarPlay el consumo importa.
@MainActor
final class LyricsController: ObservableObject {
    @Published private(set) var state: LyricsViewState = .idle
    @Published private(set) var position: TimeInterval = 0

    private let repository: LyricsRepository
    private let settings: UserSettings
    private var synchronizer: LyricsSynchronizer?
    private var snapshot: LyricsSnapshot = .empty
    private var currentTrack: Track?
    private var playback: PlaybackState = .idle
    private var ticker: Timer?
    private var fetchTask: Task<Void, Never>?

    private let tickInterval: TimeInterval = 0.1

    init(repository: LyricsRepository, settings: UserSettings = .shared) {
        self.repository = repository
        self.settings = settings
    }

    deinit {
        ticker?.invalidate()
    }

    /// Punto de entrada: se llama con cada actualización del reproductor.
    func apply(_ newState: PlaybackState) {
        let previousTrack = playback.track
        playback = newState

        if newState.track != previousTrack {
            handleTrackChange(newState.track)
        }

        updateTicker()
        refreshPosition()
    }

    /// Reintenta la búsqueda para el tema actual (botón "Reintentar").
    func retry() {
        guard let track = currentTrack else { return }
        currentTrack = nil
        handleTrackChange(track)
    }

    /// Recalcula el resaltado tras cambiar el offset en Ajustes.
    func offsetDidChange() {
        refreshPosition()
    }

    // MARK: - Interno

    private func handleTrackChange(_ track: Track?) {
        fetchTask?.cancel()
        synchronizer = nil
        snapshot = .empty
        currentTrack = track

        guard let track else {
            state = .idle
            return
        }

        state = .loading
        fetchTask = Task { [weak self, repository] in
            do {
                let result = try await repository.lyrics(for: track)
                guard !Task.isCancelled else { return }
                await MainActor.run { self?.handle(result, for: track) }
            } catch is CancellationError {
                return
            } catch {
                guard !Task.isCancelled else { return }
                await MainActor.run { self?.handleFailure(error, for: track) }
            }
        }
    }

    private func handle(_ result: LyricsResult, for track: Track) {
        // Puede haber cambiado la canción mientras buscábamos.
        guard track == currentTrack else { return }

        switch result {
        case .notFound:
            state = .notFound
        case .instrumental:
            state = .instrumental
        case .found(let lyrics):
            let sync = LyricsSynchronizer(lyrics: lyrics)
            synchronizer = sync
            snapshot = LyricsSnapshot(
                lines: lyrics.lines,
                activeIndex: nil,
                isSynced: sync.isSynced,
                sourceName: lyrics.sourceName,
                sourceURL: lyrics.sourceURL
            )
            state = .ready(snapshot)
            refreshPosition()
        }
        updateTicker()
    }

    private func handleFailure(_ error: Error, for track: Track) {
        guard track == currentTrack else { return }
        Log.lyrics.error("Búsqueda de letra falló: \(error.localizedDescription, privacy: .public)")

        let message: String
        switch error as? HTTPError {
        case .transport:
            message = L10n.errorOffline
        case .rateLimited:
            message = L10n.errorRateLimited
        default:
            message = L10n.errorGeneric
        }
        state = .failed(message)
        updateTicker()
    }

    private func updateTicker() {
        let needsTicker = playback.isPlaying && synchronizer?.isSynced == true

        if needsTicker, ticker == nil {
            let timer = Timer(timeInterval: tickInterval, repeats: true) { [weak self] _ in
                Task { @MainActor in self?.refreshPosition() }
            }
            // `.common` para que el timer no se congele mientras el usuario
            // hace scroll en la lista de letras.
            RunLoop.main.add(timer, forMode: .common)
            ticker = timer
        } else if !needsTicker {
            ticker?.invalidate()
            ticker = nil
        }
    }

    private func refreshPosition() {
        let now = ProcessInfo.processInfo.systemUptime
        let estimated = playback.estimatedPosition(at: now)

        // `position` alimenta el reloj de la cabecera. Publicarlo en cada
        // tick haría re-renderizar toda la pantalla 10 veces por segundo sin
        // que cambie nada visible; con resolución de un segundo alcanza. El
        // cálculo de la línea activa sigue usando el valor exacto.
        if Int(estimated) != Int(position) {
            position = estimated
        }

        guard let synchronizer, case .ready = state else { return }

        let index = synchronizer.index(at: estimated, offset: settings.lyricsOffset)
        guard index != snapshot.activeIndex else { return }

        snapshot.activeIndex = index
        state = .ready(snapshot)
    }
}
