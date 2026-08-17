import Foundation

/// Orquesta caché + proveedores y garantiza que sólo haya una búsqueda en
/// vuelo por canción (importante: al cambiar de tema, iPhone y CarPlay
/// piden la letra casi al mismo tiempo).
actor LyricsRepository {
    private let providers: [LyricsProvider]
    private let cache: LyricsCache
    private var inFlight: [String: Task<LyricsResult, Error>] = [:]

    init(providers: [LyricsProvider] = [LRCLIBProvider()], cache: LyricsCache = LyricsCache()) {
        self.providers = providers
        self.cache = cache
    }

    func lyrics(for track: Track) async throws -> LyricsResult {
        let key = track.cacheKey

        if let cached = await cache.value(for: key) {
            Log.lyrics.debug("Letra servida desde caché")
            return cached
        }

        if let running = inFlight[key] {
            return try await running.value
        }

        let task = Task<LyricsResult, Error> { [providers, cache] in
            var lastError: Error?

            for provider in providers {
                do {
                    let result = try await provider.lyrics(for: track)
                    if case .notFound = result { continue }
                    await cache.store(result, for: key)
                    return result
                } catch is CancellationError {
                    throw CancellationError()
                } catch {
                    Log.lyrics.error("Proveedor \(provider.displayName, privacy: .public) falló: \(error.localizedDescription, privacy: .public)")
                    lastError = error
                }
            }

            // Sólo cacheamos el "no encontrado" si ningún proveedor falló por
            // red: si hubo error de conexión, queremos reintentar más tarde.
            if lastError == nil {
                await cache.store(.notFound, for: key)
                return .notFound
            }
            throw lastError!
        }

        inFlight[key] = task
        defer { inFlight[key] = nil }
        return try await task.value
    }

    func clearCache() async {
        await cache.clear()
    }

    func cacheSizeInBytes() async -> Int {
        await cache.diskSizeInBytes()
    }
}
