# HAWK — Independent Native Apple Music Application

[![Platform](https://img.shields.io/badge/Platform-iOS%2017.0%2B-blue.svg)](https://apple.com)
[![Swift](https://img.shields.io/badge/Swift-6.0-orange.svg)](https://swift.org)
[![License](https://img.shields.io/badge/License-GPL%20v3-green.svg)](LICENSE)

HAWK is an independent, native Apple iOS music application built for stability, audiophile fidelity, and seamless Apple ecosystem integration.

---

## Features

- **Native Audio Pipeline:** AVFoundation audio engine with true studio crossfade (0–12s) and gapless playback.
- **Lock Screen & Control Center:** Full `MPNowPlayingInfoCenter` and `MPRemoteCommandCenter` integration with high-resolution artwork and scrubbing.
- **Apple AirPlay:** First-class AirPlay route picker for streaming to HomePods, Apple TVs, and AirPlay speakers.
- **Multi-Source Streaming:** Unified streaming from YouTube Music (high-bitrate Opus/AAC), JioSaavn (320kbps AAC), and local file imports.
- **Synchronized Lyrics:** Apple-style kinetic syllable/word-timed and line-synced lyrics powered by LRCLIB and TTML parsers.
- **3-Tier Queue Management:** Protected USER_QUEUE, CONTEXT, and AUTOPLAY tiers with multi-tier shuffle.
- **Local-First Privacy:** Zero analytics, zero trackers, hardware-backed Apple Keychain storage, and monthly local Replay listening statistics.
- **Original Apple HIG Design:** Native SwiftUI interface with fluid gesture navigation, SF Symbols, and dynamic artwork mesh gradient backdrops.

---

## Target Devices & Requirements

- **Primary Target:** iPhone 12 (and all iOS 17.0+ devices)
- **Minimum OS:** iOS 17.0
- **Build System:** Swift Package Manager & Xcode 16+
- **Sideloading Target:** AltStore Classic / SideStore / TrollStore

---

## Project Structure

```
HAWK/
  App/                  # iOS Application Entry & App Delegate
  Packages/             # Modular Swift Packages
    HawkCore/           # Domain models, errors, utilities
    HawkSecurity/       # Keychain enclave & CryptoKit hashing
    HawkNetworking/     # URLSession async client & retry logic
    HawkSources/        # Music providers (YouTube, JioSaavn, Local)
    HawkPlayback/       # AVFoundation playback & crossfade engine
    HawkLyrics/         # Synchronized lyrics engine
    HawkStats/          # Listening statistics & monthly Replay
    HawkUI/             # SwiftUI components & design system
  Configuration/        # App configurations & Info.plist
  Resources/            # Assets, icons, launch screen
  Tests/                # Automated unit & integration tests
  Scripts/              # Build, test, and IPA packaging scripts
  Documentation/        # Architecture & security specifications
```

---

## License

This project is licensed under the GNU General Public License v3.0 — see the [LICENSE](LICENSE) file for details.
