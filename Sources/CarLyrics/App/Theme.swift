import SwiftUI

/// Paleta única para el teléfono. CarPlay usa la del sistema del auto (no se
/// puede ni se debe pisar: cada fabricante calibra su pantalla).
enum Theme {
    static let accent = Color(red: 0.114, green: 0.843, blue: 0.451)
    static let background = Color(red: 0.043, green: 0.043, blue: 0.055)
    static let surface = Color.white.opacity(0.06)

    static let activeLine = Color.white
    static let inactiveLine = Color.white.opacity(0.35)
    static let pastLine = Color.white.opacity(0.22)

    /// Tipografía de la letra: pesada y grande, legible de un vistazo.
    static func lyricFont(scale: Double, isActive: Bool) -> Font {
        .system(size: (isActive ? 30 : 26) * scale, weight: isActive ? .bold : .semibold, design: .rounded)
    }
}
