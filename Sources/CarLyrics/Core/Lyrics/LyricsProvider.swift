import Foundation

/// Fuente de letras. La app encadena varios proveedores: si el primero no
/// tiene la canción, prueba el siguiente.
protocol LyricsProvider: Sendable {
    /// Nombre visible, usado para la atribución obligatoria en pantalla.
    var displayName: String { get }
    func lyrics(for track: Track) async throws -> LyricsResult
}
