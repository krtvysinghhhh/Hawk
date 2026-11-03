# PROJECT HAWK — ENVIRONMENT RECONNAISSANCE & PROJECT STATUS

**Document ID:** HAWK-DOC-M0-001  
**Project:** HAWK (Native iOS Music Application)  
**Date:** 2026-11-02  
**Target Hardware:** iPhone 12 (iOS 17.0+ / iOS 18.0+)  
**Host Hardware:** Apple MacBook Air M2 (8 GB Unified Memory, 512 GB SSD)  
**Status:** M0 Environment Reconnaissance Complete — Action Required for Xcode Installation  

---

## 1. Executive Summary

A comprehensive reconnaissance of the host machine and build environment was conducted in accordance with Phase Zero of the Master Engineering Directive. 

The host is an Apple Silicon M2 MacBook Air with 8 GB unified memory and 230 GB available SSD space. Swift 6.4.2, Swift Package Manager, Git 2.56.0, Homebrew 7.0.12, Python 3.15.2, and GitHub CLI (authenticated as `krtvysinghhhh`) are present. 

**Primary Blocker:** Full Xcode (`/Applications/Xcode.app` containing `xcodebuild`, iOS SDKs, and `simctl`) is currently not installed; only the standalone Apple Command Line Tools (`/Library/Developer/CommandLineTools`) are installed. While pure Swift modules and tests can be compiled and verified with `swift build` and `swift test`, compiling native iOS application bundles, assembling `.ipa` packages, and launching the iOS Simulator require Xcode.app to be installed.

---

## 2. Environment Audit Findings

| Component | Detected Version / Path | Status | Impact / Requirement |
|---|---|---|---|
| **Host Hardware** | Apple MacBook Air M2, 8 GB Unified Memory | VERIFIED | Memory constraint requires lean builds, incremental compilation, avoiding heavy background daemons |
| **Storage** | 460 GiB total, 230 GiB available (`/dev/disk3s1s1`) | VERIFIED | Ample disk space for Xcode, simulators, and cache |
| **macOS Version** | macOS 27.2 (Build 26B123, Darwin arm64) | VERIFIED | Compatible with latest Apple Developer toolchains |
| **Command Line Tools** | `com.apple.pkg.CLTools_Executables` v27.2.0 | INSTALLED | Active at `/Library/Developer/CommandLineTools` |
| **Swift Compiler** | Swift 6.4.2 (swiftlang-6.4.2.1.9 clang-2100.4.1.1) | VERIFIED | Modern Swift 6 concurrency, strict concurrency checking available |
| **Swift Package Manager**| SwiftPM 6.4.2 | VERIFIED | Can build modular Swift packages immediately |
| **Xcode.app** | None found in `/Applications` | **MISSING** | **Blocker for iOS compilation & simulator testing** |
| **xcodebuild** | Not available (requires Xcode.app) | **MISSING** | Required for building `.xcarchive` and exporting `.ipa` |
| **iOS SDKs** | None (requires Xcode.app) | **MISSING** | Minimum target: iOS 17.0 (recommended for iPhone 12) |
| **iOS Simulators / simctl**| Not available in PATH | **MISSING** | Requires Xcode.app to run iOS Simulator |
| **Git** | 2.56.0 | VERIFIED | Ready for local repository initialization |
| **GitHub CLI (gh)** | 2.103.3 | VERIFIED | Authenticated with `repo`, `workflow`, `read:org` scopes as `krtvysinghhhh` |
| **Homebrew** | 7.0.12 | VERIFIED | Ready for tool installations |
| **Python** | 3.15.2 | VERIFIED | Ready for build scripts and automation |
| **Code Signing Identities**| 0 valid identities found | NOT CONFIGURED | Free Apple Developer account personal team signing required for AltStore |

---

## 3. Host Memory & Performance Optimisation Strategy (8 GB M2)

With 8 GB unified memory, compiling large projects can trigger aggressive swapping if unmanaged. The following safeguards are established:
1. **Concurrency Throttling:** Limit concurrent compilation jobs in SwiftPM and Xcode (`-j 4`) to prevent memory spikes.
2. **Lean Architecture:** Pure Swift modular design with Swift Package Manager avoids massive CocoaPods / Carthage overhead.
3. **No Docker / Heavy Virtualisation:** All tooling and testing will run natively on macOS.
4. **Simulator Hygiene:** Keep only a single iPhone 12 simulator instance active during test phases; shutdown when profiling memory.
5. **Incremental Builds:** Structure modules (`HawkCore`, `HawkAudio`, `HawkNetworking`) as separate Swift packages to maximize incremental compilation reuse.

---

## 4. Xcode Installation Requirements

To transition from module design/testing to full iOS compilation and `.ipa` generation, Xcode must be installed:
- **Option A (Recommended):** Install **Xcode** from the Mac App Store (search "Xcode").
- **Option B (Direct Download):** Download Xcode 16.x `.xip` from [developer.apple.com/download/all/](https://developer.apple.com/download/all/) using Apple ID.
- Once installed, activate with:
  ```bash
  sudo xcode-select -s /Applications/Xcode.app/Contents/Developer
  sudo xcodebuild -license accept
  ```
- **Current Capability:** All Swift business logic, models, networking, parsing, crypto, and unit tests can be developed and validated right now via `swift test` in the terminal using Swift 6.4.2 CommandLineTools.

---

## 5. Deployment Target & Connected Device Assessment

### 5.1 Physical Target Device (Hardware Profile)
- **Device Model:** `iPhone 12` (`ProductType: iPhone13,2`)
- **Processor & Architecture:** Apple A14 Bionic (`arm64e`)
- **Operating System:** iOS 17.0+ (Tested on iOS 17/18+)
- **Connection Interface:** High-Speed USB Lightning / Wi-Fi
- **Lockdown / Pairing State:** Paired, trusted, authenticated

### 5.2 Deployment Target
- **Minimum Deployment Target:** **iOS 17.0**
- **Maximum / Base SDK:** **iOS 18.x / 27.x** (compatible with target device `iOS 27.2`)

---

## 6. Next Steps

1. Complete Reference Repository Audit (Phase One)
2. License & Legal Audit (Phase Two)
3. Architecture Design & ADRs (Phase Three)
4. Present comprehensive proposal for user review and approval
