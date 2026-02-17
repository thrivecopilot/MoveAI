# Orchestrator — Multi-Agent Coordination Hub

## Quick Reference

| Resource | Path |
|----------|------|
| **Taskboard** (live status) | [`taskboard.md`](taskboard.md) |
| **Spec** (what we're building) | [`spec.md`](spec.md) |
| **Decisions** (runtime journal) | [`decisions.md`](decisions.md) |
| **Review Checklist** | [`review_checklist.md`](review_checklist.md) |
| **Test Plan** | [`test_plan.md`](test_plan.md) |

## Worktree Layout

```
~/Developer/
  MoveAI/           main                  Source of truth
  moveai-lead/      orchestration/lead    Claude Code orchestrates here
  moveai-ios/       feat/squat-layout-ios UI, layout, view-layer work
  moveai-ml/        feat/squat-layout-ml  Model, data, analysis pipeline
  moveai-review/    review/squat-layout   Validation, testing, QA
```

## Phase → Worktree Mapping

| Phase | Spec | Worktree | Depends On |
|-------|------|----------|------------|
| 0 - Model Foundation | [`tasks/phase-0-model.md`](../tasks/phase-0-model.md) | moveai-ml | — |
| 1 - Sheet Detents | [`tasks/phase-1-layout.md`](../tasks/phase-1-layout.md) | moveai-ios | — |
| 2 - Limb Highlighting | [`tasks/phase-2-overlay.md`](../tasks/phase-2-overlay.md) | moveai-ml | Phase 0 |
| 3 - Cue Logic | [`tasks/phase-3-cue-logic.md`](../tasks/phase-3-cue-logic.md) | moveai-ios | Phase 1 |
| 4 - Video Polish | [`tasks/phase-4-video-polish.md`](../tasks/phase-4-video-polish.md) | moveai-ios | Phase 1 |

## Kick Off Batch 1

```bash
# In moveai-ml (Phase 0):
cd ~/Developer/moveai-ml
# Open in Codex/Cursor: "implement the spec in tasks/phase-0-model.md"

# In moveai-ios (Phase 1):
cd ~/Developer/moveai-ios
# Open in Codex/Cursor: "implement the spec in tasks/phase-1-layout.md"
```

## After a Phase Completes

1. Agent fills in self-check: [`templates/review_bundle_selfcheck_template.md`](templates/review_bundle_selfcheck_template.md)
2. Run verification: `bash orchestrator/scripts/verify.sh <worktree-path>`
3. Generate review bundle: `bash orchestrator/scripts/make_bundle.sh <worktree-path> <phase-name>`
4. Review in moveai-review, merge to main
5. Rebase other worktrees, update [`taskboard.md`](taskboard.md)
6. Start next phase

## Key Documents (outside this directory)

- [Architectural Plan](../.claude/plans/eager-bouncing-hejlsberg.md) — full 5-phase plan with locked decisions
- [Workflow Rules](../.cursor/rules/workflow-orchestration.mdc) — agent behavior rules
- [Lessons Learned](../tasks/lessons.md) — captured patterns from past mistakes
- [Project Conventions](../.cursorrules) — coding standards (TCA, SwiftUI, async/await)
