# Taskboard — Squat Analysis UI Revamp

## Baseline

- Target branch: `main`
- Baseline commit: `cb9436b` (2026-02-19)

## Completed (reference)

| Phase | Status | Evidence |
|------:|--------|----------|
| Phase 0 — Model Foundation | ✅ done | `810e7a9` |
| Phase 1 — Sheet + Video Layout | ✅ done | `0aead2d` (merged), `430dc72` (refined) |

## Active Tasks (Batch 2)

Notes:
- **Implementation steps are suggestions.** The **objective + success criteria are binding.**
- Agents may propose alternatives and should ask any questions needed to understand the goal.
- **Workers do not commit by default.** If needed, use the escape hatch (local commits + `series.patch`).
- **No-test-no-merge:** each TID must add/upgrade at least one automated test that would fail pre-change, or request an explicit waiver.
- **Perf note required:** each TID must document at least one manual performance sanity scenario + result in `selfcheck.md`.

| TID | Objective | Owner | Worktree | Status | Depends On |
|-----|-----------|-------|----------|--------|------------|
| T-201 | Cue logic → `CueController` + tests + scrub suppression | iOS Worker | `~/Developer/moveai-ios` | READY | Baseline `cb9436b` |
| T-202 | Pose overlay supports `limbHighlights` (render + plumbing; default empty) | ML Worker | `~/Developer/moveai-ml` | READY | Baseline `cb9436b` |
| T-203 | Compute + wire `currentLimbHighlights` into review layout + tests | iOS Worker | `~/Developer/moveai-ios` | BLOCKED | T-201 + T-202 integrated |

## Review Bundle (required output)

Each TID must produce a bundle directory:
- `~/Developer/MoveAI/orchestrator/review/<TID>/selfcheck.md`
  - Must follow: `orchestrator/templates/review_bundle_selfcheck_template.md`
- `~/Developer/MoveAI/orchestrator/review/<TID>/verify.md`
- Change payload (choose one):
  - `~/Developer/MoveAI/orchestrator/review/<TID>/diff.patch` (default; no commits)
  - `~/Developer/MoveAI/orchestrator/review/<TID>/series.patch` (escape hatch; `git format-patch` output)

### Test waiver (rare)
If a TID cannot reasonably add an automated test:
1. Worker: request a waiver in `selfcheck.md` (why + compensating controls).
2. Integrator: record the waiver + rationale in this taskboard when integrating.

### Patch creation recipe (worker)

#### Default payload: `diff.patch` (no commits)
1. Stage only intended files:
   - `git add <paths...>`
2. Create patch from staged changes:
   - `git diff --cached --binary > ~/Developer/MoveAI/orchestrator/review/<TID>/diff.patch`
3. **Do not stage** anything under `orchestrator/review/<TID>/`.

#### Escape hatch payload: `series.patch` (local commits allowed; no push)
Use only if necessary (rename-heavy changes, repeated `git apply` conflicts, or you need incremental commits).
1. Make local commits (no push, no merges).
2. Generate a format-patch series file:
   - `git format-patch origin/main..HEAD --stdout > ~/Developer/MoveAI/orchestrator/review/<TID>/series.patch`
3. In `selfcheck.md`, include:
   - why the escape hatch was needed
   - `git log origin/main..HEAD --oneline`

### `verify.md` required headings (worker)
- Manual scenarios run
- Expected behavior (what should the reviewer look for)
- Edge cases checked

## Task details + prompts

### T-201 — CueController refactor (Phase 3)

**Objective**
- Move cue behavior out of `VideoReviewLayoutView` into a testable controller with:
  - 400ms debounced pause cues
  - explicit taps show immediately
  - play clears cue
  - scrub suppression (no cue spam during rapid seeks)
  - one active cue at a time

**Suggested references (optional)**
- `tasks/phase-3-cue-logic.md` (suggested approach + test ideas)

**Verification**
- Automated:
  - Add/upgrade at least one automated test (no-test-no-merge).
  - `bash orchestrator/scripts/verify.sh ~/Developer/moveai-ios` → PASS
- Manual:
  - Pause near a marker → cue appears after ~0.4s
  - Scrub rapidly across markers then stop → no auto-cue pop
  - Tap issue/marker → cue appears immediately
  - Press play → cue clears
- Perf sanity:
  - Rapid scrub for ~30s across markers → no cue spam and no obvious jank

**Worker prompt (copy/paste)**
Work in `~/Developer/moveai-ios`.
- Sync to latest `origin/main` (baseline `cb9436b` or newer).
- Implement **T-201** only. Ask any preflight questions needed to understand the goal; propose alternatives if you think they’re better (document them).
- Use the canonical template for `selfcheck.md`: `orchestrator/templates/review_bundle_selfcheck_template.md`.
- Add/upgrade automated tests (required) or explicitly request a waiver in `selfcheck.md`.
- Document a manual perf sanity scenario + result in `selfcheck.md`.
- Do **not** commit (default). If you must use the escape hatch, document why and output `series.patch`.
- Run `bash ~/Developer/MoveAI/orchestrator/scripts/verify.sh ~/Developer/moveai-ios` until PASS.
- Output review bundle to `~/Developer/MoveAI/orchestrator/review/T-201/`.

---

### T-202 — Pose overlay highlight plumbing (Phase 2A)

**Objective**
- Add `limbHighlights: LimbHighlightState` support through:
  - `PoseOverlayView` (keypoints + skeleton segments)
  - `VideoPlayerView` (passes highlights to all overlay call sites)
- Default behavior remains unchanged when highlights are empty.

**Suggested references (optional)**
- `tasks/phase-2-overlay.md` (suggested approach)

**Verification**
- Automated:
  - Add/upgrade at least one automated test (no-test-no-merge).
  - `bash orchestrator/scripts/verify.sh ~/Developer/moveai-ml` → PASS
- Manual sanity:
  - With empty highlights, overlay coloring remains confidence-based; skeleton stroke remains default.
- Perf sanity:
  - Play + scrub while overlays render → no obvious stutter/regression

**Worker prompt (copy/paste)**
Work in `~/Developer/moveai-ml`.
- Sync to latest `origin/main` (baseline `cb9436b` or newer).
- Implement **T-202** only. Ask any preflight questions needed to understand the goal; propose alternatives if you think they’re better (document them).
- Use the canonical template for `selfcheck.md`: `orchestrator/templates/review_bundle_selfcheck_template.md`.
- Add/upgrade automated tests (required) or explicitly request a waiver in `selfcheck.md`.
- Document a manual perf sanity scenario + result in `selfcheck.md`.
- Do **not** commit (default). If you must use the escape hatch, document why and output `series.patch`.
- Run `bash ~/Developer/MoveAI/orchestrator/scripts/verify.sh ~/Developer/moveai-ml` until PASS.
- Output review bundle to `~/Developer/MoveAI/orchestrator/review/T-202/`.

---

### T-203 — Compute + wire current limb highlights (Phase 2B)

**Objective**
- Compute `currentLimbHighlights` in `SessionReviewViewModel` and wire it into `VideoReviewLayoutView` → `VideoPlayerView(limbHighlights: ...)`.
- Add unit tests for the highlight selection/merge logic.

**Suggested references (optional)**
- `tasks/phase-2-overlay.md` (selection/tolerance ideas)

**Verification**
- Automated:
  - Add/upgrade automated tests (required) covering selection/merge logic.
  - `bash orchestrator/scripts/verify.sh ~/Developer/moveai-ios` → PASS
- Manual:
  - Select an issue → its joints glow amber/red near the relevant timestamp
  - No selection → pausing near a feedback moment highlights affected joints
  - Far from any issue → no highlights
- Perf sanity:
  - Scrub across multiple issue occurrences → highlights update without obvious lag

**Worker prompt (copy/paste)**
Work in `~/Developer/moveai-ios` after T-201 and T-202 are integrated.
- Sync to latest `origin/main`.
- Implement **T-203** only (avoid unrelated refactors).
- Use the canonical template for `selfcheck.md`: `orchestrator/templates/review_bundle_selfcheck_template.md`.
- Add/upgrade automated tests (required) or explicitly request a waiver in `selfcheck.md`.
- Document a manual perf sanity scenario + result in `selfcheck.md`.
- Do **not** commit (default). If you must use the escape hatch, document why and output `series.patch`.
- Run `bash ~/Developer/MoveAI/orchestrator/scripts/verify.sh ~/Developer/moveai-ios` until PASS.
- Output review bundle to `~/Developer/MoveAI/orchestrator/review/T-203/`.

## Integration order (moveai-review)

1. Integrate T-201 and T-202 (either order; run `verify.sh` after each).
2. Once both are merged, start + integrate T-203.
