# Squat Analysis UI Revamp — Spec

## Status / Baseline (source of truth)

- Baseline branch: `main`
- Baseline commit: `cb9436b` (2026-02-19) — “Enable analysis sheet tabs without auto-expansion”
- Phase 0 (Model foundation): ✅ merged (`810e7a9`)
- Phase 1 (Sheet + video layout): ✅ merged (`0aead2d`) + refined (`430dc72`)
- Next focus: **Batch 2** = Phase 2 (limb highlighting) + Phase 3 (cue logic refactor)

## Problem

The analysis/video review screen has working bones but still needs polish as a coaching tool:
- Pose overlay colors by confidence, not by issue severity
- No mapping from active issues to visible “what to fix” highlights on the skeleton
- Cue logic is simplistic (show on pause, hide on play) with no robust scrub suppression
- Need to preserve the Photos/YouTube “full-bleed” feel while adding coaching affordances

## Target UX

1. **Video**: Full-width, edge-to-edge between safe areas. Photos-like full-bleed media.
2. **Timeline**: Persistent playbar in bottom safe area with severity-colored feedback markers.
3. **Sheet**: 3 detents — collapsed (handle only, 36pt), minimal (score + rep summary), expanded (85–90% full detail). Tap handle to expand. Cannot dismiss.
4. **Limb Highlighting**: Active issue highlights affected joints — amber (warning), red (critical). Other joints remain confidence-based.
5. **Feedback Grouping**: Per-frame events aggregated into IssueSummary cards. Tap issue jumps to worst occurrence. Tap timestamp jumps to that time.
6. **Coaching Cues**: One at a time. Triggers (issue tap, marker tap, pause near feedback). 400ms debounce. No cue spam during scrubbing.

## Success Criteria (product)

- [x] Collapsed sheet is ~36pt (handle only), not ~170pt
- [x] Tapping handle when collapsed animates to medium
- [x] `FormFeedback` carries `affectedBodyJoints` populated by `SquatAnalyzer`
- [x] Legacy sessions (no joint data) render correctly with confidence-based fallback
- [ ] Pose overlay joints and skeleton segments glow amber/red when an issue is active
- [ ] Cue logic is extracted into a `CueController` and passes unit tests for debounce + scrub suppression
- [ ] `bash orchestrator/scripts/verify.sh` passes after each integration step
- [ ] Screenshot pipeline shows no visual regressions (optional gate; run if UI changes look risky)

## Non-Goals

- No pixel-perfect screenshot comparison (structural/accessibility tests only)
- No new movement types (deadlift, bench press) — squat only
- No changes to the analysis pipeline itself (SquatAnalyzer logic stays the same)
- No TCA migration (staying with current vanilla SwiftUI + AppStore pattern)
- No landscape orientation support

## Coordination Contract (process)

### Objective vs. suggested steps
- **Binding**: objective + success criteria in `orchestrator/taskboard.md` and this spec.
- **Suggested**: step-by-step implementation details in `tasks/phase-*.md` and in the taskboard. These are a recommended path, not a requirement.
- Alternatives are welcome if they:
  1) stay in-scope,
  2) keep diffs minimal,
  3) satisfy success criteria, and
  4) are documented in `selfcheck.md`.

### Questions are encouraged
Agents should ask **as many questions as needed** to fully understand the objective and UX intent.
- Prefer one “Preflight Questions” message that batches questions.
- Tag questions as **Blocking** vs **Non-blocking**.
- For **Non-blocking** questions, propose a default and proceed; document the assumption.

### Worker contract (moveai-ios / moveai-ml)
- Implement only assigned task(s) from `orchestrator/taskboard.md`.
- Run `bash orchestrator/scripts/verify.sh <worktree>` until PASS.
- Produce Review Bundle in `~/Developer/MoveAI/orchestrator/review/<TID>/`:
  - `selfcheck.md` (use the canonical template in `orchestrator/templates/`)
  - `verify.md` (manual scenarios + expected behavior)
  - Change payload (choose one):
    - **Default**: `diff.patch` (staged changes, no commits)
    - **Escape hatch**: `series.patch` (`git format-patch` output; local commits allowed)
- Escalate only if blocked after ~3 fix attempts; include failing output + hypothesis.

#### Default: `diff.patch` (no commits)
- Do **not** commit.
- Stage only intended files, then:
  - `git diff --cached --binary > ~/Developer/MoveAI/orchestrator/review/<TID>/diff.patch`

#### Escape hatch: `series.patch` (local commits allowed; no push)
Use only when the default staged diff patch is too painful (e.g., rename-heavy change, repeated apply conflicts, or you need incremental commits for review/debugging).
- Local commits are allowed, but:
  - Do not push
  - Do not merge
  - Keep commits small and scoped
- Generate:
  - `git format-patch origin/main..HEAD --stdout > ~/Developer/MoveAI/orchestrator/review/<TID>/series.patch`
- In `selfcheck.md`, include:
  - why escape hatch was needed
  - `git log origin/main..HEAD --oneline`

### Integrator contract (moveai-review)
- Apply bundles in the order listed in `orchestrator/taskboard.md`.
- Prefer applying `diff.patch` via `git apply --index --3way`.
- If a bundle provides `series.patch`, apply via `git am --3way`.
- Run `bash orchestrator/scripts/verify.sh ~/Developer/moveai-review` until PASS after each apply.
- Commit integration branch:
  - Prefer **one commit per TID**
  - If a `series.patch` contains multiple commits, either keep them (record SHAs) or squash into one TID commit (record final SHA).
- Update `orchestrator/taskboard.md` with evidence (commit SHA(s) + verify PASS).

## Architecture / Locked Decisions
See `orchestrator/decisions.md` (A1–A5).
