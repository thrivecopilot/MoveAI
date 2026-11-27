#!/usr/bin/env bash
#
# Swift ↔ JS golden parity check for the web movement analyzer
# (P0.6 in MOVEAI_WEB_TODO.md).
#
# Usage:
#   bash scripts/web-parity.sh [case-name] [--refresh]
#
#   case-name   defaults to test_case_1
#   --refresh   re-run the Swift CLI analyze step before comparing
#               (extract is only run if the pose cache is missing)
#
# Exports the Swift pose cache + analyzer results as fixtures into the prehab
# web prototype, then runs its jsc-based parity driver. Override the prehab
# checkout location with PREHAB_DIR.

set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PREHAB="${PREHAB_DIR:-$HOME/Developer/prehab}"
PARITY="$PREHAB/prototype/move-analyzer/tests/parity"
CASE="${1:-test_case_1}"
REFRESH="${2:-}"

CACHE="$ROOT/MoveAITests/TestVideos/.cache/${CASE}_poses.json"
RESULTS="$ROOT/MoveAITests/TestVideos/.results/${CASE}_results.json"

if [[ ! -d "$PARITY" ]]; then
  echo "error: parity harness not found at $PARITY (set PREHAB_DIR?)" >&2
  exit 1
fi

if [[ ! -f "$CACHE" ]]; then
  echo "[web-parity] pose cache missing; extracting (slow, one-time)..."
  bash "$ROOT/scripts/run-test.sh" extract "$CASE"
fi

if [[ "$REFRESH" == "--refresh" || ! -f "$RESULTS" ]]; then
  echo "[web-parity] running Swift analyzer for golden results..."
  bash "$ROOT/scripts/run-test.sh" analyze "$CASE"
fi

mkdir -p "$PARITY/fixtures"
cp "$CACHE" "$PARITY/fixtures/${CASE}_poses.json"
cp "$RESULTS" "$PARITY/fixtures/${CASE}_expected.json"
echo "[web-parity] fixtures exported to $PARITY/fixtures"

bash "$PARITY/run-parity.sh" "$CASE"
