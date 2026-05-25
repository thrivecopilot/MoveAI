#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
SCHEME="MoveAI"
IOS_SIM_DESTINATION="${MOVEAI_IOS_SIM_TEST_DESTINATION:-platform=iOS Simulator,name=iPhone 17 Pro}"
MAC_DESTINATION="${MOVEAI_MAC_TEST_DESTINATION:-platform=macOS,arch=arm64,name=My Mac}"
DEFAULT_DESTINATION="${MOVEAI_DEFAULT_TEST_DESTINATION:-$IOS_SIM_DESTINATION}"
DESTINATION="${MOVEAI_TEST_DESTINATION:-$DEFAULT_DESTINATION}"
DERIVED_DATA="${MOVEAI_DERIVED_DATA_PATH:-$PROJECT_ROOT/.build/running-derived-data}"
DEFAULT_CACHE_SUBDIR="${MOVEAI_RUNNING_CACHE_SUBDIR:-.cache_running_device}"
XCODEBUILD_RETRIES="${MOVEAI_XCODEBUILD_RETRIES:-3}"
XCODEBUILD_RETRY_DELAY_SECONDS="${MOVEAI_XCODEBUILD_RETRY_DELAY_SECONDS:-2}"

refresh_simulator_service() {
  DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer \
  xcrun simctl list devices >/dev/null 2>&1 || true
}

destination_uses_simulator() {
  case "$1" in
    *"Simulator"*)
      return 0
      ;;
    *)
      return 1
      ;;
  esac
}

run_xcodebuild_with_retry() {
  local destination="$1"
  shift

  local attempt=1
  local max_attempts="$XCODEBUILD_RETRIES"

  while true; do
    set +e
    "$@"
    local status=$?
    set -e

    if [ "$status" -eq 0 ]; then
      return 0
    fi

    if [ "$attempt" -ge "$max_attempts" ]; then
      echo "[running-regression] xcodebuild failed (exit=$status, attempt $attempt/$max_attempts); no more retries."
      return "$status"
    fi

    if destination_uses_simulator "$destination"; then
      echo "[running-regression] xcodebuild failed (exit=$status, attempt $attempt/$max_attempts); refreshing CoreSimulator and retrying..."
      refresh_simulator_service
    else
      echo "[running-regression] xcodebuild failed (exit=$status, attempt $attempt/$max_attempts); retrying..."
    fi
    sleep "$XCODEBUILD_RETRY_DELAY_SECONDS"
    attempt=$((attempt + 1))
  done
}

run_cached_analysis() {
  local destination="${1:-$DESTINATION}"
  local cache_subdir="${2:-$DEFAULT_CACHE_SUBDIR}"
  local signing_args=()
  if destination_uses_simulator "$destination"; then
    signing_args=(CODE_SIGNING_ALLOWED=NO CODE_SIGNING_REQUIRED=NO CODE_SIGN_IDENTITY=)
  fi

  echo "[running-regression] running cache-only running regression checks (cache=$cache_subdir)"
  DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer \
  MOVEAI_POSE_CACHE_SUBDIR="$cache_subdir" \
  run_xcodebuild_with_retry "$destination" xcodebuild test \
    -scheme "$SCHEME" \
    -destination "$destination" \
    -derivedDataPath "$DERIVED_DATA" \
    -parallel-testing-enabled NO \
    -maximum-concurrent-test-simulator-destinations 1 \
    -maximum-concurrent-test-device-destinations 1 \
    -only-testing:MoveAITests/RunningLabeledVideoRegressionTests/testIssueExpectationsMatchFromCache \
    -only-testing:MoveAITests/RunningLabeledVideoRegressionTests/testMetricExpectationsMatchFromCache \
    -only-testing:MoveAITests/RunningLabeledVideoRegressionTests/testIssueCountExpectationsMatchFromCache \
    "${signing_args[@]}"
}

run_fixture_summary() {
  local destination="${1:-$DESTINATION}"
  local cache_subdir="${2:-$DEFAULT_CACHE_SUBDIR}"
  local signing_args=()
  if destination_uses_simulator "$destination"; then
    signing_args=(CODE_SIGNING_ALLOWED=NO CODE_SIGNING_REQUIRED=NO CODE_SIGN_IDENTITY=)
  fi

  echo "[running-regression] dumping running fixture summaries (cache=$cache_subdir)"
  DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer \
  MOVEAI_POSE_CACHE_SUBDIR="$cache_subdir" \
  run_xcodebuild_with_retry "$destination" xcodebuild test \
    -scheme "$SCHEME" \
    -destination "$destination" \
    -derivedDataPath "$DERIVED_DATA" \
    -parallel-testing-enabled NO \
    -maximum-concurrent-test-simulator-destinations 1 \
    -maximum-concurrent-test-device-destinations 1 \
    -only-testing:MoveAITests/RunningLabeledVideoRegressionTests/testDumpFixtureAnalysisSummaryFromCache \
    "${signing_args[@]}"
}

run_extract() {
  local destination="${1:-$DESTINATION}"
  local cache_subdir="${2:-$DEFAULT_CACHE_SUBDIR}"
  local signing_args=()
  if destination_uses_simulator "$destination"; then
    signing_args=(CODE_SIGNING_ALLOWED=NO CODE_SIGNING_REQUIRED=NO CODE_SIGN_IDENTITY=)
  fi

  echo "[running-regression] extracting running fixture caches (cache=$cache_subdir)"
  DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer \
  MOVEAI_ENABLE_LIVE_POSE_EXTRACTION_TESTS=1 \
  MOVEAI_POSE_CACHE_SUBDIR="$cache_subdir" \
  run_xcodebuild_with_retry "$destination" xcodebuild test \
    -scheme "$SCHEME" \
    -destination "$destination" \
    -derivedDataPath "$DERIVED_DATA" \
    -parallel-testing-enabled NO \
    -maximum-concurrent-test-simulator-destinations 1 \
    -maximum-concurrent-test-device-destinations 1 \
    -only-testing:MoveAITests/RunningLabeledVideoRegressionTests/testExtractAllLabeledVideosToCache \
    "${signing_args[@]}"
}

run_cross_sport_gate() {
  local destination="${1:-$DESTINATION}"
  local cache_subdir="${2:-$DEFAULT_CACHE_SUBDIR}"
  local signing_args=()
  if destination_uses_simulator "$destination"; then
    signing_args=(CODE_SIGNING_ALLOWED=NO CODE_SIGNING_REQUIRED=NO CODE_SIGN_IDENTITY=)
  fi

  run_cached_analysis "$destination" "$cache_subdir"

  echo "[running-regression] running cross-sport safety checks (running + squat + muay thai)"
  DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer \
  MOVEAI_POSE_CACHE_SUBDIR="$cache_subdir" \
  run_xcodebuild_with_retry "$destination" xcodebuild test \
    -scheme "$SCHEME" \
    -destination "$destination" \
    -derivedDataPath "$DERIVED_DATA" \
    -parallel-testing-enabled NO \
    -maximum-concurrent-test-simulator-destinations 1 \
    -maximum-concurrent-test-device-destinations 1 \
    -only-testing:MoveAITests/RunningAnalysisTests \
    -only-testing:MoveAITests/SquatMechanicsSolverTests \
    -only-testing:MoveAITests/AnalysisSummaryBuilderTests \
    -only-testing:MoveAITests/FormFeedbackCodableTests \
    -only-testing:MoveAITests/MuayThaiAnalyzerTests \
    "${signing_args[@]}"
}

case "${1:-}" in
  analyze)
    run_cached_analysis "$DESTINATION" "${2:-$DEFAULT_CACHE_SUBDIR}"
    ;;
  summary)
    run_fixture_summary "$DESTINATION" "${2:-$DEFAULT_CACHE_SUBDIR}"
    ;;
  extract)
    run_extract "$DESTINATION" "${2:-$DEFAULT_CACHE_SUBDIR}"
    ;;
  gate)
    run_cross_sport_gate "$DESTINATION" "${2:-$DEFAULT_CACHE_SUBDIR}"
    ;;
  all)
    run_extract "$DESTINATION" "${2:-$DEFAULT_CACHE_SUBDIR}"
    run_cross_sport_gate "$DESTINATION" "${2:-$DEFAULT_CACHE_SUBDIR}"
    ;;
  *)
    echo "Usage: $0 {analyze [cache_subdir]|summary [cache_subdir]|extract [cache_subdir]|gate [cache_subdir]|all [cache_subdir]}"
    echo "  analyze   Run running cache-only issue + metric regression checks"
    echo "  summary   Print per-fixture running issue/metric summary from cache"
    echo "  extract   Run extraction tests for running fixtures that define videoFile"
    echo "  gate      Run running checks plus cross-sport safety suite"
    echo "  all       Run extract then gate"
    echo "Environment overrides:"
    echo "  MOVEAI_RUNNING_CACHE_SUBDIR=<subdir>      Default cache subdirectory (default $DEFAULT_CACHE_SUBDIR)"
    echo "  MOVEAI_POSE_CACHE_SUBDIR=<subdir>         Explicit cache subdirectory for this invocation"
    echo "  MOVEAI_TEST_DESTINATION=<destination>     Override xcodebuild destination (default $DEFAULT_DESTINATION)"
    echo "  MOVEAI_DEFAULT_TEST_DESTINATION=<dest>    Change the default destination when MOVEAI_TEST_DESTINATION is unset"
    echo "  MOVEAI_IOS_SIM_TEST_DESTINATION=<dest>    Simulator destination used by default (default $IOS_SIM_DESTINATION)"
    echo "  MOVEAI_MAC_TEST_DESTINATION=<dest>        Mac destination for manual overrides (default $MAC_DESTINATION)"
    echo "  MOVEAI_ENABLE_LIVE_POSE_EXTRACTION_TESTS=1  Required by extract"
    ;;
esac
