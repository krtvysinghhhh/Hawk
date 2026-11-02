# HAWK — IPA VERIFICATION REPORT

**Document ID:** HAWK-IPA-001  
**Project:** HAWK (Native iOS Music Application)  
**Target Device:** iPhone 12 (`iPhone13,2`, iOS 27.2)  
**Date:** 2026-11-02  

---

## 1. Build & Sideloading Status Breakdown

In strict accordance with Rule 14 (*"Never claim that a signed IPA is verified until the signing and installation process has actually been validated"*) and Section 24:

| Milestone Gate | Status | Evidence / Notes |
|---|---|---|
| **Core Modules Compiled** | **VERIFIED** | All 8 Swift packages compiled natively for iOS 27.2 with Swift 6 strict concurrency (`./Scripts/verify.sh`). |
| **Release Build Automation**| **VERIFIED** | Build script `./Scripts/build_ipa.sh` executed with zero warnings/errors. |
| **Xcode Application Bundle**| **VERIFIED** | `HAWK.app` bundled with compiled assets (`Assets.car`), universal icons, and `Info.plist`. |
| **IPA Exported on Disk** | **VERIFIED** | `build/HAWK.ipa` (2.1 MB, 8 files, valid `Payload/HAWK.app` structure). |
| **Physical Device Connected** | **VERIFIED (ONLINE)** | `Kartavya’s iPhone` (iPhone 12 / `iPhone13,2`, iOS 27.2, UDID: `00008101-001E542A3EE2001E`) connected and paired via USB. |
| **AltStore Provisioning** | **VERIFIED (INSTALLED)** | AltStore installed, Developer Mode enabled, and Developer Profile trusted on iPhone 12. |
| **Physical Device Sideloading** | **READY FOR USER VALIDATION** | Ready to install `HAWK.ipa` via AltStore. |

---

## 2. IPA Artifact Verification Details

```text
Archive:  build/HAWK.ipa
  Length      Date    Time    Name
---------  ---------- -----   ----
        0  11-02-2026 21:01   Payload/
        0  11-02-2026 21:01   Payload/HAWK.app/
    15506  11-02-2026 21:01   Payload/HAWK.app/AppIcon60x60@2x.png
  1878104  11-02-2026 21:01   Payload/HAWK.app/Assets.car
    23685  11-02-2026 21:01   Payload/HAWK.app/AppIcon76x76@2x~ipad.png
   843136  11-02-2026 21:01   Payload/HAWK.app/HAWK
      923  11-02-2026 21:01   Payload/HAWK.app/Info.plist
        8  11-02-2026 21:01   Payload/HAWK.app/PkgInfo
---------                     -------
  2761362                     8 files
```

---

## 3. Installation Instructions

1. **Option A (AltServer Direct Push):**
   - Hold down the **Option (⌥)** key and click the **AltServer** icon in the macOS menu bar.
   - Choose **"Install .ipa to Device..."** → Select `Kartavya’s iPhone` → Select `/Users/krtvysingh/.gemini/antigravity/scratch/HAWK/build/HAWK.ipa`.

2. **Option B (AirDrop / Files):**
   - AirDrop `build/HAWK.ipa` to your iPhone 12.
   - Tap **AltStore** on the share sheet to install and sign.
