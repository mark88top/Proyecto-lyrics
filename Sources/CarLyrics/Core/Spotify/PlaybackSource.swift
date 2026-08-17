import Foundation

/// Fuente de estado de reproducción. Tenemos tres implementaciones:
///
///   - `SpotifyAppRemoteSource`: SDK nativo. Push en tiempo real, latencia
///     mínima, pero exige la app de Spotify instalada y el SDK enlazado.
///   - `SpotifyWebAPISource`: polling a la Web API. Funciona siempre (incluso
///     con Spotify sonando en otro dispositivo), pero refresca cada ~2 s.
///   - `SimulatedPlaybackSource`: para simulador y tests.
///
/// La app elige automáticamente, con degradación en cascada.
///
/// Está aislado al hilo principal porque todas sus implementaciones publican
/// directo a la UI y porque CarPlay exige actualizaciones desde main.
@MainActor
protocol PlaybackSource: AnyObject {
    var displayName: String { get }
    /// Se invoca en el hilo principal con cada cambio de estado.
    var onStateChange: ((PlaybackState) -> Void)? { get set }
    var onConnectionChange: ((PlaybackConnectionState) -> Void)? { get set }

    func start() async
    func stop()
    /// Fuerza una relectura (al volver del background, por ejemplo).
    func refresh() async
}
