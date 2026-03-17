#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
SCHEME="MoveAI"
DESTINATION="${MOVEAI_TEST_DESTINATION:-platform=iOS Simulator,id=B512B7D6-8471-4F50-98D4-EF0932937865}"
DERIVED_DATA="${MOVEAI_DERIVED_DATA_PATH:-$PROJECT_ROOT/.build/muaythai-derived-data}"
MANIFEST_PATH="$PROJECT_ROOT/MoveAITests/TestVideos/muay_thai_labeled_fixtures.json"
VIDEOS_DIR="$PROJECT_ROOT/MoveAITests/TestVideos"
CACHE_DIR="$VIDEOS_DIR/.cache"
MACOS_EXTRACTOR="$SCRIPT_DIR/extract_muaythai_pose_cache.swift"

extract_cache_macos() {
  echo "[muay-thai-regression] extracting/refreshing pose caches on macOS Vision pipeline"
  mkdir -p "$CACHE_DIR"

  ruby -rjson -e 'm=JSON.parse(File.read(ARGV[0])); m["fixtures"].each { |f| puts "#{f["id"]}|#{f["videoFile"]}" }' "$MANIFEST_PATH" \
  | while IFS='|' read -r fixture_id video_file; do
      local video_path="$VIDEOS_DIR/$video_file"
      local cache_path="$CACHE_DIR/${fixture_id}_poses.json"
      echo "  - $fixture_id ($video_file)"
      "$MACOS_EXTRACTOR" --input "$video_path" --output "$cache_path" --fps 30
    done
}

extract_cache_simulator() {
  echo "[muay-thai-regression] extracting/refreshing pose caches from simulator (debug only)"
  DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer \
  MOVEAI_ENABLE_MUAY_THAI_ANALYZER=1 \
  MOVEAI_ENABLE_MUAY_THAI_COMBO_ANALYZER=1 \
  xcodebuild test \
    -scheme "$SCHEME" \
    -destination "$DESTINATION" \
    -derivedDataPath "$DERIVED_DATA" \
    -parallel-testing-enabled NO \
    -maximum-concurrent-test-simulator-destinations 1 \
    -maximum-concurrent-test-device-destinations 1 \
    -only-testing:MoveAITests/MuayThaiLabeledVideoRegressionTests/testExtractAllLabeledVideosToCache
}

run_cached_analysis() {
  local debug_flag="${1:-0}"

  echo "[muay-thai-regression] running cached Muay Thai regression checks"
  DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer \
  MOVEAI_ENABLE_MUAY_THAI_ANALYZER=1 \
  MOVEAI_ENABLE_MUAY_THAI_COMBO_ANALYZER=1 \
  MOVEAI_MUAY_THAI_DEBUG="$debug_flag" \
  xcodebuild test \
    -scheme "$SCHEME" \
    -destination "$DESTINATION" \
    -derivedDataPath "$DERIVED_DATA" \
    -parallel-testing-enabled NO \
    -maximum-concurrent-test-simulator-destinations 1 \
    -maximum-concurrent-test-device-destinations 1 \
    -only-testing:MoveAITests/MuayThaiLabeledVideoRegressionTests/testAutoDetectMatchesFixtureExpectationFromCache \
    -only-testing:MoveAITests/MuayThaiLabeledVideoRegressionTests/testIssueExpectationsMatchFromCache \
    -only-testing:MoveAITests/MuayThaiLabeledVideoRegressionTests/testJabLeadHandErrorFixtureDoesNotReportRearHandDrop
}

case "${1:-}" in
  extract)
    extract_cache_macos
    ;;
  extract-sim)
    extract_cache_simulator
    ;;
  analyze)
    run_cached_analysis 0
    ;;
  analyze-debug)
    run_cached_analysis 1
    ;;
  all)
    extract_cache_macos
    run_cached_analysis 0
    ;;
  *)
    echo "Usage: $0 {extract|extract-sim|analyze|analyze-debug|all}"
    echo "  extract       Extract/refresh caches via macOS Vision extractor (recommended)"
    echo "  extract-sim   Extract via iOS simulator test path (debug only)"
    echo "  analyze       Run cache-only auto-detect + issue regression checks"
    echo "  analyze-debug Run cache-only checks with MOVEAI_MUAY_THAI_DEBUG=1"
    echo "  all           Run extract then analyze"
    ;;
esac
