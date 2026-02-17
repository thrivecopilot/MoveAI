# Post-Merge Integration Checklist

Use this checklist in `moveai-review` after merging a phase branch to main.

## Build

- [ ] `xcodebuild build -scheme MoveAI -destination 'platform=iOS Simulator,id=B512B7D6-8471-4F50-98D4-EF0932937865'` succeeds
- [ ] No new warnings introduced

## Unit Tests

- [ ] `xcodebuild test -scheme MoveAI -only-testing:MoveAITests -destination 'platform=iOS Simulator,id=B512B7D6-8471-4F50-98D4-EF0932937865'` — all pass
- [ ] New tests written for this phase all pass
- [ ] Existing tests not broken

## UI Tests

- [ ] `xcodebuild test -scheme MoveAI -only-testing:MoveAIUITests -destination 'platform=iOS Simulator,id=B512B7D6-8471-4F50-98D4-EF0932937865'` — all pass
- [ ] Structural snapshot baselines still valid (or intentionally updated)

## Visual Validation

- [ ] `bash scripts/capture_screenshots.sh` — no visual regressions
- [ ] Collapsed state looks correct (handle only above playbar)
- [ ] Medium state shows score + rep summary
- [ ] Expanded state shows full content

## Code Quality

- [ ] Accessibility identifiers present on new/modified elements
- [ ] No hardcoded magic numbers (use constants from DesignSystem or metrics enums)
- [ ] Codable backward compatibility verified (old JSON decodes without crash)
- [ ] No merge conflicts in shared files (especially `VideoReviewLayoutView.swift`)

## Integration

- [ ] Phase's "done when" checklist fully satisfied (from task spec)
- [ ] Agent self-check bundle reviewed (in `orchestrator/review/`)
- [ ] Trajectory logged (in `orchestrator/trajectories/`)
- [ ] Taskboard updated with merge status
