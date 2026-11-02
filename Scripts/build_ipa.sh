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
    echo "⚠️  NOTE: Xcode.app is required for compiling iOS app bundles and archiving .ipa packages."
    echo "   Currently, only standalone Apple Command Line Tools are active."
    echo ""
    echo "   To produce an installable IPA:"
    echo "   1. Install Xcode from the Mac App Store."
    echo "   2. Run: sudo xcode-select -s /Applications/Xcode.app/Contents/Developer"
    echo "   3. Re-run: ./Scripts/build_ipa.sh"
    echo ""
    echo "   AltStore Classic sideloading note:"
    echo "   AltStore automatically re-signs and installs IPAs using your free Apple ID account."
    exit 0
fi

echo "Compiling HAWK iOS Release Build..."
xcodebuild clean archive \
    -scheme HAWK \
    -configuration Release \
    -destination 'generic/platform=iOS' \
    -archivePath "$OUTPUT_DIR/HAWK.xcarchive" \
    CODE_SIGNING_ALLOWED=NO

echo "Exporting IPA for AltStore Classic..."
mkdir -p "$OUTPUT_DIR/Payload"
cp -r "$OUTPUT_DIR/HAWK.xcarchive/Products/Applications/HAWK.app" "$OUTPUT_DIR/Payload/"
cd "$OUTPUT_DIR"
zip -r "HAWK.ipa" Payload
rm -rf Payload

echo ""
echo "✅ HAWK.ipa successfully created at: $OUTPUT_DIR/HAWK.ipa"
