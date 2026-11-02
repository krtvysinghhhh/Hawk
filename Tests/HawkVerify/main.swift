import Foundation
import AVFoundation
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

    // 1. HawkCore Domain & PlaylistStore Tests
    print("\n[1/8] Testing HawkCore Domain & PlaylistStore...")
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

    let tempPlaylistURL = FileManager.default.temporaryDirectory.appendingPathComponent("TestPlaylists_\(UUID().uuidString).json")
    let playlistStore = PlaylistStore(storageURL: tempPlaylistURL)
    let created = await playlistStore.createPlaylist(title: "Synthwave Vibes")
    assertTest("PlaylistStore creates custom playlist", created.title == "Synthwave Vibes")

    await playlistStore.addSong(to: created.id, song: song)
    let fetched = await playlistStore.getPlaylist(id: created.id)
    assertTest("Song added to playlist", fetched?.songs.count == 1 && fetched?.songs.first?.id == song.id)

    let isFav = await playlistStore.toggleFavorite(song: song)
    assertTest("PlaylistStore toggleFavorite adds to Favorites", isFav == true)
    let favCheck = await playlistStore.isFavorite(songId: song.id)
    assertTest("PlaylistStore isFavorite verified", favCheck == true)

    // 2. HawkSecurity & Crypto Tests
    print("\n[2/8] Testing HawkSecurity & Crypto...")
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

    // Test JioSaavn DES Decryption
    let testEncryptedMedia = "ID2ieOjCrwfgWvL5sXl4B1ImC5QfbsDyF/c5nqlFTXM0C74GbTF9AaylMpcN37HtcTaLl9ufWl/TC2QaaKAJJBw7tS9a8Gtq"
    let decryptedStreamUrl = try? CryptoUtils.decryptJioSaavnUrl(encryptedUrl: testEncryptedMedia)
    assertTest("JioSaavn DES Decryption with 38346591 key", decryptedStreamUrl?.contains("saavncdn.com") == true)

    // 3. HawkSources, Deduplication & Track Matcher Tests
    print("\n[3/8] Testing HawkSources & Matcher...")
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

    // Deduplication and Version Preservation Test
    let songOriginalA = Song(id: "saavn_1", title: "Blinding Lights", artist: "The Weeknd", duration: 200.0, artworkURL: URL(string: "https://example.com/art.jpg"))
    let songOriginalB = Song(id: "yt_1", title: "Blinding Lights (Official Video)", artist: "The Weeknd", duration: 200.0, artworkURL: nil)
    let songRemix = Song(id: "yt_2", title: "Blinding Lights (Chromatics Remix)", artist: "The Weeknd", duration: 260.0)
    let songLive = Song(id: "yt_3", title: "Blinding Lights (Live at Super Bowl)", artist: "The Weeknd", duration: 230.0)

    let deduplicated = TrackDeduplicator.deduplicate([songOriginalA, songOriginalB, songRemix, songLive])
    assertTest("Deduplicator merged duplicate original records (count: 3)", deduplicated.count == 3)
    assertTest("Deduplicator retained artwork from primary candidate", deduplicated.first?.artworkURL != nil)
    assertTest("Deduplicator preserved Remix version", deduplicated.contains(where: { $0.version == "Remix" }))
    assertTest("Deduplicator preserved Live version", deduplicated.contains(where: { $0.version == "Live" }))

    // Artwork Resolver upgrade test
    let saavnLowRes = URL(string: "https://c.saavncdn.com/077/Blinding-Lights-150x150.jpg")!
    let upgradedArt = ArtworkResolver.upgradeResolution(of: saavnLowRes)
    assertTest("ArtworkResolver upgrades 150x150 to 500x500", upgradedArt.absoluteString.contains("500x500"))

    let localSource = LocalLibrarySource()
    assertTest("LocalLibrarySource registered", localSource.sourceId == "local")

    let saavnSource = JioSaavnSource()
    let saavnResults = (try? await saavnSource.search(query: "Tum Hi Ho")) ?? []
    assertTest("JioSaavn live search returns results", !saavnResults.isEmpty)
    if let first = saavnResults.first {
        print("  -> JioSaavn top match: '\(first.title)' by '\(first.artist)' (ID: \(first.id))")
        assertTest("Tum Hi Ho artist extracted and non-empty", !first.artist.isEmpty && first.artist.contains("Arijit Singh"))
        let resolvedStream = try? await saavnSource.resolveStream(song: first)
        assertTest("JioSaavn stream resolution produces valid HTTP URL", resolvedStream?.url.scheme == "https")
    }

    // Version penalty test in TrackMatcher
    let originalVsRemixScore = TrackMatcher.matchScore(
        titleA: "Blinding Lights",
        artistA: "The Weeknd",
        durationA: 200.0,
        versionA: "Original",
        titleB: "Blinding Lights (Remix)",
        artistB: "The Weeknd",
        durationB: 260.0,
        versionB: "Remix"
    )
    assertTest("TrackMatcher penalizes version discrepancy (< 0.3)", originalVsRemixScore < 0.3)

    // Quality check on the 6 mandatory queries
    print("  Testing 6 core discovery queries:")
    let coreQueries = [
        ("Blinding Lights The Weeknd", "The Weeknd"),
        ("Starboy The Weeknd", "The Weeknd"),
        ("Die For You The Weeknd", "The Weeknd"),
        ("Perfect Ed Sheeran", "Ed Sheeran"),
        ("Tum Hi Ho Arijit Singh", "Arijit Singh"),
        ("Apna Bana Le Arijit Singh", "Arijit Singh")
    ]
    for (q, expectedArtist) in coreQueries {
        if let res = try? await saavnSource.search(query: q), let top = res.first {
            let pass = top.artist.lowercased().contains(expectedArtist.lowercased())
            assertTest("Query '\(q)' top artist matches '\(expectedArtist)'", pass)
        }
    }

    let ytSource = YouTubeSource()
    let ytResults = (try? await ytSource.search(query: "Starboy")) ?? []
    print("  -> YouTube search returned \(ytResults.count) results")
    if let firstYt = ytResults.first {
        print("  -> YouTube top match: '\(firstYt.title)' by '\(firstYt.artist)' (ID: \(firstYt.id))")
    }

    // 4. SpotifyImporter Tests
    print("\n[4/8] Testing Spotify Importer...")
    let parsedUrlId = SpotifyImporter.extractPlaylistId(from: "https://open.spotify.com/playlist/37i9dQZF1DXcBWIGoYBM5M?si=123")
    assertTest("Spotify URL playlist ID extraction", parsedUrlId == "37i9dQZF1DXcBWIGoYBM5M")

    let parsedUriId = SpotifyImporter.extractPlaylistId(from: "spotify:playlist:37i9dQZF1DXcBWIGoYBM5M")
    assertTest("Spotify URI playlist ID extraction", parsedUriId == "37i9dQZF1DXcBWIGoYBM5M")

    // 5. DownloadManager Tests
    print("\n[5/8] Testing DownloadManager...")
    let tempDownloadDir = FileManager.default.temporaryDirectory.appendingPathComponent("HawkVerifyDL_\(UUID().uuidString)")
    let downloadManager = DownloadManager(downloadsDirectory: tempDownloadDir)
    let initialDLCount = await downloadManager.getDownloadedSongs().count
    assertTest("DownloadManager initializes with 0 downloads", initialDLCount == 0)
    let notDL = await downloadManager.isDownloaded(songId: "non_existent_123")
    assertTest("DownloadManager isDownloaded false for non-existent", notDL == false)

    // 6. HawkPlayback & Multi-Tier Queue Tests
    print("\n[6/8] Testing HawkPlayback 3-Tier Queue Engine...")
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

    let eq = EqualizerManager.shared
    eq.applyPreset(.bassBooster)
    assertTest("Equalizer preset Bass Booster loaded", eq.currentPreset.name == "Bass Booster")
    assertTest("Equalizer low-band gain boosted (+6dB)", eq.customGains[0] == 6.0)

    // 7. HawkLyrics & LRC Parser Tests
    print("\n[7/8] Testing HawkLyrics Engine...")
    let sampleLrc = """
    [00:15.50]Hello from HAWK
    [01:02.00]Synchronized Apple Music lyrics
    [02:10.75]Pure native Swift audio
    """
    let parsedLyrics = LrcParser.parse(sampleLrc)
    assertTest("LRC parsed 3 lines", parsedLyrics.count == 3)
    assertTest("LRC line 0 timestamp (15.5s)", abs(parsedLyrics[0].timestamp - 15.5) < 0.01)
    assertTest("LRC line 0 text match", parsedLyrics[0].text == "Hello from HAWK")

    let testSongForLyrics = Song(id: "bl_lyrics_test", title: "Blinding Lights", artist: "The Weeknd", duration: 200.0)
    let fetchedLiveLyrics = try? await LyricsEngine.shared.fetchLyrics(for: testSongForLyrics)
    assertTest("Live LRCLIB lyrics fetched for 'Blinding Lights'", (fetchedLiveLyrics?.count ?? 0) > 0)

    let bogusSong = Song(id: "bogus_test", title: "NonExistentTrackXYZ987", artist: "FakeArtistQWE123", duration: 120.0)
    let bogusLyrics = try? await LyricsEngine.shared.fetchLyrics(for: bogusSong)
    assertTest("LyricsEngine rejects non-existent / mismatched tracks", bogusLyrics == nil || bogusLyrics!.isEmpty)

    // Real Native AVPlayer Audio Playback Engine Test
    print("\n  Testing Native AVPlayer Hardware Pipeline...")
    let testAudioURL = URL(string: "https://aac.saavncdn.com/077/0b02a92687d1ae3369b6859f44872e52_320.mp4")!
    let playerItem = AVPlayerItem(url: testAudioURL)
    let nativePlayer = AVPlayer(playerItem: playerItem)

    var isReady = false
    let readyObs = playerItem.observe(\.status, options: [.new, .initial]) { obsItem, _ in
        if obsItem.status == .readyToPlay { isReady = true }
    }
    let waitStart = Date()
    while !isReady && Date().timeIntervalSince(waitStart) < 4.0 {
        try? await Task.sleep(nanoseconds: 50_000_000)
    }
    assertTest("AVPlayerItem status transitions to .readyToPlay", isReady)
    assertTest("AVPlayerItem duration is finite and valid (> 100s)", playerItem.duration.seconds > 100.0)

    nativePlayer.play()
    let playStart = Date()
    while nativePlayer.currentTime().seconds < 0.5 && Date().timeIntervalSince(playStart) < 3.0 {
        try? await Task.sleep(nanoseconds: 50_000_000)
    }
    assertTest("AVPlayer rate becomes > 0 (playing)", nativePlayer.rate > 0)
    assertTest("Playback time genuinely advances", nativePlayer.currentTime().seconds > 0)

    nativePlayer.pause()
    assertTest("AVPlayer pause stops playback (rate == 0)", nativePlayer.rate == 0)

    var seekComplete = false
    nativePlayer.seek(to: CMTime(seconds: 30.0, preferredTimescale: 1000)) { _ in
        seekComplete = true
    }
    let seekStart = Date()
    while !seekComplete && Date().timeIntervalSince(seekStart) < 2.0 {
        try? await Task.sleep(nanoseconds: 50_000_000)
    }
    assertTest("AVPlayer seeking updates playback position (~30s)", abs(nativePlayer.currentTime().seconds - 30.0) < 1.0)

    // 8. HawkStats Listening Recorder Tests
    print("\n[8/8] Testing HawkStats Wall-Clock Recorder...")
    let statsDir = FileManager.default.temporaryDirectory.appendingPathComponent("HawkVerifyStats_\(UUID().uuidString)")
    let statsRecorder = ListeningStatsRecorder(storageDirectory: statsDir)

    // Two ticks to record interval
    let testPlaySong = Song(id: "stat_track_1", title: "Song One", artist: "Artist One", duration: 100)
    await statsRecorder.onSample(song: testPlaySong, isPlaying: true)
    try? await Task.sleep(nanoseconds: 100_000_000)
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
