# Squat Layout Refactor — Spec

## Problem

The analysis/video review screen has working bones but feels like a prototype, not a polished coaching tool:
- Collapsed sheet shows 20% of the screen (should be handle-only)
- Pose overlay colors by confidence, not by issue severity
- No mapping from detected issues to specific body joints
- Cue logic is simplistic (show on pause, hide on play) with no scrub suppression
- Video layout doesn't fully achieve the Photos/YouTube full-bleed feel

## Target UX

1. **Video**: Full-width, edge-to-edge between safe areas. Photos-like full-bleed media.
2. **Timeline**: Persistent playbar in bottom safe area with severity-colored feedback markers.
3. **Sheet**: 3 detents — collapsed (handle only, 36pt), minimal (score + rep summary), expanded (85-90% full detail). Tap handle to expand. Cannot dismiss.
4. **Limb Highlighting**: Selected issue highlights affected joints — yellow (warning), red (critical). Other joints remain confidence-based.
5. **Feedback Grouping**: Per-frame events aggregated into IssueSummary cards. Tap issue jumps to worst occurrence. Tap timestamp jumps to that time. (Already implemented.)
6. **Coaching Cues**: One at a time. Contextual triggers (issue tap, marker tap, pause near feedback). 400ms debounce. No cue spam during scrubbing.

## Success Criteria

- [ ] Collapsed sheet is ~36pt (handle only), not ~170pt
- [ ] Tapping handle when collapsed animates to medium
- [ ] `FormFeedback` carries `affectedBodyJoints` populated by `SquatAnalyzer`
- [ ] Pose overlay joints glow amber/red when an issue is active
- [ ] `CueController` passes unit tests for debounce, scrub suppression, and conflict resolution
- [ ] Legacy sessions (no joint data) render correctly with confidence-based fallback
- [ ] All existing unit and UI tests pass after each phase merge
- [ ] Screenshot pipeline shows no visual regressions

## Non-Goals

- No pixel-perfect screenshot comparison (structural/accessibility tests only)
- No new movement types (deadlift, bench press) — squat only
- No changes to the analysis pipeline itself (SquatAnalyzer logic stays the same)
- No TCA migration (staying with current vanilla SwiftUI + AppStore pattern)
- No landscape orientation support

## Architectural Decisions

See [full plan](../.claude/plans/eager-bouncing-hejlsberg.md) for the 5 locked decisions:
1. Joint mapping on `FormFeedback` (not a separate registry)
2. Highlight state computed by `SessionReviewViewModel`
3. `CueController` extracted from view layer
4. Collapsed height = absolute 36pt
5. Playbar stays in `.safeAreaInset(edge: .bottom)`
