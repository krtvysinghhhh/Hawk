# PROJECT HAWK — LEGAL & LICENSING AUDIT

**Document ID:** HAWK-DOC-M1-004  
**Project:** HAWK (Native Apple Music Application)  
**Reference Codebase:** BitChord (`https://github.com/kushagrasinghx/BitChord`)  
**Audit Date:** 2026-11-02  

---

## 1. Reference Repository Licensing Profile

The reference repository, BitChord, is licensed under the **GNU General Public License v3.0 (GPLv3)**.

### Key Terms of GPLv3:
- **Copyleft Scope:** If any source code covered by GPLv3 is directly copied, adapted, or statically linked into a derivative work, the resulting work as a whole must be licensed under the GPLv3, and the corresponding source code must be made available to recipients under identical terms.
- **Independence & Clean-Room Architecture for HAWK:**
  - HAWK is **not** a fork, translation, or direct derivation of BitChord's source files.
  - HAWK is designed and implemented independently in Swift, utilizing Apple's proprietary SDKs (`AVFoundation`, `SwiftUI`, `MediaPlayer`, `Security`, etc.).
  - The BitChord repository serves solely as an **architectural reference** to identify functional workflows, API schemas (e.g. YouTubei request headers, JioSaavn DES encryption parameters, Spotify GraphQL query structures, LRCLIB endpoints), and design considerations.
  - Zero Kotlin or C++ source code is copied into HAWK. All Swift code is authored cleanly and independently.

---

## 2. Upstream Third-Party Licensing Audit

| Upstream Component | Stated License | Copyleft Obligations | HAWK Exposure / Handling |
|---|---|---|---|
| **BitChord Source** | GNU GPLv3 | Strong copyleft on derived source | Clean-room independent native Swift implementation. No source copied. Reference used for functional behavior only. |
| **NewPipeExtractor** | GNU GPLv3 | Strong copyleft | Not included in HAWK. HAWK implements its own lightweight YouTubei protocol client. |
| **InnerTubeX** | GNU GPLv3 / LGPLv3 | Strong copyleft | Not included in HAWK. HAWK communicates directly with public YouTubei API endpoints using native `URLSession`. |
| **Mornye (Bit-perfect code)** | LGPL-3.0 | Weak copyleft | Not included. HAWK uses native Apple CoreAudio / AudioUnit interfaces. |
| **Signalsmith Stretch** | MIT | Permissive attribution | Not included in initial release. Time-stretching is handled by `AVAudioUnitTimePitch`. |
| **Oboe / AAudio** | Apache-2.0 | Permissive attribution | Android-specific. Dropped entirely. |
| **libusb** | LGPL-2.1-or-later | Weak copyleft | Android-specific. Dropped entirely. |
| **Haze (Chris Banes)** | Apache-2.0 | Permissive attribution | Android-specific. Replaced with SwiftUI `.ultraThinMaterial`. |
| **LRCLIB (lrclib.net)** | Public Web API (MIT upstream) | Permissive | Used via standard HTTP queries. Attributed in documentation. |

---

## 3. Third-Party API Terms & Fair-Use Analysis

### 3.1 YouTube Music / YouTubei API
- **Mechanism:** Client queries `/youtubei/v1` with standard mobile client context (`WEB_REMIX`, `IOS`) and SAPISIDHASH session cookies.
- **Legal Boundaries & Safeguards:**
  - HAWK does **not** bypass DRM or access protected Widevine streams.
  - HAWK does **not** scrape private content or circumvent subscription barriers.
  - HAWK respects user credentials: sign-in occurs strictly in a user-facing `ASWebAuthenticationSession` or `WKWebView`, storing authentication cookies in Apple's encrypted Keychain.
  - Clear user disclaimers are provided: HAWK is an independent client and is not affiliated with Google LLC or YouTube Music.

### 3.2 Spotify Integration
- **Mechanism:** Spotify Web API & public embed endpoints for playlist metadata and Liked Songs importing.
- **Legal Boundaries & Safeguards:**
  - HAWK does **not** extract, download, or stream DRM-protected audio from Spotify servers.
  - Track matching is performed to find counterpart recordings on authorized open/user-configured sources.
  - User OAuth tokens are securely stored in the iOS Keychain.

### 3.3 JioSaavn Integration
- **Mechanism:** Direct metadata queries and standard DES URL resolution.
- **Legal Boundaries & Safeguards:**
  - Relies on standard public CDN endpoints. No user credentials required.

### 3.4 Open Lyrics Providers (LRCLIB)
- **Mechanism:** Queries `https://lrclib.net/api/get` for synchronized song lyrics.
- **Compliance:** LRCLIB is a community-driven, lawful, free open-access lyrics database specifically built for open-source music players.

---

## 4. HAWK Licensing Recommendation

To ensure complete legal compliance and open-source hygiene while guaranteeing clean distribution for sideloading and personal development:
- **HAWK Project License:** **GNU General Public License v3.0 (GPLv3)** (or MIT, depending on user preference, with GPLv3 chosen for parity and community freedom).
- **Mandatory Attributions:** Full credit and attributions to BitChord author Kushagra Singh, LRCLIB, and upstream open-source communities are maintained in `ATTRIBUTIONS.md` and user-facing Settings > About.
