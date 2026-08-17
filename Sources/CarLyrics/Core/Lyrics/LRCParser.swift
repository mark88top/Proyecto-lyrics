import Foundation

/// Parser de formato LRC (letras sincronizadas).
///
/// Soporta:
///   - `[mm:ss.xx] texto` y `[mm:ss:xx] texto`
///   - varias marcas de tiempo por línea: `[00:12.00][01:20.00] estribillo`
///   - metadatos `[ar:]`, `[ti:]`, `[offset:]` (el offset se aplica)
///   - texto plano sin marcas (devuelve líneas sin `time`)
enum LRCParser {
    static func parse(_ raw: String) -> [LyricLine] {
        var timed: [(time: TimeInterval, text: String)] = []
        var plain: [String] = []
        var fileOffset: TimeInterval = 0

        for rawLine in raw.components(separatedBy: .newlines) {
            let line = rawLine.trimmingCharacters(in: .whitespaces)
            guard !line.isEmpty else { continue }

            if let offset = metadataOffset(in: line) {
                fileOffset = offset
                continue
            }
            if isMetadata(line) { continue }

            let (stamps, text) = splitTimestamps(line)
            if stamps.isEmpty {
                plain.append(line)
            } else {
                for stamp in stamps {
                    timed.append((stamp, text))
                }
            }
        }

        if !timed.isEmpty {
            // El `offset` del archivo LRC se define como "milisegundos a
            // adelantar", o sea que se resta del tiempo de cada línea.
            let sorted = timed
                .map { (time: max(0, $0.time - fileOffset), text: $0.text) }
                .sorted { $0.time < $1.time }

            return sorted.enumerated().map { index, item in
                LyricLine(index: index, time: item.time, text: item.text)
            }
        }

        return plain.enumerated().map { index, text in
            LyricLine(index: index, time: nil, text: text)
        }
    }

    // MARK: - Interno

    private static func isMetadata(_ line: String) -> Bool {
        // `[ar:Artista]`, `[by:...]`, etc. El primer carácter tras `[` no es dígito.
        guard line.hasPrefix("["), let close = line.firstIndex(of: "]") else { return false }
        let inner = line[line.index(after: line.startIndex)..<close]
        guard let first = inner.first else { return false }
        return !first.isNumber && inner.contains(":")
    }

    private static func metadataOffset(in line: String) -> TimeInterval? {
        guard line.lowercased().hasPrefix("[offset:"), let close = line.firstIndex(of: "]") else { return nil }
        let start = line.index(line.startIndex, offsetBy: 8)
        let value = line[start..<close].trimmingCharacters(in: .whitespaces)
        guard let milliseconds = Double(value) else { return nil }
        return milliseconds / 1000
    }

    /// Separa las marcas iniciales del texto. `[00:12.00][00:40.00] hola`
    /// devuelve `([12, 40], "hola")`.
    private static func splitTimestamps(_ line: String) -> ([TimeInterval], String) {
        var stamps: [TimeInterval] = []
        var rest = Substring(line)

        while rest.hasPrefix("[") {
            guard let close = rest.firstIndex(of: "]") else { break }
            let inner = String(rest[rest.index(after: rest.startIndex)..<close])
            guard let seconds = seconds(fromTimestamp: inner) else { break }
            stamps.append(seconds)
            rest = rest[rest.index(after: close)...]
        }

        return (stamps, String(rest).trimmingCharacters(in: .whitespaces))
    }

    /// `mm:ss.xx`, `mm:ss:xx` o `mm:ss` -> segundos.
    static func seconds(fromTimestamp text: String) -> TimeInterval? {
        let normalized = text.replacingOccurrences(of: ",", with: ".")
        let parts = normalized.split(separator: ":", omittingEmptySubsequences: false).map(String.init)
        guard parts.count >= 2, let minutes = Double(parts[0]) else { return nil }

        if parts.count == 2 {
            guard let seconds = Double(parts[1]) else { return nil }
            return minutes * 60 + seconds
        }

        // Formato `mm:ss:cc`, donde `cc` son centésimas.
        guard let seconds = Double(parts[1]), let fraction = Double(parts[2]) else { return nil }
        let divisor = pow(10.0, Double(parts[2].count))
        return minutes * 60 + seconds + fraction / divisor
    }
}
