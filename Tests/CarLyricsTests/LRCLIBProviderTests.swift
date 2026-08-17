import XCTest
@testable import CarLyrics

final class LRCLIBProviderTests: XCTestCase {
    private let base = URL(string: "https://lrclib.net")!

    private func track(duration: TimeInterval = 354) -> Track {
        Track(
            id: "spotify:track:1",
            title: "Bohemian Rhapsody - Remastered 2011",
            artist: "Queen",
            album: "A Night at the Opera",
            duration: duration,
            artworkURL: nil
        )
    }

    private func makeProvider(_ session: StubHTTPSession) -> LRCLIBProvider {
        LRCLIBProvider(client: HTTPClient(session: session, userAgent: "tests"), baseURL: base)
    }

    func testReturnsSyncedLyricsFromExactMatch() async throws {
        let session = StubHTTPSession()
        session.stub("api/get", json: """
        {
          "id": 1,
          "trackName": "Bohemian Rhapsody",
          "artistName": "Queen",
          "duration": 354.0,
          "instrumental": false,
          "plainLyrics": "Is this the real life",
          "syncedLyrics": "[00:00.50]Is this the real life\\n[00:05.00]Is this just fantasy"
        }
        """)

        let result = try await makeProvider(session).lyrics(for: track())

        guard case .found(let lyrics) = result else {
            return XCTFail("Se esperaba una letra, llegó \(result)")
        }
        XCTAssertTrue(lyrics.isSynced)
        XCTAssertEqual(lyrics.lines.count, 2)
        XCTAssertEqual(lyrics.sourceName, "LRCLIB")
    }

    func testSendsNormalizedTitleAndArtist() async throws {
        let session = StubHTTPSession()
        session.stub("api/get", json: """
        { "id": 1, "instrumental": false, "plainLyrics": "hola", "syncedLyrics": null }
        """)

        _ = try await makeProvider(session).lyrics(for: track())

        let url = try XCTUnwrap(session.requestedURLs.first)
        XCTAssertTrue(url.contains("track_name=Bohemian%20Rhapsody"), url)
        XCTAssertFalse(url.contains("Remastered"), url)
    }

    func testFallsBackToSearchWhenExactMatchIs404() async throws {
        let session = StubHTTPSession()
        session.stub("api/get", statusCode: 404)
        session.stub("api/search", json: """
        [
          { "id": 9, "duration": 540.0, "instrumental": false, "plainLyrics": "version en vivo", "syncedLyrics": null },
          { "id": 8, "duration": 355.0, "instrumental": false, "plainLyrics": "version de estudio", "syncedLyrics": null }
        ]
        """)

        let result = try await makeProvider(session).lyrics(for: track())

        guard case .found(let lyrics) = result else {
            return XCTFail("Se esperaba una letra, llegó \(result)")
        }
        // Debe elegir la de duración parecida, no la primera de la lista.
        XCTAssertEqual(lyrics.plainText, "version de estudio")
        XCTAssertFalse(lyrics.isSynced)
    }

    func testPrefersSyncedCandidateOverCloserDuration() async throws {
        let session = StubHTTPSession()
        session.stub("api/get", statusCode: 404)
        session.stub("api/search", json: """
        [
          { "id": 1, "duration": 354.0, "instrumental": false, "plainLyrics": "sin sincronizar", "syncedLyrics": null },
          { "id": 2, "duration": 358.0, "instrumental": false, "plainLyrics": "x", "syncedLyrics": "[00:01.00]sincronizada" }
        ]
        """)

        let result = try await makeProvider(session).lyrics(for: track())

        guard case .found(let lyrics) = result else {
            return XCTFail("Se esperaba una letra, llegó \(result)")
        }
        XCTAssertTrue(lyrics.isSynced)
    }

    func testRejectsCandidatesWithWildlyDifferentDuration() async throws {
        let session = StubHTTPSession()
        session.stub("api/get", statusCode: 404)
        session.stub("api/search", json: """
        [ { "id": 1, "duration": 60.0, "instrumental": false, "plainLyrics": "otra cancion", "syncedLyrics": null } ]
        """)

        let result = try await makeProvider(session).lyrics(for: track(duration: 354))

        XCTAssertEqual(result, .notFound)
    }

    func testReportsInstrumentalTracks() async throws {
        let session = StubHTTPSession()
        session.stub("api/get", json: """
        { "id": 1, "duration": 354.0, "instrumental": true, "plainLyrics": null, "syncedLyrics": null }
        """)

        let result = try await makeProvider(session).lyrics(for: track())

        XCTAssertEqual(result, .instrumental)
    }

    func testReturnsNotFoundWhenNothingMatches() async throws {
        let session = StubHTTPSession()
        session.stub("api/get", statusCode: 404)
        session.stub("api/search", json: "[]")

        let result = try await makeProvider(session).lyrics(for: track())

        XCTAssertEqual(result, .notFound)
    }

    func testPropagatesTransportErrors() async {
        let session = StubHTTPSession()
        session.stub("api/get", statusCode: 500)

        do {
            _ = try await makeProvider(session).lyrics(for: track())
            XCTFail("Se esperaba un error")
        } catch {
            XCTAssertEqual(error as? HTTPError, .status(500))
        }
    }
}
