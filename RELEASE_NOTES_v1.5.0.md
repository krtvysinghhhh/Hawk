# HAWK v1.5.0 Release Notes

**Release Version:** v1.5.0 (Build 7)  
**Target Platform:** iOS 17.0+ / iPadOS 17.0+ / Apple CarPlay  
**Language & Runtime:** Swift 6.4.2 / Xcode 27.2  
**License:** GNU General Public License v3.0 (GPLv3)  
**Architect:** Senior Software Engineering Team  

---

## Executive Summary

HAWK v1.5.0 represents a comprehensive engineering stabilization and production-hardening milestone for the independent native Apple iOS music player. This release resolves fundamental Swift 6 compiler type-checking bottlenecks, hardens the dual-player AVFoundation audio engine against concurrent crossfade race conditions, implements order-sensitive Levenshtein fuzzy track resolution, establishes atomic Keychain persistence, coordinates concurrent authentication token refreshes into single in-flight tasks, and introduces 7 native SwiftPM XCTest targets.

With 207 automated tests (29 SwiftPM XCTest cases + 178 verification harness tests) and zero compiler warnings or errors, HAWK v1.5.0 delivers reliable, high-fidelity music streaming across physical iPhones, iPads, and Apple CarPlay head units.

---

## What's New & Key Improvements

### 1. Swift 6 Compiler & UI Architecture Stabilization
- **Decomposed Complex SwiftUI Views:** Refactored `MainTabView.swift` (Explore genre grid) and `HawkColors.swift` (`HawkLiquidGlassModifier`) by breaking deeply nested closures into discrete subviews (`GenreCardView`) and typed intermediate computed properties (`backgroundFill`, `borderGradient`, `shadowColor`).
- **Eliminated Type-Checker Timeouts:** Fixed the root cause of CI build failures where the Swift compiler exceeded type-checking time limits.
- **Search Task Debouncing:** Implemented active task cancellation (`searchTask?.cancel()`) on rapid keystrokes in `SearchView`, preventing redundant network queries and state thrashing.
- **Interface Orientation Alignment:** Added `UIRequiresFullScreen: true` and complete iPad interface orientations to `project.yml` and `Info.plist`, eliminating all Xcode build warnings.

### 2. AVFoundation Playback Hardening
- **Race-Condition-Free Crossfade:** Replaced uncoordinated dual-player crossfade tasks with explicit cancellation checks (`crossfadeTask?.cancel()`) upon rapid track skips, pauses, or seeks.
- **Preload Lifecycle Management:** Enforced synchronous cancellation of pending asset preloads (`preloadTask?.cancel()`) when interrupting playback.
- **Observer Leak Prevention:** Centralized audio session and route change notification observers into tracked memory collections (`sessionObservers: [any NSObjectProtocol]`), ensuring complete cleanup.
- **Expired Stream Protection:** Integrated playback failure recovery that triggers fresh stream URL resolution when an expired stream link is encountered.

### 3. Multi-Source Streaming & Resolution Accuracy
- **Deterministic Fuzzy Matching:** Replaced naive character-set intersection with a dynamic-programming Levenshtein distance algorithm in `SourceResolver`. Anagrams and out-of-order titles are properly rejected while title variations (e.g. `feat.`, `ft.`, `(Official Video)`) are normalized cleanly.
- **Stream Quality Ceiling Enforcement:** Filtered audio streams strictly against maximum configured bitrates (128kbps, 256kbps, 320kbps) while validating that stream URLs have not expired.
- **InnerTube Filter Scoping:** Added explicit category parameters for YouTube searches (`.songs`, `.albums`, `.artists`, `.playlists`) and video ID deduplication.
- **Download Path Sanitization:** Sanitized offline filenames against directory traversal attacks and prevented simultaneous duplicate downloads of the same track.

### 4. Networking & Concurrency Resilience
- **Smart Exponential Backoff:** Added randomized jitter (`0.8...1.2`) to retry delays to mitigate thundering herd effects against upstream APIs.
- **RFC 7231 Retry-After Support:** Parsed HTTP `Retry-After` headers on 429/503 responses, respecting upstream rate limits up to a bounded 10-second ceiling.
- **Cancellation Propagation:** Ensured `CancellationError` and `URLError.cancelled` immediately exit retry loops without synthetic delay or spurious re-execution.
- **Single-Flight Token Refresh:** Coordinated concurrent Google Music token refresh requests in `GoogleMusicSyncManager` into a single shared `Task<String, Error>`, preventing duplicate OAuth handshakes.

### 5. Security & Persistence Enclave
- **Atomic Keychain Upsert:** Replaced destructive delete-then-add logic with atomic `SecItemUpdate` falling back to `SecItemAdd`, eliminating the risk of permanent credential loss if re-insertion failed.
- **Forward-Compatible Playlist Storage:** Added future-schema version preservation (`future_schema_backup.json`) to prevent data corruption when older app versions encounter newer schema payloads.

### 6. Automated Testing & Verification Suite
- **7 Native SwiftPM XCTest Targets:** Added `HawkCoreTests`, `HawkSecurityTests`, `HawkNetworkingTests`, `HawkSourcesTests`, `HawkPlaybackTests`, `HawkLyricsTests`, and `HawkStatsTests` to `Package.swift`.
- **29 Automated XCTest Cases:** Real deterministic unit and integration tests covering Levenshtein string metrics, Keychain updates, network cancellation, and playlist integrity.
- **Transparent Verification Reporting:** Replaced hardcoded dummy assertions in `HawkVerify` with genuine runtime checks and explicit, honest skip reporting (`skipTest`) for macOS CLI hardware limitations.
- **CI Modernization:** Updated `.github/workflows/ci.yml` to execute both `swift test` and `swift run HawkVerify` on pull requests and pushes to `main`.

---

## Test Verification Summary

| Suite | Executed | Passed | Failed | Skipped | Status |
|:---|:---:|:---:|:---:|:---:|:---:|
| **SwiftPM XCTest Suite** | 29 | 29 | 0 | 0 | **100% Pass** |
| **HawkVerify Harness** | 178 | 177 | 0 | 1 | **100% Pass** (1 HW skipped) |
| **Total Automated Assertions** | **207** | **206** | **0** | **1** | **VERIFIED** |
| **Xcode Release Build** | — | — | 0 Errors | 0 Warnings | **BUILD SUCCEEDED** |

*Note: The single skipped test in `HawkVerify` is `hardwareConfig`, which requires a physical iOS audio hardware route (`AVAudioSession.isInputAvailable`) unavailable in macOS Darwin terminal environments.*

---

## Known Hardware Limitations

1. **AVAudioSession Hardware Verification:** Real-time audio session interruption by telephonic calls and Bluetooth route changes requires physical iOS execution with connected audio accessories.
2. **Apple CarPlay Head Unit Testing:** Production distribution of CarPlay requires the Apple-granted `com.apple.developer.carplay-audio` entitlement. On developer devices and simulators, CarPlay functions via the provided `Configuration/HAWK-CarPlay.entitlements` file.
3. **Third-Party Streaming Rate Limits:** YouTube InnerTube and JioSaavn endpoints are subject to third-party rate limiting; exponential backoff with jitter and 1-hour stream caching minimize upstream request volume.

---

## Upgrade & Installation Guide

### AltStore / SideStore / TrollStore (Recommended)
1. Download `HAWK.ipa` from the GitHub Release assets.
2. Open AltServer on your Mac/PC, connect your iOS device via USB or local Wi-Fi.
3. Sideload `HAWK.ipa` to install or upgrade in-place. All existing playlists and downloaded audio files are preserved.

### Building from Source
```bash
# Clone the repository
git clone https://github.com/krtvysinghhhh/Hawk.git
cd Hawk

# Run the complete test suite
swift test
swift run HawkVerify

# Generate Xcode project and build
xcodegen generate
xcodebuild clean build \
  -project HAWK.xcodeproj \
  -scheme HAWK \
  -configuration Release \
  -destination 'generic/platform=iOS' \
  CODE_SIGN_IDENTITY="" \
  CODE_SIGNING_REQUIRED=NO \
  CODE_SIGNING_ALLOWED=NO
```
