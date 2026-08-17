import Foundation

/// Canción que Spotify está reproduciendo. Es el identificador con el que
/// buscamos la letra, así que la igualdad se define por `id` para no
/// re-disparar búsquedas cuando sólo cambia la posición de reproducción.
struct Track: Equatable, Hashable, Codable, Identifiable {
    /// URI de Spotify (`spotify:track:...`) o un id sintético para fuentes
    /// de prueba.
    let id: String
    let title: String
    let artist: String
    let album: String
    /// Duración total en segundos.
    let duration: TimeInterval
    let artworkURL: URL?

    static func == (lhs: Track, rhs: Track) -> Bool { lhs.id == rhs.id }
    func hash(into hasher: inout Hasher) { hasher.combine(id) }

    /// Artista principal: los proveedores de letras indexan por el primero,
    /// no por "A, B & C".
    var primaryArtist: String {
        let separators = CharacterSet(charactersIn: ",;&")
        let first = artist.components(separatedBy: separators).first ?? artist
        return first
            .replacingOccurrences(of: " feat.", with: "", options: .caseInsensitive)
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// Título sin los sufijos que Spotify agrega y que arruinan la búsqueda:
    /// "Song - Remastered 2011", "Song (feat. X)", "Song - Radio Edit".
    var searchTitle: String {
        var value = title

        if let dashRange = value.range(of: " - ") {
            let suffix = value[dashRange.upperBound...].lowercased()
            let noise = ["remaster", "remix", "radio edit", "live", "mono", "stereo",
                         "version", "edit", "mix", "deluxe", "bonus"]
            if noise.contains(where: { suffix.contains($0) }) {
                value = String(value[..<dashRange.lowerBound])
            }
        }

        while let open = value.range(of: "("), let close = value.range(of: ")"), close.lowerBound > open.lowerBound {
            let inner = value[open.upperBound..<close.lowerBound].lowercased()
            let noise = ["feat", "with", "remaster", "remix", "live", "version", "edit", "bonus"]
            guard noise.contains(where: { inner.contains($0) }) else { break }
            value.removeSubrange(open.lowerBound..<close.upperBound)
        }

        return value.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// Clave estable para la caché en disco.
    var cacheKey: String {
        "\(primaryArtist.lowercased())|\(searchTitle.lowercased())|\(Int(duration.rounded()))"
            .addingPercentEncoding(withAllowedCharacters: .alphanumerics) ?? id
    }
}
