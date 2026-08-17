import XCTest
@testable import CarLyrics

final class LRCParserTests: XCTestCase {
    func testParsesBasicSyncedLyrics() {
        let raw = """
        [00:12.00]Primera línea
        [00:17.20]Segunda línea
        [00:21.10]Tercera línea
        """

        let lines = LRCParser.parse(raw)

        XCTAssertEqual(lines.count, 3)
        XCTAssertEqual(lines[0].time ?? -1, 12, accuracy: 0.001)
        XCTAssertEqual(lines[1].time ?? -1, 17.2, accuracy: 0.001)
        XCTAssertEqual(lines[2].text, "Tercera línea")
        XCTAssertEqual(lines.map(\.index), [0, 1, 2])
    }

    func testExpandsRepeatedTimestampsOnSameLine() {
        // Los estribillos se codifican con varias marcas en una sola línea.
        let raw = "[00:10.00][01:30.00][02:50.00]Estribillo"

        let lines = LRCParser.parse(raw)

        XCTAssertEqual(lines.count, 3)
        XCTAssertEqual(lines.map(\.text), Array(repeating: "Estribillo", count: 3))
        XCTAssertEqual(lines[1].time ?? -1, 90, accuracy: 0.001)
    }

    func testSortsOutOfOrderTimestamps() {
        let raw = """
        [01:00.00]Segunda
        [00:30.00]Primera
        """

        let lines = LRCParser.parse(raw)

        XCTAssertEqual(lines.map(\.text), ["Primera", "Segunda"])
        XCTAssertEqual(lines[0].index, 0)
    }

    func testSkipsMetadataButAppliesOffset() {
        let raw = """
        [ar:Queen]
        [ti:Bohemian Rhapsody]
        [offset:+500]
        [00:10.00]Is this the real life
        """

        let lines = LRCParser.parse(raw)

        XCTAssertEqual(lines.count, 1)
        // offset positivo = adelantar la letra medio segundo.
        XCTAssertEqual(lines[0].time ?? -1, 9.5, accuracy: 0.001)
    }

    func testFallsBackToPlainTextWhenThereAreNoTimestamps() {
        let raw = """
        Primera línea
        Segunda línea
        """

        let lines = LRCParser.parse(raw)

        XCTAssertEqual(lines.count, 2)
        XCTAssertNil(lines[0].time)
        XCTAssertEqual(lines[1].text, "Segunda línea")
    }

    func testParsesColonFractionFormat() {
        XCTAssertEqual(LRCParser.seconds(fromTimestamp: "01:02:50") ?? -1, 62.5, accuracy: 0.001)
        XCTAssertEqual(LRCParser.seconds(fromTimestamp: "00:05.25") ?? -1, 5.25, accuracy: 0.001)
        XCTAssertEqual(LRCParser.seconds(fromTimestamp: "02:00") ?? -1, 120, accuracy: 0.001)
        XCTAssertNil(LRCParser.seconds(fromTimestamp: "no-es-un-tiempo"))
    }

    func testIgnoresEmptyLines() {
        let raw = "[00:01.00]Uno\n\n\n[00:02.00]Dos"
        XCTAssertEqual(LRCParser.parse(raw).count, 2)
    }
}
