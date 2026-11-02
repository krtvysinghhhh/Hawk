# REFERENCE REPOSITORY AUDIT: BITCHORD

**Document ID:** HAWK-DOC-M1-001  
**Reference Project:** BitChord (`https://github.com/kushagrasinghx/BitChord`)  
**Commit / Checkpoint:** Latest `main` branch (2026-11)  
**Reference Codebase Size:** 1,396 files, 159 MB, 284 Kotlin source files in `app/`, multiplatform modules in `shared/`, `sharedUi/`, `tv/`, `wearos/`, `desktop/`, and C++ native code in `native/`.  
**License:** GNU General Public License v3.0 (GPLv3)  

---

## 1. Architectural Overview of Reference Repository

BitChord is a multiplatform Kotlin/Compose application targeting Android (phone, TV, WearOS), desktop (JVM/Compose), and web. Its architecture is organized as:
- `:app`: Android phone application (Compose Material 3, Android Media3/ExoPlayer, services, widgets).
- `:shared`: Common and JVM-shared Kotlin business logic (models, Innertube client, stream resolvers, lyrics engine, audio DSP algorithms, Spotify importer, Listen Together protocol).
- `:sharedUi`: Multiplatform Compose UI components (screens, player controls, lyrics rendering, color extraction).
- `:native`: C++ audio DSP and native code (analyzer, loopmix, resamplers, third-party libraries `signalsmith-stretch`, `signalsmith-linear`, Oboe, libusb).
- `:tv` & `:wearos`: Android TV and Wear OS counterparts.
- `:backend`: Go-based WebSocket server for the "Listen Together" party session feature.

---

## 2. Component-by-Component Technical Analysis

### 2.1 Application Entry Point & Lifecycle
- **Implementation:** `BitChordApplication.kt` and `MainActivity.kt`.
- **Mechanism:** Initializes Singletons (`AppSettings`, `AuthStore`, `DownloadStore`, `InnerTubeXResolver`, `ListeningStats`). `MainActivity` handles Compose `setContent`, window insets, deep links (`bitchord://`, `https://music.youtube.com`), and binds to `PlaybackService` via `PlayerConnection`.
- **iOS Mapping:** `HawkApp.swift` (`@main App`), `AppState` environment object, `ScenePhase` observation.

### 2.2 Navigation Architecture
- **Implementation:** `AppNavigator.kt`, `MainViewModel.kt`, `HomeScreen.kt`, `ExploreScreen.kt`, `SearchScreen.kt`, `LibraryScreen.kt`.
- **Mechanism:** Four primary tabs (Home, Explore, Search, Library) with a persistent mini-player dock that expands into a full-screen Now Playing modal sheet. Drill-down detail pages (Album, Artist, Playlist) are managed on a separate `detailStack` interleaved with pushed modal route entries (Settings, Equalizer, Replay, History, etc.).
- **iOS Mapping:** Native SwiftUI `TabView` with modern `NavigationStack`, custom bottom player bar overlay, and native `.sheet` / `.fullScreenCover` presentations.

### 2.3 Audio Playback Engine
- **Implementation:** `PlaybackService.kt` (476 KB), `CrossfadeController.kt`, `EqualizerProcessor.kt`, `LoudnessProcessor.kt`, `AudioRouting.kt`, `PrecisionAudioSink.kt`.
- **Mechanism:** Android Media3 ExoPlayer with dual player instances for true crossfade (0–12s). Custom audio processor chain (`EqualizerProcessor` 10-band SVF filter, `LoudnessProcessor` limiter and replay gain, bit-perfect direct USB DAC output). Foreground service with `MediaSessionService` and notifications.
- **iOS Mapping:** `AVFoundation` + `AVAudioEngine` or dual `AVPlayer` instances. `AVAudioUnitEQ` for 10-band parametric EQ, `AVAudioSession` category `.playback`, `MPNowPlayingInfoCenter` and `MPRemoteCommandCenter` for Lock Screen and Control Center controls.

### 2.4 Music Sources & Stream Resolution
- **Implementation:** `MusicSource.kt`, `YouTubeSource.kt`, `SourceResolver.kt`, `InnerTubeXResolver.kt`, `StreamResolver.kt`, `JioSaavnService.kt`, `ModuleSource.kt`, `AddonSource.kt`.
- **Mechanism:** 
  - **YouTube Music:** Uses YouTube's `WEB_REMIX` and mobile client endpoints via `InnerTube` (Ktor HTTP client). For stream extraction, invokes `InnerTubeX` or falls back to `NewPipeExtractor` with Rhino JS engine to solve YouTube's signature decipher and `n` parameter throttling.
  - **JioSaavn:** Direct API queries with DES encryption/decryption of `encrypted_media_url` to obtain 320 kbps AAC/MP4 streams.
  - **Module Sources / Addons:** QuickJS JavaScript engine running community scrapers/modules (e.g. for high-res FLAC) or external HTTP endpoints.
  - **Local Media:** Scans device storage using MediaStore, reads audio tags and embedded artwork.
  - **Network Shares:** SMB (via `smbj` pure Java client) and WebDAV.
- **iOS Mapping:**
  - YouTube Music: Native Swift `URLSession` client querying `/youtubei/v1` with iOS/WebRemix client context and SAPISIDHASH authentication. Unthrottled/direct audio streams obtained without running heavy Java runtimes.
  - JioSaavn: Native Swift CommonCrypto DES decryption for JioSaavn streams.
  - Local Library: Native iOS `UIDocumentPickerViewController` and security-scoped URLs to import local audio files into HAWK's container; `AVURLAsset` for tag and artwork extraction.
  - Module/Addon: Clean REST API client in Swift.

### 2.5 Spotify Integration
- **Implementation:** `SpotifyLibrary.kt`, `SpotifyImporter.kt`, `SpotifyLoginScreen.kt`, `SpotifyMatch.kt`.
- **Mechanism:** OAuth login via WebView to acquire user access tokens. Fetches user playlists and Liked Songs via Spotify's GraphQL / Web API. Uses `TrackMatcher` to find matching tracks on YouTube Music or local sources by matching track title, artist, album, and duration.
- **Critical Policy Compliance:** BitChord does *not* stream or download audio from Spotify directly (which would violate Spotify TOS and DRM); it only reads playlist and track metadata and streams the matched song from lawful sources.
- **iOS Mapping:** `ASWebAuthenticationSession` for Spotify OAuth, Swift Codable for Spotify Web API / GraphQL metadata fetching, followed by intelligent matching against HAWK's audio providers.

### 2.6 Synchronized Lyrics Engine
- **Implementation:** `LyricsRepository.kt`, `LrcLib.kt`, `LyricsPlus.kt`, `EmbeddedLyrics.kt`, `PlayerLyrics.kt`, `LyricClock.kt`.
- **Mechanism:** Multi-provider priority waterfall:
  - TTML syllable-synced / word-synced lyrics (`LrcRed`, `BetterLyrics`, `PaxSenix`, `BiniLyrics`, `LyricsPlus`).
  - Line-synced open lyrics (`LrcLib` via `lrclib.net`, `KuGou`, `Musixmatch`).
  - Embedded ID3/Vorbis lyrics from local files.
  - Lyrics UI displays word-by-word highlights synced to playback progress with spring animations.
- **iOS Mapping:** Swift implementation querying `LRCLIB` (open API) and TTML parsers; SwiftUI `TimelineView` or display link driving synchronized smooth lyric scrolling and active-word text shading.

### 2.7 Local Storage & Persistence
- **Implementation:** `AppSettings.kt`, `OfflinePlaylists.kt`, `SearchHistory.kt`, `AuthStore.kt`, `EncryptedPrefs.kt`, `BoundedContextPersistence.kt`.
- **Mechanism:** Android `SharedPreferences` storing serialized JSON blobs. `EncryptedSharedPreferences` for auth tokens and cookies. No SQL database or Room is used.
- **iOS Mapping:** Local JSON files written atomically via `FileManager`, `UserDefaults` for light preferences, and **Apple Keychain Services** (`Security.framework`) for secure token and session cookie storage.

### 2.8 Queue Management & Shuffle
- **Implementation:** `QueueCoordinator.kt`, `QueueBuilder.kt`, `QueueShuffle.kt`, `QueueSections.kt`, `QueueWindow.kt`, `Autoplay.kt`.
- **Mechanism:** Three queue tiers:
  - `USER_QUEUE`: Manually added tracks ("Play Next").
  - `CONTEXT`: Active Album/Playlist/Artist tracks.
  - `AUTOPLAY`: Generated radio recommendations when context ends.
  - Balanced multi-tier shuffle preserving user queue integrity.
- **iOS Mapping:** Native Swift `QueueManager` actor with identical tier isolation, thread-safe queue reordering, and state restoration.

### 2.9 Listening Statistics & Replay
- **Implementation:** `ListeningRecorder.kt`, `ListeningStats.kt`, `ReplayModel.kt`, `ReplayStories.kt`, `ReplayPoster.kt`.
- **Mechanism:** Progress sampler samples wall-clock playback (50% or 4 min rule for play counts), stores monthly JSON aggregate buckets locally, computes top artists, top tracks, total hours, and renders visual shareable story cards.
- **iOS Mapping:** Native Swift statistics engine logging locally to JSON files; SwiftUI Replay cards rendered to shareable images using `ImageRenderer`.

### 2.10 Offline Downloads & File Tagging
- **Implementation:** `Downloads.kt`, `Downloader.kt`, `DownloadStore.kt`, `MediaTagger.kt`, `FlacTagger.kt`, `Mp4Tagger.kt`.
- **Mechanism:** Background file download with chunked requests, writing audio files with embedded ID3v2, Vorbis, and MP4 atom metadata and album artwork.
- **iOS Mapping:** `URLSessionDownloadTask` with background session configuration; native metadata writing or storage in app documents directory.

### 2.11 Widgets & Apple Ecosystem Features
- **Implementation:** Android `AppWidgetProvider` (`MediaWidgetSquare`, `MediaWidgetWide`, `MediaWidgetPill`).
- **iOS Mapping:** Native iOS `WidgetKit` with small, medium, and lock screen widgets displaying current track and quick actions via `AppIntents`.

---

## 3. Code Reusability Assessment

| Architectural Domain | BitChord Implementation | Reusability in HAWK | Required Action |
|---|---|---|---|
| UI Layer | Jetpack Compose (Kotlin) | 0% | Complete native rewrite in **SwiftUI** |
| Audio Playback | Media3 / ExoPlayer (Java/Kotlin) | 0% | Complete native rewrite in **AVFoundation / AVAudioEngine** |
| Native DSP / C++ | Oboe, AAudio, signalsmith | 10% (DSP algorithms only) | Replaced with native Apple **AudioToolbox / Accelerate vDSP** |
| Network Layer | Ktor + OkHttp (Kotlin) | 0% | Native rewrite in **URLSession** with Swift Concurrency |
| Innertube Protocol | Kotlin JSON endpoints & headers | 40% (Logic/Schemas) | Adapted and rewritten in Swift `Codable` |
| JioSaavn Protocol | Kotlin + DES cipher | 50% (Logic/Endpoint) | Adapted in Swift with `CommonCrypto` |
| Spotify Importer | Kotlin + Web/GraphQL | 50% (Logic/Parsers) | Adapted in Swift `Codable` + `ASWebAuthenticationSession` |
| Lyrics Engine | Kotlin waterfall parser | 60% (Parsing logic) | Adapted in Swift (`LRCLIB`, TTML parsing) |
| Queue State Machine | Kotlin `QueueCoordinator` | 70% (State logic) | Adapted as a Swift `actor` |
| Stats & Replay | Kotlin monthly aggregate math | 80% (Algorithms) | Adapted in Swift |
| Storage & Keychain | Android SharedPreferences / EncryptedPrefs | 0% | Native rewrite with `FileManager` + **Apple Keychain** |

---

## 4. Architectural Summary for HAWK

BitChord has solid functional designs (queue tiers, multi-provider lyrics waterfall, monthly stats aggregation, Spotify playlist matching), but its implementation is deeply coupled to the Android SDK (Android Context, ExoPlayer, Compose, MediaStore, SharedPreferences).

**HAWK must be built from the ground up as a native Swift application.** We preserve the elegant domain models and workflow concepts, but implement them natively using Apple-standard patterns, HIG design, AVFoundation, and SwiftUI.
