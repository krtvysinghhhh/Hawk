import Foundation
import HawkCore
import HawkSecurity
import HawkNetworking
import HawkSources
import HawkPlayback
import HawkLyrics
import HawkStats

@MainActor
func runAllVerifications() async {
    print("==================================================")
    print("    PROJECT HAWK — AUTOMATED VERIFICATION SUITE   ")
    print("==================================================")
    var passed = 0
    var failed = 0

    func assertTest(_ name: String, _ condition: Bool) {
        if condition {
            print("  ✓ PASS: \(name)")
            passed += 1
        } else {
            print("  ✗ FAIL: \(name)")
            failed += 1
        }
    }

    // 1. HawkCore Domain Tests
    print("\n[1/7] Testing HawkCore Domain Models...")
    let song = Song(
        id: "vid_test_101",
        title: "Starboy",
        artist: "The Weeknd",
        duration: 230.0
    )
    assertTest("Song ID and properties", song.id == "vid_test_101" && song.title == "Starboy")
    assertTest("Song duration formatting (230s -> 3:50)", song.durationText == "3:50")

    let queuedSong = song.withQueueMetadata(tier: .userQueue)
    assertTest("Queue tier mutation immutability", queuedSong.queueTier == .userQueue && queuedSong.id == song.id)
    assertTest("Audio quality ceilings", AudioQuality.high.maxKbps == 320 && AudioQuality.lossless.maxKbps == Int.max)

    // 2. HawkSecurity & Crypto Tests
    print("\n[2/7] Testing HawkSecurity & Crypto...")
    let sapisidHash = CryptoUtils.generateSapisidHash(
        sapisid: "demo_sapisid",
        origin: "https://music.youtube.com",
        timestamp: 1700000000
    )
    assertTest("SAPISIDHASH prefix and format", sapisidHash.hasPrefix("SAPISIDHASH 1700000000_"))

    let sha256 = CryptoUtils.sha256Hex("HAWK")
    assertTest("SHA256 hex digest length (64 chars)", sha256.count == 64)

    let keyStore = KeychainStore(serviceName: "com.hawk.verify")
    try? await keyStore.saveString(key: "auth_token", value: "secret_value_123")
    let retrieved = try? await keyStore.readString(key: "auth_token")
    assertTest("Keychain store save and read", retrieved == "secret_value_123")

    // 3. HawkSources & Track Matcher Tests
    print("\n[3/7] Testing HawkSources & Matcher...")
    let exactScore = TrackMatcher.matchScore(
        titleA: "Blinding Lights",
        artistA: "The Weeknd",
        durationA: 200.0,
        titleB: "Blinding Lights",
        artistB: "The Weeknd",
        durationB: 200.0
    )
    assertTest("TrackMatcher exact match confidence >= 0.9", exactScore >= 0.9)

    let mismatchScore = TrackMatcher.matchScore(
        titleA: "Blinding Lights",
        artistA: "The Weeknd",
        durationA: 200.0,
        titleB: "Another Song",
        artistB: "Another Artist",
        durationB: 350.0
    )
    assertTest("TrackMatcher mismatch confidence < 0.3", mismatchScore < 0.3)

    let localSource = LocalLibrarySource()
    assertTest("LocalLibrarySource registered", localSource.sourceId == "local")

    // 4. HawkPlayback & Multi-Tier Queue Tests
    print("\n[4/7] Testing HawkPlayback 3-Tier Queue Engine...")
    let queue = QueueManager.shared
    await queue.clearQueue()

    let c1 = Song(id: "c1", title: "Context 1", artist: "Artist A")
    let c2 = Song(id: "c2", title: "Context 2", artist: "Artist A")
    await queue.setContext(songs: [c1, c2])

    let u1 = Song(id: "u1", title: "User Added", artist: "Artist B")
    await queue.playNext(song: u1)

    let timeline = await queue.fullTimeline
    assertTest("Queue timeline has 3 items", timeline.count == 3)
    assertTest("User-queued song placed at index 0 ahead of context", timeline[0].id == "u1" && timeline[0].queueTier == .userQueue)
    assertTest("Contextual track follows at index 1", timeline[1].id == "c1" && timeline[1].queueTier == .context)

    let nextTrack = await queue.next()
    assertTest("Queue next() navigation advances correctly", nextTrack?.id == "c1")

    // 5. Equalizer Presets Tests
    print("\n[5/7] Testing Equalizer Presets...")
    let eq = EqualizerManager.shared
    eq.applyPreset(.bassBooster)
    assertTest("Equalizer preset Bass Booster loaded", eq.currentPreset.name == "Bass Booster")
    assertTest("Equalizer low-band gain boosted (+6dB)", eq.customGains[0] == 6.0)

    // 6. HawkLyrics & LRC Parser Tests
    print("\n[6/7] Testing HawkLyrics Engine...")
    let sampleLrc = """
    [00:15.50]Hello from HAWK
    [01:02.00]Synchronized Apple Music lyrics
    [02:10.75]Pure native Swift audio
    """
    let parsedLyrics = LrcParser.parse(sampleLrc)
    assertTest("LRC parsed 3 lines", parsedLyrics.count == 3)
    assertTest("LRC line 0 timestamp (15.5s)", abs(parsedLyrics[0].timestamp - 15.5) < 0.01)
    assertTest("LRC line 0 text match", parsedLyrics[0].text == "Hello from HAWK")

    // 7. HawkStats Listening Recorder Tests
    print("\n[7/7] Testing HawkStats Wall-Clock Recorder...")
    let statsDir = FileManager.default.temporaryDirectory.appendingPathComponent("HawkVerifyStats_\(UUID().uuidString)")
    let statsRecorder = ListeningStatsRecorder(storageDirectory: statsDir)

    // Test playback sampling with two ticks
    let testPlaySong = Song(id: "stat_track_1", title: "Song One", artist: "Artist One", duration: 100)
    await statsRecorder.onSample(song: testPlaySong, isPlaying: true)
    try? await Task.sleep(nanoseconds: 100_000_000) // 0.1s tick interval
    await statsRecorder.onSample(song: testPlaySong, isPlaying: true)

    let formatter = DateFormatter()
    formatter.dateFormat = "yyyy-MM"
    let month = formatter.string(from: Date())

    let bucket = await statsRecorder.getMonthlyReplay(monthKey: month)
    assertTest("Monthly aggregate bucket created", bucket != nil)

    print("\n==================================================")
    print("  VERIFICATION RESULT: \(passed) PASSED, \(failed) FAILED")
    print("==================================================")
    if failed > 0 {
        exit(1)
    }
}

Task { @MainActor in
    await runAllVerifications()
    exit(0)
}

dispatchMain()
