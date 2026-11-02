# PROJECT HAWK — THIRD-PARTY NOTICES

This file records the third-party software components, open-source libraries, web service specifications, and attributions acknowledged in Project HAWK.

---

## 1. Reference Architecture & Functional Concepts

### BitChord
- **Author:** Kushagra Singh (`kushagrasinghx`)
- **Repository:** https://github.com/kushagrasinghx/BitChord
- **License:** GNU General Public License v3.0 (GPLv3)
- **Notice:** HAWK acknowledges BitChord as an architectural and functional reference for understanding YouTube Music client design, multi-tier queue models, and synchronized lyrics integration. HAWK is an independent native Swift implementation with original visual identity, codebase, and Apple-centric architecture.

---

## 2. Public APIs & Web Services

### LRCLIB
- **Provider:** LRCLIB (`https://lrclib.net`)
- **Author:** Tran Chau
- **License:** MIT License
- **Notice:** HAWK queries the public LRCLIB API to retrieve synchronized, line-level and plain-text lyrics for musical tracks.

### Spotify Web API & Embed Services
- **Provider:** Spotify AB
- **Terms:** https://developer.spotify.com/terms/
- **Notice:** HAWK queries public and user-authorized Spotify API endpoints strictly for metadata and playlist structure. HAWK does not stream or cache DRM-protected Spotify audio streams.

### YouTube Music / Innertube Services
- **Provider:** Google LLC / YouTube LLC
- **Notice:** HAWK communicates with public `music.youtube.com` endpoints for browsing, searching, and user-authenticated library management. HAWK is not affiliated with or endorsed by Google LLC or YouTube.

---

## 3. Apple Open Source & System Frameworks

HAWK is built exclusively upon native Apple developer frameworks:
- `SwiftUI` & `UIKit`
- `AVFoundation` (`AVPlayer`, `AVAudioSession`, `AVAudioEngine`, `AVAudioUnitEQ`)
- `MediaPlayer` (`MPNowPlayingInfoCenter`, `MPRemoteCommandCenter`)
- `WidgetKit`
- `Security` & `CryptoKit`
- `CoreImage`
- `JavaScriptCore`

All system frameworks are copyright © Apple Inc.
