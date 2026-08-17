import XCTest
@testable import CarLyrics

/// La normalización del título es lo que decide si encontramos la letra o no:
/// LRCLIB indexa "Bohemian Rhapsody", no "Bohemian Rhapsody - Remastered 2011".
final class TrackNormalizationTests: XCTestCase {
    private func track(title: String, artist: String = "Queen", duration: TimeInterval = 300) -> Track {
        Track(id: "spotify:track:x", title: title, artist: artist, album: "A", duration: duration, artworkURL: nil)
    }

    func testStripsRemasterSuffix() {
        XCTAssertEqual(track(title: "Bohemian Rhapsody - Remastered 2011").searchTitle, "Bohemian Rhapsody")
    }

    func testStripsRadioEditSuffix() {
        XCTAssertEqual(track(title: "Titanium - Radio Edit").searchTitle, "Titanium")
    }

    func testStripsFeatParentheses() {
        XCTAssertEqual(track(title: "Titanium (feat. Sia)").searchTitle, "Titanium")
    }

    func testKeepsMeaningfulDashes() {
        // "Stop - Time" no es un sufijo de edición: hay que conservarlo.
        XCTAssertEqual(track(title: "Stop - Time").searchTitle, "Stop - Time")
    }

    func testKeepsMeaningfulParentheses() {
        XCTAssertEqual(
            track(title: "Everything (I Do) I Do It for You").searchTitle,
            "Everything (I Do) I Do It for You"
        )
    }

    func testTakesPrimaryArtist() {
        XCTAssertEqual(track(title: "X", artist: "David Guetta, Sia").primaryArtist, "David Guetta")
        XCTAssertEqual(track(title: "X", artist: "Queen & David Bowie").primaryArtist, "Queen")
    }

    func testCacheKeyIgnoresIrrelevantDifferences() {
        let a = track(title: "Song - Remastered", artist: "Queen", duration: 200.4)
        let b = track(title: "song", artist: "queen", duration: 200.2)
        XCTAssertEqual(a.cacheKey, b.cacheKey)
    }

    func testCacheKeySeparatesDifferentDurations() {
        let studio = track(title: "Song", duration: 200)
        let live = track(title: "Song", duration: 540)
        XCTAssertNotEqual(studio.cacheKey, live.cacheKey)
    }
}
