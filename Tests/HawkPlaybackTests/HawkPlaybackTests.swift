import XCTest
@testable import HawkPlayback
@testable import HawkCore

final class HawkPlaybackTests: XCTestCase {

    func testQueueTierPriority() async {
        let q = QueueManager()

        let contextTrack1 = Song(id: "c1", title: "Context 1", artist: "Artist A")
        let contextTrack2 = Song(id: "c2", title: "Context 2", artist: "Artist A")
        await q.setContext(songs: [contextTrack1, contextTrack2])

        let userTrack = Song(id: "u1", title: "User Pick", artist: "Artist B")
        await q.playNext(song: userTrack)

        let timeline = await q.fullTimeline
        XCTAssertEqual(timeline.count, 3)
        XCTAssertEqual(timeline[0].id, "u1")
        XCTAssertEqual(timeline[0].queueTier, .userQueue)
        XCTAssertEqual(timeline[1].id, "c1")
    }

    func testQueueNavigation() async {
        let q = QueueManager()
        let song1 = Song(id: "s1", title: "Song 1", artist: "A")
        let song2 = Song(id: "s2", title: "Song 2", artist: "A")

        await q.setContext(songs: [song1, song2])
        let curIdx = await q.currentIndex
        XCTAssertEqual(curIdx, 0)

        let nextSong = await q.next()
        XCTAssertEqual(nextSong?.id, "s2")
        let newIdx = await q.currentIndex
        XCTAssertEqual(newIdx, 1)

        let atEnd = await q.next()
        XCTAssertNil(atEnd)
    }

    @MainActor
    func testEqualizerPresets() {
        let eq = EqualizerManager()
        eq.applyPreset(.bassBooster)

        XCTAssertEqual(eq.currentPreset.name, "Bass Booster")
        XCTAssertEqual(eq.customGains[0], 6.0)
    }

    func testCrossfadeDurationClamping() async {
        let engine = HawkAudioEngine()
        await engine.setCrossfadeDuration(25.0)
        let dur = await engine.crossfadeDuration
        XCTAssertEqual(dur, 12.0)

        await engine.setCrossfadeDuration(-5.0)
        let durMin = await engine.crossfadeDuration
        XCTAssertEqual(durMin, 0.0)
    }

    func testPlaybackStateTransitions() async {
        let engine = HawkAudioEngine()
        let initial = await engine.playbackState
        XCTAssertFalse(initial.isPlaying)

        await engine.pause()
        let pausedState = await engine.playbackState
        XCTAssertFalse(pausedState.isPlaying)
    }

    func testStopResetsPlaybackStateToIdleAndClearsPlayers() async {
        let engine = HawkAudioEngine()
        await engine.stop()
        let state = await engine.playbackState
        XCTAssertEqual(state, .idle)
        let standbyItem = await engine.standbyPlayerItem
        XCTAssertNil(standbyItem)
        let isStandbyPlaying = await engine.isStandbyPlaying
        XCTAssertFalse(isStandbyPlaying)
    }

    func testPauseStopsStandbyPlayer() async {
        let engine = HawkAudioEngine()
        await engine.pause()
        let isStandbyPlaying = await engine.isStandbyPlaying
        XCTAssertFalse(isStandbyPlaying)
    }

    func testMonotonicPlayRequestIdIncrements() async {
        let engine = HawkAudioEngine()
        let initialId = await engine.activePlayRequestId
        let song1 = Song(id: "s1", title: "Song 1", artist: "Artist 1")
        // Invoking play on invalid media will reject/fail but advance request ID
        try? await engine.play(song: song1)
        let nextId = await engine.activePlayRequestId
        XCTAssertGreaterThan(nextId, initialId)
    }
}
