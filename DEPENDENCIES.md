# PROJECT HAWK — DEPENDENCIES MANIFEST

**Project:** HAWK (Native iOS Music Application)  
**Philosophy:** Pure Native Swift — Zero Paid Infrastructure — Zero Heavy External Runtimes  

---

## 1. System Frameworks Utilized

HAWK utilizes the standard iOS 17.0+ SDK frameworks provided by Apple. No CocoaPods, Carthage, or heavyweight third-party packages are used:

| Framework | Purpose in HAWK | Justification / Apple HIG Fit |
|---|---|---|
| **SwiftUI** | Declarative User Interface | High performance, fluid spring animations, native Apple Human Interface Guidelines |
| **AVFoundation** | Playback, Crossfade, Audio Session | Native audio pipeline, gapless scheduling, background streaming |
| **MediaPlayer** | Lock Screen & Control Center | System transport buttons, scrubbing, artwork display on iOS Lock Screen |
| **Security** | Hardware-backed Keychain storage | Secure storage of session cookies and OAuth tokens in Secure Enclave |
| **CryptoKit** | SHA-1, SHA-256, HMAC | SAPISIDHASH signature computation for authenticated YouTube Music requests |
| **CoreImage** | Artwork Color Palette & QR Code | Fast hardware-accelerated dominant color extraction and QR generation |
| **JavaScriptCore** | Lightweight JS Engine | Safe sandboxed execution of client signature decipher algorithms if required |
| **WidgetKit** | Home & Lock Screen Widgets | Glanceable playback controls and artwork |
| **AuthenticationServices** | Spotify & Google Web Auth | `ASWebAuthenticationSession` for secure modal browser sign-in |

---

## 2. Swift Package Manager (SwiftPM) Structure

HAWK is structured into modular SwiftPM targets:
- `HawkCore`: Shared models (`Song`, `ArtistRef`, `QueueTier`, `SearchResult`), utilities, errors.
- `HawkSecurity`: Apple Keychain storage, CryptoKit hashing, secure token management.
- `HawkNetworking`: Native `URLSession` async HTTP client, rate-limiting, retry policies.
- `HawkSources`: Provider protocol abstraction, YouTube Music (`InnertubeClient`), JioSaavn, and Local Library providers.
- `HawkPlayback`: Audio state machine, dual `AVPlayer` crossfade engine, `AVAudioSession` lifecycle.
- `HawkLyrics`: Synchronized lyrics engine (`LRCLIB`, TTML parser, offset calibration).
- `HawkStats`: Wall-clock listening recorder and monthly local aggregate engine.
- `HawkUI`: Native SwiftUI components, Now Playing sheet, mesh backdrops, library views.
- `HawkApp`: Main iOS application target and App Intent integrations.
