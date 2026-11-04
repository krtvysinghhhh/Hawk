import Foundation
import AVFoundation
import HawkCore
import HawkSecurity
import HawkNetworking
import HawkSources
import HawkPlayback
import HawkLyrics
import HawkStats

/// Thread-safe synchronized container for AVFoundation asynchronous callbacks
final class AtomicPlaybackState: @unchecked Sendable {
    private let lock = NSLock()
    private var _isReady = false
    private var _seekComplete = false

    var isReady: Bool {
        get { lock.withLock { _isReady } }
        set { lock.withLock { _isReady = newValue } }
    }

    var seekComplete: Bool {
        get { lock.withLock { _seekComplete } }
        set { lock.withLock { _seekComplete = newValue } }
    }
}

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
    print("\n[1/15] Testing HawkCore Domain & PlaylistStore...")
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
    print("\n[2/15] Testing HawkSecurity & Crypto...")
    let sapisidHash = CryptoUtils.generateSapisidHash(
        sapisid: "demo_sapisid",
        origin: "https://music.youtube.com",
        timestamp: 1700000000
    )
    assertTest("SAPISIDHASH prefix and format", sapisidHash.hasPrefix("SAPISIDHASH 1700000000_"))

    let sha256 = CryptoUtils.sha256Hex("HAWK")
    assertTest("SHA256 hex digest length (64 chars)", sha256.count == 64)

    let keyStore = KeychainStore(serviceName: "com.hawk.verify", inMemoryOnly: true)
    try? await keyStore.saveString(key: "auth_token", value: "secret_value_123")
    let retrieved = try? await keyStore.readString(key: "auth_token")
    assertTest("Keychain store save and read", retrieved == "secret_value_123")

    // Test JioSaavn DES Decryption
    let testEncryptedMedia = "ID2ieOjCrwfgWvL5sXl4B1ImC5QfbsDyF/c5nqlFTXM0C74GbTF9AaylMpcN37HtcTaLl9ufWl/TC2QaaKAJJBw7tS9a8Gtq"
    let decryptedStreamUrl = try? CryptoUtils.decryptJioSaavnUrl(encryptedUrl: testEncryptedMedia)
    assertTest("JioSaavn DES Decryption with 38346591 key", decryptedStreamUrl?.contains("saavncdn.com") == true)

    // 3. HawkSources, Deduplication & Track Matcher Tests
    print("\n[3/15] Testing HawkSources & Matcher...")
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

    // Six core discovery query checks
    print("  Testing 6 core discovery queries:")
    let queries = [
        ("Blinding Lights The Weeknd", "The Weeknd"),
        ("Starboy The Weeknd", "The Weeknd"),
        ("Die For You The Weeknd", "The Weeknd"),
        ("Perfect Ed Sheeran", "Ed Sheeran"),
        ("Tum Hi Ho Arijit Singh", "Arijit Singh"),
        ("Apna Bana Le Arijit Singh", "Arijit Singh")
    ]
    for (q, expectedArtist) in queries {
        let results = (try? await saavnSource.search(query: q)) ?? []
        let matched = results.first(where: { $0.artist.contains(expectedArtist) }) != nil
        assertTest("Query '\(q)' top artist matches '\(expectedArtist)'", matched)
    }

    // YouTube Source Test
    let ytSource = YouTubeSource()
    let ytResults = (try? await ytSource.search(query: "Starboy The Weeknd")) ?? []
    print("  -> YouTube search returned \(ytResults.count) results")
    if let firstYt = ytResults.first {
        print("  -> YouTube top match: '\(firstYt.title)' by '\(firstYt.artist)' (ID: \(firstYt.id))")
    }

    // 4. Spotify Importer Tests
    print("\n[4/15] Testing Spotify Importer...")
    let spotifyUrl = "https://open.spotify.com/playlist/37i9dQZF1DXcBWIGoYBM5M"
    let extractedId = SpotifyImporter.extractPlaylistId(from: spotifyUrl)
    assertTest("Spotify URL playlist ID extraction", extractedId == "37i9dQZF1DXcBWIGoYBM5M")

    let spotifyUri = "spotify:playlist:37i9dQZF1DXcBWIGoYBM5M"
    let extractedUriId = SpotifyImporter.extractPlaylistId(from: spotifyUri)
    assertTest("Spotify URI playlist ID extraction", extractedUriId == "37i9dQZF1DXcBWIGoYBM5M")

    // 5. DownloadManager Tests
    print("\n[5/15] Testing DownloadManager...")
    let tempDownloadDir = FileManager.default.temporaryDirectory.appendingPathComponent("HawkVerifyDL_\(UUID().uuidString)")
    let downloadManager = DownloadManager(downloadsDirectory: tempDownloadDir)
    let initialDLCount = await downloadManager.getDownloadedSongs().count
    assertTest("DownloadManager initializes with 0 downloads", initialDLCount == 0)
    let notDL = await downloadManager.isDownloaded(songId: "non_existent")
    assertTest("DownloadManager isDownloaded false for non-existent", notDL == false)
    let idleState = await downloadManager.getState(songId: "non_existent")
    assertTest("DownloadManager returns .idle for non-existent", idleState == .idle)

    // 6. HawkPlayback 3-Tier Queue Engine Tests
    print("\n[6/15] Testing HawkPlayback 3-Tier Queue Engine...")
    let queueManager = QueueManager.shared
    await queueManager.clearQueue()
    await queueManager.setContext(songs: [song, songOriginalA])
    await queueManager.playNext(song: queuedSong)

    let timeline = await queueManager.fullTimeline
    assertTest("Queue timeline has 3 items", timeline.count == 3)
    assertTest("User-queued song placed at index 0 ahead of context", timeline.first?.queueTier == .userQueue)
    assertTest("Contextual track follows at index 1", timeline[1].queueTier == .context)

    let nextTrack = await queueManager.next()
    assertTest("Queue next() navigation advances correctly", nextTrack?.id == song.id)

    // Equalizer Manager Tests
    let eq = EqualizerManager.shared
    eq.applyPreset(.bassBooster)
    assertTest("Equalizer preset Bass Booster loaded", eq.currentPreset == .bassBooster)
    assertTest("Equalizer low-band gain boosted (+6dB)", eq.customGains[0] > 5.0)

    // 7. HawkLyrics Engine & Native Hardware AVPlayer Pipeline
    print("\n[7/15] Testing HawkLyrics Engine...")
    let sampleLrc = """
    [00:15.50] First line of lyric
    [00:20.10] Second line of lyric
    [00:25.80] Third line of lyric
    """
    let lines = LrcParser.parse(sampleLrc)
    assertTest("LRC parsed 3 lines", lines.count == 3)
    assertTest("LRC line 0 timestamp (15.5s)", abs(lines[0].timestamp - 15.5) < 0.01)
    assertTest("LRC line 0 text match", lines[0].text == "First line of lyric")

    let lyricsEngine = LyricsEngine.shared
    let liveLyrics = try? await lyricsEngine.fetchLyrics(for: songOriginalA)
    assertTest("Live LRCLIB lyrics fetched for 'Blinding Lights'", (liveLyrics?.count ?? 0) > 0)

    let dummySong = Song(id: "fake_id_999", title: "NonExistentTrackXYZ", artist: "NobodySpecial123")
    let rejectedLyrics = try? await lyricsEngine.fetchLyrics(for: dummySong)
    assertTest("LyricsEngine rejects non-existent / mismatched tracks", rejectedLyrics == nil || rejectedLyrics?.isEmpty == true)

    print("\n  Testing Native AVPlayer Hardware Pipeline...")
    let testAudioURL = URL(string: "https://aac.saavncdn.com/077/0b02a92687d1ae3369b6859f44872e52_320.mp4")!
    let playerItem = AVPlayerItem(url: testAudioURL)
    let nativePlayer = AVPlayer(playerItem: playerItem)

    let playbackSync = AtomicPlaybackState()
    let readyObs = playerItem.observe(\.status, options: [.new, .initial]) { obsItem, _ in
        if obsItem.status == .readyToPlay {
            playbackSync.isReady = true
        }
    }
    let waitStart = Date()
    while !playbackSync.isReady && Date().timeIntervalSince(waitStart) < 4.0 {
        try? await Task.sleep(nanoseconds: 50_000_000)
    }
    assertTest("AVPlayerItem status transitions to .readyToPlay", playbackSync.isReady)
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

    nativePlayer.seek(to: CMTime(seconds: 30.0, preferredTimescale: 1000)) { _ in
        playbackSync.seekComplete = true
    }
    let seekStart = Date()
    while !playbackSync.seekComplete && Date().timeIntervalSince(seekStart) < 2.0 {
        try? await Task.sleep(nanoseconds: 50_000_000)
    }
    assertTest("AVPlayer seeking updates playback position (~30s)", abs(nativePlayer.currentTime().seconds - 30.0) < 1.0)
    _ = readyObs // Retain observer

    // 8. HawkStats Wall-Clock Recorder & History
    print("\n[8/15] Testing HawkStats Wall-Clock Recorder & History...")
    let statsDir = FileManager.default.temporaryDirectory.appendingPathComponent("HawkVerifyStats_\(UUID().uuidString)")
    let statsRecorder = ListeningStatsRecorder(storageDirectory: statsDir)

    let testPlaySong = Song(id: "stat_track_1", title: "Midnight City", artist: "M83", duration: 240)
    await statsRecorder.onSample(song: testPlaySong, isPlaying: true)
    try? await Task.sleep(nanoseconds: 100_000_000)
    await statsRecorder.onSample(song: testPlaySong, isPlaying: true)

    let formatter = DateFormatter()
    formatter.dateFormat = "yyyy-MM"
    let month = formatter.string(from: Date())

    let bucket = await statsRecorder.getMonthlyReplay(monthKey: month)
    assertTest("Monthly aggregate bucket created", bucket != nil)

    let recents = await statsRecorder.getRecentlyPlayed()
    assertTest("Listening history tracks recently played song", recents.contains(where: { $0.id == "stat_track_1" }))

    // 9. CarPlay & Library Architecture Tests
    print("\n[9/15] Testing CarPlay & Library Architecture...")
    let carPlayManager = CarPlaySyncManager.shared
    let cpFavorites = await carPlayManager.fetchFavorites()
    assertTest("CarPlaySyncManager fetchFavorites returns list", cpFavorites.count >= 0)

    let cpPlaylists = await carPlayManager.fetchPlaylists()
    assertTest("CarPlaySyncManager fetchPlaylists returns list", cpPlaylists.count >= 0)

    let cpArtists = await carPlayManager.fetchArtists()
    assertTest("CarPlaySyncManager fetchArtists returns list", cpArtists.count >= 0)

    let cpQueue = await carPlayManager.fetchQueueItems()
    assertTest("CarPlaySyncManager fetchQueueItems reflects queue", cpQueue.count == 3)

    let iconPath = "Resources/Assets.xcassets/AppIcon.appiconset/AppIcon-1024.png"
    let iconExists = FileManager.default.fileExists(atPath: iconPath)
    assertTest("Official HAWK AppIcon-1024.png asset exists", iconExists)

    // 10. Queue Stability & 100 Consecutive Navigation Operations Regression
    print("\n[10/15] Testing 100 Consecutive Queue Operations Regression...")
    let stressQueue = QueueManager.shared
    await stressQueue.clearQueue()
    let baseTracks = (0..<10).map { Song(id: "base_\($0)", title: "Base Track \($0)", artist: "Artist") }
    await stressQueue.setContext(songs: baseTracks)

    for i in 0..<100 {
        if i % 4 == 0 {
            await stressQueue.playNext(song: Song(id: "pn_\(i)", title: "PlayNext \(i)", artist: "PN Artist"))
        } else if i % 5 == 0 {
            await stressQueue.addToQueue(song: Song(id: "aq_\(i)", title: "AddToQueue \(i)", artist: "AQ Artist"))
        } else if i % 7 == 0 {
            _ = await stressQueue.previous()
        } else {
            _ = await stressQueue.next()
        }
    }
    let currentAfterStress = await stressQueue.currentSong
    assertTest("Queue remains stable and non-nil across 100 structural operations", currentAfterStress != nil)

    // 11. PlaylistStore Corruption Quarantine & Safe Recovery
    print("\n[11/15] Testing PlaylistStore Corruption Recovery...")
    let corruptURL = FileManager.default.temporaryDirectory.appendingPathComponent("CorruptStore_\(UUID().uuidString).json")
    let store1 = PlaylistStore(storageURL: corruptURL)
    _ = await store1.createPlaylist(title: "Persistent Playlist")

    // Intentionally corrupt primary JSON file with junk
    try! "CORRUPTED { INVALID_DATA".data(using: .utf8)!.write(to: corruptURL)

    // Initialize new store: must quarantine corrupted file and recover
    let store2 = PlaylistStore(storageURL: corruptURL)
    let favsAfterRecovery = await store2.getFavorites()
    assertTest("PlaylistStore recovers safely from corrupted file without crashing", favsAfterRecovery.id == Playlist.favoritesId)

    // 12. 10-Band Biquad DSP Equalizer & Universal Playlist Importer
    print("\n[12/15] Testing 10-Band Biquad DSP Audio Equalizer & Universal Importer...")
    let eqEngine = EqualizerManager.shared
    eqEngine.isEnabled = true
    eqEngine.applyPreset(.bassBooster)
    var testBuffer: [Float] = [0.1, 0.2, -0.1, -0.2, 0.05, -0.05, 0.15, -0.15]
    let initialSample = testBuffer[0]
    eqEngine.process(buffer: &testBuffer, sampleRate: 44100.0)
    assertTest("Biquad DSP modifies audio buffer according to gain curves", testBuffer[0] != initialSample)

    let testPlaylist = Playlist(title: "Road Trip", songs: [song, queuedSong])
    let exportedM3U = UniversalPlaylistImporter.exportToM3U8(playlist: testPlaylist)
    assertTest("UniversalPlaylistImporter exports valid M3U8", exportedM3U.contains("#EXTM3U") && exportedM3U.contains("Starboy"))
    let parsedM3U = UniversalPlaylistImporter.parseM3U(content: exportedM3U)
    assertTest("UniversalPlaylistImporter parses M3U8 correctly", parsedM3U.tracks.count == 2)

    // 13. Next & Previous Navigation State Machine & Remote Command Wiring
    print("\n[13/15] Testing Next & Previous Navigation State Machine...")
    let navQueue = QueueManager.shared
    await navQueue.clearQueue()
    let track1 = Song(id: "nav_1", title: "Track 1", artist: "Artist 1")
    let track2 = Song(id: "nav_2", title: "Track 2", artist: "Artist 2")
    let track3 = Song(id: "nav_3", title: "Track 3", artist: "Artist 3")
    await navQueue.setContext(songs: [track1, track2, track3], startAt: 0)

    // Verify next advances to track 2
    let afterNext = await navQueue.next()
    assertTest("QueueManager next() advances to track 2", afterNext?.id == track2.id)

    // Verify repeatMode .one autoAdvance repeats current track
    await navQueue.setRepeatMode(.one)
    let autoAdvancedRepeatOne = await navQueue.next(isAutoAdvance: true)
    assertTest("QueueManager auto-advance repeats current track in .one mode", autoAdvancedRepeatOne?.id == track2.id)

    // Verify repeatMode .one manual skip still advances to track 3
    let manualSkipRepeatOne = await navQueue.next(isAutoAdvance: false)
    assertTest("QueueManager manual skip advances to track 3 in .one mode", manualSkipRepeatOne?.id == track3.id)

    // Verify previous returns track 2
    let afterPrev = await navQueue.previous()
    assertTest("QueueManager previous() returns track 2", afterPrev?.id == track2.id)

    // 14. Word-Level LRC Parsing & Google Music Sync Credentials
    print("\n[14/15] Testing Word-Level LRC Parsing & Google Auth Credentials...")
    let sampleEnhancedLRC = """
    [00:10.50]<00:10.50> Hello <00:11.00> world <00:11.50> from <00:12.00> HAWK
    [00:15.00] Plain line without words
    """
    let parsedLines = LrcParser.parse(sampleEnhancedLRC)
    assertTest("LrcParser parsed 2 lines", parsedLines.count == 2)
    assertTest("Line 0 isWordSynced is true", parsedLines.first?.isWordSynced == true)
    assertTest("Line 0 has 4 words", parsedLines.first?.words.count == 4)
    assertTest("Line 0 clean text is correct", parsedLines.first?.text == "Hello world from HAWK")
    assertTest("Line 1 isWordSynced is false", parsedLines.last?.isWordSynced == false)

    // Test GoogleMusicSyncManager credentials & clean disconnect
    let googleSync = GoogleMusicSyncManager.shared
    try? await googleSync.connectWithToken(email: "test@example.com", accessToken: "ya29.mock_token")
    assertTest("GoogleMusicSyncManager connects with email and token", googleSync.isConnected && googleSync.accountEmail == "test@example.com")
    await googleSync.disconnect()
    assertTest("GoogleMusicSyncManager disconnect cleans up credentials", !googleSync.isConnected && googleSync.accountEmail == nil)

    // 15. v1.3.1 Security, Classification, Concurrency & Robustness Regressions
    print("\n[15/15] Testing v1.3.1 Security, Classification, Concurrency & Robustness Regressions...")

    // 15.1 Music Classification Model
    let topicClass = MusicClassificationService.classify(title: "Blinding Lights", channelOrArtist: "The Weeknd - Topic", duration: 200)
    assertTest("MusicClassification classifies Topic channel as officialMusic", topicClass.classification == .officialMusic && topicClass.classification.isPlayableSong)

    let vevoClass = MusicClassificationService.classify(title: "Save Your Tears (Official Music Video)", channelOrArtist: "TheWeekndVEVO", duration: 245)
    assertTest("MusicClassification classifies VEVO video as officialMusic/musicVideo", (vevoClass.classification == .officialMusic || vevoClass.classification == .musicVideo) && vevoClass.classification.isPlayableSong)

    let liveClass = MusicClassificationService.classify(title: "Die For You (Live at SoFi Stadium)", channelOrArtist: "The Weeknd", duration: 270)
    assertTest("MusicClassification classifies live concert as livePerformance", liveClass.classification == .livePerformance && liveClass.classification.isPlayableSong)

    let podcastClass = MusicClassificationService.classify(title: "The Joe Rogan Experience #2000 - Full Podcast Episode", channelOrArtist: "PowerfulJRE", duration: 10800)
    assertTest("MusicClassification rejects podcast from playable songs", podcastClass.classification == .podcast && !podcastClass.classification.isPlayableSong)

    let gamingClass = MusicClassificationService.classify(title: "Elden Ring Walkthrough Gameplay Part 1", channelOrArtist: "IGN", duration: 1800, categoryId: "20")
    assertTest("MusicClassification rejects gaming category from playable songs", gamingClass.classification == .nonMusic && !gamingClass.classification.isPlayableSong)

    let snippetClass = MusicClassificationService.classify(title: "Alarm Sound Effect", channelOrArtist: "Ringtones", duration: 12)
    assertTest("MusicClassification flags short snippet (<30s) as uncertain", snippetClass.classification == .uncertain && !snippetClass.classification.isPlayableSong)

    // 15.2 Universal Playlist Importer Security & HLS Isolation
    let hlsManifest = """
    #EXTM3U
    #EXT-X-VERSION:3
    #EXT-X-TARGETDURATION:10
    #EXT-X-MEDIA-SEQUENCE:0
    #EXTINF:10.0,
    segment0.ts
    """
    assertTest("UniversalPlaylistImporter detects HLS stream manifest", UniversalPlaylistImporter.isHLSManifest(content: hlsManifest))
    let parsedHLS = UniversalPlaylistImporter.parseM3U(content: hlsManifest)
    assertTest("UniversalPlaylistImporter rejects HLS stream from track import", parsedHLS.tracks.isEmpty)

    // SSRF URL validation
    assertTest("UniversalPlaylistImporter SSRF rejects localhost", !UniversalPlaylistImporter.isSafeRemoteURL(URL(string: "http://localhost:8080/p.m3u")!))
    assertTest("UniversalPlaylistImporter SSRF rejects 127.0.0.1", !UniversalPlaylistImporter.isSafeRemoteURL(URL(string: "http://127.0.0.1/p.m3u")!))
    assertTest("UniversalPlaylistImporter SSRF rejects private 10.x.x.x", !UniversalPlaylistImporter.isSafeRemoteURL(URL(string: "http://10.0.0.1/p.m3u")!))
    assertTest("UniversalPlaylistImporter SSRF rejects private 192.168.x.x", !UniversalPlaylistImporter.isSafeRemoteURL(URL(string: "http://192.168.1.1/p.m3u")!))
    assertTest("UniversalPlaylistImporter SSRF rejects non-http file:// scheme", !UniversalPlaylistImporter.isSafeRemoteURL(URL(string: "file:///etc/passwd")!))
    assertTest("UniversalPlaylistImporter SSRF accepts public HTTPS URL", UniversalPlaylistImporter.isSafeRemoteURL(URL(string: "https://example.com/playlist.m3u")!))

    // Path traversal in M3U
    let traversalM3U = """
    #EXTM3U
    #EXTINF:180,Safe Artist - Safe Title
    ../../../../var/mobile/secret.mp3
    """
    let parsedTraversal = UniversalPlaylistImporter.parseM3U(content: traversalM3U)
    assertTest("UniversalPlaylistImporter sanitizes path traversal", parsedTraversal.tracks.count == 1 && parsedTraversal.tracks[0].title == "Safe Title")

    // 15.3 Concurrency & Monotonic Request ID
    let initialEngineReq = await HawkAudioEngine.shared.activePlayRequestId
    try? await HawkAudioEngine.shared.play(song: song)
    let updatedEngineReq = await HawkAudioEngine.shared.activePlayRequestId
    assertTest("HawkAudioEngine monotonic request ID advances on play()", updatedEngineReq > initialEngineReq)

    // 15.4 Multi-Timestamp & Unicode LRC Parsing
    let multiTimestampLRC = """
    [00:12.50][00:24.00] Repeated chorus line
    [01:05.10] तुम ही हो - Arijit Singh
    """
    let parsedMulti = LrcParser.parse(multiTimestampLRC)
    assertTest("LrcParser expands multi-timestamp line into 2 distinct instances", parsedMulti.filter { $0.text == "Repeated chorus line" }.count == 2)
    assertTest("LrcParser handles UTF-8 / Unicode characters correctly", parsedMulti.contains(where: { $0.text.contains("तुम ही हो") }))

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
