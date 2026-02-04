#!/bin/bash
# Quick iteration: analyze, show summary, wait for changes
# Usage: ./scripts/iterate-solver.sh [test-case-name]

TEST_NAME=${1:-test_case_1}

echo "🔄 Solver Iteration Mode"
echo "========================="
echo "Watching for solver changes. Run analysis with: ./scripts/run-test.sh analyze $TEST_NAME"
echo "Press Ctrl+C to exit"
echo ""

# Run initial analysis
./scripts/run-test.sh analyze $TEST_NAME

# Show where results are saved
echo ""
echo "📁 Results saved to: MoveAITests/TestVideos/.results/${TEST_NAME}_summary.txt"
echo "📁 JSON results: MoveAITests/TestVideos/.results/${TEST_NAME}_results.json"
