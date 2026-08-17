import XCTest
@testable import CarLyrics

final class LyricsCacheTests: XCTestCase {
    private var cache: LyricsCache!

    override func setUp() async throws {
        cache = LyricsCache()
        await cache.clear()
    }

    override func tearDown() async throws {
        await cache.clear()
    }

    func testStoresAndReadsLyrics() async {
        let lyrics = Lyrics(
            lines: [LyricLine(index: 0, time: 1, text: "hola")],
            isSynced: true, sourceName: "Test", sourceURL: nil, isInstrumental: false
        )
        await cache.store(.found(lyrics), for: "clave")

        let result = await cache.value(for: "clave")

        XCTAssertEqual(result, .found(lyrics))
    }

    func testStoresNegativeResults() async {
        await cache.store(.notFound, for: "clave")
        XCTAssertEqual(await cache.value(for: "clave"), .notFound)
    }

    func testStoresInstrumentalResults() async {
        await cache.store(.instrumental, for: "clave")
        XCTAssertEqual(await cache.value(for: "clave"), .instrumental)
    }

    func testReturnsNilForUnknownKeys() async {
        XCTAssertNil(await cache.value(for: "no-existe"))
    }

    func testClearRemovesEverything() async {
        await cache.store(.notFound, for: "clave")
        await cache.clear()
        XCTAssertNil(await cache.value(for: "clave"))
    }

    func testSurvivesANewCacheInstance() async {
        let lyrics = Lyrics(
            lines: [LyricLine(index: 0, time: 1, text: "persistida")],
            isSynced: true, sourceName: "Test", sourceURL: nil, isInstrumental: false
        )
        await cache.store(.found(lyrics), for: "persistencia")

        // Una instancia nueva simula reabrir la app: tiene que leer del disco.
        let reopened = LyricsCache()
        XCTAssertEqual(await reopened.value(for: "persistencia"), .found(lyrics))
        await reopened.clear()
    }
}
