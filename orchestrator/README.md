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

## Review & Merge Playbook

When agents report done, run this in a **short "Review & Merge" session**:

### 1. Generate review bundles (don't read raw diffs)
```bash
bash orchestrator/scripts/make_bundle.sh ~/Developer/moveai-ml phase-2-overlay
bash orchestrator/scripts/make_bundle.sh ~/Developer/moveai-ios phase-3-cue-logic
```

### 2. Trial-merge in moveai-review (keeps main clean)
```bash
cd ~/Developer/moveai-review
git reset --hard main
git merge feat/squat-layout-ml --no-ff -m "Trial: Phase 2"
git merge feat/squat-layout-ios --no-ff -m "Trial: Phase 3"
```

### 3. Verify the integration
```bash
bash orchestrator/scripts/verify.sh ~/Developer/moveai-review
```

### 4. If green → merge to main
```bash
cd ~/Developer/MoveAI
git merge feat/squat-layout-ml --no-ff -m "Merge Phase 2: ..."
git merge feat/squat-layout-ios --no-ff -m "Merge Phase 3: ..."
```

### 5. Sync all worktrees
```bash
for wt in moveai-ios moveai-ml moveai-lead moveai-review; do
  cd ~/Developer/$wt && git merge main --ff-only
done
```

### 6. Update taskboard
Mark completed phases, unblock next ones, update `orchestrator/taskboard.md`.

---

## Legacy: After a Phase Completes (simple version)

1. Agent fills in self-check: [`templates/review_bundle_selfcheck_template.md`](templates/review_bundle_selfcheck_template.md)
2. Run verification: `bash orchestrator/scripts/verify.sh <worktree-path>`
3. Generate review bundle: `bash orchestrator/scripts/make_bundle.sh <worktree-path> <phase-name>`
4. Trial-merge in moveai-review, verify, then merge to main
5. Fast-forward other worktrees, update [`taskboard.md`](taskboard.md)
6. Start next phase

## Key Documents (outside this directory)

- [Architectural Plan](../.claude/plans/eager-bouncing-hejlsberg.md) — full 5-phase plan with locked decisions
- [Workflow Rules](../.cursor/rules/workflow-orchestration.mdc) — agent behavior rules
- [Lessons Learned](../tasks/lessons.md) — captured patterns from past mistakes
- [Project Conventions](../.cursorrules) — coding standards (TCA, SwiftUI, async/await)
