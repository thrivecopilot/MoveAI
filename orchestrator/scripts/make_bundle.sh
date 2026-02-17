#!/bin/bash
# orchestrator/scripts/make_bundle.sh
#
# Packages a phase's changes into a review bundle for the orchestrator.
# Usage: bash orchestrator/scripts/make_bundle.sh [worktree-path] [phase-name]
#
# Examples:
#   bash orchestrator/scripts/make_bundle.sh ~/Developer/moveai-ml phase-0-model
#   bash orchestrator/scripts/make_bundle.sh ~/Developer/moveai-ios phase-1-layout

set -euo pipefail

WORKTREE="${1:-.}"
PHASE_NAME="${2:-unknown}"
WORKTREE=$(cd "$WORKTREE" && pwd)

ORCHESTRATOR_DIR="$WORKTREE/orchestrator"
REVIEW_DIR="$ORCHESTRATOR_DIR/review"
BUNDLE_FILE="$REVIEW_DIR/${PHASE_NAME}-bundle.md"
TEMPLATE="$ORCHESTRATOR_DIR/templates/review_bundle_selfcheck_template.md"

echo "========================================"
echo "  Make Review Bundle"
echo "  Worktree: $WORKTREE"
echo "  Phase: $PHASE_NAME"
echo "  Output: $BUNDLE_FILE"
echo "========================================"
echo ""

mkdir -p "$REVIEW_DIR" 2>/dev/null || true

# Start the bundle
{
    echo "# Review Bundle: $PHASE_NAME"
    echo ""
    echo "Generated: $(date '+%Y-%m-%d %H:%M')"
    echo "Worktree: $WORKTREE"
    echo "Branch: $(cd "$WORKTREE" && git branch --show-current)"
    echo ""

    echo "---"
    echo ""
    echo "## Commits (since main)"
    echo ""
    echo '```'
    cd "$WORKTREE" && git log main..HEAD --oneline 2>/dev/null || echo "(no commits ahead of main)"
    echo '```'
    echo ""

    echo "## Files Changed (since main)"
    echo ""
    echo '```'
    cd "$WORKTREE" && git diff main --stat 2>/dev/null || echo "(no diff from main)"
    echo '```'
    echo ""

    echo "## Diff Summary"
    echo ""
    echo '```'
    cd "$WORKTREE" && git diff main --shortstat 2>/dev/null || echo "(no changes)"
    echo '```'
    echo ""

    echo "---"
    echo ""
    echo "## Self-Check (fill in below)"
    echo ""

    # Append the self-check template
    if [ -f "$TEMPLATE" ]; then
        cat "$TEMPLATE"
    else
        echo "(template not found at $TEMPLATE)"
        echo ""
        echo "## Files Changed"
        echo "## Tests Written"
        echo "## Tests Passing"
        echo "## Build Status"
        echo "## Done When Checklist"
        echo "## Known Issues"
        echo "## Merge Readiness: YES / NO"
    fi

} > "$BUNDLE_FILE"

echo "Bundle written to: $BUNDLE_FILE"
echo ""
echo "Next steps:"
echo "  1. Agent fills in the Self-Check section"
echo "  2. Run: bash orchestrator/scripts/verify.sh $WORKTREE"
echo "  3. Review in moveai-review, merge to main"
