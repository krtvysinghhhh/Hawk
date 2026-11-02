# HAWK — BUILD & COMPILATION GUIDE

**Document ID:** HAWK-BLD-001  
**Project:** HAWK (Native iOS Music Application)  

---

## 1. Prerequisites

- macOS 14.0+ running on Apple Silicon or Intel
- Swift 6.0+ (Included in Xcode 16 or Command Line Tools)
- Xcode 16+ (Mandatory for assembling the `.ipa` and simulator testing)

---

## 2. Command Line Build Commands

### Compiling Core Packages
From the `HAWK/` root directory:

```bash
# Build all release libraries
./Scripts/build.sh
```

### Running Automated Verifications
```bash
# Run the 20-test automated verification suite
./Scripts/verify.sh
```

### Exporting Sideloadable IPA
```bash
# Builds and packages HAWK.ipa for AltStore Classic
./Scripts/build_ipa.sh
```

---

## 3. Opening in Xcode

1. Open `HAWK` in Xcode by double-clicking `Package.swift` or opening the folder in Xcode.
2. Select target `HAWK` and choose your connected iPhone 12 or an iOS Simulator.
3. In Signing & Capabilities, select your **Personal Team** (Free Apple ID account).
4. Press `⌘B` to build or `⌘R` to run.
