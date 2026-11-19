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

    func testRecommendationDeterministicScoring() async {
        let recEngine = RecommendationEngine()

        let candidateFav = Song(id: "c_fav", title: "Liked Song", artist: "Artist 1")
        let candidatePlayed = Song(id: "c_play", title: "Heavy Play", artist: "Artist 2")
        let candidateSkipped = Song(id: "c_skip", title: "Skipped Song", artist: "Artist 3")
        let candidateDisliked = Song(id: "c_dislike", title: "Disliked Song", artist: "Artist 4")

        // 1. Record a skip (<30s) on c_skip
        await recEngine.recordSkip(songId: "c_skip", durationBeforeSkip: 10.0)

        // 2. Record explicit dislike on c_dislike
        await recEngine.dislikeTrack(songId: "c_dislike")

        // 3. Setup monthly bucket with 5 plays on c_play
        var bucket = MonthlyBucket(monthKey: "2026-11")
        bucket.tracks["c_play"] = TrackPlayStat(songId: "c_play", title: "Heavy Play", artist: "Artist 2", playCount: 5, totalSeconds: 600)

        let scored = await recEngine.scoreCandidates(
            candidates: [candidateFav, candidatePlayed, candidateSkipped, candidateDisliked],
            history: [],
            favorites: [candidateFav],
            monthlyBucket: bucket
        )

        // c_dislike must be completely excluded
        XCTAssertFalse(scored.contains { $0.song.id == "c_dislike" })

        // c_fav has 50 points from favorites
        let favItem = scored.first { $0.song.id == "c_fav" }
        XCTAssertEqual(favItem?.score, 50.0)
        XCTAssertEqual(favItem?.reason, "From your Liked Songs")

        // c_play has 5 plays * 10 = 50 + 10 points duration = 60.0
        let playItem = scored.first { $0.song.id == "c_play" }
        XCTAssertGreaterThan(playItem?.score ?? 0, 50.0)

        // c_skip has penalty (-25.0)
        let skipItem = scored.first { $0.song.id == "c_skip" }
        XCTAssertEqual(skipItem?.score, -25.0)
    }
}
