# HAWK v1.5.0 — PHYSICAL DEVICE & REGRESSION TEST CHECKLIST

**Target Device:** iPhone 12 / 13 / 14 / 15 / 16 / 17 Series (iOS 17.0+)  
**Secondary Targets:** iPad (iPadOS 17.0+), Apple CarPlay Vehicle Head Units  
**Hardware Verification Status:** **PENDING PHYSICAL DEVICE CONNECTION**  
**Offline Device Detected:** `Kartavya’s iPhone (27.2)` (`00008101-001E542A3EE2001E`)  

---

## 1. Verification State Legend

- ✅ **AUTOMATED & VERIFIED:** Verified deterministically via SwiftPM XCTest or HawkVerify.
- 📱 **SIMULATOR VERIFIED:** Verified in iOS Simulator software execution pipeline.
- 🔍 **MANUAL ON-DEVICE REQUIRED:** Requires physical iPhone interaction.
- ⚠️ **BLOCKED BY HARDWARE:** Requires physical hardware currently unavailable/offline.

---

## 2. Regression Checklist

### Phase 1: Installation & Onboarding
- [ ] 🔍 **Sideload Installation:** Install `HAWK.ipa` via AltStore Classic, SideStore, or TrollStore. Verify the app installs without entitlement rejection.
- [ ] 📱 **App Launch:** Verify cold launch completes in <400ms without splash screen stutter.
- [ ] 📱 **Initial Permission Prompts:** Confirm no unneeded permission prompts (camera, location, contacts) appear.

### Phase 2: Authentication & Security Enclave
- [x] ✅ **PKCE Code Challenge & Verifier:** Verified by automated cryptographic tests.
- [x] ✅ **State Token CSRF Verification:** Verified by automated URL parser tests.
- [ ] 🔍 **ASWebAuthenticationSession Interactive Sign-In:** Complete Google sign-in; verify browser sheet presents and redirects to `com.hawk.music://oauth2callback`.
- [x] ✅ **Keychain Enclave Storage:** Verified via `testKeychainStoreUpsertPreservesState`.
- [ ] 🔍 **Disconnect / Sign-Out:** Verify sign-out executes `purgeAll()`, clearing cached tokens while preserving local playlists.

### Phase 3: Search, Discovery & Source Resolution
- [x] ✅ **Deterministic Levenshtein Matching:** Verified via `testAnagramRejectionInDeterministicMatcher`.
- [x] ✅ **Quality Ceiling Enforcement:** Verified via format selector tests.
- [ ] 🔍 **Search Responsiveness:** Search for "The Weeknd" on cellular and Wi-Fi; verify results render in <250ms with debouncing.
- [ ] 🔍 **Source Switching:** Manually switch track playback from YouTube Music to JioSaavn stream.

### Phase 4: Audio Engine & Playback Stress
- [x] ✅ **9-State Playback Machine:** Verified via `testPlaybackStateTransitions`.
- [x] ✅ **Crossfade Clamping (0–12s):** Verified via `testCrossfadeDurationClamping`.
- [x] ✅ **Standby Player Cancellation:** Verified via `testStopResetsPlaybackStateToIdleAndClearsPlayers` and `testPauseStopsStandbyPlayer`.
- [ ] 🔍 **Rapid Track Skipping:** Rapidly tap "Next" 10 times in 3 seconds; verify no audio overlaps, volume spikes, or crash.
- [ ] 🔍 **Seek Scrubbing:** Scrub audio slider during active stream buffering; verify playhead resumes smoothly.
- [ ] ⚠️ **Telephony Audio Interruption:** Receive incoming cellular call while playing; verify audio pauses cleanly and resumes upon call termination (`.shouldResume`).

### Phase 5: Bluetooth, AirPlay & Lock Screen
- [x] ✅ **MPNowPlayingInfoCenter Metadata:** Verified via `updateNowPlaying` test assertions.
- [x] ✅ **MPRemoteCommandCenter Handlers:** Verified via remote command tests.
- [ ] ⚠️ **AirPods / Bluetooth Connect & Disconnect:** Disconnect Bluetooth headphones during playback; verify playback immediately pauses per Apple HIG (`.oldDeviceUnavailable`).
- [ ] ⚠️ **AirPlay Route Switch:** Stream to HomePod or Apple TV; verify volume and playback controls respond without latency.
- [ ] 🔍 **Lock Screen & Dynamic Island:** Verify artwork, title, artist, elapsed time, and scrubber display accurately on Lock Screen.

### Phase 6: Tap-to-Seek Synchronized Lyrics
- [x] ✅ **LRC Parser Accuracy:** Verified via `testLrcParser`.
- [ ] 🔍 **Live Lyric Scrolling:** Confirm current line highlights in coral `#FF375F` in sync with audio.
- [ ] 🔍 **Tap-to-Seek Scrubbing:** Tap a future lyric line; verify AVPlayer immediately jumps to that exact timestamp.
- [ ] 🔍 **Floating Sync Pill:** Scroll away from active line; verify floating glass pill *"Sync to Audio"* appears and centers the view when tapped.

### Phase 7: Downloads & Offline Storage
- [x] ✅ **Path Traversal Defense:** Verified via `testDownloadPathTraversalSanitization`.
- [x] ✅ **Concurrent Download Protection:** Verified via `testDownloadManagerDuplicatePrevention`.
- [ ] 🔍 **Airplane Mode Playback:** Enable Airplane Mode; verify downloaded tracks play without network access.
- [ ] 🔍 **Storage Management:** Delete downloaded track from Library; verify file is removed from disk.

### Phase 8: Apple CarPlay Vehicle Integration
- [x] ✅ **CarPlay Template Architecture:** Verified via `CPTemplateApplicationSceneDelegate` inspection.
- [ ] ⚠️ **In-Car Vehicle Head Unit Test:** Connect iPhone to CarPlay head unit or run CarPlay Simulator via **Xcode -> I/O -> External Displays -> CarPlay**. Verify *Listen Now*, *Playlists*, *Library*, and *Now Playing* navigation.
- [ ] ⚠️ **CarPlay Steering Wheel Controls:** Verify next/prev buttons on steering wheel trigger `onNextRequested` and `onPreviousRequested`.

### Phase 9: Accessibility & UI Themes
- [x] ✅ **Theme Hex Values & Fallbacks:** Verified via `HawkTheme` unit assertions.
- [ ] 🔍 **Dynamic Type Scaling:** Test with iOS Largest Accessibility Text; verify no truncated labels.
- [ ] 🔍 **Reduce Motion & Transparency:** Enable in iOS Settings; verify Liquid Glass modifiers fall back to high-contrast opaque materials without blur animations.
- [ ] 🔍 **Dark / Light Appearance:** Toggle system dark mode; verify instant UI adaptation without flash.
