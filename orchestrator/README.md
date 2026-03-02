# Orchestrator — Multi-Agent Coordination Hub

This folder is the coordination “source of truth” for multi-agent work on MoveAI.

## Quick Reference

| Resource | Path | Purpose |
|----------|------|---------|
| Taskboard | [`taskboard.md`](taskboard.md) | Live TIDs, objectives, owners, status |
| Spec | [`spec.md`](spec.md) | Product intent + success criteria |
| Decisions | [`decisions.md`](decisions.md) | Locked + runtime decisions |
| Review checklist | [`review_checklist.md`](review_checklist.md) | What a Review Bundle must contain |
| Integration checklist | [`integration_checklist.md`](integration_checklist.md) | How to apply bundles + verify + commit |
| Test plan | [`test_plan.md`](test_plan.md) | Verification gates + scenarios |
| Templates | [`templates/`](templates/) | Bundle templates and trajectories |

## Current Workflow (Patch Bundles)

**Workers** (in `~/Developer/moveai-ios` / `~/Developer/moveai-ml`):
1. Implement only the assigned TID from the taskboard.
2. Run `bash orchestrator/scripts/verify.sh <worktree>` until PASS.
3. Produce a Review Bundle: `orchestrator/review/<TID>/`
   - `selfcheck.md` (use the canonical template in `templates/`)
   - `verify.md` (manual scenarios + expected behavior)
   - payload (choose one):
     - `diff.patch` (default; staged changes; no commits)
     - `series.patch` (escape hatch; local commits allowed; no push)

**Integrator** (in `~/Developer/moveai-review`):
1. Apply bundles in taskboard order.
2. Run `bash orchestrator/scripts/verify.sh ~/Developer/moveai-review` until PASS after each apply.
3. Commit the integration branch (prefer 1 commit per TID).
4. Update the taskboard with evidence (commit SHA(s) + verify PASS).

Canonical step-by-step:
- [`review_checklist.md`](review_checklist.md)
- [`integration_checklist.md`](integration_checklist.md)

## Worktree Layout

```
~/Developer/
  MoveAI/           main                Source of truth (promoted by integrator)
  moveai-ios/       iOS worker          SwiftUI / app layer tasks
  moveai-ml/        ML worker           analysis/model/data tasks
  moveai-review/    Integrator          applies bundles + runs verify.sh + commits
  moveai-lead/      Lead (optional)     planning + coordination
```

## Notes

- Implementation steps in task docs are **suggestions**; objectives + success criteria are **binding**.
- If instructions conflict, treat `taskboard.md` + the checklists as authoritative.

## Legacy

Previous merge-based playbooks were removed from this README to avoid drift.
If you need to reference old commands, use git history for this file.
