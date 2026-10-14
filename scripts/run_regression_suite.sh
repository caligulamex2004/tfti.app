#!/usr/bin/env bash
# ==============================================================================
# TFTI Regression Prevention Test Suite Runner
# ==============================================================================
# Runs static analysis followed by the comprehensive test suite to safeguard
# TFTI's golden state against regressions across Android and iOS.
# ==============================================================================

set -e

# Detect Flutter path
if command -v flutter >/dev/null 2>&1; then
  FLUTTER_CMD="flutter"
elif [ -x "/Users/asanchez/Code/flutter/bin/flutter" ]; then
  FLUTTER_CMD="/Users/asanchez/Code/flutter/bin/flutter"
else
  echo "❌ Error: Flutter CLI not found in PATH or standard location."
  exit 1
fi

echo "=================================================="
echo "🛡️  Running TFTI Golden State Regression Checks..."
echo "=================================================="

# 1. Static Analysis
echo ""
echo "🔍 Step 1: Running Flutter static analysis..."
$FLUTTER_CMD analyze --no-fatal-infos

# 2. Comprehensive Test Suite
echo ""
echo "🧪 Step 2: Running automated test suite..."
$FLUTTER_CMD test

echo ""
echo "=================================================="
echo "✅ All regression prevention checks passed!"
echo "=================================================="
