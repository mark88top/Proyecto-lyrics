import XCTest
@testable import CarLyrics

/// Proveedor controlable: cuenta llamadas y puede fallar a pedido.
private final class FakeProvider: LyricsProvider, @unchecked Sendable {
    let displayName: String
    private let result: Result<LyricsResult, Error>
    private let lock = NSLock()
    private var _callCount = 0
    private let delay: TimeInterval

    var callCount: Int {
        lock.lock(); defer { lock.unlock() }
        return _callCount
    }

    init(displayName: String, result: Result<LyricsResult, Error>, delay: TimeInterval = 0) {
        self.displayName = displayName
        self.result = result
        self.delay = delay
    }

    func lyrics(for track: Track) async throws -> LyricsResult {
        lock.lock(); _callCount += 1; lock.unlock()
        if delay > 0 {
            try? await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
        }
        return try result.get()
    }
}

private func makeLyrics(_ text: String) -> LyricsResult {
    .found(Lyrics(
        lines: [LyricLine(index: 0, time: 0, text: text)],
        isSynced: true,
        sourceName: "Fake",
        sourceURL: nil,
        isInstrumental: false
    ))
}

final class LyricsRepositoryTests: XCTestCase {
    private var cache: LyricsCache!

    private let track = Track(
        id: "spotify:track:1", title: "Song", artist: "Artist", album: "Album",
        duration: 200, artworkURL: nil
    )

    override func setUp() async throws {
        cache = LyricsCache()
        await cache.clear()
    }

    override func tearDown() async throws {
        await cache.clear()
    }

    func testReturnsFirstProviderResult() async throws {
        let first = FakeProvider(displayName: "A", result: .success(makeLyrics("de A")))
        let second = FakeProvider(displayName: "B", result: .success(makeLyrics("de B")))
        let repository = LyricsRepository(providers: [first, second], cache: cache)

        let result = try await repository.lyrics(for: track)

        XCTAssertEqual(result, makeLyrics("de A"))
        XCTAssertEqual(second.callCount, 0, "No hay que consultar el respaldo si el primero respondió")
    }

    func testFallsThroughWhenFirstProviderHasNothing() async throws {
        let first = FakeProvider(displayName: "A", result: .success(.notFound))
        let second = FakeProvider(displayName: "B", result: .success(makeLyrics("de B")))
        let repository = LyricsRepository(providers: [first, second], cache: cache)

        let result = try await repository.lyrics(for: track)

        XCTAssertEqual(result, makeLyrics("de B"))
        XCTAssertEqual(first.callCount, 1)
    }

    func testFallsThroughWhenFirstProviderThrows() async throws {
        let first = FakeProvider(displayName: "A", result: .failure(HTTPError.status(500)))
        let second = FakeProvider(displayName: "B", result: .success(makeLyrics("de B")))
        let repository = LyricsRepository(providers: [first, second], cache: cache)

        let result = try await repository.lyrics(for: track)

        XCTAssertEqual(result, makeLyrics("de B"))
    }

    func testCachesSuccessfulLookups() async throws {
        let provider = FakeProvider(displayName: "A", result: .success(makeLyrics("hola")))
        let repository = LyricsRepository(providers: [provider], cache: cache)

        _ = try await repository.lyrics(for: track)
        _ = try await repository.lyrics(for: track)

        XCTAssertEqual(provider.callCount, 1, "La segunda consulta tiene que salir de la caché")
    }

    func testDoesNotCacheNotFoundWhenAProviderFailed() async throws {
        // Si el "no encontrado" viene de un error de red, guardarlo dejaría
        // la canción sin letra durante días.
        let provider = FakeProvider(displayName: "A", result: .failure(HTTPError.transport("sin red")))
        let repository = LyricsRepository(providers: [provider], cache: cache)

        do {
            _ = try await repository.lyrics(for: track)
            XCTFail("Se esperaba un error")
        } catch {
            // esperado
        }

        let cached = await cache.value(for: track.cacheKey)
        XCTAssertNil(cached)
    }

    func testCachesGenuineNotFound() async throws {
        let provider = FakeProvider(displayName: "A", result: .success(.notFound))
        let repository = LyricsRepository(providers: [provider], cache: cache)

        _ = try await repository.lyrics(for: track)
        _ = try await repository.lyrics(for: track)

        XCTAssertEqual(provider.callCount, 1)
    }

    func testDeduplicatesConcurrentLookups() async throws {
        // iPhone y CarPlay piden la letra a la vez al cambiar de canción.
        let provider = FakeProvider(displayName: "A", result: .success(makeLyrics("hola")), delay: 0.2)
        let repository = LyricsRepository(providers: [provider], cache: cache)

        async let a = repository.lyrics(for: track)
        async let b = repository.lyrics(for: track)
        async let c = repository.lyrics(for: track)
        _ = try await (a, b, c)

        XCTAssertEqual(provider.callCount, 1, "Sólo debe haber una búsqueda en vuelo por canción")
    }
}
