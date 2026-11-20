# HAWK v1.5.0 — MASTER ENGINEERING CHANGELOG

**Target:** HAWK v1.5.0 (Build 7)  
**Author:** Staff Software Architect & Lead Release Manager  
**Branch:** `engineering/hawk-1.5.0-stabilization`  

---

## Summary of Code Changes

### 1. `Packages/HawkUI/Sources/HawkUI/HawkColors.swift`
- **Why Necessary:** Swift 6 actor isolation warning for navigation bar appearance; compiler type-checking bottlenecks in `HawkLiquidGlassModifier`.
- **Changes:**
  - Added `@MainActor` attribute to `public static func configureSystemAppearance()`.
  - Extracted computed subviews and properties (`backgroundFill: some View`, `borderColors: [Color]`, `borderGradient: LinearGradient`, `shadowColor: Color`) from `HawkLiquidGlassModifier.body(content:)` to reduce generic constraint solver depth.
- **Compatibility:** Fully compatible; improves compilation speed and eliminates actor warning.

### 2. `Packages/HawkUI/Sources/HawkUI/MainTabView.swift`
- **Why Necessary:** Swift compiler timeout on `ExploreView.body` around line 480 due to complex untyped tuple iteration and nested ViewBuilders; search task flooding on rapid keystrokes.
- **Changes:**
  - Introduced `struct GenreCategory: Identifiable` with typed `name`, `icon`, `query`, and `color` fields.
  - Created standalone component `struct GenreCardView: View`.
  - Refactored `ExploreView.body` to use `ForEach(genres) { ... }` with `GenreCardView`.
  - In `SearchView`, added `@State private var searchTask: Task<Void, Never>?` and cancelled any active search task upon receiving new query input.
- **Compatibility:** Fully preserves visual appearance and interaction behavior while guaranteeing fast, stable compile times.

### 3. `Packages/HawkPlayback/Sources/HawkPlayback/HawkAudioEngine.swift`
- **Why Necessary:** Race conditions during rapid track selection when crossfade was active; notification observer memory leaks; missing cancellation checks before player item replacement.
- **Changes:**
  - Added `crossfadeTask?.cancel()` and `preloadTask?.cancel()` at the beginning of `play(song:isAutoAdvance:)`.
  - Added `crossfadeTask?.cancel()` in `pause()`.
  - Added `guard !Task.isCancelled else { return }` inside `executeCrossfade` before pausing outgoing player and replacing item with nil.
  - Stored `NotificationCenter` observer tokens in `sessionObservers` array.
- **Compatibility:** 100% backward compatible. Eliminates unexpected pauses and volume glitches during rapid track switching.

### 4. `Packages/HawkSources/Sources/HawkSources/YouTubeSource.swift`
- **Why Necessary:** Quality ceiling fallback previously selected the highest-bitrate format when ceiling wasn't met; search filter parameter was ignored; duplicate video IDs in search results.
- **Changes:**
  - Filtered adaptive formats by valid audio MIME types (`audio/mp4`, `audio/webm`, `audio/m4a`, `audio/aac`).
  - Added stream URL `expire` timestamp verification.
  - Strictly enforced quality ceiling: formats must satisfy `bitrate <= qualityCeiling.maxKbps`; if none qualify, throws `HawkError.streamNotFound` instead of knowingly exceeding the ceiling.
  - Handled `SearchFilter` parameter (`.songs`, `.albums`, `.artists`, `.playlists`) by injecting YouTube Music InnerTube `params` tokens.
  - Added `seenIds` set in `parseSearchResults` to prevent duplicate search results.
  - Checked `playabilityStatus` for unplayable or login-required tracks.
- **Compatibility:** Preserves existing public API; improves stream selection reliability and data savings.

### 5. `Packages/HawkSources/Sources/HawkSources/SourceResolver.swift`
- **Why Necessary:** Anagram false positives in `TrackMatcher.stringSimilarity` caused by character-set Jaccard index; inadequate title normalization.
- **Changes:**
  - Replaced character-set intersection with deterministic two-row Levenshtein distance algorithm: `max(0.0, 1.0 - (Double(distance) / Double(maxLen)))`.
  - Expanded normalization to strip `(feat.`, `(ft.`, `(with`, `[official video]`, `(official audio)`, `[music video]`, `(lyrics)`.
- **Compatibility:** Preserves public method signatures; significantly increases track matching precision across disparate providers.

### 6. `Packages/HawkNetworking/Sources/HawkNetworking/HawkHttpClient.swift`
- **Why Necessary:** Cancellation was caught and retried like transient errors; lack of jitter in backoff; unhandled HTTP `Retry-After`.
- **Changes:**
  - Added strict check for `CancellationError`, `Task.isCancelled`, and `URLError.cancelled` to rethrow immediately without retrying.
  - Filtered non-retryable URL errors (`.badURL`, `.unsupportedURL`, etc.).
  - Added randomized jitter `Double.random(in: 0.8...1.2)` to exponential backoff delay.
  - Parsed HTTP `Retry-After` header for status 429 and 503 (bounded to 10s maximum).
- **Compatibility:** Drop-in enhancement for all networking consumers.

### 7. `Packages/HawkSecurity/Sources/HawkSecurity/KeychainStore.swift`
- **Why Necessary:** Deleting existing Keychain item before adding replacement caused potential permanent credential loss on failed insertion.
- **Changes:**
  - Implemented safe atomic upsert: first attempts `SecItemUpdate`; if `errSecItemNotFound`, executes `SecItemAdd`.
  - Guaranteed existing credential is never purged unless replacement succeeds.
- **Compatibility:** Identical public API; eliminates data loss risk.

### 8. `Packages/HawkSources/Sources/HawkSources/GoogleMusicSyncManager.swift`
- **Why Necessary:** Concurrent callers requesting an expired access token triggered simultaneous refresh requests to Google token endpoint.
- **Changes:**
  - Added single-flight `inFlightRefreshTask: Task<String, Error>?` coordination.
  - Refactored token refresh into dedicated `performTokenRefresh` helper.
- **Compatibility:** Transparent to callers; prevents API token race conditions.

### 9. `Packages/HawkCore/Sources/HawkCore/PlaylistStore.swift`
- **Why Necessary:** Opening files with future schema versions had no protection against data clobbering.
- **Changes:**
  - Added forward-compatibility backup: saves `future_schema_backup.json` when `envelope.schemaVersion > PlaylistEnvelope.currentVersion`.
- **Compatibility:** Fully backward and forward compatible.

### 10. `Packages/HawkSources/Sources/HawkSources/DownloadManager.swift`
- **Why Necessary:** Calling download on an active download spawned duplicate tasks; filenames needed sanitization.
- **Changes:**
  - Added active task check in `download(song:)` to await existing task if in progress.
  - Sanitized destination filenames against path traversal.
- **Compatibility:** Thread-safe actor improvement.

### 11. `Package.swift` & `Tests/`
- **Why Necessary:** SwiftPM had no test targets wired up (`swift test` failed); `HawkSecurityTests.swift` had a missing `try`.
- **Changes:**
  - Wired all 7 test targets (`HawkCoreTests`, `HawkSecurityTests`, `HawkNetworkingTests`, `HawkSourcesTests`, `HawkPlaybackTests`, `HawkLyricsTests`, `HawkStatsTests`) in `Package.swift`.
  - Added missing `try` to `await store.delete(key: key)` in `HawkSecurityTests.swift`.
  - Added 29 robust XCTest cases across all targets.
  - In `HawkVerify/main.swift`, replaced fake unconditional assertion with real iOS check or explicit `skipTest`.
- **Compatibility:** Restores full `swift test` and `swift run HawkVerify` compliance.

### 12. `project.yml`, `Configuration/Info.plist`, & `.github/workflows/ci.yml`
- **Why Necessary:** Target version bump to 1.5.0; eliminate interface orientation warning; include XCTest execution in CI.
- **Changes:**
  - Bumped version to `1.5.0` (Build 7).
  - Added `UIRequiresFullScreen: true` and iPad interface orientations.
  - Updated CI workflow to execute both `swift test` and `swift run HawkVerify`.
- **Compatibility:** App Store and Xcode 16/27 compliant.
