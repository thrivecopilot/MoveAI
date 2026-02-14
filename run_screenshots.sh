#!/usr/bin/env bash
# Wrapper so agents can run screenshot capture from repo root.
# Usage: from repo root, run: bash run_screenshots.sh
# Requires: full repo (scripts/, MoveAI/) visible in run context.
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
exec bash "$ROOT/scripts/capture_screenshots.sh"
