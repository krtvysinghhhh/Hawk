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

    func testPlaylistStoreAtomicPersistenceAndRecovery() async throws {
        let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent("TestPlaylists_\(UUID().uuidString).json")
        defer {
            try? FileManager.default.removeItem(at: tempURL)
            let backup = tempURL.deletingPathExtension().appendingPathExtension("backup.json")
            try? FileManager.default.removeItem(at: backup)
        }

        let store = PlaylistStore(storageURL: tempURL)
        let pl = await store.createPlaylist(title: "Ambient Chill")
        let song = Song(id: "amb_1", title: "Weightless", artist: "Marconi Union", duration: 480)
        await store.addSong(to: pl.id, song: song)

        let loaded = await store.getPlaylist(id: pl.id)
        XCTAssertEqual(loaded?.songs.count, 1)
        XCTAssertEqual(loaded?.songs.first?.id, "amb_1")

        // Test corruption recovery: corrupt file, recreate store, ensure it recovers without crashing
        try "corrupted_garbage_data".write(to: tempURL, atomically: true, encoding: .utf8)
        let recoveredStore = PlaylistStore(storageURL: tempURL)
        let favs = await recoveredStore.getFavorites()
        XCTAssertTrue(favs.isFavorites)
    }

    func testTrackDeduplication() {
        let s1 = Song(id: "s1", title: "Blinding Lights", artist: "The Weeknd", duration: 200, sourceId: "yt")
        let s2 = Song(id: "s2", title: "Blinding Lights", artist: "The Weeknd", duration: 201, sourceId: "saavn")
        let s3 = Song(id: "s3", title: "Save Your Tears", artist: "The Weeknd", duration: 215, sourceId: "yt")

        let deduped = TrackDeduplicator.deduplicate([s1, s2, s3])
        XCTAssertEqual(deduped.count, 2)
    }
}
