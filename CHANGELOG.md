# CHANGELOG — PROJECT HAWK

All notable changes to Project HAWK will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased] - 2026-11-02

### Added
- **Phase Zero (M0):** Complete host environment reconnaissance report (`PROJECT_STATUS.md`).
- **Phase One (M1):** Deep reference repository audit of BitChord (`REFERENCE_AUDIT.md`, `FEATURE_INVENTORY.md`, `DEPENDENCY_AUDIT.md`, `LICENSE_AUDIT.md`, `SECURITY_AUDIT.md`).
- **Phase Two (Legal):** GPLv3 license adoption, third-party notices (`THIRD_PARTY_NOTICES.md`), and attributions (`ATTRIBUTIONS.md`).
- **Phase Three (M2):** HAWK architecture proposal (`ARCHITECTURE.md`, `MIGRATION_PLAN.md`, `ARCHITECTURE_DECISIONS.md`, `IOS_FEATURE_MAPPING.md`). Approved by user.
- **Phase Four (M3 Foundation):** Project directory structure, Git initialization, `.gitignore`, modular Swift package configuration.
- **Phase Five (M4–M9 Modules):**
  - `HawkCore`: Domain entities (`Song`, `ArtistRef`, `AudioQuality`, `Playlist`, `QueueTier`), thread-safe `PlaylistStore` actor with atomic JSON persistence.
  - `HawkSecurity`: Hardware-backed `KeychainStore` enclave, `CryptoUtils` (`SAPISIDHASH` SHA-1 and SHA-256).
  - `HawkNetworking`: `HawkHttpClient` with async retry and rate limiting, `NetworkMonitor` interface watcher.
  - `HawkSources`: `YouTubeSource` (Innertube WEB_REMIX/IOS context), `JioSaavnSource` (320kbps AAC), `LocalLibrarySource`, `TrackMatcher` confidence engine, `SpotifyImporter` regex playlist scraper, `DownloadManager` offline track manager.
  - `HawkPlayback`: `QueueManager` 3-tier queue state machine, `HawkAudioEngine` (dual AVPlayer crossfade, lock screen NowPlaying info & MPRemoteCommandCenter), `EqualizerManager` 10-band presets.
  - `HawkLyrics`: Synchronized LRC parser with millisecond precision and `LyricsEngine`.
  - `HawkStats`: Wall-clock listening recorder and monthly aggregate bucketing.
  - `HawkUI`: Apple HIG dark glass aesthetic (`HawkTheme`, `MiniPlayerView`, `NowPlayingView`, `MainTabView`, `FavoritesView`, `PlaylistsView`, `DownloadsView`, `SettingsView`).
- **Phase Six (M10–M12 Delivery & Tooling):**
  - Generated original 1024x1024 HAWK falcon waveform app icon (`AppIcon.appiconset`).
  - Added Xcode workspace (`HAWK.xcworkspace`) and XcodeGen specification (`project.yml`).
  - Added automated verification harness (`Tests/HawkVerify`) with 28 passing tests.
  - Added build automation scripts (`build.sh`, `verify.sh`, `build_ipa.sh`).
  - GitHub Actions CI workflow (`.github/workflows/ci.yml`).
