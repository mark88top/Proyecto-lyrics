import Foundation

/// Una línea de la letra. `time` es `nil` cuando la letra no está
/// sincronizada (sólo texto plano).
struct LyricLine: Equatable, Codable, Identifiable {
    let index: Int
    let time: TimeInterval?
    let text: String

    var id: Int { index }
    var isBlank: Bool { text.trimmingCharacters(in: .whitespaces).isEmpty }
}

/// Letra completa más la atribución de su origen. La atribución no es
/// opcional: mostrarla es requisito de los proveedores y también de la
/// guía 5.2 de App Review.
struct Lyrics: Equatable, Codable {
    let lines: [LyricLine]
    let isSynced: Bool
    let sourceName: String
    let sourceURL: URL?
    /// `true` cuando el proveedor marca el tema como instrumental.
    let isInstrumental: Bool

    static let empty = Lyrics(lines: [], isSynced: false, sourceName: "", sourceURL: nil, isInstrumental: false)

    var isEmpty: Bool { lines.isEmpty && !isInstrumental }

    var plainText: String {
        lines.map(\.text).joined(separator: "\n")
    }
}

/// Resultado de pedir la letra de un tema.
enum LyricsResult: Equatable {
    case found(Lyrics)
    case notFound
    case instrumental
}
