# PROJECT HAWK — MIGRATION PLAN & EXECUTION ROADMAP

**Document ID:** HAWK-PLAN-001  
**Project:** HAWK (Native iOS Music Application)  
**Target:** Independent Native iOS Application  

---

## 1. Migration Philosophy: Clean-Room Native Re-Engineering

HAWK does not perform mechanical Kotlin-to-Swift code translation. Instead, HAWK adopts a clean-room architectural re-engineering methodology:

1. **Understand Reference Domain Models:** Inspect and adopt the conceptual domain models (three-tier queue, waterfall lyrics resolution, monthly aggregate listening stats, confidence-scored track matching).
2. **Re-architect for Apple Ecosystem:** Design native Swift actors, structs, and protocols utilizing `AVFoundation`, `SwiftUI`, and `URLSession`.
3. **Independent UI/UX:** Construct an original HAWK design system built on Apple HIG principles, avoiding Androidisms or cloned UI layouts.
4. **Stepwise Milestone Verification:** Each milestone produces tangible, testable code with automated test evidence before advancing to the next.

---

## 2. Milestone Breakdown & Schedule

```mermaid
flowchart LR
    M0[M0: Reconnaissance] --> M1[M1: Audit]
    M1 --> M2[M2: Architecture & Stop]
    M2 --> M3[M3: Foundation & SPM]
    M3 --> M4[M4: Design System & Nav]
    M4 --> M5[M5: Sources & Storage]
    M5 --> M6[M6: Audio Engine]
    M6 --> M7[M7: Music Resolvers]
    M7 --> M8[M8: Lyrics & Offline]
    M8 --> M9[M9: Stats & AirPlay]
    M9 --> M10[M10: Testing]
    M10 --> M11[M11: Automation & CI]
    M11 --> M12[M12: IPA Verification]
```

### Milestone Schedule:

- **Milestone 0 (M0) — Environment Reconnaissance:**  
  *Deliverable:* `HAWK/PROJECT_STATUS.md`.  
  *Status:* COMPLETED.

- **Milestone 1 (M1) — Reference Repository Audit:**  
  *Deliverables:* `HAWK/REFERENCE_AUDIT.md`, `HAWK/FEATURE_INVENTORY.md`, `HAWK/DEPENDENCY_AUDIT.md`, `HAWK/LICENSE_AUDIT.md`, `HAWK/SECURITY_AUDIT.md`.  
  *Status:* COMPLETED.

- **Milestone 2 (M2) — Architecture Design & Proposal:**  
  *Deliverables:* `HAWK/ARCHITECTURE.md`, `HAWK/MIGRATION_PLAN.md`, `HAWK/ARCHITECTURE_DECISIONS.md`, `HAWK/IOS_FEATURE_MAPPING.md`.  
  *Status:* **CURRENT STAGE — PRESENTED FOR USER APPROVAL.**

*(The following milestones begin upon explicit user approval of M2)*

- **Milestone 3 (M3) — Project Foundation & Swift Packages:**  
  Set up Git repository, `.gitignore`, Xcode project structure, Swift Package Manager modular targets (`HawkCore`, `HawkSecurity`, `HawkNetworking`), build settings, and verify initial compilation with `swift build` and `swift test`.

- **Milestone 4 (M4) — Original HAWK Design System & SwiftUI Navigation:**  
  Implement the HAWK color system, typography, glass material modifiers, bottom tab navigation (`Home`, `Explore`, `Search`, `Library`), collapsible Now Playing mini-player dock, and modal player sheet.

- **Milestone 5 (M5) — Core Music Sources & Persistence:**  
  Implement `KeychainStore`, atomic JSON `PlaylistStore`, `QueueManager` actor with 3 queue tiers (`USER_QUEUE`, `CONTEXT`, `AUTOPLAY`), and `LocalLibrarySource` for device file imports.

- **Milestone 6 (M6) — Native Audio Engine & Lock Screen Integration:**  
  Implement `HawkAudioEngine` actor with dual `AVPlayer` crossfade logic, `AVAudioSession` background configuration, interruption handling, route change notifications, and `MPNowPlayingInfoCenter` / `MPRemoteCommandCenter`.

- **Milestone 7 (M7) — Music Providers (YouTube Music & JioSaavn):**  
  Implement `YouTubeSource` (`InnertubeClient` in native Swift) for search, browse, recommendations, and stream resolution; implement `JioSaavnSource` for 320 kbps AAC stream decryption.

- **Milestone 8 (M8) — Lyrics Engine & Offline Downloads:**  
  Implement `LyricsEngine` with `LRCLIB` API integration, TTML syllable parsing, kinetic word-highlighting animations, and background offline download task manager.

- **Milestone 9 (M9) — Replay Statistics & AirPlay:**  
  Implement wall-clock `ListeningStatsRecorder`, monthly local JSON storage, Replay cards rendering to images, and native Apple AirPlay route selection.

- **Milestone 10 (M10) — QA, Testing & Performance Stabilization:**  
  Execute automated unit test suites for all modules; simulate offline state, network dropouts, audio interruptions, and high-load queues.

- **Milestone 11 (M11) — Build Automation & CI/CD:**  
  Author `Scripts/build.sh`, `Scripts/build_ipa.sh`, and `.github/workflows/ci.yml`.

- **Milestone 12 (M12) — Release Signing & IPA Delivery:**  
  Export valid signed/installable IPA for AltStore Classic and physical iPhone 12 deployment. Deliver `IPA_VERIFICATION_REPORT.md`.
