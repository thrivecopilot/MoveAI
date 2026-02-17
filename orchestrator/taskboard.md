# Taskboard — Live Execution Tracker

## Phase Status

| Phase | Worktree | Branch | Status | Started | Merged | Notes |
|-------|----------|--------|--------|---------|--------|-------|
| 0 - Model Foundation | moveai-ml | feat/squat-layout-ml | pending | — | — | Batch 1 |
| 1 - Sheet Detents | moveai-ios | feat/squat-layout-ios | pending | — | — | Batch 1 |
| 2 - Limb Highlighting | moveai-ml | feat/squat-layout-ml | blocked | — | — | Needs Phase 0 |
| 3 - Cue Logic | moveai-ios | feat/squat-layout-ios | blocked | — | — | Needs Phase 1 |
| 4 - Video Polish | moveai-ios | feat/squat-layout-ios | blocked | — | — | Needs Phase 1 |

## Batch 1 (current)

**Parallel work:**
- [ ] Phase 0 in moveai-ml
- [ ] Phase 1 in moveai-ios

**After both complete:**
- [ ] Merge feat/squat-layout-ml to main
- [ ] Merge feat/squat-layout-ios to main
- [ ] Validate integration in moveai-review
- [ ] Rebase both worktree branches onto main

## Batch 2 (after batch 1 merges)

- [ ] Phase 3 in moveai-ios (cue logic)
- [ ] Phase 2 in moveai-ml (limb highlighting)
- [ ] Merge and validate
- [ ] Phase 4 in moveai-ios (video polish)
- [ ] Final integration validation

## Blockers

_None currently._

## Integration Status

| Merge | Date | Commit | Tests | Notes |
|-------|------|--------|-------|-------|
| — | — | — | — | No merges yet |

## Next Actions

1. Kick off Phase 0 in moveai-ml
2. Kick off Phase 1 in moveai-ios
3. Monitor progress, review when agents report done
