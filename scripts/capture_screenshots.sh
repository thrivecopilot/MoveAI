#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SCHEME="MoveAI"
PROJECT="$ROOT_DIR/MoveAI.xcodeproj"

# ---------------------------------------------------------------------------
# Usage: capture_screenshots.sh [--only <filter>] [--keep-previous]
#
#   --only session-history   Run only testSessionHistoryScreenshots (12 PNGs)
#   --only video-review      Run only testVideoReviewScreenshots   ( 9 PNGs)
#   (omitted)                Run all ScreenshotTests               (21 PNGs)
#
#   --keep-previous          Don't delete previous screenshot folders
# ---------------------------------------------------------------------------

ONLY_FILTER=""
KEEP_PREVIOUS=false

while [[ $# -gt 0 ]]; do
  case "$1" in
    --only)
      ONLY_FILTER="$2"
      shift 2
      ;;
    --keep-previous)
      KEEP_PREVIOUS=true
      shift
      ;;
    *)
      echo "Unknown option: $1" >&2
      echo "Usage: capture_screenshots.sh [--only session-history|video-review] [--keep-previous]" >&2
      exit 1
      ;;
  esac
done

# Map --only value to xcodebuild -only-testing target
TEST_TARGET="MoveAIUITests/ScreenshotTests"
case "$ONLY_FILTER" in
  "")                TEST_TARGET="MoveAIUITests/ScreenshotTests" ;;
  session-history)   TEST_TARGET="MoveAIUITests/ScreenshotTests/testSessionHistoryScreenshots" ;;
  video-review)      TEST_TARGET="MoveAIUITests/ScreenshotTests/testVideoReviewScreenshots" ;;
  *)
    echo "Unknown --only filter: $ONLY_FILTER" >&2
    echo "Valid values: session-history, video-review" >&2
    exit 1
    ;;
esac

log() {
  echo "[capture] $*"
}

warn() {
  echo "[capture][warn] $*" >&2
}

err() {
  echo "[capture][error] $*" >&2
}

if ! command -v xcodebuild >/dev/null 2>&1; then
  err "xcodebuild not found. Install Xcode and its command line tools."
  exit 1
fi

if ! command -v xcrun >/dev/null 2>&1; then
  err "xcrun not found. Install Xcode and its command line tools."
  exit 1
fi

restart_core_simulator() {
  warn "Restarting CoreSimulator services..."
  xcrun simctl shutdown all >/dev/null 2>&1 || true
  killall -9 com.apple.CoreSimulator.CoreSimulatorService >/dev/null 2>&1 || true

  local dev_dir
  dev_dir="$(xcode-select -p 2>/dev/null || true)"
  local sim_app=""
  if [[ -n "$dev_dir" ]]; then
    sim_app="$dev_dir/Applications/Simulator.app"
  fi

  if [[ -n "$sim_app" && -d "$sim_app" ]]; then
    open -a "$sim_app" >/dev/null 2>&1 || true
  else
    warn "Simulator.app not found via xcode-select; skipping launch."
  fi
  sleep 2
}

ensure_simctl_ready() {
  local attempts=3
  for attempt in $(seq 1 "$attempts"); do
    if xcrun simctl list devices available >/dev/null 2>&1; then
      return 0
    fi
    warn "simctl is unavailable (attempt $attempt/$attempts)."
    restart_core_simulator
    sleep $((attempt * 2))
  done

  err "simctl still unavailable after retries."
  err "xcode-select -p => $(xcode-select -p 2>/dev/null || echo 'N/A')"
  err "CoreSimulator may be down or Simulator/Xcode is missing."
  return 1
}

TIMESTAMP="$(date +"%Y-%m-%d_%H-%M-%S")"
OUTPUT_DIR="$ROOT_DIR/Screenshots/latest/$TIMESTAMP"
# Use repo-local temp dir (no spaces) so extraction and output share the same filesystem
SCREENSHOT_TMP_DIR="${ROOT_DIR}/.screenshot_tmp"
mkdir -p "$SCREENSHOT_TMP_DIR"
RESULT_BUNDLE_TMP="${SCREENSHOT_TMP_DIR}/MoveAI_Screenshots_${TIMESTAMP}.xcresult"

# Clean up previous screenshot folders BEFORE creating the new output dir
LATEST_DIR="$ROOT_DIR/Screenshots/latest"
if [[ "$KEEP_PREVIOUS" == false && -d "$LATEST_DIR" ]]; then
  PREV_COUNT=$(find "$LATEST_DIR" -mindepth 1 -maxdepth 1 -type d 2>/dev/null | wc -l | tr -d ' ')
  if [[ "$PREV_COUNT" -gt 0 ]]; then
    log "Cleaning up $PREV_COUNT previous screenshot folder(s)"
    find "$LATEST_DIR" -mindepth 1 -maxdepth 1 -type d -exec rm -rf {} +
  fi
fi

mkdir -p "$OUTPUT_DIR"

ensure_simctl_ready

DEVICE_NAME="iPhone 16 Pro"
DESTINATION=""

DEVICE_ID="$(xcrun simctl list devices available | sed -n "s/.*${DEVICE_NAME} (\\([A-F0-9-]*\\)).*/\\1/p" | head -n 1)"
if [[ -n "$DEVICE_ID" ]]; then
  DESTINATION="platform=iOS Simulator,id=$DEVICE_ID"
else
  BOOTED_ID=$(xcrun simctl list devices booted | sed -n 's/.*(\([A-F0-9-]*\)) (Booted).*/\1/p' | head -n 1)
  if [[ -n "$BOOTED_ID" ]]; then
    DESTINATION="platform=iOS Simulator,id=$BOOTED_ID"
  else
    ANY_ID=$(xcrun simctl list devices available | sed -n 's/.*iPhone.*(\([A-F0-9-]*\)).*/\1/p' | head -n 1)
    if [[ -n "$ANY_ID" ]]; then
      DESTINATION="platform=iOS Simulator,id=$ANY_ID"
    else
      echo "Error: No available iPhone simulator found." >&2
      exit 1
    fi
  fi
fi

log "Running screenshot tests on: $DESTINATION"
log "Test target: $TEST_TARGET"
log "Results will be saved to: $OUTPUT_DIR"
log "xcresult bundle (temp): $RESULT_BUNDLE_TMP"

set +e
xcodebuild test \
  -project "$PROJECT" \
  -scheme "$SCHEME" \
  -destination "$DESTINATION" \
  -parallel-testing-enabled NO \
  -parallel-testing-worker-count 1 \
  "-only-testing:$TEST_TARGET" \
  -resultBundlePath "$RESULT_BUNDLE_TMP"
XCODE_STATUS=$?
set -e

if [[ $XCODE_STATUS -ne 0 ]]; then
  err "xcodebuild failed with status $XCODE_STATUS"
  err "Check the result bundle for details: $RESULT_BUNDLE_TMP"
  exit $XCODE_STATUS
fi

if [[ ! -d "$RESULT_BUNDLE_TMP" ]]; then
  err "xcresult bundle not found at $RESULT_BUNDLE_TMP"
  exit 1
fi

# Copy xcresult into output dir so "Extract PNGs from latest xcresult" can use it
cp -R "$RESULT_BUNDLE_TMP" "$OUTPUT_DIR/MoveAI_Screenshots.xcresult"
log "Result bundle copied to $OUTPUT_DIR/MoveAI_Screenshots.xcresult"

# Export all attachments (screenshots, etc.) using native xcresulttool
set +e
xcrun xcresulttool export attachments --path "$OUTPUT_DIR/MoveAI_Screenshots.xcresult" --output-path "$OUTPUT_DIR"
EXPORT_STATUS=$?
set -e

COUNT=0
if [[ $EXPORT_STATUS -eq 0 ]]; then
  COUNT=$(find "$OUTPUT_DIR" -maxdepth 1 -type f 2>/dev/null | wc -l | tr -d ' ')
fi

if [[ "$COUNT" -eq 0 ]]; then
  warn "No screenshots extracted from xcresult."
  warn "Extraction wrote 0 PNGs. OUTPUT_DIR=$OUTPUT_DIR"
  FALLBACK_PATH="$OUTPUT_DIR/fallback_booted.png"
  log "Attempting fallback: xcrun simctl io booted screenshot $FALLBACK_PATH"
  if xcrun simctl io booted screenshot "$FALLBACK_PATH"; then
    log "Fallback screenshot saved: $FALLBACK_PATH"
  else
    err "Fallback screenshot failed. Ensure a simulator is booted."
    exit 1
  fi
else
  log "Extracted $COUNT screenshots to $OUTPUT_DIR"
fi

# Clean up temp xcresult bundle (already copied into output dir)
if [[ -d "$RESULT_BUNDLE_TMP" ]]; then
  rm -rf "$RESULT_BUNDLE_TMP"
  log "Cleaned up temp xcresult: $RESULT_BUNDLE_TMP"
fi

# Clean up any other stale xcresult bundles in .screenshot_tmp/
find "$SCREENSHOT_TMP_DIR" -name "*.xcresult" -type d -exec rm -rf {} + 2>/dev/null || true
