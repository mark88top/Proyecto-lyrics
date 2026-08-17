import XCTest
import CarPlay
@testable import CarLyrics

/// Lo que se ve en el auto es lo más caro de verificar a mano, así que la
/// lógica está en un struct puro y se prueba acá.
final class CarPlayLyricsBoardTests: XCTestCase {
    private let track = Track(
        id: "spotify:track:1", title: "Song", artist: "Artist", album: "Album",
        duration: 200, artworkURL: nil
    )

    private func snapshot(activeIndex: Int?, count: Int = 6) -> LyricsSnapshot {
        LyricsSnapshot(
            lines: (0..<count).map { LyricLine(index: $0, time: TimeInterval($0) * 10, text: "Línea \($0)") },
            activeIndex: activeIndex,
            isSynced: true,
            sourceName: "LRCLIB",
            sourceURL: nil
        )
    }

    private func board(
        _ state: LyricsViewState,
        isAuthorized: Bool = true,
        visibleLines: Int = 3
    ) -> CarPlayLyricsBoard {
        CarPlayLyricsBoard(
            lyricsState: state,
            playback: PlaybackState(track: track, isPlaying: true, position: 30, timestamp: 0),
            connection: .connected(sourceName: "test"),
            isAuthorized: isAuthorized,
            visibleLines: visibleLines
        )
    }

    func testShowsConnectPromptWhenSignedOut() {
        let sections = board(.idle, isAuthorized: false).makeSections()

        XCTAssertEqual(sections.count, 1)
        XCTAssertEqual(sections[0].items.count, 1)
    }

    func testShowsWindowAroundActiveLine() {
        let sections = board(.ready(snapshot(activeIndex: 3))).makeSections()

        // Sección 0 = cabecera con el tema; sección 1 = la letra.
        XCTAssertEqual(sections.count, 2)
        XCTAssertEqual(sections[1].items.count, 3)
    }

    func testWindowIsClampedAtTheStart() {
        let sections = board(.ready(snapshot(activeIndex: 0))).makeSections()

        // Al principio no hay línea anterior: quedan 2, no 3.
        XCTAssertEqual(sections[1].items.count, 2)
    }

    func testWindowIsClampedAtTheEnd() {
        let sections = board(.ready(snapshot(activeIndex: 5, count: 6))).makeSections()

        XCTAssertEqual(sections[1].items.count, 2)
    }

    func testSingleLineModeShowsOnlyTheActiveLine() {
        let sections = board(.ready(snapshot(activeIndex: 3)), visibleLines: 1).makeSections()

        XCTAssertEqual(sections[1].items.count, 1)
    }

    func testFiveLineModeShowsFive() {
        let sections = board(.ready(snapshot(activeIndex: 3, count: 12)), visibleLines: 5).makeSections()

        XCTAssertEqual(sections[1].items.count, 5)
    }

    func testIdentityChangesWithActiveLine() {
        let first = board(.ready(snapshot(activeIndex: 2))).identity
        let second = board(.ready(snapshot(activeIndex: 3))).identity

        XCTAssertNotEqual(first, second)
    }

    func testIdentityIsStableWhenNothingRelevantChanged() {
        // Es la garantía de que no repintamos la pantalla del auto de gusto.
        let first = board(.ready(snapshot(activeIndex: 2))).identity
        let second = board(.ready(snapshot(activeIndex: 2))).identity

        XCTAssertEqual(first, second)
    }

    func testIdentityChangesWithVisibleLineSetting() {
        XCTAssertNotEqual(
            board(.ready(snapshot(activeIndex: 2)), visibleLines: 3).identity,
            board(.ready(snapshot(activeIndex: 2)), visibleLines: 5).identity
        )
    }

    func testUnsyncedLyricsShowPreviewWithoutTracking() {
        let unsynced = LyricsSnapshot(
            lines: (0..<10).map { LyricLine(index: $0, time: nil, text: "L\($0)") },
            activeIndex: nil,
            isSynced: false,
            sourceName: "LRCLIB",
            sourceURL: nil
        )

        let sections = board(.ready(unsynced)).makeSections()

        XCTAssertEqual(sections[1].items.count, 3)
    }

    func testNoItemIsTappableWhileDriving() {
        let sections = board(.ready(snapshot(activeIndex: 2))).makeSections()

        for section in sections {
            for item in section.items {
                let listItem = try? XCTUnwrap(item as? CPListItem)
                XCTAssertEqual(listItem?.isEnabled, false)
            }
        }
    }
}
