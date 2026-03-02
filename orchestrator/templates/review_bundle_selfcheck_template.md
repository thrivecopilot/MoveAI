# Review Bundle Self-Check — <TID> — <Short Title>

> Save as: `orchestrator/review/<TID>/selfcheck.md`
>
> Notes:
> - All sections are **required**. Use **N/A** if not applicable.
> - Be explicit over clever. Prefer edge-case handling.
> - Flag DRY violations aggressively (even if you don’t fix them).

## Metadata

- **TID**: `<TID>`
- **Title**: `<Short Title>`
- **Agent**: `<Codex/Cursor/etc>`
- **Worktree**: `<~/Developer/moveai-ios | ~/Developer/moveai-ml | ...>`
- **Branch**: `<branch>`
- **Baseline**: `origin/main` @ `<sha>`
- **Date**: `<YYYY-MM-DD>`

## Objective (in my words)

<Explain the objective concisely, in your own words.>

## Preflight questions + answers

### Blocking

- Q: …
  - A: …

### Non-blocking

- Q: …
  - Default chosen: …
  - A / rationale: …

## Assumptions (defaults chosen)

- …

## Approach chosen + alternatives considered

- **Approach**: …
- **Alternatives considered** (and why not): …
- **Deviations from suggested steps** (if any): …

## Change payload (required)

- Payload type (choose one):
  - [ ] `diff.patch` (default; staged changes; no commits)
  - [ ] `series.patch` (escape hatch; local commits allowed; no push)

If `series.patch`:
- Why escape hatch was needed:
  - …
- Commits included:
  ```
  git log origin/main..HEAD --oneline
  ```

## Files changed

<List every file modified/added/removed. Keep this list complete.>

## Architecture notes

Evaluate boundaries and coupling.

- Components touched (views / view models / services / analyzers): …
- Dependency changes (new imports, new protocols, new shared state): …
- Data flow changes (where data originates, transforms, and is consumed): …
- Potential bottlenecks / hot paths introduced or altered: …
- Single points of failure or new tight coupling introduced: …

## Code quality notes (DRY + engineered-enough)

- DRY audit (repetition spotted, recommended consolidation): …
- Under-engineered risks (fragile logic, implicit assumptions): …
- Over-engineered risks (premature abstraction, needless indirection): …
- Explicitness/readability improvements made (or deferred): …

## Error handling + edge cases

Be thorough and list both handled and unhandled cases.

- Edge cases handled: …
- Edge cases not handled (and why): …
- Failure modes (crash paths, nil data, out-of-range timestamps, empty sessions): …

## Security / privacy notes

- Data access changes (files, Photos, network, local persistence): …
- Logging/telemetry changes (any PII risk?): …
- API boundary changes (new surfaces that need validation?): …

## Test review (no-test-no-merge)

**Policy:** Each TID must include at least one new/updated automated test that would fail pre-change, or explicitly request a waiver.

### Tests added/updated

- `<TestFile.swift>`: `<testName>` — what it asserts

### Coverage gaps + why

- …

### Test waiver (rare; must be explicit)

If requesting a waiver:
- Why an automated test is not reasonable here:
  - …
- Compensating controls (manual checks, guardrails, follow-up task):
  - …

## Performance

- Hot-path reasoning (per-frame work, allocations, SwiftUI invalidations, draw cost): …
- Manual perf sanity scenario(s) run + results:
  - Scenario: …
  - Result: …

## Verification results

Paste real output summaries.

- `bash orchestrator/scripts/verify.sh <worktree>`:
  ```
  <paste PASS summary here>
  ```

## Deviations from suggested steps (if any) + rationale

- …

## Known issues / follow-ups

Include **file:line** references.

- `<path/to/file.swift>:123` — …

## Risk log (optional, but required if you found concerns)

For each issue, include concrete references + options.

### R-1: <Short label>

- **Location**: `<path/to/file.swift>:123`
- **Problem**: …

Options (recommended option first):
- **A (Recommended)**: …
  - Effort: <S/M/L>
  - Risk: <Low/Med/High>
  - Impact: …
  - Maintenance: …
- **B**: …
  - Effort: …
  - Risk: …
  - Impact: …
  - Maintenance: …
- **C (Do nothing)**: …
  - Effort: …
  - Risk: …
  - Impact: …
  - Maintenance: …
