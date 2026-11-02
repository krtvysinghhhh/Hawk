# PROJECT HAWK — FEATURE INVENTORY & PARITY MATRIX

**Document ID:** HAWK-DOC-M1-002  
**Project:** HAWK (Native iOS Music Application)  
**Reference:** BitChord Android Client  
**Parity Statuses:** `REUSABLE` | `REQUIRES ADAPTATION` | `REQUIRES NATIVE REWRITE` | `BLOCKED` | `UNSUPPORTED` | `NOT PRESENT IN REFERENCE`  

---

## 1. Feature Parity Matrix

| Feature Area | Specific Capability | BitChord Reference Implementation | HAWK iOS Target Implementation | Parity Status | Notes / Limitations |
|---|---|---|---|---|---|
| **Audio Playback** | Background Audio Playback | Android Foreground Service + MediaSession | `AVAudioSession` (`.playback`), Background Modes | **REQUIRES NATIVE REWRITE** | Core iOS requirement; fully supported |
| **Audio Playback** | Gapless Playback | ExoPlayer audio buffer scheduling | `AVPlayerItem` / `AVQueuePlayer` pre-buffering | **REQUIRES NATIVE REWRITE** | Native AVFoundation gapless playback |
| **Audio Playback** | True Crossfade (0–12s) | Dual ExoPlayer volume envelope mixing | Dual `AVPlayer` instances with smooth volume ramp | **REQUIRES NATIVE REWRITE** | Verified architectural approach |
| **Audio Playback** | Playback Speed Control (0.5x–2.0x) | ExoPlayer playback parameters | `AVPlayer.rate` adjustment | **REQUIRES NATIVE REWRITE** | Built into AVPlayer with pitch correction |
| **Audio Playback** | Lock Screen & Control Center | MediaSessionCompat + Notifications | `MPNowPlayingInfoCenter` + `MPRemoteCommandCenter` | **REQUIRES NATIVE REWRITE** | Standard Apple Now Playing controls |
| **Audio Playback** | Headphone & Bluetooth Controls | MediaButtonReceiver + AudioRouting | `MPRemoteCommandCenter` + `AVAudioSessionRouteChange` | **REQUIRES NATIVE REWRITE** | Responds to AirPods, CarPlay, Bluetooth |
| **Audio Playback** | Audio Route Interruption (Calls/Siri)| AudioManager focus listener | `AVAudioSessionInterruptionNotification` | **REQUIRES NATIVE REWRITE** | Graceful pause and resume on end |
| **Audio Playback** | Sleep Timer | Custom coroutine timer with fade out | Swift `Task.sleep` with volume fade | **REQUIRES ADAPTATION** | Supports preset times or "Stop after track" |
| **Audio Processing**| 10-Band Parametric Equalizer | Custom C++ & Kotlin State-Variable Filters | `AVAudioUnitEQ` (10 parametric bands) | **REQUIRES NATIVE REWRITE** | In-app audio pipeline only (cannot affect system) |
| **Audio Processing**| Bass & Treble Tone Controls | Preamp & shelf filters in EqualizerProcessor | `AVAudioUnitEQ` low/high shelf bands | **REQUIRES NATIVE REWRITE** | Direct mapping to Apple audio units |
| **Audio Processing**| ReplayGain / Volume Normalization | Custom LoudnessProcessor with limiter | Track loudness metadata + volume leveling | **REQUIRES ADAPTATION** | Uses decoded track gain or standard RMS |
| **Audio Processing**| Bit-Perfect USB Exclusive Output | Android 14 `AudioMixerAttributes` + libusb | iOS CoreAudio external DAC USB output | **REQUIRES ADAPTATION** | CoreAudio routes bit-exact stream to connected Lightning/USB DAC |
| **Audio Processing**| Automix DJ Beat-Matching [Beta] | ONNX Runtime (`Beat This!`) + Signalsmith C++ | CoreML or offline beat analysis | **REQUIRES ADAPTATION** | Optional beta; keep architecture modular |
| **Music Source** | YouTube Music Search & Browse | Ktor client querying `/youtubei/v1` | Swift `URLSession` querying `/youtubei/v1` | **REQUIRES ADAPTATION** | Reuses endpoint schemas & header structure |
| **Music Source** | YouTube Stream Resolution | InnerTubeX client catalog + NewPipe | iOS/Web client context stream extraction | **REQUIRES ADAPTATION** | Clean native Swift resolver |
| **Music Source** | JioSaavn Search & High-Bitrate Stream | JioSaavn API + DES URL decryptor | Swift `URLSession` + `CommonCrypto` DES | **REQUIRES ADAPTATION** | Delivers 320 kbps AAC directly |
| **Music Source** | Local Audio File Library | Android MediaStore audio query | iOS `UIDocumentPicker` + App Sandbox directory | **REQUIRES NATIVE REWRITE** | Secure file import adhering to iOS sandbox |
| **Music Source** | Network Shares (SMB / WebDAV) | `smbj` (Java) and WebDavService | Swift SMB / WebDAV client or deferred | **REQUIRES ADAPTATION** | Low priority compared to core streaming |
| **Spotify** | Spotify OAuth Login | WebView reading session cookie/tokens | `ASWebAuthenticationSession` | **REQUIRES NATIVE REWRITE** | Standard Apple secure web auth |
| **Spotify** | Spotify Liked Songs & Playlists | Spotify Pathfinder / GraphQL & Embed API | Swift `URLSession` querying Spotify endpoints | **REQUIRES ADAPTATION** | Reads metadata only |
| **Spotify** | Spotify Track Matching | `TrackMatcher` (title, artist, album, duration)| Swift `TrackMatcher` algorithm | **REQUIRES ADAPTATION** | Confidence scoring algorithm ported to Swift |
| **Spotify** | Direct Spotify DRM Audio Streaming | Not supported in reference | Not supported (violates Spotify Terms/DRM) | **UNSUPPORTED** | Policy compliance: stream via matched sources |
| **Lyrics** | Synchronized Syllable/Word-Level Lyrics| TTML parsers (`LrcRed`, `BiniLyrics`, etc.) | Swift TTML parser + active word highlight | **REQUIRES ADAPTATION** | Beautiful Apple Music-style lyrics |
| **Lyrics** | Synchronized Line-Level Lyrics | `LRCLIB` (lrclib.net), KuGou, Musixmatch | Swift `LRCLIB` client | **REQUIRES ADAPTATION** | Open, lawful lyrics API |
| **Lyrics** | Embedded Audio File Lyrics | Reads `USLT`/`SYLT` ID3 tags from local audio| `AVURLAsset` metadata inspection | **REQUIRES NATIVE REWRITE** | Local file tag extraction |
| **Lyrics** | Manual Lyrics Offset Adjustment | Per-track offset in SharedPreferences | Per-track offset in UserDefaults | **REQUIRES ADAPTATION** | Adjust sync by ±0.1s increments |
| **Queue** | 3-Tier Queue (User, Context, Autoplay)| `QueueCoordinator` with tier preservation | Swift `actor QueueManager` | **REQUIRES ADAPTATION** | Ported state machine |
| **Queue** | Queue Persistence & Restoration | `BoundedContextPersistence` JSON serialization| Swift `Codable` atomic JSON file storage | **REQUIRES ADAPTATION** | Restores exact queue on app restart |
| **Queue** | Multi-Tier Shuffle | Multi-pass tier-aware randomizer | Swift multi-tier shuffle algorithm | **REQUIRES ADAPTATION** | Keeps user-inserted songs in place |
| **Playlists** | Local Offline Playlists & Likes | `OfflinePlaylists` JSON file store | Swift `Codable` JSON storage | **REQUIRES ADAPTATION** | Fast local-first playlists |
| **Downloads** | Offline Track Downloads & Caching | Background DownloadService + ID3/MP4 tagger| `URLSessionDownloadTask` background download | **REQUIRES NATIVE REWRITE** | Legitimately downloaded streams stored locally |
| **Downloads** | Storage Management & Cache Clearing | `DynamicLruCacheEvictor` + Settings | `FileManager` cache directory eviction | **REQUIRES NATIVE REWRITE** | Clean UI in Settings |
| **Statistics** | Wall-clock Listening Recorder | `ListeningRecorder` (50% or 4 min rule) | Swift `ListeningRecorder` sampler | **REQUIRES ADAPTATION** | Exact mathematical calculation ported |
| **Statistics** | Monthly & Yearly Replay Summaries | `ListeningStats` monthly JSON buckets | Swift monthly JSON aggregate files | **REQUIRES ADAPTATION** | Fully offline, zero telemetry |
| **Statistics** | Replay Visual Story Cards & Posters | Jetpack Compose canvas poster generation | SwiftUI Replay Views + `ImageRenderer` | **REQUIRES NATIVE REWRITE** | Shareable high-res images |
| **External** | Discord Rich Presence | Discord WebSocket gateway RPC | Swift WebSocket (`URLSessionWebSocketTask`) | **REQUIRES ADAPTATION** | In-app user login |
| **External** | Last.fm & ListenBrainz Scrobbling | Standard REST API scrobbling | Swift REST client for Last.fm & ListenBrainz | **REQUIRES ADAPTATION** | Background scrobble dispatch |
| **Streaming** | Apple AirPlay Streaming | Not natively present (Android Cast used) | `AVRoutePickerView` + `AVAudioSession` AirPlay | **NOT PRESENT IN REFERENCE** | **First-class native Apple feature** |
| **Streaming** | Google Cast (Chromecast) | Google Cast Framework (Android) | Google Cast iOS SDK (deferred/optional) | **REQUIRES NATIVE REWRITE** | Treated as distinct system from AirPlay |
| **Widgets** | iOS Home Screen & Lock Screen Widgets| Android RemoteViews AppWidgetProvider | Apple `WidgetKit` + `AppIntents` | **REQUIRES NATIVE REWRITE** | Native SwiftUI widgets |
| **System** | Dynamic Island & Live Activities | One UI 7 Samsung notification hacks | `ActivityKit` Live Activities (where supported)| **NOT PRESENT IN REFERENCE** | Note: iPhone 12 lacks Dynamic Island |
| **System** | In-App APK Updater | Android package installer intent | Not applicable on iOS (managed by AltStore/App Store)| **UNSUPPORTED** | iOS platform restriction |
| **Wearable** | Wear OS Companion App | Android Wear OS data layer | Apple Watch companion app (future milestone) | **UNSUPPORTED** | Out of scope for initial iPhone deliverable |

---

## 2. Summary Statistics

- **Total Distinct Features Analyzed:** 42
- **Requires Native Rewrite (iOS Platform APIs):** 18 (43%)
- **Requires Adaptation (Algorithmic / Protocol Logic):** 19 (45%)
- **Not Present in Reference (New Native Apple Features):** 2 (5% — AirPlay, WidgetKit)
- **Unsupported (Android-Specific / Against Apple Policy):** 3 (7% — In-app APK updater, Android Wear OS installer, Spotify DRM audio extraction)
- **Blocked:** 0 (All core features have clear native iOS implementations)
