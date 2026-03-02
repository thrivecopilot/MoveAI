# Test Plan — Squat Analysis UI Revamp

## Standard gate (every task)
All tasks must pass:
- `bash orchestrator/scripts/verify.sh <worktree>` → PASS
  - Build
  - Unit tests
  - UI tests

## Policy: no-test-no-merge (with explicit waiver)

**Default:** every TID must include **at least one new/updated automated test** that would fail pre-change.

Acceptable “automated tests” include:
- Unit tests in `MoveAITests/*`
- UI tests in `MoveAIUITests/*` (including `StructuralUITests` / structured tests)

Not sufficient on its own:
- Manual-only `verify.md`
- “Verify.sh PASS” without any new/updated assertions covering the change

### Waiver (rare)
If a TID cannot reasonably add an automated test:
- Worker must explicitly request a waiver in `selfcheck.md` with:
  - why a test is not feasible
  - compensating controls (manual scenarios, guardrails)
  - suggested follow-up to restore coverage
- Integrator records the waiver + rationale in `orchestrator/taskboard.md` when integrating

## Baseline regression (already on main)
Spot-check (manual):
- Collapsed sheet is handle-only (~36pt)
- Tap handle from collapsed → medium
- Full-bleed video surface still looks correct
- No crashes loading legacy sessions without joint data

## T-202 — Pose overlay highlight plumbing
- Automated: `verify.sh` PASS + at least one new/updated automated test
- Manual:
  - With empty `limbHighlights`, keypoint colors remain confidence-based.
  - Skeleton strokes remain default (telemetry cyan / standard white).
- Perf sanity:
  - Play + scrub while overlay renders → no obvious stutter/regression

## T-201 — CueController refactor
- Unit tests (suggested): `MoveAITests/CueControllerTests.swift`
  - Play clears cue
  - Explicit issue/marker selection shows cue immediately
  - Debounced pause cue fires after ~400ms when stable
  - Rapid seeks suppress auto-cues
- Manual:
  - Pause near marker → cue after ~0.4s
  - Scrub rapidly → no cue flash/spam
  - Tap marker/issue → cue immediately
  - Play → cue clears
- Perf sanity:
  - Rapid scrub for ~30s → no cue spam and no obvious jank

## T-203 — Compute + wire current limb highlights
- Unit tests (suggested): `MoveAITests/LimbHighlightTests.swift`
  - No selection + no nearby occurrence → empty
  - Selected issue near time → correct joints + severity
  - Overlapping occurrences → max severity per joint
  - Empty joints (legacy) → empty
- Manual:
  - Select issue → joints glow amber/red
  - No selection → pause near feedback → highlights appear
  - Far from issues → no highlights
- Perf sanity:
  - Scrub across multiple occurrences → highlights update without obvious lag

## Integration verification (moveai-review)
After each patch apply:
- `bash orchestrator/scripts/verify.sh ~/Developer/moveai-review` → PASS

Optional (only if visuals look risky):
- `bash scripts/capture_screenshots.sh`
- `bash scripts/run_structural_tests.sh`
