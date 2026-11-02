# Changelog — Project HAWK

All notable changes to Project HAWK are documented in this file.
The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

---

## [1.1.0] - 2026-11-02

### Added
- **Apple CarPlay Audio Integration:**
  - Implemented `HawkCarPlaySceneDelegate` conforming to `CPTemplateApplicationSceneDelegate`.
  - In-car tabbed browsing via `CPTabBarTemplate`: Listen Now, Favourites, Playlists, and Library (Artists, Songs, Queue).
  - Full synchronization with `CPNowPlayingTemplate.shared` and `PlaybackCoordinator`.
  - Prepared `Configuration/HAWK-CarPlay.entitlements` with `com.apple.developer.carplay-audio`.
- **Dedicated Personal Music Library:**
  - Comprehensive Apple Music-inspired Library hub in bottom navigation.
  - Category routes with custom iconography and badge accents: Playlists, Artists, Albums, Songs, Favourites, Recently Added, Downloads, and Local Files.
  - `AllSongsView` with full-text search, Play All, and Shuffle All controls.
  - `ArtistsView` and `AlbumsView` with alphabetical groupings and discography drill-down.
  - `LibraryAggregator` service aggregating distinct user tracks across playlists, downloads, and favorites.
- **Official Brand Identity:**
  - Adopted official HAWK rainbow-wave dimensional artwork as the master application icon.
  - Generated high-resolution 1024×1024 `AppIcon.appiconset` asset catalog compliant with Xcode and Apple App Store specifications.
  - Master logo asset placed in `Resources/hawk-logo.png`.
- **Liquid Glass Design System:**
  - Native SwiftUI `.ultraThinMaterial` surfaces with continuous corner radii (`.continuous`) and specular gradient borders.
  - Interactive press effects with dynamic spring animations.
  - Built-in accessibility fallbacks for *Reduce Transparency* and *Reduce Motion*.
- **Editorial 1:1 Home Screen:**
  - Dynamic time-of-day greeting ("Good morning", "Good afternoon", "Good evening").
  - Editorial featured hero banner with blurred artwork backdrop and floating Liquid Glass play button.
  - 1:1 square artwork horizontal carousels (160×160pt) for Jump Back In, Made For You, Trending Worldwide, and Favorite Artists.
- **Predictive Stream Preload & Cache:**
  - In-memory stream resolution cache with 1-hour TTL.
  - Background `AVPlayerItem` asset preloader (`triggerPredictivePreload`) for instant track transitions.
- **Enhanced Synchronized Lyrics:**
  - Real-time line highlighting synced to true `AVPlayer` hardware time.
  - Tap-to-seek on any lyric line to jump audio directly to that timestamp.
  - Manual scroll detection with floating "Sync to Audio" re-center pill.
- **Automated Verification & CI:**
  - Expanded `HawkVerify` automated test suite to 57 passing tests.
  - Added GitHub Actions CI workflow (`.github/workflows/ci.yml`) for macOS 14 runners.

---

## [1.0.0] - 2026-11-02

### Added
- **Core Architecture:**
  - Complete independent native iOS music application codebase in Swift 6.
  - Modular package architecture: `HawkCore`, `HawkSecurity`, `HawkNetworking`, `HawkSources`, `HawkPlayback`, `HawkLyrics`, `HawkStats`, `HawkUI`.
- **Audio & Playback:**
  - AVFoundation dual-player engine with studio crossfade (0–12s).
  - True 9-state playback machine (`idle`, `loading`, `buffering`, `ready`, `playing`, `paused`, `seeking`, `ended`, `failed`).
  - JioSaavn live DES decryption with key `38346591`.
  - YouTube Music high-bitrate audio streaming with SAPISIDHASH signature authentication.
  - 3-tier queue management (`userQueue`, `context`, `autoplay`).
  - Lock Screen Control Center integration (`MPNowPlayingInfoCenter`, `MPRemoteCommandCenter`).
- **Discovery & Metadata:**
  - `TrackMatcher` confidence scoring algorithm.
  - Version preservation for Live, Remix, Remaster, and Acoustic recordings.
  - High-resolution 500×500 artwork upscaling.
  - Spotify playlist URL regex importer.
- **Testing & Packaging:**
  - Automated verification test suite (`HawkVerify`).
  - Standalone release package script (`build_ipa.sh`) for AltStore sideloading.
