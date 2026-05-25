#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
SCHEME="MoveAI"
IPHONE17_DESTINATION="${MOVEAI_IPHONE17_DESTINATION:-platform=iOS Simulator,name=iPhone 17 Pro}"
MAC_DESTINATION="${MOVEAI_MAC_TEST_DESTINATION:-platform=macOS,arch=arm64,name=My Mac}"
DESTINATION="${MOVEAI_TEST_DESTINATION:-$MAC_DESTINATION}"
DERIVED_DATA="${MOVEAI_DERIVED_DATA_PATH:-$PROJECT_ROOT/.build/muaythai-derived-data}"
MANIFEST_PATH="$PROJECT_ROOT/MoveAITests/TestVideos/muay_thai_labeled_fixtures.json"
VIDEOS_DIR="$PROJECT_ROOT/MoveAITests/TestVideos"
MACOS_EXTRACTOR="$SCRIPT_DIR/extract_muaythai_pose_cache.swift"
DEFAULT_CACHE_SUBDIR="${MOVEAI_POSE_CACHE_SUBDIR:-.cache_device}"
MACOS_CACHE_SUBDIR="${MOVEAI_MUAY_THAI_MACOS_CACHE_SUBDIR:-.cache_macos}"
IOS_CACHE_SUBDIR="${MOVEAI_MUAY_THAI_IOS_CACHE_SUBDIR:-.cache_ios}"
DEVICE_CACHE_SUBDIR="${MOVEAI_MUAY_THAI_DEVICE_CACHE_SUBDIR:-.cache_device}"
XCODEBUILD_RETRIES="${MOVEAI_XCODEBUILD_RETRIES:-4}"
XCODEBUILD_RETRY_DELAY_SECONDS="${MOVEAI_XCODEBUILD_RETRY_DELAY_SECONDS:-3}"

resolve_cache_dir() {
  local cache_subdir="${1:-$DEFAULT_CACHE_SUBDIR}"
  if [ -n "${MOVEAI_POSE_CACHE_DIR:-}" ]; then
    echo "$MOVEAI_POSE_CACHE_DIR"
    return
  fi

  echo "$VIDEOS_DIR/$cache_subdir"
}

refresh_simulator_service() {
  # Touch CoreSimulator to recover from transient "connection invalid" failures.
  DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer \
  xcrun simctl list devices >/dev/null 2>&1 || true
}

require_simulator_extraction_opt_in() {
  if [ "${MOVEAI_ALLOW_SIMULATOR_EXTRACTION:-0}" != "1" ]; then
    echo "[muay-thai-regression] simulator extraction is disabled by default."
    echo "[muay-thai-regression] use device/macOS extraction, or set MOVEAI_ALLOW_SIMULATOR_EXTRACTION=1 for an explicit override."
    return 2
  fi
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

    if [ "$destination" = "$MAC_DESTINATION" ] || [ "$attempt" -ge "$max_attempts" ]; then
      echo "[muay-thai-regression] xcodebuild failed (exit=$status, attempt $attempt/$max_attempts); no more retries."
      return "$status"
    fi

    echo "[muay-thai-regression] xcodebuild failed (exit=$status, attempt $attempt/$max_attempts); refreshing CoreSimulator and retrying..."
    refresh_simulator_service
    sleep "$XCODEBUILD_RETRY_DELAY_SECONDS"
    attempt=$((attempt + 1))
  done
}

extract_cache_macos() {
  local cache_subdir="${1:-$DEFAULT_CACHE_SUBDIR}"
  local cache_dir
  cache_dir="$(resolve_cache_dir "$cache_subdir")"
  local module_cache_dir="$PROJECT_ROOT/.build/clang-modcache"

  echo "[muay-thai-regression] extracting/refreshing pose caches on macOS Vision pipeline (cache=$cache_subdir)"
  mkdir -p "$cache_dir"
  mkdir -p "$module_cache_dir"

  ruby -rjson -e 'm=JSON.parse(File.read(ARGV[0])); m["fixtures"].each { |f| puts "#{f["id"]}|#{f["videoFile"]}" }' "$MANIFEST_PATH" \
  | while IFS='|' read -r fixture_id video_file; do
      local video_path="$VIDEOS_DIR/$video_file"
      local cache_path="$cache_dir/${fixture_id}_poses.json"
      echo "  - $fixture_id ($video_file)"
      DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer \
      CLANG_MODULE_CACHE_PATH="$module_cache_dir" \
      xcrun --sdk macosx swift "$MACOS_EXTRACTOR" \
        --input "$video_path" \
        --output "$cache_path" \
        --fps 30
    done
}

extract_cache_simulator() {
  local destination="${1:-$DESTINATION}"
  local cache_subdir="${2:-$DEFAULT_CACHE_SUBDIR}"
  require_simulator_extraction_opt_in
  echo "[muay-thai-regression] extracting/refreshing pose caches from simulator (cache=$cache_subdir, debug only)"
  DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer \
  MOVEAI_ENABLE_LIVE_POSE_EXTRACTION_TESTS=1 \
  MOVEAI_ALLOW_SIMULATOR_EXTRACTION=1 \
  MOVEAI_ENABLE_MUAY_THAI_ANALYZER=1 \
  MOVEAI_ENABLE_MUAY_THAI_COMBO_ANALYZER=1 \
  MOVEAI_POSE_CACHE_SUBDIR="$cache_subdir" \
  run_xcodebuild_with_retry "$destination" xcodebuild test \
    -scheme "$SCHEME" \
    -destination "$destination" \
    -derivedDataPath "$DERIVED_DATA" \
    -parallel-testing-enabled NO \
    -maximum-concurrent-test-simulator-destinations 1 \
    -maximum-concurrent-test-device-destinations 1 \
    -only-testing:MoveAITests/MuayThaiLabeledVideoRegressionTests/testExtractAllLabeledVideosToCache \
    CODE_SIGNING_ALLOWED=NO \
    CODE_SIGNING_REQUIRED=NO \
    CODE_SIGN_IDENTITY=
}

extract_cache_device() {
  local device_identifier="${1:-}"
  local cache_subdir="${2:-$DEVICE_CACHE_SUBDIR}"
  local destination="platform=iOS,id=$device_identifier"
  local bundle_id="${MOVEAI_DEVICE_BUNDLE_ID:-com.thrivecopilot.MoveAI}"
  local remote_cache_source="${MOVEAI_DEVICE_REMOTE_CACHE_SOURCE:-tmp/muaythai_cache}"
  local remote_cache_dir="${remote_cache_source#/}"
  local remote_cache_abs="/$remote_cache_dir"
  local pull_root="$PROJECT_ROOT/.build/muaythai-device-pull"
  local pulled_cache_dir
  local local_cache_dir
  local expected_count
  local pose_count
  local meta_count
  local missing=0

  if [ -z "$device_identifier" ]; then
    echo "[muay-thai-regression] extract-device requires a physical device id/udid."
    echo "Usage: $0 extract-device <device_id_or_udid> [cache_subdir]"
    return 2
  fi

  local_cache_dir="$(resolve_cache_dir "$cache_subdir")"
  mkdir -p "$PROJECT_ROOT/.build"
  rm -rf "$pull_root"
  mkdir -p "$pull_root"

  echo "[muay-thai-regression] extracting pose caches on physical iOS device (device=$device_identifier, remote=$remote_cache_abs)"
  DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer \
  MOVEAI_ENABLE_LIVE_POSE_EXTRACTION_TESTS=1 \
  MOVEAI_ENABLE_MUAY_THAI_ANALYZER=1 \
  MOVEAI_ENABLE_MUAY_THAI_COMBO_ANALYZER=1 \
  MOVEAI_POSE_CACHE_DIR="$remote_cache_abs" \
  xcodebuild test \
    -scheme "$SCHEME" \
    -destination "$destination" \
    -derivedDataPath "$DERIVED_DATA" \
    -parallel-testing-enabled NO \
    -maximum-concurrent-test-device-destinations 1 \
    -only-testing:MoveAITests/MuayThaiLabeledVideoRegressionTests/testExtractAllLabeledVideosToCache

  echo "[muay-thai-regression] pulling device cache from app container (bundle=$bundle_id, source=$remote_cache_dir)"
  DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer \
  xcrun devicectl device copy from \
    --device "$device_identifier" \
    --domain-type appDataContainer \
    --domain-identifier "$bundle_id" \
    --source "$remote_cache_dir" \
    --destination "$pull_root"

  if [ -d "$pull_root/$(basename "$remote_cache_dir")" ]; then
    pulled_cache_dir="$pull_root/$(basename "$remote_cache_dir")"
  else
    pulled_cache_dir="$pull_root"
  fi

  pose_count="$(find "$pulled_cache_dir" -maxdepth 1 -type f -name '*_poses.json' | wc -l | tr -d ' ')"
  meta_count="$(find "$pulled_cache_dir" -maxdepth 1 -type f -name '*_poses.meta.json' | wc -l | tr -d ' ')"

  if [ "$pose_count" -eq 0 ]; then
    echo "[muay-thai-regression] no pose cache files were pulled from device path '$remote_cache_dir'."
    echo "[muay-thai-regression] inspect pull artifacts under: $pull_root"
    return 1
  fi

  rm -rf "$local_cache_dir"
  mkdir -p "$local_cache_dir"
  cp "$pulled_cache_dir"/*_poses.json "$local_cache_dir"/
  cp "$pulled_cache_dir"/*_poses.meta.json "$local_cache_dir"/

  expected_count="$(
    ruby -rjson -e '
      m = JSON.parse(File.read(ARGV[0]))
      fixtures = m.fetch("fixtures")
      raw_filter = ENV["MOVEAI_FIXTURE_IDS"]
      if raw_filter && !raw_filter.empty?
        ids = raw_filter.split(",").map { |v| v.strip }.reject(&:empty?)
        fixtures = fixtures.select { |f| ids.include?(f.fetch("id")) }
      end
      puts fixtures.length
    ' "$MANIFEST_PATH"
  )"

  while IFS= read -r fixture_id; do
    [ -f "$local_cache_dir/${fixture_id}_poses.json" ] || { echo "[muay-thai-regression] missing cache JSON for fixture '$fixture_id'"; missing=1; }
    [ -f "$local_cache_dir/${fixture_id}_poses.meta.json" ] || { echo "[muay-thai-regression] missing cache metadata for fixture '$fixture_id'"; missing=1; }
  done < <(
    ruby -rjson -rset -e '
      m = JSON.parse(File.read(ARGV[0]))
      fixtures = m.fetch("fixtures")
      raw_filter = ENV["MOVEAI_FIXTURE_IDS"]
      if raw_filter && !raw_filter.empty?
        ids = raw_filter.split(",").map { |v| v.strip }.reject(&:empty?).to_set
        fixtures = fixtures.select { |f| ids.include?(f.fetch("id")) }
      end
      fixtures.each { |f| puts f.fetch("id") }
    ' "$MANIFEST_PATH"
  )

  if [ "$missing" -ne 0 ]; then
    echo "[muay-thai-regression] pulled cache set is incomplete."
    echo "[muay-thai-regression] local cache dir: $local_cache_dir"
    echo "[muay-thai-regression] pull artifacts: $pull_root"
    return 1
  fi

  echo "[muay-thai-regression] pulled $pose_count pose json files and $meta_count metadata files."
  echo "[muay-thai-regression] expected fixtures: $expected_count"
  echo "[muay-thai-regression] local cache ready at: $local_cache_dir"
}

run_cached_analysis() {
  local debug_flag="${1:-0}"
  local destination="${2:-$DESTINATION}"
  local cache_subdir="${3:-$DEFAULT_CACHE_SUBDIR}"

  echo "[muay-thai-regression] running cached Muay Thai regression checks (cache=$cache_subdir)"
  DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer \
  MOVEAI_ENABLE_MUAY_THAI_ANALYZER=1 \
  MOVEAI_ENABLE_MUAY_THAI_COMBO_ANALYZER=1 \
  MOVEAI_MUAY_THAI_DEBUG="$debug_flag" \
  MOVEAI_POSE_CACHE_SUBDIR="$cache_subdir" \
  run_xcodebuild_with_retry "$destination" xcodebuild test \
    -scheme "$SCHEME" \
    -destination "$destination" \
    -derivedDataPath "$DERIVED_DATA" \
    -parallel-testing-enabled NO \
    -maximum-concurrent-test-simulator-destinations 1 \
    -maximum-concurrent-test-device-destinations 1 \
    -only-testing:MoveAITests/MuayThaiLabeledVideoRegressionTests/testAutoDetectMatchesFixtureExpectationFromCache \
    -only-testing:MoveAITests/MuayThaiLabeledVideoRegressionTests/testIssueExpectationsMatchFromCache \
    -only-testing:MoveAITests/MuayThaiLabeledVideoRegressionTests/testStrikeAndIssueCountExpectationsMatchFromCache \
    -only-testing:MoveAITests/MuayThaiLabeledVideoRegressionTests/testJabArcherFixtureUsesSpecializedRearHandDropMessage
}

run_fixture_summary() {
  local destination="${1:-$DESTINATION}"
  local cache_subdir="${2:-$DEFAULT_CACHE_SUBDIR}"
  local capture_path="${3:-}"

  echo "[muay-thai-regression] dumping cached Muay Thai fixture summaries (cache=$cache_subdir)"
  if [ -n "$capture_path" ]; then
    DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer \
    MOVEAI_ENABLE_MUAY_THAI_ANALYZER=1 \
    MOVEAI_ENABLE_MUAY_THAI_COMBO_ANALYZER=1 \
    MOVEAI_POSE_CACHE_SUBDIR="$cache_subdir" \
    run_xcodebuild_with_retry "$destination" xcodebuild test \
      -scheme "$SCHEME" \
      -destination "$destination" \
      -derivedDataPath "$DERIVED_DATA" \
      -parallel-testing-enabled NO \
      -maximum-concurrent-test-simulator-destinations 1 \
      -maximum-concurrent-test-device-destinations 1 \
      -only-testing:MoveAITests/MuayThaiLabeledVideoRegressionTests/testDumpFixtureAnalysisSummaryFromCache \
      | tee "$capture_path"
  else
    DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer \
    MOVEAI_ENABLE_MUAY_THAI_ANALYZER=1 \
    MOVEAI_ENABLE_MUAY_THAI_COMBO_ANALYZER=1 \
    MOVEAI_POSE_CACHE_SUBDIR="$cache_subdir" \
    run_xcodebuild_with_retry "$destination" xcodebuild test \
      -scheme "$SCHEME" \
      -destination "$destination" \
      -derivedDataPath "$DERIVED_DATA" \
      -parallel-testing-enabled NO \
      -maximum-concurrent-test-simulator-destinations 1 \
      -maximum-concurrent-test-device-destinations 1 \
      -only-testing:MoveAITests/MuayThaiLabeledVideoRegressionTests/testDumpFixtureAnalysisSummaryFromCache
  fi
}

compare_cache_summaries() {
  local cache_a="${1:-$MACOS_CACHE_SUBDIR}"
  local cache_b="${2:-$IOS_CACHE_SUBDIR}"
  local destination="${3:-$DESTINATION}"

  local log_a
  local log_b
  local summary_a
  local summary_b
  local label_a
  local label_b
  log_a="$(mktemp "/tmp/muaythai_${cache_a//[^A-Za-z0-9]/_}_summary_XXXXXX")"
  log_b="$(mktemp "/tmp/muaythai_${cache_b//[^A-Za-z0-9]/_}_summary_XXXXXX")"
  summary_a="$(mktemp "/tmp/muaythai_${cache_a//[^A-Za-z0-9]/_}_summary_XXXXXX")"
  summary_b="$(mktemp "/tmp/muaythai_${cache_b//[^A-Za-z0-9]/_}_summary_XXXXXX")"
  label_a="${cache_a#.}"
  label_b="${cache_b#.}"

  run_fixture_summary "$destination" "$cache_a" "$log_a"
  run_fixture_summary "$destination" "$cache_b" "$log_b"

  rg '^FIXTURE_SUMMARY\|' "$log_a" > "$summary_a"
  rg '^FIXTURE_SUMMARY\|' "$log_b" > "$summary_b"

  ruby - "$summary_a" "$summary_b" "$label_a" "$label_b" <<'RUBY'
lines_a = File.readlines(ARGV[0], chomp: true)
lines_b = File.readlines(ARGV[1], chomp: true)
label_a = ARGV[2]
label_b = ARGV[3]

parse = lambda do |lines|
  rows = {}
  lines.each do |line|
    next unless line.start_with?("FIXTURE_SUMMARY|")
    data = {}
    line.split("|")[1..].each do |field|
      key, value = field.split("=", 2)
      data[key] = value
    end
    rows[data.fetch("id")] = data
  end
  rows
end

a = parse.call(lines_a)
b = parse.call(lines_b)
ids = (a.keys + b.keys).uniq.sort

puts "id\t#{label_a}_detected\t#{label_b}_detected\t#{label_a}_strikes\t#{label_b}_strikes\t#{label_a}_issues\t#{label_b}_issues"
ids.each do |id|
  row_a = a[id] || {}
  row_b = b[id] || {}
  puts [
    id,
    row_a.fetch("detected", "missing"),
    row_b.fetch("detected", "missing"),
    row_a.fetch("strikes", "missing"),
    row_b.fetch("strikes", "missing"),
    row_a.fetch("issues", "missing"),
    row_b.fetch("issues", "missing")
  ].join("\t")
end
RUBY
}

case "${1:-}" in
  extract)
    extract_cache_macos "${2:-$DEFAULT_CACHE_SUBDIR}"
    ;;
  extract-macos)
    extract_cache_macos "${2:-$MACOS_CACHE_SUBDIR}"
    ;;
  extract-sim)
    extract_cache_simulator "$DESTINATION" "${2:-$DEFAULT_CACHE_SUBDIR}"
  ;;
  extract-sim-ios17)
    extract_cache_simulator "$IPHONE17_DESTINATION" "${2:-$DEFAULT_CACHE_SUBDIR}"
    ;;
  extract-device)
    extract_cache_device "${2:-}" "${3:-$DEVICE_CACHE_SUBDIR}"
    ;;
  extract-ios)
    extract_cache_simulator "$DESTINATION" "${2:-$IOS_CACHE_SUBDIR}"
    ;;
  extract-ios17)
    extract_cache_simulator "$IPHONE17_DESTINATION" "${2:-$IOS_CACHE_SUBDIR}"
    ;;
  extract-dual)
    extract_cache_macos "${2:-$MACOS_CACHE_SUBDIR}"
    extract_cache_simulator "$IPHONE17_DESTINATION" "${3:-$IOS_CACHE_SUBDIR}"
    ;;
  analyze)
    run_cached_analysis 0 "$DESTINATION" "${2:-$DEFAULT_CACHE_SUBDIR}"
    ;;
  analyze-ios17)
    run_cached_analysis 0 "$IPHONE17_DESTINATION" "${2:-$DEFAULT_CACHE_SUBDIR}"
    ;;
  analyze-mac)
    run_cached_analysis 0 "$MAC_DESTINATION" "${2:-$DEFAULT_CACHE_SUBDIR}"
    ;;
  analyze-debug)
    run_cached_analysis 1 "$DESTINATION" "${2:-$DEFAULT_CACHE_SUBDIR}"
    ;;
  analyze-cache)
    run_cached_analysis 0 "$DESTINATION" "${2:-$DEFAULT_CACHE_SUBDIR}"
    ;;
  summary)
    run_fixture_summary "$DESTINATION" "${2:-$DEFAULT_CACHE_SUBDIR}"
    ;;
  summary-ios17)
    run_fixture_summary "$IPHONE17_DESTINATION" "${2:-$DEFAULT_CACHE_SUBDIR}"
    ;;
  summary-mac)
    run_fixture_summary "$MAC_DESTINATION" "${2:-$DEFAULT_CACHE_SUBDIR}"
    ;;
  summary-cache)
    run_fixture_summary "$DESTINATION" "${2:-$DEFAULT_CACHE_SUBDIR}"
    ;;
  compare)
    compare_cache_summaries "${2:-$MACOS_CACHE_SUBDIR}" "${3:-$IOS_CACHE_SUBDIR}" "$DESTINATION"
    ;;
  compare-ios17)
    compare_cache_summaries "${2:-$MACOS_CACHE_SUBDIR}" "${3:-$IOS_CACHE_SUBDIR}" "$IPHONE17_DESTINATION"
    ;;
  all)
    extract_cache_macos "${2:-$DEFAULT_CACHE_SUBDIR}"
    run_cached_analysis 0 "$DESTINATION" "${2:-$DEFAULT_CACHE_SUBDIR}"
    ;;
  all-ios17)
    extract_cache_simulator "$IPHONE17_DESTINATION" "${2:-$DEFAULT_CACHE_SUBDIR}"
    run_cached_analysis 0 "$IPHONE17_DESTINATION" "${2:-$DEFAULT_CACHE_SUBDIR}"
    ;;
  *)
    echo "Usage: $0 {extract [cache_subdir]|extract-macos [cache_subdir]|extract-sim [cache_subdir]|extract-sim-ios17 [cache_subdir]|extract-device <device_id_or_udid> [cache_subdir]|extract-ios [cache_subdir]|extract-ios17 [cache_subdir]|extract-dual [macos_cache_subdir] [ios_cache_subdir]|analyze [cache_subdir]|analyze-ios17 [cache_subdir]|analyze-mac [cache_subdir]|analyze-debug [cache_subdir]|analyze-cache [cache_subdir]|summary [cache_subdir]|summary-ios17 [cache_subdir]|summary-mac [cache_subdir]|summary-cache [cache_subdir]|compare [cache_a] [cache_b]|compare-ios17 [cache_a] [cache_b]|all [cache_subdir]|all-ios17 [cache_subdir]}"
    echo "  extract             Extract/refresh caches via macOS Vision extractor (default cache: $DEFAULT_CACHE_SUBDIR)"
    echo "  extract-macos       Extract/refresh macOS Vision caches (default cache: $MACOS_CACHE_SUBDIR)"
    echo "  extract-sim         Extract via iOS simulator test path (requires MOVEAI_ALLOW_SIMULATOR_EXTRACTION=1)"
    echo "  extract-sim-ios17   Extract via iPhone 17 simulator destination (requires MOVEAI_ALLOW_SIMULATOR_EXTRACTION=1)"
    echo "  extract-device      Extract on physical iOS device and pull cache back to Mac (default cache: $DEVICE_CACHE_SUBDIR)"
    echo "  extract-ios         Alias of extract-sim with iOS cache default (requires MOVEAI_ALLOW_SIMULATOR_EXTRACTION=1)"
    echo "  extract-ios17       Alias of extract-sim-ios17 with iOS cache default (requires MOVEAI_ALLOW_SIMULATOR_EXTRACTION=1)"
    echo "  extract-dual        Build both macOS and iOS cache sets (defaults: $MACOS_CACHE_SUBDIR, $IOS_CACHE_SUBDIR)"
    echo "  analyze             Run cache-only auto-detect + issue regression checks"
    echo "  analyze-ios17       Run cache-only checks on iPhone 17 simulator destination"
    echo "  analyze-mac         Run cache-only checks on My Mac (Designed for iPad/iPhone)"
    echo "  analyze-debug       Run cache-only checks with MOVEAI_MUAY_THAI_DEBUG=1"
    echo "  analyze-cache       Alias of analyze"
    echo "  summary             Print per-fixture detection + issue summary from cache"
    echo "  summary-ios17       Print per-fixture summary on iPhone 17 simulator destination"
    echo "  summary-mac         Print per-fixture summary on My Mac destination"
    echo "  summary-cache       Alias of summary"
    echo "  compare             Print side-by-side diff table of two cache sets"
    echo "  compare-ios17       Compare two cache sets on iPhone 17 simulator destination"
    echo "  all                 Run extract then analyze for one cache set"
    echo "  all-ios17           Run iPhone 17 simulator extract + analyze (requires MOVEAI_ALLOW_SIMULATOR_EXTRACTION=1)"
    echo "Environment overrides:"
    echo "  MOVEAI_POSE_CACHE_SUBDIR=<subdir>        Set cache subdirectory used by tests (default $DEFAULT_CACHE_SUBDIR)"
    echo "  MOVEAI_TEST_DESTINATION=<destination>    Override test destination (default $MAC_DESTINATION)"
    echo "  MOVEAI_POSE_CACHE_DIR=<absolute-or-relative-path>  Override cache directory path"
    echo "  MOVEAI_MUAY_THAI_MACOS_CACHE_SUBDIR=<subdir>       Default for extract-macos/extract-dual"
    echo "  MOVEAI_MUAY_THAI_IOS_CACHE_SUBDIR=<subdir>         Default for extract-ios/extract-dual"
    echo "  MOVEAI_MUAY_THAI_DEVICE_CACHE_SUBDIR=<subdir>      Default local destination for extract-device"
    echo "  MOVEAI_ENABLE_LIVE_POSE_EXTRACTION_TESTS=1         Enable extraction tests (set automatically by extract-device/extract-sim)"
    echo "  MOVEAI_ALLOW_SIMULATOR_EXTRACTION=1                Explicitly allow simulator extraction commands"
    echo "  MOVEAI_DEVICE_BUNDLE_ID=<bundle-id>                App bundle id used for devicectl copy (default com.thrivecopilot.MoveAI)"
    echo "  MOVEAI_DEVICE_REMOTE_CACHE_SOURCE=<path>           Device app-container source path (default tmp/muaythai_cache)"
    ;;
esac
