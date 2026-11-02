# HAWK — SIDELOADING & RELEASE GUIDE

**Document ID:** HAWK-REL-001  
**Project:** HAWK (Native iOS Music Application)  
**Distribution Channel:** Personal Sideloading (AltStore Classic / SideStore / TrollStore)  

---

## 1. AltStore Classic Installation Workflow

AltStore Classic is the primary distribution vehicle for HAWK on a free Apple Developer account.

### Step 1: Install AltServer on your Mac
1. Download **AltServer** from [altstore.io](https://altstore.io) on your Mac.
2. Launch AltServer and install the Mail plug-in if prompted.
3. Connect your iPhone 12 to the Mac using a Lightning-to-USB cable and "Trust" the computer.
4. From the Mac menu bar icon, click **Install AltStore** and select your iPhone 12. Enter your Apple ID credentials (used only to generate personal provisioning profiles).

### Step 2: Enable Developer Mode on iPhone 12
1. On iPhone 12 running iOS 16/17/18: Go to **Settings > Privacy & Security > Developer Mode**.
2. Turn **Developer Mode ON** and restart the device when prompted.

### Step 3: Install HAWK.ipa via AltStore
1. Export the IPA on your Mac using `./Scripts/build_ipa.sh`.
2. Transfer `build/HAWK.ipa` to your iPhone 12 (via AirDrop, iCloud Drive, or the Files app).
3. Open **AltStore** on your iPhone 12, go to the **My Apps** tab, tap the **`+`** icon in the top left, and select `HAWK.ipa`.
4. AltStore will sign HAWK with your personal certificate and install it directly onto your home screen.

---

## 2. Free Apple Developer Account Constraints

- **7-Day Provisioning Expiration:** Apps installed with a free Apple ID remain valid for 7 days. AltStore automatically refreshes the certificate wirelessly over Wi-Fi when on the same network as AltServer.
- **3-App Sideloading Ceiling:** iOS allows a maximum of 3 active sideloaded apps simultaneously under a free Apple account.
- **No App Store / Public TestFlight:** Direct submission to the App Store or public TestFlight requires a paid Apple Developer Program membership ($99/year).
