#!/bin/bash
# orchestrator/scripts/verify.sh
#
# Runs build + unit tests + UI tests in a worktree and outputs a compact report.
# Usage: bash orchestrator/scripts/verify.sh [worktree-path]
#
# Examples:
#   bash orchestrator/scripts/verify.sh ~/Developer/moveai-ml
#   bash orchestrator/scripts/verify.sh ~/Developer/moveai-review
#   bash orchestrator/scripts/verify.sh .  # current directory

set -euo pipefail

WORKTREE="${1:-.}"
WORKTREE=$(cd "$WORKTREE" && pwd)
SIMULATOR="platform=iOS Simulator,id=B512B7D6-8471-4F50-98D4-EF0932937865"
SCHEME="MoveAI"
REPORT_DIR="$WORKTREE/orchestrator/review"

echo "========================================"
echo "  Orchestrator Verify"
echo "  Worktree: $WORKTREE"
echo "  Simulator: iPhone 16 Pro (iOS 18.5)"
echo "========================================"
echo ""

# Ensure report directory exists
mkdir -p "$REPORT_DIR" 2>/dev/null || true

BUILD_OK=false
UNIT_OK=false
UI_OK=false

# --- Build ---
echo ">>> Step 1/3: Building..."
if xcodebuild build \
    -project "$WORKTREE/MoveAI.xcodeproj" \
    -scheme "$SCHEME" \
    -destination "$SIMULATOR" \
    -quiet \
    2>&1; then
    BUILD_OK=true
    echo "    BUILD: PASS"
else
    echo "    BUILD: FAIL"
fi
echo ""

# --- Unit Tests ---
if [ "$BUILD_OK" = true ]; then
    echo ">>> Step 2/3: Running unit tests..."
    if xcodebuild test \
        -project "$WORKTREE/MoveAI.xcodeproj" \
        -scheme "$SCHEME" \
        -destination "$SIMULATOR" \
        -only-testing:MoveAITests \
        -quiet \
        2>&1 | tail -5; then
        UNIT_OK=true
        echo "    UNIT TESTS: PASS"
    else
        echo "    UNIT TESTS: FAIL"
    fi
else
    echo ">>> Step 2/3: Skipping unit tests (build failed)"
fi
echo ""

# --- UI Tests ---
if [ "$BUILD_OK" = true ]; then
    echo ">>> Step 3/3: Running UI tests..."
    if xcodebuild test \
        -project "$WORKTREE/MoveAI.xcodeproj" \
        -scheme "$SCHEME" \
        -destination "$SIMULATOR" \
        -only-testing:MoveAIUITests \
        -quiet \
        2>&1 | tail -5; then
        UI_OK=true
        echo "    UI TESTS: PASS"
    else
        echo "    UI TESTS: FAIL"
    fi
else
    echo ">>> Step 3/3: Skipping UI tests (build failed)"
fi

# --- Summary ---
echo ""
echo "========================================"
echo "  SUMMARY"
echo "========================================"
echo "  Build:      $([ "$BUILD_OK" = true ] && echo 'PASS' || echo 'FAIL')"
echo "  Unit Tests: $([ "$UNIT_OK" = true ] && echo 'PASS' || echo 'FAIL')"
echo "  UI Tests:   $([ "$UI_OK" = true ] && echo 'PASS' || echo 'FAIL')"
echo "========================================"

if [ "$BUILD_OK" = true ] && [ "$UNIT_OK" = true ] && [ "$UI_OK" = true ]; then
    echo "  RESULT: ALL CLEAR"
    exit 0
else
    echo "  RESULT: ISSUES FOUND"
    exit 1
fi
