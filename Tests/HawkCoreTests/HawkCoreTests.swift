import XCTest
@testable import HawkCore

final class HawkCoreTests: XCTestCase {

    func testSongFormatting() {
        let song = Song(
            id: "test_vid_123",
            title: "Midnight City",
            artist: "M83",
            duration: 243.0
        )

        XCTAssertEqual(song.id, "test_vid_123")
        XCTAssertEqual(song.title, "Midnight City")
        XCTAssertEqual(song.durationText, "4:03")
        XCTAssertEqual(song.queueTier, .context)
    }

    func testQueueMetadata() {
        let original = Song(
            id: "vid_1",
            title: "Track 1",
            artist: "Artist 1",
            queueTier: .context
        )

        let modified = original.withQueueMetadata(tier: .userQueue)
        XCTAssertEqual(modified.queueTier, .userQueue)
        XCTAssertEqual(modified.id, original.id)
        XCTAssertNotEqual(modified.queueEntryId, original.queueEntryId)
    }

    func testAudioQualityCeilings() {
        XCTAssertEqual(AudioQuality.low.maxKbps, 96)
        XCTAssertEqual(AudioQuality.standard.maxKbps, 160)
        XCTAssertEqual(AudioQuality.high.maxKbps, 320)
        XCTAssertEqual(AudioQuality.lossless.maxKbps, Int.max)
    }

    func testFavoritesPlaylist() {
        let favs = Playlist.favoritesPlaylist()
        XCTAssertTrue(favs.isFavorites)
        XCTAssertEqual(favs.id, Playlist.favoritesId)
    }
}
