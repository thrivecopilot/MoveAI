#!/bin/bash
# Extract poses from all test videos in MoveAITests/TestVideos/
# Skips videos that already have a cache file newer than the video.
# Run from project root.

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
CLI_DIR="$PROJECT_ROOT/Tools/MoveAICLI"
VIDEOS_DIR="$PROJECT_ROOT/MoveAITests/TestVideos"
CACHE_DIR="$VIDEOS_DIR/.cache"

mkdir -p "$CACHE_DIR"

for video in "$VIDEOS_DIR"/test_case_*.MOV "$VIDEOS_DIR"/test_case_*.mp4 "$VIDEOS_DIR"/test_case_*.mov; do
    [ -f "$video" ] || continue

    base=$(basename "$video" | sed 's/\.[^.]*$//')
    cache="$CACHE_DIR/${base}_poses.json"

    if [ -f "$cache" ] && [ "$cache" -nt "$video" ]; then
        echo "Skipping $base (cache is newer than video)"
        continue
    fi

    echo "Extracting poses from $base..."
    cd "$CLI_DIR" && swift run MoveAICLI extract "$video" --output "$cache"
done

echo "Done"
