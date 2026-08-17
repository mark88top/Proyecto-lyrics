import XCTest
@testable import CarLyrics

final class LyricsSynchronizerTests: XCTestCase {
    private func makeSynchronizer() -> LyricsSynchronizer {
        let lines = [
            LyricLine(index: 0, time: 10, text: "Uno"),
            LyricLine(index: 1, time: 20, text: "Dos"),
            LyricLine(index: 2, time: 30, text: "Tres"),
            LyricLine(index: 3, time: 40, text: "Cuatro")
        ]
        return LyricsSynchronizer(lyrics: Lyrics(
            lines: lines,
            isSynced: true,
            sourceName: "Test",
            sourceURL: nil,
            isInstrumental: false
        ))
    }

    func testReturnsNilBeforeFirstLine() {
        XCTAssertNil(makeSynchronizer().index(at: 5))
    }

    func testReturnsLineAtExactBoundary() {
        XCTAssertEqual(makeSynchronizer().index(at: 20), 1)
    }

    func testReturnsPreviousLineBetweenTimestamps() {
        XCTAssertEqual(makeSynchronizer().index(at: 25), 1)
        XCTAssertEqual(makeSynchronizer().index(at: 39.9), 2)
    }

    func testHoldsLastLineAfterTheEnd() {
        XCTAssertEqual(makeSynchronizer().index(at: 500), 3)
    }

    func testAppliesOffset() {
        let sync = makeSynchronizer()
        // Con offset +2 s la letra se atrasa: a los 21 s todavía va la 0.
        XCTAssertEqual(sync.index(at: 21, offset: 2), 0)
        // Con offset negativo se adelanta.
        XCTAssertEqual(sync.index(at: 19, offset: -2), 1)
    }

    func testUnsyncedLyricsHaveNoActiveIndex() {
        let lyrics = Lyrics(
            lines: [LyricLine(index: 0, time: nil, text: "Sin tiempo")],
            isSynced: false,
            sourceName: "Test",
            sourceURL: nil,
            isInstrumental: false
        )
        let sync = LyricsSynchronizer(lyrics: lyrics)

        XCTAssertFalse(sync.isSynced)
        XCTAssertNil(sync.index(at: 100))
    }

    func testWindowIsClampedAtTheEdges() {
        let sync = makeSynchronizer()

        XCTAssertEqual(sync.window(around: 0, radius: 1).map(\.text), ["Uno", "Dos"])
        XCTAssertEqual(sync.window(around: 3, radius: 1).map(\.text), ["Tres", "Cuatro"])
        XCTAssertEqual(sync.window(around: 2, radius: 1).map(\.text), ["Dos", "Tres", "Cuatro"])
    }

    func testProgressWithinLine() {
        let sync = makeSynchronizer()
        XCTAssertEqual(sync.progressWithinLine(at: 25, trackDuration: 60), 0.5, accuracy: 0.001)
        XCTAssertEqual(sync.progressWithinLine(at: 20, trackDuration: 60), 0, accuracy: 0.001)
    }
}
