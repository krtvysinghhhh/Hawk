#!/bin/bash
set -euo pipefail

echo "=================================================="
echo "      HAWK AUTOMATED VERIFICATION HARNESS         "
echo "=================================================="

PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$PROJECT_DIR"

echo "Compiling and executing HawkVerify test harness..."
swift run HawkVerify

echo ""
echo "All HAWK core subsystems verified successfully!"
