#!/bin/bash
set -euo pipefail

PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$PROJECT_DIR"

echo "=================================================="
echo "          BUILDING PROJECT HAWK MODULES           "
echo "=================================================="

echo "Building Swift Package Manager core targets..."
swift build -c release --product HawkCore
swift build -c release --product HawkSecurity
swift build -c release --product HawkNetworking
swift build -c release --product HawkSources
swift build -c release --product HawkPlayback
swift build -c release --product HawkLyrics
swift build -c release --product HawkStats
swift build -c release --product HawkVerify

echo ""
echo "Core modules compiled successfully!"
