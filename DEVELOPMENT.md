# HAWK — Development Guide

**Target Audience:** iOS Engineers, Audio Systems Specialists, QA Engineers  
**Toolchain:** Swift 6.0+, Xcode 16+, XcodeGen  
**Target Device:** iPhone 12 (and iOS 17.0+ devices)  

---

## 1. Environment & Prerequisites

- **macOS:** macOS Sonoma 14+ or macOS Sequoia 15+
- **Xcode:** Xcode 16.0 or later (configured via `sudo xcode-select -s /Applications/Xcode.app/Contents/Developer`)
- **XcodeGen:** Required for generating `.xcodeproj` from `project.yml`:
  ```bash
  brew install xcodegen
  ```

---

## 2. Quick Start

### Build and Verify via SwiftPM
Build all core frameworks, audio state machines, cryptographic utilities, and run the 57-test automated verification suite:

```bash
cd HAWK
swift run HawkVerify
```

### Regenerate Xcode Project
Whenever project structure or source files are added/modified:
```bash
xcodegen generate
```

### Build & Export Release IPA
To produce an installable `.ipa` for physical devices (AltStore / TrollStore / Sideloadly):
```bash
./Scripts/build_ipa.sh
```
Output artifact is generated at `build/HAWK.ipa`.

---

## 3. Apple CarPlay Integration & Testing

HAWK integrates native Apple CarPlay support using the `CarPlay` framework and `CPTemplateApplicationSceneDelegate`.

### CarPlay Scene Architecture
- **Delegate:** `HawkCarPlaySceneDelegate` (`App/HawkCarPlaySceneDelegate.swift`)
- **Root Template:** `CPTabBarTemplate` exposing **Listen Now**, **Favourites**, **Playlists**, and **Library**.
- **Now Playing:** Full synchronization with `CPNowPlayingTemplate.shared` and `PlaybackCoordinator`.

### Testing in the CarPlay Simulator
1. Launch Xcode and boot any iOS 17+ Simulator (`Xcode` -> `Open Developer Tool` -> `Simulator`).
2. Run the `HAWK` scheme on the simulator.
3. In the Simulator menu, navigate to:
   **I/O -> External Displays -> CarPlay**
4. A secondary CarPlay vehicle display will appear running the native HAWK in-car interface.

### CarPlay Distribution Entitlement Requirement
- Distribution on the Apple App Store requires the official `com.apple.developer.carplay-audio` entitlement granted by Apple.
- Entitlement reference: [Requesting CarPlay Entitlements](https://developer.apple.com/documentation/carplay/requesting-carplay-entitlements).
- A reference entitlement file is provided at `Configuration/HAWK-CarPlay.entitlements`.
- For standard sideloading (free Apple ID via AltStore), the active build leaves unauthorized entitlements disabled so installations succeed cleanly without signing conflicts.

---

## 4. Architectural Rules

1. **Swift Concurrency:** All shared mutable state is isolated within `actor` types (`HawkAudioEngine`, `QueueManager`, `PlaylistStore`, `DownloadManager`).
2. **True State Synchronization:** Never simulate playback states. UI indicators (play/pause, buffer spinners, scrubbing elapsed time) must strictly reflect `AVPlayer` state.
3. **Local Privacy:** No third-party analytical SDKs or tracking networks are permitted.
