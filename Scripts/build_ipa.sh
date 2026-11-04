#!/bin/bash
set -euo pipefail

PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$PROJECT_DIR"

echo "=================================================="
echo "          PROJECT HAWK — IPA BUILD & EXPORT       "
echo "=================================================="

OUTPUT_DIR="$PROJECT_DIR/build"
mkdir -p "$OUTPUT_DIR"

if ! command -v xcodebuild >/dev/null 2>&1 || [ ! -d "/Applications/Xcode.app" ]; then
    echo "❌ Error: Xcode.app is required for compiling iOS app bundles and archiving .ipa packages."
    echo "   Currently, only standalone Apple Command Line Tools are active."
    echo ""
    echo "   To produce an installable IPA:"
    echo "   1. Install Xcode from the Mac App Store."
    echo "   2. Run: sudo xcode-select -s /Applications/Xcode.app/Contents/Developer"
    echo "   3. Re-run: ./Scripts/build_ipa.sh"
    exit 1
fi

# Synchronize OAuth configuration if present in environment or xcconfig
CONFIG_FILE="$PROJECT_DIR/Configuration/GoogleOAuth.xcconfig"
if [ -f "$CONFIG_FILE" ]; then
    XCCONFIG_CLIENT_ID="$(grep -E '^HAWK_GOOGLE_CLIENT_ID[[:space:]]*=' "$CONFIG_FILE" | cut -d'=' -f2 | tr -d '[:space:]')"
    ACTIVE_CLIENT_ID="${HAWK_GOOGLE_CLIENT_ID:-$XCCONFIG_CLIENT_ID}"
    if [ -n "$ACTIVE_CLIENT_ID" ]; then
        echo "Synchronizing build with Google OAuth Client ID: $ACTIVE_CLIENT_ID"
        "$PROJECT_DIR/Scripts/configure_oauth.sh" "$ACTIVE_CLIENT_ID"
    fi
fi

echo "Compiling HAWK iOS Release Build..."
xcodebuild clean archive \
    -project HAWK.xcodeproj \
    -scheme HAWK \
    -configuration Release \
    -destination 'generic/platform=iOS' \
    -archivePath "$OUTPUT_DIR/HAWK.xcarchive" \
    CODE_SIGNING_ALLOWED=NO \
    CODE_SIGNING_REQUIRED=NO \
    CODE_SIGN_IDENTITY=""

echo "Exporting IPA for AltStore Classic & Sideloadly..."
rm -rf "$OUTPUT_DIR/Payload"
mkdir -p "$OUTPUT_DIR/Payload"
cp -r "$OUTPUT_DIR/HAWK.xcarchive/Products/Applications/HAWK.app" "$OUTPUT_DIR/Payload/"
cd "$OUTPUT_DIR"
zip -r "HAWK.ipa" Payload >/dev/null
rm -rf Payload

if [ ! -f "$OUTPUT_DIR/HAWK.ipa" ]; then
    echo "❌ Build Failed: $OUTPUT_DIR/HAWK.ipa was not created."
    exit 1
fi

echo ""
echo "✅ HAWK.ipa successfully created at: $OUTPUT_DIR/HAWK.ipa"

# Verify compiled Info.plist in the generated IPA
echo ""
echo "--- Built IPA Verification ---"
python3 -c "
import zipfile, plistlib

ipa_path = '$OUTPUT_DIR/HAWK.ipa'
with zipfile.ZipFile(ipa_path, 'r') as z:
    for name in z.namelist():
        if name.endswith('Info.plist'):
            data = z.read(name)
            pl = plistlib.loads(data)
            print('Built CFBundleIdentifier:', pl.get('CFBundleIdentifier'))
            print('Built CFBundleShortVersionString:', pl.get('CFBundleShortVersionString'))
            print('Built CFBundleVersion:', pl.get('CFBundleVersion'))
            print('Built CFBundleURLTypes:', pl.get('CFBundleURLTypes'))
            print('Built GoogleClientID:', pl.get('GoogleClientID'))
"

# Copy to Desktop and Downloads for sideloading
cp "$OUTPUT_DIR/HAWK.ipa" ~/Desktop/HAWK.ipa
cp "$OUTPUT_DIR/HAWK.ipa" ~/Downloads/HAWK.ipa
echo "Copied release IPA to ~/Desktop/HAWK.ipa and ~/Downloads/HAWK.ipa."
