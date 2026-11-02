import XCTest
@testable import HawkStats
@testable import HawkCore

final class HawkStatsTests: XCTestCase {

    func testBucketSorting() {
        var bucket = MonthlyBucket(monthKey: "2026-11")

        bucket.tracks["t1"] = TrackPlayStat(songId: "t1", title: "Song 1", artist: "Artist A", playCount: 5)
        bucket.tracks["t2"] = TrackPlayStat(songId: "t2", title: "Song 2", artist: "Artist B", playCount: 15)

        bucket.artists["Artist A"] = ArtistPlayStat(name: "Artist A", playCount: 5)
        bucket.artists["Artist B"] = ArtistPlayStat(name: "Artist B", playCount: 15)

        let topTracks = bucket.topTracks
        XCTAssertEqual(topTracks.first?.songId, "t2")
        XCTAssertEqual(topTracks.first?.playCount, 15)

        let topArtists = bucket.topArtists
        XCTAssertEqual(topArtists.first?.name, "Artist B")
    }

    func testRecorderPause() async {
        let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        let recorder = ListeningStatsRecorder(storageDirectory: tempDir)

        let song = Song(id: "s_rec", title: "Test Song", artist: "Test Artist", duration: 180)

        // Sample when paused should not record time
        await recorder.onSample(song: song, isPlaying: false)

        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM"
        let currentMonth = formatter.string(from: Date())

        let bucket = await recorder.getMonthlyReplay(monthKey: currentMonth)
        XCTAssertTrue(bucket == nil || bucket?.totalListeningSeconds == 0)
    }
}
