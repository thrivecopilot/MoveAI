#!/bin/bash
# Usage: ./scripts/run-test.sh [extract|analyze] [test-case-name]
#
# Autonomous testing workflow - no Xcode or simulator required.
# Run from project root directory.

TEST_NAME=${2:-test_case_1}
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
CLI_DIR="$PROJECT_ROOT/Tools/MoveAICLI"
VIDEOS_DIR="$PROJECT_ROOT/MoveAITests/TestVideos"
CACHE_DIR="$VIDEOS_DIR/.cache"
RESULTS_DIR="$VIDEOS_DIR/.results"

case "$1" in
  extract)
    VIDEO_PATH="$VIDEOS_DIR/${TEST_NAME}.MOV"
    if [ ! -f "$VIDEO_PATH" ]; then
      VIDEO_PATH="$VIDEOS_DIR/${TEST_NAME}.mp4"
    fi
    if [ ! -f "$VIDEO_PATH" ]; then
      VIDEO_PATH="$VIDEOS_DIR/${TEST_NAME}.mov"
    fi
    if [ ! -f "$VIDEO_PATH" ]; then
      echo "❌ Video not found: $VIDEOS_DIR/${TEST_NAME}.{MOV,mp4,mov}"
      exit 1
    fi
    echo "🎬 Extracting poses for $TEST_NAME..."
    echo "  Cache dir: $CACHE_DIR"
    mkdir -p "$CACHE_DIR"
    cd "$CLI_DIR" && swift run MoveAICLI extract "$VIDEO_PATH" \
      --output "$CACHE_DIR/${TEST_NAME}_poses.json"
    ;;
  analyze)
    echo "📊 Analyzing cached poses for $TEST_NAME..."
    cd "$CLI_DIR" && swift run MoveAICLI analyze "$TEST_NAME" \
      --cache-dir "$CACHE_DIR" \
      --results-dir "$RESULTS_DIR"
    ;;
  *)
    echo "Usage: $0 [extract|analyze] [test-case-name]"
    echo "  extract - Extract poses and cache them (slow, run once)"
    echo "  analyze - Analyze using cached poses (fast, for iteration)"
    echo ""
    echo "Examples:"
    echo "  $0 extract test_case_1"
    echo "  $0 analyze test_case_1"
    exit 1
    ;;
esac
