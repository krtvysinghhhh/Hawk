# PROJECT HAWK — ARCHITECTURAL DECISION RECORDS (ADR)

**Document ID:** HAWK-ADR-001  
**Project:** HAWK (Native iOS Music Application)  

---

## ADR-001: Pure Swift Concurrency & Actors vs. Reactive Frameworks

### Context
BitChord uses Kotlin Coroutines and StateFlows heavily. On iOS, asynchronous operations and shared state can be handled via Combine, RxSwift, or modern Swift Concurrency (async/await, Tasks, Actors).

### Decision
Adopt modern **Swift 6 Concurrency and Actors** exclusively. Use `@Observable` for SwiftUI state models.

### Rationale
- Zero third-party dependency overhead (eliminates RxSwift / RxCocoa).
- Superior compile-time thread safety via Sendable checking and Actor isolation.
- Native integration with modern SwiftUI (iOS 17+).
- Dramatically cleaner call sites compared to Combine subscriber pipelines.

---

## ADR-002: Dual AVPlayer Coordinated Crossfade vs. AVAudioEngine

### Context
Seamless crossfading (0–12s) requires two audio decoders running simultaneously during transitions. Android BitChord uses two ExoPlayer instances. On iOS, we evaluated:
1. `AVAudioEngine` with `AVAudioPlayerNode`s and `AVAudioUnitEQ`.
2. Coordinated dual `AVPlayer` instances with volume ramps.

### Decision
Use **coordinated dual `AVPlayer` instances** as the primary streaming playback engine, with an `AVQueuePlayer` fallback for gapless playback when crossfade is 0s.

### Rationale
- `AVPlayer` handles remote progressive HTTP streaming, adaptive bitrates (HLS), chunked caching, and AirPlay natively with minimal battery consumption.
- `AVAudioPlayerNode` requires full audio files to be downloaded or manually decompressed into PCM audio buffers before scheduling, creating latency and high memory spikes on an 8 GB host and mobile device.
- Dual `AVPlayer` volume ramping provides smooth equal-power crossfades with zero buffer management overhead.

---

## ADR-003: Atomic JSON Files & Apple Keychain vs. Core Data / SwiftData / SQLite

### Context
BitChord avoids Room and SQLite, using SharedPreferences and JSON. On iOS, options include SwiftData, Core Data, SQLite.swift, or Atomic JSON documents.

### Decision
Use **Atomic JSON Documents** for playlists, queue state, and monthly stats; use **Apple Keychain** for credentials and tokens; use **UserDefaults** for simple boolean flags.

### Rationale
- SwiftData and Core Data introduce significant schema migration overhead, multithreading complexity, and SQLite locking issues.
- The data volume in HAWK (playlists of hundreds of tracks, monthly listening counts) is well under a few megabytes.
- Atomic writes (`Data.write(to:options: .atomic)`) guarantee ACID crash-resilience with zero corruption risk.
- Simple, testable, and completely human-inspectable for export and backup.

---

## ADR-004: Independent Swift Innertube Client vs. Java Extractor Porting

### Context
BitChord uses `InnerTubeX` and `NewPipeExtractor` with Mozilla Rhino JS engine to decipher YouTube player signatures.

### Decision
Implement a clean, native Swift **`InnertubeClient`** querying YouTubei's mobile and web remix endpoints directly, using standard client identities (`WEB_REMIX`, `IOS`) that deliver direct audio streams without requiring a heavyweight JavaScript runtime.

### Rationale
- Avoids bundling massive Java or QuickJS runtimes in an iOS app.
- Keeps binary size below 15 MB and startup time under 300 ms on iPhone 12.
- Adheres to clean-room legal independence from GPL-licensed NewPipeExtractor source.

---

## ADR-005: Native Apple HIG Design System vs. Android UI Reproduction

### Context
The user directive strictly mandates: *"HAWK must be recognisably native to Apple's ecosystem... It must not look like an Android interface placed inside an iPhone."*

### Decision
Design an original, Apple-native SwiftUI visual system adhering to Apple Human Interface Guidelines:
- Standard Apple bottom navigation bar with SF Symbols.
- Native sheet transitions with interactive drag-to-dismiss.
- Native dynamic typography (`SF Pro`) and Dynamic Type scaling.
- Apple-style blurred translucent materials (`.ultraThinMaterial`).
- Kinetic synchronized lyrics with spring animations.

### Rationale
- Provides the polish and familiarity expected of top-tier iOS music applications (e.g. Apple Music, Marvis Pro).
- Fully accessible with VoiceOver and Reduce Motion support.

---

## ADR-006: Local-First Privacy & Zero Telemetry

### Context
Commercial music players integrate analytics, crash reporters, and trackers.

### Decision
HAWK is strictly **local-first**:
- Zero analytics, trackers, or advertising SDKs.
- Listening statistics are recorded locally and never transmitted off-device.
- External connections are made exclusively to user-selected music and lyrics sources.
