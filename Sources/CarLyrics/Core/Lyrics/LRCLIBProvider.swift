import Foundation

/// Proveedor basado en LRCLIB (https://lrclib.net), una base comunitaria de
/// letras sincronizadas, gratuita y sin API key. Es lo que hace viable que
/// la app sea gratis: no hay costo por consulta.
///
/// Estrategia: primero `/api/get`, que hace match exacto por
/// artista + título + álbum + duración. Si falla, `/api/search`, que es
/// difuso, y se elige el candidato cuya duración se parezca más al tema
/// sonando (evita traer una versión en vivo de 9 minutos).
final class LRCLIBProvider: LyricsProvider, @unchecked Sendable {
    let displayName = "LRCLIB"

    private let client: HTTPClient
    private let baseURL: URL
    /// Tolerancia de duración al elegir candidatos en la búsqueda difusa.
    private let durationTolerance: TimeInterval = 6

    init(client: HTTPClient = HTTPClient(), baseURL: URL = AppConfiguration.current.lyricsAPIBaseURL) {
        self.client = client
        self.baseURL = baseURL
    }

    func lyrics(for track: Track) async throws -> LyricsResult {
        if let exact = try await exactMatch(track) {
            return exact
        }
        return try await fuzzyMatch(track)
    }

    // MARK: - Interno

    private func exactMatch(_ track: Track) async throws -> LyricsResult? {
        var query: [String: String] = [
            "artist_name": track.primaryArtist,
            "track_name": track.searchTitle
        ]
        if !track.album.isEmpty { query["album_name"] = track.album }
        if track.duration > 0 { query["duration"] = String(Int(track.duration.rounded())) }

        do {
            let record = try await client.get(
                Record.self,
                url: baseURL.appendingPathComponent("api/get"),
                query: query
            )
            return convert(record)
        } catch HTTPError.notFound {
            return nil
        }
    }

    private func fuzzyMatch(_ track: Track) async throws -> LyricsResult {
        let records: [Record]
        do {
            records = try await client.get(
                [Record].self,
                url: baseURL.appendingPathComponent("api/search"),
                query: [
                    "artist_name": track.primaryArtist,
                    "track_name": track.searchTitle
                ]
            )
        } catch HTTPError.notFound {
            return .notFound
        }

        guard !records.isEmpty else { return .notFound }

        // Preferimos: (1) que tenga letra sincronizada, (2) duración cercana.
        let scored = records.map { record -> (Record, Double) in
            let durationPenalty = abs((record.duration ?? 0) - track.duration)
            let syncedBonus: Double = (record.syncedLyrics?.isEmpty == false) ? -1000 : 0
            return (record, durationPenalty + syncedBonus)
        }

        guard let best = scored.min(by: { $0.1 < $1.1 })?.0 else { return .notFound }

        // Si ni el mejor candidato tiene una duración razonable, es probable
        // que sea otra canción con nombre parecido. Mejor no mostrar nada
        // que mostrar la letra equivocada.
        if track.duration > 0, let candidate = best.duration,
           abs(candidate - track.duration) > durationTolerance * 4 {
            return .notFound
        }

        return convert(best) ?? .notFound
    }

    private func convert(_ record: Record) -> LyricsResult? {
        if record.instrumental == true { return .instrumental }

        if let synced = record.syncedLyrics, !synced.isEmpty {
            let lines = LRCParser.parse(synced)
            if !lines.isEmpty {
                return .found(Lyrics(
                    lines: lines,
                    isSynced: lines.contains { $0.time != nil },
                    sourceName: displayName,
                    sourceURL: URL(string: "https://lrclib.net"),
                    isInstrumental: false
                ))
            }
        }

        if let plain = record.plainLyrics, !plain.isEmpty {
            let lines = LRCParser.parse(plain)
            guard !lines.isEmpty else { return nil }
            return .found(Lyrics(
                lines: lines,
                isSynced: false,
                sourceName: displayName,
                sourceURL: URL(string: "https://lrclib.net"),
                isInstrumental: false
            ))
        }

        return nil
    }

    // MARK: - DTO

    private struct Record: Decodable {
        let id: Int?
        let trackName: String?
        let artistName: String?
        let albumName: String?
        let duration: Double?
        let instrumental: Bool?
        let plainLyrics: String?
        let syncedLyrics: String?
    }
}
