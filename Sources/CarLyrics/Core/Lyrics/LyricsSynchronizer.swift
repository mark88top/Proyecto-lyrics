import Foundation

/// Traduce una posición de reproducción al índice de línea que corresponde.
///
/// Se construye una vez por canción y guarda los tiempos en un array para
/// resolver con búsqueda binaria: se consulta ~10 veces por segundo y no
/// queremos recorrer 80 líneas cada vez.
struct LyricsSynchronizer {
    private let times: [TimeInterval]
    let lines: [LyricLine]
    let isSynced: Bool

    init(lyrics: Lyrics) {
        self.lines = lyrics.lines
        self.isSynced = lyrics.isSynced && lyrics.lines.contains { $0.time != nil }
        self.times = lyrics.lines.compactMap(\.time)
    }

    var isEmpty: Bool { lines.isEmpty }

    /// Índice de la línea activa en `position` (segundos), o `nil` si la
    /// canción todavía no llegó a la primera línea.
    func index(at position: TimeInterval, offset: TimeInterval = 0) -> Int? {
        guard isSynced, !times.isEmpty else { return nil }

        let adjusted = position - offset
        guard let first = times.first, adjusted >= first else { return nil }

        // Última línea cuyo tiempo es <= adjusted.
        var low = 0
        var high = times.count - 1
        var result = 0

        while low <= high {
            let mid = (low + high) / 2
            if times[mid] <= adjusted {
                result = mid
                low = mid + 1
            } else {
                high = mid - 1
            }
        }
        return result
    }

    /// Progreso (0...1) dentro de la línea activa. Sirve para animar el
    /// resaltado en el iPhone.
    func progressWithinLine(at position: TimeInterval, offset: TimeInterval = 0, trackDuration: TimeInterval) -> Double {
        guard let index = index(at: position, offset: offset), index < times.count else { return 0 }
        let start = times[index]
        let end = index + 1 < times.count ? times[index + 1] : max(trackDuration, start + 4)
        guard end > start else { return 1 }
        return min(1, max(0, ((position - offset) - start) / (end - start)))
    }

    /// Ventana de líneas alrededor de la activa. CarPlay muestra pocas
    /// líneas a propósito (menos texto que leer manejando).
    func window(around index: Int?, radius: Int) -> [LyricLine] {
        guard !lines.isEmpty else { return [] }
        guard let index else { return Array(lines.prefix(radius * 2 + 1)) }

        let lower = max(0, index - radius)
        let upper = min(lines.count - 1, index + radius)
        return Array(lines[lower...upper])
    }
}
