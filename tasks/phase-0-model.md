# Phase 0 — Data Model Foundation

## Goal
Add `affectedBodyJoints` to `FormFeedback` so the pose overlay and cue systems can map issues to specific body segments. This is a data-layer-only change with zero UI impact.

## Context
- The pose overlay (`PoseOverlayView`) currently colors keypoints by confidence level (cyan/orange/red). We need issue-driven highlighting (yellow for warning, red for critical) on specific joints.
- `FormFeedback` (in `MovementRecording.swift`) has no joint references. The `SquatAnalyzer.generateFeedback()` method already knows which joints are involved per deviation type, but doesn't record that.
- `BodyJoint` enum (in `PoseKeypoint.swift`) has 24 keypoints matching Vision framework naming.
- `IssueSummaryBuilder` (in `SessionReviewViewModel.swift`) aggregates `FormFeedback` into `IssueSummary` with `IssueOccurrence` items, but currently discards joint info.

## Changes Required

### 1. Add `affectedBodyJoints` to `FormFeedback`
**File**: `MoveAI/Core/Models/MovementRecording.swift`

Add an optional `affectedBodyJoints: [BodyJoint]?` property to `FormFeedback`. It MUST be optional to preserve backward compatibility — existing persisted `Session` JSON files will not have this field.

Current `FormFeedback` (lines 47-63):
```swift
struct FormFeedback: Codable, Identifiable {
    let id: UUID
    let category: FeedbackCategory
    let message: String
    let severity: FeedbackSeverity
    let timestamp: TimeInterval
    let repNumber: Int?

    init(category: FeedbackCategory, message: String, severity: FeedbackSeverity, timestamp: TimeInterval, repNumber: Int? = nil) {
        self.id = UUID()
        self.category = category
        self.message = message
        self.severity = severity
        self.timestamp = timestamp
        self.repNumber = repNumber
    }
}
```

**Required changes**:
- Add `let affectedBodyJoints: [BodyJoint]?` property
- Add `affectedBodyJoints: [BodyJoint]? = nil` parameter to `init`
- `BodyJoint` is NOT currently `Codable`. You must add `Codable` conformance to `BodyJoint` in `PoseKeypoint.swift`. Since it's a `String` rawValue enum, this is free — just add `: Codable` to the enum declaration.
- Verify `FormFeedback`'s auto-synthesized `Decodable` handles the missing field gracefully via optional. If needed, add a custom `init(from decoder:)` using `decodeIfPresent`.

### 2. Create `LimbHighlightState.swift`
**File**: `MoveAI/Core/Models/LimbHighlightState.swift` (NEW)

```swift
import Foundation

/// Severity level for highlighted limbs on the pose overlay.
enum HighlightSeverity: Comparable {
    case warning   // Yellow/amber — needs improvement
    case critical  // Red — danger/critical issue
}

/// Maps body joints to their highlight severity for the current frame.
/// Empty dictionary = no highlights (confidence-based fallback).
typealias LimbHighlightState = [BodyJoint: HighlightSeverity]
```

### 3. Populate `affectedBodyJoints` in SquatAnalyzer
**File**: `MoveAI/Core/Services/SquatAnalyzer.swift`

In `generateFeedback()` (starting at line 1977), update each `FormFeedback(...)` constructor call to include `affectedBodyJoints`:

**Range of motion feedback** (lines 2048-2054, 2056-2063):
- "Incomplete range of motion" → `affectedBodyJoints: [.leftHip, .rightHip, .leftKnee, .rightKnee]`
- "Need to go deeper" → `affectedBodyJoints: [.leftHip, .rightHip, .leftKnee, .rightKnee]`

**Knee valgus feedback** (lines 2077-2083):
- "Knees caving inward" → `affectedBodyJoints: [.leftKnee, .rightKnee]`

**Individual deviation feedback** (lines 2172-2178):
Map `deviation.type` to joints:
```swift
let joints: [BodyJoint] = {
    switch deviation.type {
    case .torsoBias:       return [.leftShoulder, .rightShoulder, .leftHip, .rightHip]
    case .torsoInstability: return [.leftShoulder, .rightShoulder, .leftHip, .rightHip]
    case .hipShoot:        return [.leftHip, .rightHip, .leftKnee, .rightKnee]
    case .balanceDrift:    return [.leftAnkle, .rightAnkle]
    }
}()
```
Then pass `affectedBodyJoints: joints` in the `FormFeedback(...)` call.

### 4. Propagate joints through `IssueOccurrence`
**File**: `MoveAI/Features/Sessions/SessionReviewModels.swift`

Add `affectedBodyJoints: [BodyJoint]` to `IssueOccurrence` (line 23-27):

Current:
```swift
struct IssueOccurrence: Identifiable {
    let id: UUID
    let time: TimeInterval
    let severity: FeedbackSeverity
}
```

Change to:
```swift
struct IssueOccurrence: Identifiable {
    let id: UUID
    let time: TimeInterval
    let severity: FeedbackSeverity
    let affectedBodyJoints: [BodyJoint]
}
```

### 5. Update `IssueSummaryBuilder` to propagate joints
**File**: `MoveAI/Features/Sessions/SessionReviewViewModel.swift`

In `IssueSummaryBuilder.from()` (line 115-116), the `IssueOccurrence` mapping currently is:
```swift
let occurrences = items.map {
    IssueOccurrence(id: $0.id, time: $0.timestamp, severity: $0.severity)
}
```

Change to:
```swift
let occurrences = items.map {
    IssueOccurrence(
        id: $0.id,
        time: $0.timestamp,
        severity: $0.severity,
        affectedBodyJoints: $0.affectedBodyJoints ?? []
    )
}
```

## Patterns to Follow
- All model types in this codebase use `let` properties (immutable structs)
- Optional parameters default to `nil` in `init`
- Keep changes minimal — don't restructure existing code
- Maintain Codable conformance for all persisted types

## Tests to Write
**File**: `MoveAITests/FormFeedbackCodableTests.swift` (NEW)

1. **testDecodeLegacyJSON**: Create a JSON string without `affectedBodyJoints`, decode it into `FormFeedback`, assert the field is `nil`.
2. **testRoundTripWithJoints**: Create a `FormFeedback` with `affectedBodyJoints: [.leftKnee, .rightKnee]`, encode to JSON, decode back, verify joints match.
3. **testIssueSummaryBuilderPropagatesJoints**: Create `FormFeedback` items with `affectedBodyJoints`, run through `IssueSummaryBuilder.from()`, verify the resulting `IssueOccurrence` items carry the joints.
4. **testIssueSummaryBuilderHandlesNilJoints**: Create `FormFeedback` items WITHOUT `affectedBodyJoints`, verify `IssueSummaryBuilder.from()` produces `IssueOccurrence` items with empty `affectedBodyJoints`.

## Done When
- [ ] `BodyJoint` conforms to `Codable`
- [ ] `FormFeedback` has `affectedBodyJoints: [BodyJoint]?` with backward-compatible decoding
- [ ] `LimbHighlightState.swift` exists with `HighlightSeverity` and typealias
- [ ] `SquatAnalyzer.generateFeedback()` populates `affectedBodyJoints` for all feedback types
- [ ] `IssueOccurrence` has `affectedBodyJoints: [BodyJoint]`
- [ ] `IssueSummaryBuilder.from()` propagates joints
- [ ] All 4 unit tests pass
- [ ] `xcodebuild build` succeeds (no compilation errors)
- [ ] `xcodebuild test -scheme MoveAI -only-testing:MoveAITests` passes
