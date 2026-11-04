# Changelog — Project HAWK

All notable changes to Project HAWK are documented in this file.
The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

---

## [1.3.0] - 2026-11-04

### Added & Fixed
- **Playback Engine Reliability & Queue Synchronization (P0):**
  - Resolved malfunctioning Previous Track and Next Track controls across the entire system.
  - Linked `MPRemoteCommandCenter` (Lock Screen, Apple Control Center, AirPods/Bluetooth, CarPlay) directly to `PlaybackCoordinator` via delegated closures.
  - Standardized Previous Track behavior: seeks to 0.0s when `currentTime > 3.0s`; goes to previous track in queue when `currentTime <= 3.0s`.
  - Fixed context loss across Home carousels, top hits, search results, and playlists by always passing and updating active playback contexts.
- **Official Brand Identity & Restrained Palette:**
  - Standardized official colour system: Near-black `#0B0B0D`, Secondary `#151518`, Soft ivory `#F2F0EB`, Secondary text `#96969D`, Dividers `#29292F`, Accent Muted violet `#7867A8`, Light Warm white `#F7F7F5`.
  - Authoritative minimalist geometric hawk head monogram applied to all asset catalogs, About panels, and app icon.
- **Automatic Day/Night System Appearance:**
  - Added user appearance mode settings: System (default), Light, and Dark with dynamic `@AppStorage` persistence and non-restarting UI adaptation.
- **Live Synchronised Lyrics Engine (P0):**
  - Prominent active line centering with auto-scroll and 120ms perceptual lead time.
  - Enhanced word-level highlighting for word-synced LRC lines.
  - Automatic resume timer: scrolls manually suspend auto-follow and smoothly re-center 4.5 seconds after user ceases interaction.
  - Full support for `accessibilityReduceMotion`.
- **Playlist Portability System (P1):**
  - Dedicated interactive `PlaylistImportView` supporting M3U, M3U8, JSON files, and Spotify / web playlist links.
  - Three-tier match preview showing Matched, Ambiguous (for user correction), and Missing tracks.
  - One-tap M3U8 export in `PlaylistDetailView` using native iOS `ShareLink`.
- **Google Login & YouTube Music Library Sync (P0/P1):**
  - Implemented `GoogleMusicSyncManager` with `ASWebAuthenticationSession` PKCE OAuth 2.0 flow.
  - Keychain token persistence with secure cleanup on disconnect.
  - Strict music-only scope importing liked tracks and user-created music playlists while excluding watch history, comments, and channels.
- **Automated Verification:**
  - Expanded test suite to **75 passing tests (0 failed)**.

## [1.2.1] - 2026-11-03

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
