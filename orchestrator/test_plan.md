# Test Plan — Per-Phase Expectations

## Phase 0: Model Foundation

**Unit tests** (`MoveAITests/FormFeedbackCodableTests.swift`):
- Decode legacy JSON (no `affectedBodyJoints`) — field is nil, no crash
- Round-trip encode/decode with joints present — joints match
- `IssueSummaryBuilder.from()` propagates joints to `IssueOccurrence`
- `IssueSummaryBuilder.from()` handles nil joints (empty array fallback)

**Build gate**: `xcodebuild build` succeeds after adding `Codable` to `BodyJoint`

## Phase 1: Sheet Detent Tuning

**Unit tests** (`MoveAITests/SheetDetentTests.swift`):
- Collapsed height = ~36pt (not 20% of available)
- Medium height = max(300, available * 0.38)
- Expanded height = available * 0.88

**UI tests** (existing ScenarioRouter scenarios):
- `videoReviewOverviewCollapsed` — handle visible, content hidden
- `videoReviewOverviewMedium` — tab bar + score visible
- `videoReviewOverviewExpanded` — full content visible

**Manual**: Tap-to-expand gesture works from collapsed to medium

## Phase 2: Limb Highlighting

**Unit tests** (`MoveAITests/LimbHighlightTests.swift`):
- No selection + no nearby occurrence = empty highlights
- Selected issue with nearby occurrence = correct joints + severity
- Overlapping issues = max severity per joint
- Legacy occurrences (empty joints) = empty highlights

**Visual**: Select knee valgus issue — knee keypoints render red on overlay

## Phase 3: Cue Logic

**Unit tests** (`MoveAITests/CueControllerTests.swift`):
- `onPlay()` clears active cue
- `onIssueSelected()` shows cue immediately
- `onMarkerTapped()` shows cue immediately
- Rapid seeks (3 in 200ms) + pause = no cue (scrub suppression)
- Single pause near feedback = cue after 400ms delay

**UI test**: Scrub rapidly across markers — no cue flashing

## Phase 4: Video Polish

**Screenshot pipeline**: `bash scripts/capture_screenshots.sh`
- Collapsed: video fills nearly full screen
- No gaps between video and sheet
- Top bar gradient renders over video
- Playbar extends through bottom safe area

## Integration (after all phases)

**Full test suite**: `xcodebuild test -scheme MoveAI` — all pass
**Screenshot pipeline**: 21 screenshots, no regressions from baseline
**Structural tests**: `bash scripts/run_structural_tests.sh` — all pass
