# Review Checklist (Patch-Based Workflow)

Use this checklist when reviewing a worker Review Bundle and when integrating in `moveai-review`.

## 1) Bundle completeness (required)
- [ ] Bundle directory exists: `orchestrator/review/<TID>/`
- [ ] `selfcheck.md` exists and follows the canonical template:
  - `orchestrator/templates/review_bundle_selfcheck_template.md`
- [ ] `verify.md` exists with manual scenarios + expected behavior
- [ ] Change payload exists:
  - [ ] `diff.patch` (default) **or**
  - [ ] `series.patch` (escape hatch)
- [ ] If `series.patch` is used:
  - [ ] `selfcheck.md` explains why (escape hatch justification)
  - [ ] `selfcheck.md` includes `git log origin/main..HEAD --oneline`

## 2) Architecture + quality review (required)
- [ ] Architecture boundaries/coupling changes are described
- [ ] DRY audit is present (repetition flagged; consolidation suggested)
- [ ] Under-/over-engineering risks are called out explicitly
- [ ] Error handling + edge cases are enumerated (handled + unhandled)
- [ ] Security/privacy notes are present (even if “N/A”)

## 3) Tests (no-test-no-merge)
- [ ] At least one new/updated automated test exists that would fail pre-change **or** a waiver is requested
- [ ] If a waiver is requested:
  - [ ] `selfcheck.md` includes waiver rationale + compensating controls
  - [ ] Integrator records the waiver in `orchestrator/taskboard.md` during integration
- [ ] Tests cover meaningful edge cases (not just the happy path)

## 4) Performance (lightweight gate)
- [ ] `selfcheck.md` includes hot-path reasoning (where perf could regress)
- [ ] `selfcheck.md` includes at least one manual perf sanity scenario + result

## 5) Patch hygiene (required)
- [ ] Patch applies cleanly (or conflicts are small/understood)
- [ ] Patch excludes junk/editor files:
  - `.DS_Store`
  - `*.xcuserstate`
  - `*.xcuserdata/`
  - `.vscode/`, `.cursor/`
  - `Reports/` (unless explicitly required)
- [ ] Diff is tightly scoped to the assigned TID (no drive-by refactors)

## 6) Verification (required)
- [ ] Worker ran `bash orchestrator/scripts/verify.sh <worktree>` until PASS
- [ ] Integrator reran `bash orchestrator/scripts/verify.sh ~/Developer/moveai-review` until PASS after apply
- [ ] No new warnings introduced (call out any)

## 7) Behavioral / UX checks (task-specific)
- [ ] Cue behavior: pause delay, scrub suppression, play clears, explicit taps immediate
- [ ] Limb highlights: correct joints light up; default confidence-based rendering unchanged when empty

## 8) Taskboard + evidence (required)
- [ ] `orchestrator/taskboard.md` updated with:
  - TID status
  - integrated commit SHA(s)
  - verification PASS evidence
  - waiver (if used) + rationale
