#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
cd "$PROJECT_DIR"

INFO_PLIST="$PROJECT_DIR/Configuration/Info.plist"
PROJECT_YML="$PROJECT_DIR/project.yml"
CONFIG_FILE="$PROJECT_DIR/Configuration/GoogleOAuth.xcconfig"

CLIENT_ID="${1:-${HAWK_GOOGLE_CLIENT_ID:-}}"

if [ -z "$CLIENT_ID" ]; then
    echo "=================================================="
    echo "       HAWK — GOOGLE OAUTH BUILD CONFIGURATOR     "
    echo "=================================================="
    echo "Usage: ./Scripts/configure_oauth.sh <client-id> | --clear"
    echo ""
    echo "Example: ./Scripts/configure_oauth.sh 123456789012-abc123xyz.apps.googleusercontent.com"
    echo "To reset: ./Scripts/configure_oauth.sh --clear"
    exit 1
fi

if [ "$CLIENT_ID" = "--clear" ] || [ "$CLIENT_ID" = "clear" ] || [ "$CLIENT_ID" = "--reset" ]; then
    echo "Clearing Google OAuth configuration..."
    
    # Reset GoogleOAuth.xcconfig
    cat << 'EOF' > "$CONFIG_FILE"
// HAWK Google OAuth 2.0 Build Configuration
HAWK_GOOGLE_CLIENT_ID =
HAWK_GOOGLE_REVERSED_CLIENT_ID =
EOF

    # Reset Info.plist and project.yml via python script
    python3 -c "
import plistlib, yaml

plist_path = '$INFO_PLIST'
with open(plist_path, 'rb') as f:
    pl = plistlib.load(f)

pl['CFBundleURLTypes'] = [
    {
        'CFBundleTypeRole': 'Editor',
        'CFBundleURLName': 'com.hawk.music',
        'CFBundleURLSchemes': ['com.hawk.music']
    }
]
if 'GoogleClientID' in pl:
    del pl['GoogleClientID']

with open(plist_path, 'wb') as f:
    plistlib.dump(pl, f)

# Update project.yml
with open('$PROJECT_YML', 'r') as f:
    yml = yaml.safe_load(f)

target_props = yml['targets']['HAWK']['info']['properties']
target_props['CFBundleURLTypes'] = [
    {
        'CFBundleTypeRole': 'Editor',
        'CFBundleURLName': 'com.hawk.music',
        'CFBundleURLSchemes': ['com.hawk.music']
    }
]
if 'GoogleClientID' in target_props:
    del target_props['GoogleClientID']

with open('$PROJECT_YML', 'w') as f:
    yaml.dump(yml, f, sort_keys=False)
"
    xcodegen generate >/dev/null
    echo "✅ Google OAuth build configuration cleared."
    exit 0
fi

# Validate Client ID format
if [[ ! "$CLIENT_ID" =~ ^[0-9]+-[a-zA-Z0-9_-]+\.apps\.googleusercontent\.com$ ]]; then
    echo "❌ Error: Invalid Google Cloud iOS Client ID format."
    echo "   Received: '$CLIENT_ID'"
    echo "   Expected format: <project-number>-<client-hash>.apps.googleusercontent.com"
    exit 1
fi

# Reject known dummy / placeholder strings
LOWER_ID="$(echo "$CLIENT_ID" | tr '[:upper:]' '[:lower:]')"
if [[ "$LOWER_ID" =~ hawk-music-player|placeholder|dummy|example|your_client_id ]]; then
    echo "❌ Error: Dummy or placeholder client ID detected. Please provide a genuine client ID."
    exit 1
fi

PREFIX="${CLIENT_ID%.apps.googleusercontent.com}"
REVERSED_SCHEME="com.googleusercontent.apps.${PREFIX}"
REDIRECT_URI="${REVERSED_SCHEME}:/oauth2callback"

echo "=================================================="
echo "       CONFIGURING HAWK PRODUCTION OAUTH          "
echo "=================================================="
echo "Client ID:       $CLIENT_ID"
echo "Reversed Scheme: $REVERSED_SCHEME"
echo "Redirect URI:    $REDIRECT_URI"
echo "Bundle ID:       com.hawk.music"
echo "=================================================="

# 1. Update Configuration/GoogleOAuth.xcconfig
cat << EOF > "$CONFIG_FILE"
// HAWK Google OAuth 2.0 Build Configuration
HAWK_GOOGLE_CLIENT_ID = $CLIENT_ID
HAWK_GOOGLE_REVERSED_CLIENT_ID = $REVERSED_SCHEME
EOF

# 2. Update Configuration/Info.plist and project.yml via python
python3 -c "
import plistlib, yaml

plist_path = '$INFO_PLIST'
with open(plist_path, 'rb') as f:
    pl = plistlib.load(f)

pl['CFBundleURLTypes'] = [
    {
        'CFBundleTypeRole': 'Editor',
        'CFBundleURLName': 'com.hawk.music',
        'CFBundleURLSchemes': ['com.hawk.music']
    },
    {
        'CFBundleTypeRole': 'Editor',
        'CFBundleURLName': 'com.googleusercontent.apps.google-oauth',
        'CFBundleURLSchemes': ['$REVERSED_SCHEME']
    }
]
pl['GoogleClientID'] = '$CLIENT_ID'

with open(plist_path, 'wb') as f:
    plistlib.dump(pl, f)

# Update project.yml
with open('$PROJECT_YML', 'r') as f:
    yml = yaml.safe_load(f)

target_props = yml['targets']['HAWK']['info']['properties']
target_props['CFBundleURLTypes'] = [
    {
        'CFBundleTypeRole': 'Editor',
        'CFBundleURLName': 'com.hawk.music',
        'CFBundleURLSchemes': ['com.hawk.music']
    },
    {
        'CFBundleTypeRole': 'Editor',
        'CFBundleURLName': 'com.googleusercontent.apps.google-oauth',
        'CFBundleURLSchemes': ['$REVERSED_SCHEME']
    }
]
target_props['GoogleClientID'] = '$CLIENT_ID'

with open('$PROJECT_YML', 'w') as f:
    yaml.dump(yml, f, sort_keys=False)
"

# 3. Regenerate Xcode project
xcodegen generate >/dev/null

echo "✅ Configuration successful."
echo "   Info.plist & project.yml updated."
echo "   Xcode project regenerated with registered URL scheme."
echo "   Run ./Scripts/build_ipa.sh to compile the release IPA."
