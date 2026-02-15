#!/usr/bin/env bash
#
# run_structural_tests.sh — Run the StructuralUITests suite and produce a compact report.
#
# Usage:
#   bash scripts/run_structural_tests.sh [--record-snapshots]
#
# Outputs:
#   test-results/structural/xcodebuild.log    Full xcodebuild output
#   test-results/structural/failures.txt      One-line-per-failure summary
#   test-results/structural/summary.json      Machine-readable pass/fail counts
#   test-results/structural/snapshots/        JSON snapshot files (copied from /tmp)
#
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

# Resolve simulator
SIM_ID="B512B7D6-8471-4F50-98D4-EF0932937865"

# Output directory
OUT_DIR="$PROJECT_DIR/test-results/structural"
rm -rf "$OUT_DIR"
mkdir -p "$OUT_DIR"

# Handle --record-snapshots: clear existing references so tests record fresh ones
if [[ "${1:-}" == "--record-snapshots" ]]; then
    echo "🗑️  Clearing snapshot references for re-recording..."
    rm -rf /tmp/MoveAI_Snapshots
fi

echo "🧪 Running StructuralUITests..."
echo "   Simulator: $SIM_ID"
echo "   Output:    $OUT_DIR"
echo ""

set +e
xcodebuild test \
    -scheme MoveAI \
    -destination "platform=iOS Simulator,id=$SIM_ID" \
    -only-testing:MoveAIUITests/StructuralUITests \
    CODE_SIGNING_ALLOWED=NO \
    2>&1 | tee "$OUT_DIR/xcodebuild.log"
EXIT_CODE=${PIPESTATUS[0]}
set -e

# Extract failures
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

PASSED=$(grep -c "passed on" "$OUT_DIR/xcodebuild.log" || true)
FAILED=$(grep -c "failed on" "$OUT_DIR/xcodebuild.log" || true)
TOTAL=$((PASSED + FAILED))

echo "Results: $PASSED/$TOTAL passed, $FAILED failed"
echo ""

# One-line failure summary
grep "failed on" "$OUT_DIR/xcodebuild.log" | sed 's/^.*Test case //' | sed "s/' .*//" > "$OUT_DIR/failures.txt" || true

if [[ -s "$OUT_DIR/failures.txt" ]]; then
    echo "❌ Failures:"
    cat "$OUT_DIR/failures.txt"
else
    echo "✅ All tests passed!"
fi

# Machine-readable summary
cat > "$OUT_DIR/summary.json" <<EOF
{
  "suite": "StructuralUITests",
  "total": $TOTAL,
  "passed": $PASSED,
  "failed": $FAILED,
  "exitCode": $EXIT_CODE
}
EOF

# Copy snapshots
if [[ -d /tmp/MoveAI_Snapshots ]]; then
    cp -r /tmp/MoveAI_Snapshots "$OUT_DIR/snapshots"
    echo ""
    echo "📸 Snapshots copied to $OUT_DIR/snapshots/"
    ls "$OUT_DIR/snapshots/"
fi

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
exit $EXIT_CODE
