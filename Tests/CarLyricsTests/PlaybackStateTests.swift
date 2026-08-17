import XCTest
@testable import CarLyrics

final class PlaybackStateTests: XCTestCase {
    private let track = Track(
        id: "spotify:track:1", title: "T", artist: "A", album: "B",
        duration: 120, artworkURL: nil
    )

    func testInterpolatesWhilePlaying() {
        let state = PlaybackState(track: track, isPlaying: true, position: 10, timestamp: 1000)
        XCTAssertEqual(state.estimatedPosition(at: 1005), 15, accuracy: 0.001)
    }

    func testFreezesWhilePaused() {
        let state = PlaybackState(track: track, isPlaying: false, position: 10, timestamp: 1000)
        XCTAssertEqual(state.estimatedPosition(at: 1005), 10, accuracy: 0.001)
    }

    func testNeverExceedsTrackDuration() {
        let state = PlaybackState(track: track, isPlaying: true, position: 110, timestamp: 1000)
        XCTAssertEqual(state.estimatedPosition(at: 1100), 120, accuracy: 0.001)
    }

    func testHandlesClockGoingBackwards() {
        let state = PlaybackState(track: track, isPlaying: true, position: 10, timestamp: 1000)
        XCTAssertEqual(state.estimatedPosition(at: 900), 10, accuracy: 0.001)
    }
}
