# Muay Thai Warning Flow Plan (Handoff)

Date: 2026-03-17

## Goal
Improve Muay Thai warning quality for jab, cross, and roundhouse so warnings are accurate, actionable, and clearly surfaced in review UI.

## Current Focus
- Techniques: `jab`, `cross`, `roundhouse_kick`
- Prioritized warning outcomes:
  - `muay_thai.jab.rear_hand_dropping`
  - `muay_thai.jab.leaning_forward`
  - `muay_thai.jab.no_shoulder_protection`
  - `muay_thai.cross.no_hip_rotation`
  - `muay_thai.cross.overreaching`
  - `muay_thai.roundhouse_kick.no_hip_turnover`
  - `muay_thai.roundhouse_kick.no_arm_counterbalance`

## Detection Plan
1. Add Muay Thai preflight quality gating before form warnings:
   - Full-body visibility
   - Keypoint confidence stability
   - Sufficient motion
   - Stance confidence
2. If quality gate fails:
   - Surface capture-quality limitation feedback
   - Suppress form-warning generation for that clip
3. Add per-warning persistence/confidence gates:
   - Require warning signal across multiple frames, not single-frame spikes
4. Keep one event per `attempt + issue kind` to avoid duplicate noisy warnings.

## Content + UI Plan
1. Add a top-level "Detection Status" card in review/overview:
   - `Ready`, `Limited`, `Failed`
   - Show short reason for `Limited`/`Failed`
2. Keep top fixes focused on actionable form issues only.
3. Treat coverage/quality limitations as informational status, not primary top-fix warning.
4. Standardize warning card content:
   - What happened
   - Fix now
   - Why it matters
   - Suggested drill
5. Keep timeline marker and cue overlay flow:
   - Tap issue/marker -> seek to moment -> show cue overlay
   - Joint highlighting stays warning/critical color coded

## Filming Plan (Angles)
Use multiple angles for each clip for side-by-side reliability comparison.

### Angle Tags
1. `diag_rear`: 20-35 degrees off side from rear-hand side
2. `diag_lead`: 20-35 degrees off side from lead-hand side
3. `side`: true 90 degree profile
4. `diag_support`: 20-35 degrees off side from support-leg side (roundhouse priority)

### Clip Angle Matrix
| Clip ID | Primary | Secondary | Optional |
|---|---|---|---|
| `jab_clean_orthodox` | `diag_rear` | `side` | `diag_lead` |
| `jab_rear_hand_drop` | `diag_rear` | `side` | `diag_lead` |
| `jab_lean_forward` | `side` | `diag_rear` | `diag_lead` |
| `jab_no_shoulder_cover` | `diag_lead` | `side` | `diag_rear` |
| `cross_clean_orthodox` | `diag_rear` | `side` | `diag_lead` |
| `cross_arm_only` | `diag_rear` | `side` | `diag_lead` |
| `cross_overreach` | `side` | `diag_rear` | `diag_lead` |
| `roundhouse_clean_orthodox` | `diag_support` | `side` | opposite diagonal |
| `roundhouse_no_hip_turn` | `diag_support` | `side` | opposite diagonal |
| `roundhouse_static_arms` | `diag_support` | `side` | opposite diagonal |
| `mixed_jab_cross_clean` | `diag_rear` | `side` | `diag_lead` |
| `mixed_with_errors` | `diag_rear` | `side` | `diag_lead` |

Notes:
- For southpaw, mirror left/right interpretations.
- Keep full body in frame (head to feet), stable camera, consistent lighting, same distance/height across takes.

### Naming Convention
`<clip_id>__<stance>__<angle_tag>__take01.mov`

Example:
`jab_rear_hand_drop__orthodox__diag_rear__take01.mov`

## Test Fixture Expansion Plan
Update `MoveAITests/TestVideos/muay_thai_labeled_fixtures.json` with clean/error pairs for jab, cross, and roundhouse.

Add fixtures for:
- `jab_clean_orthodox`
- `jab_rear_hand_drop`
- `jab_lean_forward`
- `jab_no_shoulder_cover`
- `cross_clean_orthodox`
- `cross_arm_only`
- `cross_overreach`
- `roundhouse_clean_orthodox`
- `roundhouse_no_hip_turn`
- `roundhouse_static_arms`

Optional additional fixtures:
- `mixed_jab_cross_clean`
- `mixed_with_errors`
- quality-limited clips for gating validation

## Implementation Backlog (File-Level)
1. `MoveAI/Core/Services/PoseBasedAnalysisService.swift`
   - Add preflight quality gate for Muay Thai path
2. `MoveAI/Core/Services/MuayThaiIssueDetectors.swift`
   - Add persistence/confidence gating for warning emission
3. `MoveAI/Core/Services/MuayThaiAnalyzer.swift`
   - Add clearer detection-status/coverage messaging separation
4. `MoveAI/Core/Models/MovementIssueKind+MuayThai.swift`
   - Add Muay Thai quality-limited issue kind if needed
5. `MoveAI/Core/Models/MuayThaiIssueCatalog.swift`
   - Add catalog support text for quality-limited/coverage messaging
6. `MoveAI/Core/Services/AnalysisSummaryBuilder.swift`
   - Exclude non-actionable quality/coverage issues from warning totals
7. `MoveAI/Features/Sessions/OverviewTabView.swift`
   - Add Detection Status card and keep Top Fixes actionable
8. `MoveAI/Features/Sessions/IssueSummaryTabView.swift`
   - Improve human-readable Muay Thai metric labels/values
9. `MoveAI/Features/Sessions/MuayThaiCueLibrary.swift`
   - Tighten quick-fix/rationale/drill content
10. `MoveAITests/MuayThaiLabeledVideoRegressionTests.swift`
    - Add clean/error acceptance tests
11. `MoveAITests/TestVideos/muay_thai_labeled_fixtures.json`
    - Add new labeled fixtures

## Regression + Calibration Loop
1. Place new videos in `MoveAITests/TestVideos/`
2. Update fixture manifest with required/forbidden issue kinds
3. Extract pose cache:
   - `./scripts/muay-thai-regression.sh extract`
4. Run regression:
   - `./scripts/muay-thai-regression.sh analyze`
   - `./scripts/muay-thai-regression.sh analyze-debug` (for threshold tuning)
5. Tune thresholds until:
   - Clean clips avoid false warnings
   - Error clips trigger expected warning kinds

## Acceptance Criteria
1. Clean jab/cross/roundhouse clips produce zero prioritized warnings.
2. Intentional error clips produce expected required warning kind(s).
3. Quality-limited clips surface quality limitation and suppress misleading form warnings.
4. Top fixes in UI remain actionable and do not prioritize coverage-only notes.
5. Marker tap and cue overlay continue to align to correct timestamps.

