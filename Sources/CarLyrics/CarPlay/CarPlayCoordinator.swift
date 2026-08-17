import CarPlay
import Combine
import Foundation

/// Traduce el estado de la app a plantillas de CarPlay.
///
/// Dos restricciones marcan todo el diseño de esta clase:
///
///  1. **Seguridad.** El usuario está manejando. Mostramos pocas líneas,
///     grandes, y sin animación que invite a quedarse mirando. La cantidad
///     de líneas es configurable (1/3/5) y por defecto es 3.
///
///  2. **Presupuesto de refresco.** CarPlay no está pensado para repintar a
///     10 Hz: cada `updateSections` cruza IPC hasta la pantalla del auto.
///     Por eso sólo publicamos cuando *cambia la línea activa*, y nunca más
///     seguido que `minimumUpdateInterval`.
@MainActor
final class CarPlayCoordinator {
    private let interfaceController: CPInterfaceController
    private let environment: AppEnvironment
    private let lyricsTemplate: CPListTemplate

    private var cancellables = Set<AnyCancellable>()
    private var lastRenderedKey: String?
    private var lastUpdate: Date = .distantPast
    private var pendingWork: DispatchWorkItem?

    /// Piso entre repintados. 0,4 s alcanza para que ninguna línea se saltee
    /// (las letras rara vez cambian más rápido) y evita saturar el enlace.
    private let minimumUpdateInterval: TimeInterval = 0.4

    init(interfaceController: CPInterfaceController, environment: AppEnvironment) {
        self.interfaceController = interfaceController
        self.environment = environment
        self.lyricsTemplate = CPListTemplate(title: L10n.carPlayTabLyrics, sections: [])
    }

    func start() {
        environment.startIfNeeded()

        lyricsTemplate.emptyViewTitleVariants = [L10n.carPlayNoLyrics]
        lyricsTemplate.emptyViewSubtitleVariants = [L10n.nowPlayingNothingDetail]

        interfaceController.setRootTemplate(lyricsTemplate, animated: false) { [weak self] _, error in
            if let error {
                Log.carplay.error("No se pudo montar la plantilla raíz: \(error.localizedDescription, privacy: .public)")
            }
            Task { @MainActor in self?.render(force: true) }
        }

        observe()
    }

    func stop() {
        pendingWork?.cancel()
        cancellables.removeAll()
    }

    // MARK: - Observación

    private func observe() {
        environment.lyrics.$state
            .removeDuplicates()
            .sink { [weak self] _ in self?.scheduleRender() }
            .store(in: &cancellables)

        environment.playback.$connection
            .removeDuplicates()
            .sink { [weak self] _ in self?.scheduleRender(force: true) }
            .store(in: &cancellables)

        environment.auth.$isAuthorized
            .removeDuplicates()
            .sink { [weak self] _ in self?.scheduleRender(force: true) }
            .store(in: &cancellables)
    }

    /// Agenda un repintado respetando el intervalo mínimo. Si llegan varios
    /// cambios seguidos, sólo sobrevive el último (coalescing).
    private func scheduleRender(force: Bool = false) {
        pendingWork?.cancel()

        let elapsed = Date().timeIntervalSince(lastUpdate)
        if force || elapsed >= minimumUpdateInterval {
            render(force: force)
            return
        }

        // Todavía estamos dentro del intervalo mínimo: agendamos para cuando
        // se cumpla. Si llegan más cambios antes, este trabajo se cancela y
        // sólo sobrevive el último.
        let work = DispatchWorkItem { [weak self] in
            Task { @MainActor in self?.render() }
        }
        pendingWork = work
        DispatchQueue.main.asyncAfter(deadline: .now() + (minimumUpdateInterval - elapsed), execute: work)
    }

    // MARK: - Render

    private func render(force: Bool = false) {
        let board = CarPlayLyricsBoard(
            lyricsState: environment.lyrics.state,
            playback: environment.playback.state,
            connection: environment.playback.connection,
            isAuthorized: environment.auth.isAuthorized || environment.isSimulated,
            visibleLines: environment.settings.carPlayLinesVisible
        )

        // Sin cambios visibles, no gastamos un ciclo de actualización.
        guard force || board.identity != lastRenderedKey else { return }
        lastRenderedKey = board.identity
        lastUpdate = Date()

        lyricsTemplate.updateSections(board.makeSections())
    }
}
