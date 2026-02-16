# Phase 2 — Limb Highlighting on Pose Overlay

## Goal
When an issue is active (selected in the sheet or playhead near a feedback timestamp), the affected body joints glow **yellow/amber** (warning) or **red** (critical) instead of the default confidence-based coloring. Skeleton segments connecting highlighted joints also adopt the highlight color.

## Prerequisites
**Phase 0 must be complete.** This phase depends on:
- `affectedBodyJoints: [BodyJoint]` on `IssueOccurrence`
- `LimbHighlightState` typealias (`[BodyJoint: HighlightSeverity]`)
- `HighlightSeverity` enum (`.warning`, `.critical`)

## Context
### Current keypoint coloring (PoseOverlayView.swift, lines 89-109):
Keypoints are colored by confidence level:
- Telemetry style: cyan (>0.7), orange (0.4-0.7), red (<0.4)
- Standard style: green/yellow/red

### Current skeleton coloring (PoseOverlayView.swift, line 300-301):
All skeleton segments are uniform cyan (telemetry) or white (standard).

### Where PoseOverlayView is instantiated:
`VideoPlayerView.swift` creates `PoseOverlayView` in 3 places:
1. **Full-bleed mode** (line 196) — main video review screen
2. **Normal mode** (line 240) — scaled view
3. **`poseOverlay` computed property** (line 290) — legacy/fallback

All 3 pass the same parameters: `pose`, `previewSize`, `flipXAxis`, `isUploadedVideo`, `style`.

### Data flow for highlights:
```
SessionReviewViewModel.selectedIssueId
  → find matching IssueSummary
  → get IssueOccurrence nearest to current playback time
  → extract affectedBodyJoints + severity
  → produce LimbHighlightState dictionary
  → pass through VideoPlayerView → PoseOverlayView
```

## Changes Required

### 1. Add `currentLimbHighlights` to `SessionReviewViewModel`
**File**: `MoveAI/Features/Sessions/SessionReviewViewModel.swift`

Add a computed property after line 16:

```swift
/// Returns joint highlights for the current playback position based on the selected issue
/// or any issue occurring at the current time.
var currentLimbHighlights: LimbHighlightState {
    // Priority 1: Explicitly selected issue
    if let selectedIssueId,
       let issue = issues.first(where: { $0.id == selectedIssueId }) {
        // Find occurrence nearest to current playback time
        let nearestOcc = issue.occurrences.min(by: {
            abs($0.time - currentTime) < abs($1.time - currentTime)
        })
        if let occ = nearestOcc, abs(occ.time - currentTime) <= 1.0 {
            return buildHighlights(from: occ)
        }
    }

    // Priority 2: Any issue at current time (within tolerance)
    if let match = occurrence(at: currentTime, tolerance: 0.3) {
        return buildHighlights(from: match.occurrence)
    }

    return [:]
}

private func buildHighlights(from occurrence: IssueOccurrence) -> LimbHighlightState {
    var result: LimbHighlightState = [:]
    let severity: HighlightSeverity = (occurrence.severity == .critical) ? .critical : .warning
    for joint in occurrence.affectedBodyJoints {
        // Take the max severity if already present (from overlapping issues)
        if let existing = result[joint] {
            result[joint] = max(existing, severity)
        } else {
            result[joint] = severity
        }
    }
    return result
}
```

### 2. Add `limbHighlights` parameter to `PoseOverlayView`
**File**: `MoveAI/Features/Camera/PoseOverlayView.swift`

**Add parameter** to the struct (after line 15):
```swift
var limbHighlights: LimbHighlightState = [:]
```

**Update init** (line 20-26) to include the new parameter:
```swift
init(pose: PoseDetectionResult?, previewSize: CGSize, flipXAxis: Bool,
     isUploadedVideo: Bool = false, style: PoseOverlayStyle = .standard,
     limbHighlights: LimbHighlightState = [:]) {
    self.pose = pose
    self.previewSize = previewSize
    self.flipXAxis = flipXAxis
    self.isUploadedVideo = isUploadedVideo
    self.style = style
    self.limbHighlights = limbHighlights
}
```

**Update `keypointColor(for:)`** (lines 89-109):
```swift
private func keypointColor(for keypoint: PoseKeypoint) -> Color {
    // Check if this joint has an active highlight (issue-driven)
    if let jointEnum = BodyJoint(rawValue: keypoint.name),
       let severity = limbHighlights[jointEnum] {
        switch severity {
        case .warning:
            return Color(red: 1.0, green: 0.78, blue: 0.35) // Warm amber
        case .critical:
            return Color(red: 1.0, green: 0.42, blue: 0.42) // Red
        }
    }

    // Default: confidence-based coloring
    switch style {
    case .standard:
        if keypoint.confidence > 0.7 { return .green }
        else if keypoint.confidence > 0.4 { return .yellow }
        else { return .red }
    case .telemetry:
        if keypoint.confidence > 0.7 { return Color(red: 0.24, green: 0.86, blue: 1.0) }
        else if keypoint.confidence > 0.4 { return Color(red: 1.0, green: 0.78, blue: 0.35) }
        else { return Color(red: 1.0, green: 0.42, blue: 0.42) }
    }
}
```

### 3. Add `limbHighlights` to `SkeletonView` and color segments
**File**: `MoveAI/Features/Camera/PoseOverlayView.swift`

**Add parameter to `SkeletonView`** (after line 200):
```swift
var limbHighlights: LimbHighlightState = [:]
```

**Update `drawSkeleton` segment coloring** (around line 299-303):

Currently:
```swift
context.stroke(
    path,
    with: .color(style == .telemetry ? Color(red: 0.24, green: 0.86, blue: 1.0) : .white),
    lineWidth: style == .telemetry ? 2.6 : 2
)
```

Change to:
```swift
let segmentColor = skeletonSegmentColor(
    startJoint: startJoint,
    endJoint: endJoint
)
context.stroke(
    path,
    with: .color(segmentColor),
    lineWidth: style == .telemetry ? 2.6 : 2
)
```

Add helper method to `SkeletonView`:
```swift
private func skeletonSegmentColor(startJoint: String, endJoint: String) -> Color {
    let startEnum = BodyJoint(rawValue: startJoint)
    let endEnum = BodyJoint(rawValue: endJoint)

    // If either endpoint is highlighted, use the highest severity color
    let startSeverity = startEnum.flatMap { limbHighlights[$0] }
    let endSeverity = endEnum.flatMap { limbHighlights[$0] }

    let maxSeverity = [startSeverity, endSeverity].compactMap { $0 }.max()

    if let severity = maxSeverity {
        switch severity {
        case .warning:
            return Color(red: 1.0, green: 0.78, blue: 0.35) // Warm amber
        case .critical:
            return Color(red: 1.0, green: 0.42, blue: 0.42) // Red
        }
    }

    // Default color
    return style == .telemetry ? Color(red: 0.24, green: 0.86, blue: 1.0) : .white
}
```

**Pass `limbHighlights` through in PoseOverlayView body** (line 47-53):
```swift
SkeletonView(
    pose: pose,
    previewSize: previewSize == .zero ? geometry.size : previewSize,
    flipXAxis: flipXAxis,
    isUploadedVideo: isUploadedVideo,
    style: style,
    limbHighlights: limbHighlights
)
```

### 4. Thread `limbHighlights` through `VideoPlayerView`
**File**: `MoveAI/Features/Sessions/VideoPlayerView.swift`

Add a new parameter to `VideoPlayerView`:
```swift
var limbHighlights: LimbHighlightState = [:]
```

Pass it to all 3 `PoseOverlayView(...)` call sites (lines 196, 240, 290):
```swift
PoseOverlayView(
    pose: currentPose,
    previewSize: ...,
    flipXAxis: true,
    isUploadedVideo: !isRecordedLive,
    style: .telemetry,
    limbHighlights: limbHighlights
)
```

### 5. Pass highlights from `VideoReviewLayoutView`
**File**: `MoveAI/Features/Sessions/VideoReviewLayoutView.swift`

In `videoSection()` (line 217-230), pass the highlights:
```swift
return VideoPlayerView(
    videoURL: session.videoURL,
    poseData: session.poseData,
    isRecordedLive: session.isRecordedLive,
    analysisResult: current.analysisResult,
    constrainedHeight: constrainedHeight,
    maxVisibleHeightRatio: 1.0,
    seekToTime: $seekToTime,
    onFullScreenToggle: { sheetState = .collapsed },
    playback: playback,
    cueOverlay: visibleCueOverlay,
    cueTopPadding: cueTopPadding,
    isFullBleed: true,
    limbHighlights: reviewModel.currentLimbHighlights
)
```

## Colors Reference
| Severity | Color | RGB |
|----------|-------|-----|
| Warning (needsImprovement) | Warm amber | `(1.0, 0.78, 0.35)` |
| Critical (danger) | Red | `(1.0, 0.42, 0.42)` |
| Default telemetry | Cyan | `(0.24, 0.86, 1.0)` |

## Patterns to Follow
- Default parameter values (`= [:]`) so existing call sites don't break
- `BodyJoint(rawValue: keypoint.name)` for string-to-enum conversion (raw values match)
- Keep `PoseOverlayView` stateless — it receives highlights, doesn't compute them
- `HighlightSeverity: Comparable` means `max()` works for conflict resolution

## Tests to Write
**File**: `MoveAITests/LimbHighlightTests.swift` (NEW)

1. **testHighlightsEmptyWhenNoSelection**: No `selectedIssueId` and no nearby occurrences → `currentLimbHighlights` returns empty dict.
2. **testHighlightsFromSelectedIssue**: Set `selectedIssueId`, playback time near an occurrence → returns correct joints with correct severity.
3. **testHighlightsFromNearbyOccurrence**: No selection, but playback paused near a feedback timestamp → returns that feedback's joints.
4. **testHighlightsMergeMaxSeverity**: Two overlapping issues at same time with same joint but different severities → takes max.
5. **testHighlightsEmptyForLegacyFeedback**: `IssueOccurrence` with empty `affectedBodyJoints` → empty highlights.

## Done When
- [ ] `SessionReviewViewModel.currentLimbHighlights` returns correct `LimbHighlightState`
- [ ] `PoseOverlayView` accepts `limbHighlights` parameter
- [ ] Keypoints glow amber/red when their `BodyJoint` is in highlights
- [ ] Skeleton segments connecting highlighted joints adopt the highlight color
- [ ] Default behavior (no highlights) is unchanged — confidence-based coloring
- [ ] `VideoPlayerView` passes `limbHighlights` through to all 3 `PoseOverlayView` instances
- [ ] `VideoReviewLayoutView` passes `reviewModel.currentLimbHighlights` to `VideoPlayerView`
- [ ] All 5 unit tests pass
- [ ] `xcodebuild build` succeeds
- [ ] Existing tests pass
