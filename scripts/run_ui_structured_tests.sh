#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PROJECT="$ROOT_DIR/MoveAI.xcodeproj"
SCHEME="MoveAI"
DEFAULT_TEST_TARGET="MoveAIUITests/StructuredUITests"

TEST_TARGET="$DEFAULT_TEST_TARGET"
if [[ "${1:-}" == "--only" ]]; then
  if [[ -z "${2:-}" ]]; then
    echo "Usage: run_ui_structured_tests.sh [--only <TestClass[/testMethod]>]" >&2
    exit 1
  fi
  TEST_TARGET="MoveAIUITests/${2}"
fi

if ! command -v xcodebuild >/dev/null 2>&1; then
  echo "[ui-structured][error] xcodebuild not found." >&2
  exit 1
fi

if ! command -v xcrun >/dev/null 2>&1; then
  echo "[ui-structured][error] xcrun not found." >&2
  exit 1
fi

TIMESTAMP="$(date +"%Y-%m-%d_%H-%M-%S")"
REPORT_DIR="$ROOT_DIR/Reports/ui-structured/$TIMESTAMP"
RESULT_BUNDLE="$REPORT_DIR/MoveAI_StructuredUI.xcresult"
LOG_FILE="$REPORT_DIR/xcodebuild.log"
FAILURES_FILE="$REPORT_DIR/failures.txt"
ATTACHMENTS_DIR="$REPORT_DIR/attachments"
JSON_SNAPSHOT_DIR="$REPORT_DIR/json-snapshots"

mkdir -p "$REPORT_DIR" "$ATTACHMENTS_DIR" "$JSON_SNAPSHOT_DIR"

DEVICE_NAME="${UI_TEST_DEVICE:-iPhone 16 Pro}"
DEVICE_ID="$(xcrun simctl list devices available | sed -n "s/.*${DEVICE_NAME} (\\([A-F0-9-]*\\)).*/\\1/p" | head -n 1)"

if [[ -z "$DEVICE_ID" ]]; then
  DEVICE_ID="$(xcrun simctl list devices booted | sed -n 's/.*(\([A-F0-9-]*\)) (Booted).*/\1/p' | head -n 1)"
fi

if [[ -z "$DEVICE_ID" ]]; then
  DEVICE_ID="$(xcrun simctl list devices available | sed -n 's/.*iPhone.*(\([A-F0-9-]*\)).*/\1/p' | head -n 1)"
fi

if [[ -z "$DEVICE_ID" ]]; then
  echo "[ui-structured][error] No available iPhone simulator found." >&2
  exit 1
fi

DESTINATION="platform=iOS Simulator,id=$DEVICE_ID"

echo "[ui-structured] Running test target: $TEST_TARGET"
echo "[ui-structured] Destination: $DESTINATION"
echo "[ui-structured] Report dir: $REPORT_DIR"

set +e
xcodebuild test \
  -project "$PROJECT" \
  -scheme "$SCHEME" \
  -destination "$DESTINATION" \
  -parallel-testing-enabled NO \
  -parallel-testing-worker-count 1 \
  "-only-testing:$TEST_TARGET" \
  -resultBundlePath "$RESULT_BUNDLE" \
  | tee "$LOG_FILE"
XCODE_STATUS=${PIPESTATUS[0]}
set -e

if [[ -d "$RESULT_BUNDLE" ]]; then
  xcrun xcresulttool export attachments \
    --path "$RESULT_BUNDLE" \
    --output-path "$ATTACHMENTS_DIR" >/dev/null 2>&1 || true

  MANIFEST_FILE="$ATTACHMENTS_DIR/manifest.json"
  if [[ -f "$MANIFEST_FILE" ]]; then
    while IFS=$'\t' read -r exported_name suggested_name; do
      [[ -z "$exported_name" || -z "$suggested_name" ]] && continue
      [[ -f "$ATTACHMENTS_DIR/$exported_name" ]] || continue
      cp "$ATTACHMENTS_DIR/$exported_name" "$JSON_SNAPSHOT_DIR/$suggested_name"
    done < <(
      jq -r '
        .[]?.attachments[]? |
        select(.suggestedHumanReadableName | test("^structural_(snapshot|actual|baseline)__")) |
        [.exportedFileName, .suggestedHumanReadableName] |
        @tsv
      ' "$MANIFEST_FILE" 2>/dev/null || true
    )
  else
    find "$ATTACHMENTS_DIR" -type f \( -name 'structural_snapshot__*.json' -o -name 'structural_snapshot__*' \) -exec cp {} "$JSON_SNAPSHOT_DIR"/ \; 2>/dev/null || true
  fi
fi

# Compact failure extraction from xcodebuild output.
{
  grep -E "Assertion Failure|error: -\\[|fatal error:|\\*\\* TEST FAILED \\*\\*|Test Case '-\\[[^]]+\\]' failed" "$LOG_FILE" || true
} | sed 's/^\s*//' > "$FAILURES_FILE"

if [[ ! -s "$FAILURES_FILE" && $XCODE_STATUS -eq 0 ]]; then
  echo "No failures detected." > "$FAILURES_FILE"
fi

SNAPSHOT_COUNT=$(find "$JSON_SNAPSHOT_DIR" -type f | wc -l | tr -d ' ')

cat > "$REPORT_DIR/summary.json" <<SUMMARY
{
  "exit_code": $XCODE_STATUS,
  "test_target": "${TEST_TARGET}",
  "result_bundle": "${RESULT_BUNDLE}",
  "failures_file": "${FAILURES_FILE}",
  "json_snapshot_dir": "${JSON_SNAPSHOT_DIR}",
  "json_snapshot_count": ${SNAPSHOT_COUNT}
}
SUMMARY

echo "[ui-structured] failures.txt: $FAILURES_FILE"
echo "[ui-structured] json snapshots: $JSON_SNAPSHOT_DIR (count=$SNAPSHOT_COUNT)"
echo "[ui-structured] summary: $REPORT_DIR/summary.json"

exit $XCODE_STATUS
