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
SCHEME="MoveAI"
REPORT_DIR="$WORKTREE/orchestrator/review"

DESTINATION="${MOVEAI_XCODE_DESTINATION:-}"
SIMULATOR_UDID=""
SIMULATOR_NAME=""
SIMULATOR_STATE=""

pick_simulator_destination() {
    if [ -n "$DESTINATION" ]; then
        return 0
    fi

    if ! command -v xcrun >/dev/null 2>&1; then
        echo "ERROR: xcrun not found. Set MOVEAI_XCODE_DESTINATION to override." >&2
        exit 2
    fi

    if ! command -v jq >/dev/null 2>&1; then
        echo "ERROR: jq not found. Install jq or set MOVEAI_XCODE_DESTINATION to override." >&2
        exit 2
    fi

    local sim_info
    sim_info="$(xcrun simctl list devices available -j 2>/dev/null | jq -r '
        def devices: [ .devices[]?[]? | select(.isAvailable == true) | {name, udid, state} ];
        def iphones: devices | map(select(.name | startswith("iPhone")));
        def pick:
            (iphones | map(select(.state == "Booted"))[0])
            // (iphones | map(select(.name == "iPhone 16 Pro"))[0])
            // (iphones[0])
            // empty;
        pick | "\(.udid)\t\(.name)\t\(.state)"
    ')" || sim_info=""

    if [ -z "$sim_info" ]; then
        echo "ERROR: No available iPhone simulators found." >&2
        echo "Tip: Install an iOS Simulator runtime in Xcode, or set MOVEAI_XCODE_DESTINATION." >&2
        xcrun simctl list devices available || true
        exit 2
    fi

    IFS=$'\t' read -r SIMULATOR_UDID SIMULATOR_NAME SIMULATOR_STATE <<<"$sim_info"
    if [ -z "$SIMULATOR_UDID" ]; then
        echo "ERROR: Failed to select an iOS Simulator device." >&2
        xcrun simctl list devices available || true
        exit 2
    fi

    DESTINATION="platform=iOS Simulator,id=$SIMULATOR_UDID"
}

# Ensure report directory exists
mkdir -p "$REPORT_DIR" 2>/dev/null || true

TIMESTAMP=$(date "+%Y%m%d_%H%M%S")
RUN_DIR="$REPORT_DIR/verify_$TIMESTAMP"
mkdir -p "$RUN_DIR" 2>/dev/null || true

BUILD_LOG="$RUN_DIR/build.log"
UNIT_LOG="$RUN_DIR/unit.log"
UI_LOG="$RUN_DIR/ui.log"

print_log_tail() {
    local log_path="$1"
    local lines="${2:-200}"

    if [ ! -f "$log_path" ]; then
        return 0
    fi

    echo "    --- tail -$lines ($log_path) ---"
    tail -"$lines" "$log_path" || true
    echo "    --- end ---"
}

pick_simulator_destination

echo "========================================"
echo "  Orchestrator Verify"
echo "  Worktree: $WORKTREE"
if [ -n "${MOVEAI_XCODE_DESTINATION:-}" ]; then
    echo "  Destination: $DESTINATION (override)"
else
    echo "  Destination: $DESTINATION"
    if [ -n "$SIMULATOR_NAME" ]; then
        echo "  Simulator: $SIMULATOR_NAME (${SIMULATOR_STATE:-unknown})"
    fi
fi
echo "  Run Dir: $RUN_DIR"
echo "========================================"
echo ""

BUILD_OK=false
UNIT_OK=false
UI_OK=false

# --- Build ---
echo ">>> Step 1/3: Building..."
if xcodebuild build \
    -project "$WORKTREE/MoveAI.xcodeproj" \
    -scheme "$SCHEME" \
    -destination "$DESTINATION" \
    -resultBundlePath "$RUN_DIR/build.xcresult" \
    -quiet \
    >"$BUILD_LOG" 2>&1; then
    BUILD_OK=true
    echo "    BUILD: PASS"
else
    echo "    BUILD: FAIL"
    echo "    Log: $BUILD_LOG"
    print_log_tail "$BUILD_LOG"
fi
echo ""

# --- Unit Tests ---
if [ "$BUILD_OK" = true ]; then
    echo ">>> Step 2/3: Running unit tests..."
    if xcodebuild test \
        -project "$WORKTREE/MoveAI.xcodeproj" \
        -scheme "$SCHEME" \
        -destination "$DESTINATION" \
        -only-testing:MoveAITests \
        -resultBundlePath "$RUN_DIR/unit.xcresult" \
        -quiet \
        >"$UNIT_LOG" 2>&1; then
        UNIT_OK=true
        echo "    UNIT TESTS: PASS"
    else
        echo "    UNIT TESTS: FAIL"
        echo "    Log: $UNIT_LOG"
        print_log_tail "$UNIT_LOG"
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
        -destination "$DESTINATION" \
        -only-testing:MoveAIUITests \
        -resultBundlePath "$RUN_DIR/ui.xcresult" \
        -quiet \
        >"$UI_LOG" 2>&1; then
        UI_OK=true
        echo "    UI TESTS: PASS"
    else
        echo "    UI TESTS: FAIL"
        echo "    Log: $UI_LOG"
        print_log_tail "$UI_LOG"
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
