#!/usr/bin/env bash
# Find the latest Screenshots/latest/<timestamp> and extract PNGs from its xcresult.
# Usage: run from repo root (e.g. via .vscode task with cwd: ${workspaceFolder}).
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
LATEST_DIR="$(ls -t "$ROOT_DIR/Screenshots/latest/" 2>/dev/null | head -1)"
if [[ -z "$LATEST_DIR" ]]; then
  echo "No timestamp folder found in Screenshots/latest/ — nothing to extract."
  exit 0
fi
XCRESULT="$ROOT_DIR/Screenshots/latest/$LATEST_DIR/MoveAI_Screenshots.xcresult"
if [[ ! -d "$XCRESULT" ]]; then
  echo "No xcresult bundle at $XCRESULT — run Capture screenshots first."
  exit 0
fi
OUTPUT_DIR="$ROOT_DIR/Screenshots/latest/$LATEST_DIR"
if ! err=$(xcrun xcresulttool export attachments --path "$XCRESULT" --output-path "$OUTPUT_DIR" 2>&1); then
  echo "$err"
  echo "Extraction failed (xcresulttool issue). Check Xcode / PATH."
  exit 0
fi
COUNT=$(find "$OUTPUT_DIR" -maxdepth 1 -type f 2>/dev/null | wc -l | tr -d ' ')
echo "Exported $COUNT attachment(s) to $OUTPUT_DIR"
