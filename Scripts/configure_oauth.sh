#!/bin/bash
set -euo pipefail

# MARK: - HAWK Google OAuth 2.0 Build Configurator
# Self-contained: automatically resolves paths, manages isolated Python .venv, and updates project configuration.

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
cd "$PROJECT_DIR"

INFO_PLIST="$PROJECT_DIR/Configuration/Info.plist"
PROJECT_YML="$PROJECT_DIR/project.yml"
CONFIG_FILE="$PROJECT_DIR/Configuration/GoogleOAuth.xcconfig"
REQ_FILE="$PROJECT_DIR/requirements-build.txt"

# 1. Ensure Python Virtual Environment (.venv) with PyYAML
ensure_python_venv() {
    local VENV_DIR="$PROJECT_DIR/.venv"
    local VENV_PY="$VENV_DIR/bin/python"

    if [ ! -x "$VENV_PY" ]; then
        echo "Creating isolated Python build environment (.venv)..."
        local BASE_PY=""
        if command -v python3.12 >/dev/null 2>&1; then
            BASE_PY="$(command -v python3.12)"
        elif command -v python3 >/dev/null 2>&1; then
            BASE_PY="$(command -v python3)"
        else
            echo "❌ Error: Neither python3.12 nor python3 found in PATH." >&2
            exit 1
        fi
        "$BASE_PY" -m venv "$VENV_DIR" || {
            echo "❌ Error: Failed to create virtual environment using $BASE_PY." >&2
            exit 1
        }
    fi

    # Verify PyYAML dependency
    if ! "$VENV_PY" -c "import yaml" >/dev/null 2>&1; then
        echo "Installing build dependencies into .venv from requirements-build.txt..."
        "$VENV_PY" -m pip install --quiet -r "$REQ_FILE" || {
            echo "❌ Error: Failed to install requirements from $REQ_FILE." >&2
            exit 1
        }
    fi
    PYTHON_BIN="$VENV_PY"
}

ensure_python_venv

# Extract client ID from arguments, environment variable, or xcconfig
ARG_CLIENT_ID="${1:-}"
XCCONFIG_CLIENT_ID=""
if [ -f "$CONFIG_FILE" ]; then
    XCCONFIG_CLIENT_ID="$(grep -E '^HAWK_GOOGLE_CLIENT_ID[[:space:]]*=' "$CONFIG_FILE" | cut -d'=' -f2 | tr -d '[:space:]')"
fi
CLIENT_ID="${ARG_CLIENT_ID:-${HAWK_GOOGLE_CLIENT_ID:-$XCCONFIG_CLIENT_ID}}"

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

# Reset / Clear Configuration
if [ "$CLIENT_ID" = "--clear" ] || [ "$CLIENT_ID" = "clear" ] || [ "$CLIENT_ID" = "--reset" ]; then
    echo "Clearing Google OAuth configuration..."
    
    cat << 'EOF' > "$CONFIG_FILE"
// HAWK Google OAuth 2.0 Build Configuration
HAWK_GOOGLE_CLIENT_ID =
HAWK_GOOGLE_REVERSED_CLIENT_ID =
EOF

    "$PYTHON_BIN" -c "
import plistlib, yaml

plist_path = '$INFO_PLIST'
with open(plist_path, 'rb') as f:
    pl = plistlib.load(f)

# Preserve any custom schemes except google-oauth
existing_types = pl.get('CFBundleURLTypes', [])
filtered_types = [t for t in existing_types if t.get('CFBundleURLName') != 'com.googleusercontent.apps.google-oauth']
if not filtered_types:
    filtered_types = [{
        'CFBundleTypeRole': 'Editor',
        'CFBundleURLName': 'com.hawk.music',
        'CFBundleURLSchemes': ['com.hawk.music']
    }]
pl['CFBundleURLTypes'] = filtered_types
if 'GoogleClientID' in pl:
    del pl['GoogleClientID']

with open(plist_path, 'wb') as f:
    plistlib.dump(pl, f)

# Update project.yml
with open('$PROJECT_YML', 'r') as f:
    yml = yaml.safe_load(f)

target_props = yml['targets']['HAWK']['info']['properties']
y_existing_types = target_props.get('CFBundleURLTypes', [])
y_filtered = [t for t in y_existing_types if t.get('CFBundleURLName') != 'com.googleusercontent.apps.google-oauth']
if not y_filtered:
    y_filtered = [{
        'CFBundleTypeRole': 'Editor',
        'CFBundleURLName': 'com.hawk.music',
        'CFBundleURLSchemes': ['com.hawk.music']
    }]
target_props['CFBundleURLTypes'] = y_filtered
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

# 2. Update Configuration/Info.plist and project.yml via isolated python .venv
"$PYTHON_BIN" -c "
import plistlib, yaml

plist_path = '$INFO_PLIST'
with open(plist_path, 'rb') as f:
    pl = plistlib.load(f)

# Keep non-Google schemes and update/add Google reversed scheme
existing_types = pl.get('CFBundleURLTypes', [])
filtered_types = [t for t in existing_types if t.get('CFBundleURLName') != 'com.googleusercontent.apps.google-oauth']
filtered_types.append({
    'CFBundleTypeRole': 'Editor',
    'CFBundleURLName': 'com.googleusercontent.apps.google-oauth',
    'CFBundleURLSchemes': ['$REVERSED_SCHEME']
})
pl['CFBundleURLTypes'] = filtered_types
pl['GoogleClientID'] = '$CLIENT_ID'

with open(plist_path, 'wb') as f:
    plistlib.dump(pl, f)

# Update project.yml
with open('$PROJECT_YML', 'r') as f:
    yml = yaml.safe_load(f)

target_props = yml['targets']['HAWK']['info']['properties']
y_existing_types = target_props.get('CFBundleURLTypes', [])
y_filtered = [t for t in y_existing_types if t.get('CFBundleURLName') != 'com.googleusercontent.apps.google-oauth']
y_filtered.append({
    'CFBundleTypeRole': 'Editor',
    'CFBundleURLName': 'com.googleusercontent.apps.google-oauth',
    'CFBundleURLSchemes': ['$REVERSED_SCHEME']
})
target_props['CFBundleURLTypes'] = y_filtered
target_props['GoogleClientID'] = '$CLIENT_ID'

with open('$PROJECT_YML', 'w') as f:
    yaml.dump(yml, f, sort_keys=False)
"

# 3. Regenerate Xcode project
if command -v xcodegen >/dev/null 2>&1; then
    xcodegen generate >/dev/null
    echo "✅ Xcode project regenerated with registered URL scheme."
else
    echo "⚠️ Warning: xcodegen not found in PATH. Project files updated directly."
fi

echo "✅ Configuration successful."
echo "   Info.plist & project.yml updated."
echo "   Reversed scheme '$REVERSED_SCHEME' registered."
echo "   Run ./Scripts/build_ipa.sh to compile the release IPA."
