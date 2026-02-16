# Phase 3 — Cue Escalation Logic

## Goal
Extract coaching cue display logic from `VideoReviewLayoutView` into a testable `CueController` class with:
- **Debounced pause cues**: Show after 400ms pause, only if not actively scrubbing
- **Immediate explicit cues**: Issue tap or marker tap shows cue instantly
- **Play clears**: Resuming playback always clears the cue
- **Scrub suppression**: If seeks happen faster than 400ms apart, suppress auto-cues
- **One cue at a time**: `activeCue` is a single optional, no stacking

## Context
Cue logic currently lives in `VideoReviewLayoutView` as scattered `@State` properties and a `schedulePausedCueCheck()` method. This is untestable and hard to reason about.

### Current cue-related code in VideoReviewLayoutView.swift:
- Line 29: `@State private var cueOverlay: CoachingCueOverlay?`
- Line 30: `@State private var pausedCueTask: Task<Void, Never>?`
- Lines 185-203: `onReceive(playback.$currentTime)` and `onReceive(playback.$isPlaying)` both call `schedulePausedCueCheck()` and handle `playback.isPlaying` clearing the cue
- Lines 359-381: `handleIssueSelection`, `handleOccurrenceSelection`, `handleMarkerTap` all set `cueOverlay` directly
- Lines 383-398: `schedulePausedCueCheck()` — cancels previous task, sleeps 300ms, checks if still paused and near a feedback occurrence
- Lines 400-407: `visibleCueOverlay` — gates cue visibility on `sheetState == .collapsed`

### Current data flow:
```
User taps issue → handleIssueSelection → cueOverlay = reviewModel.cueOverlay(for: issue)
User taps occurrence → handleOccurrenceSelection → cueOverlay = reviewModel.cueOverlay(for: issue, occurrence)
User taps marker → handleMarkerTap → cueOverlay = reviewModel.cueOverlay(for: issue, occurrence)
Playback pauses → schedulePausedCueCheck → 300ms → occurrence(at:) → cueOverlay = ...
Playback resumes → cueOverlay = nil
```

## Files to Create/Modify

### 1. Create `CueController.swift`
**File**: `MoveAI/Features/Sessions/CueController.swift` (NEW)

```swift
import Foundation

/// Controls coaching cue display with debouncing, scrub suppression, and conflict resolution.
/// Designed to be unit-testable without any view dependencies.
@MainActor
final class CueController: ObservableObject {
    @Published private(set) var activeCue: CoachingCueOverlay?

    private var debounceTask: Task<Void, Never>?
    private var lastSeekTime: Date = .distantPast

    /// Minimum time between seeks before auto-cues are suppressed.
    let scrubThreshold: TimeInterval = 0.4
    /// Delay before showing a pause-triggered cue.
    let pauseDelay: UInt64 = 400_000_000  // 400ms in nanoseconds

    // MARK: - Public API

    /// Called when playback seeks to a new time (scrubbing, timeline drag).
    /// Tracks seek frequency for scrub suppression.
    func onSeek(time: TimeInterval) {
        lastSeekTime = Date()
        // Cancel any pending auto-cue
        debounceTask?.cancel()
        debounceTask = nil
    }

    /// Called when playback pauses. After a delay, shows the nearest cue
    /// if the user hasn't been scrubbing rapidly.
    func onPause(
        at time: TimeInterval,
        issues: [IssueSummary],
        occurrenceFinder: (_ time: TimeInterval, _ tolerance: TimeInterval) -> (issue: IssueSummary, occurrence: IssueOccurrence)?,
        cueBuilder: (_ issue: IssueSummary, _ occurrence: IssueOccurrence) -> CoachingCueOverlay?
    ) {
        debounceTask?.cancel()

        debounceTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: self?.pauseDelay ?? 400_000_000)
            guard !Task.isCancelled else { return }
            guard let self else { return }

            // Suppress if user was scrubbing (last seek was recent)
            let timeSinceLastSeek = Date().timeIntervalSince(self.lastSeekTime)
            guard timeSinceLastSeek >= self.scrubThreshold else { return }

            if let match = occurrenceFinder(time, 0.2) {
                self.activeCue = cueBuilder(match.issue, match.occurrence)
            }
        }
    }

    /// Called when playback resumes. Always clears the cue immediately.
    func onPlay() {
        debounceTask?.cancel()
        debounceTask = nil
        activeCue = nil
    }

    /// Called when user explicitly taps an issue card. Shows cue immediately.
    func onIssueSelected(_ issue: IssueSummary, cue: CoachingCueOverlay?) {
        debounceTask?.cancel()
        debounceTask = nil
        activeCue = cue
    }

    /// Called when user explicitly taps an occurrence timestamp. Shows cue immediately.
    func onOccurrenceSelected(issue: IssueSummary, occurrence: IssueOccurrence, cue: CoachingCueOverlay?) {
        debounceTask?.cancel()
        debounceTask = nil
        activeCue = cue
    }

    /// Called when user taps a timeline marker. Shows cue immediately.
    func onMarkerTapped(issue: IssueSummary, occurrence: IssueOccurrence, cue: CoachingCueOverlay?) {
        debounceTask?.cancel()
        debounceTask = nil
        activeCue = cue
    }

    /// Clears the active cue without cancelling any pending tasks.
    func clearCue() {
        activeCue = nil
    }
}
```

**Design notes**:
- Uses closure parameters for `occurrenceFinder` and `cueBuilder` rather than holding a reference to `SessionReviewViewModel`. This avoids tight coupling and makes testing easier.
- `[weak self]` in the Task to avoid retain cycles.
- Explicit cue triggers (issue tap, marker tap) cancel any pending debounce and show immediately.
- `activeCue` is `private(set)` — only `CueController` can write it.

### 2. Modify `VideoReviewLayoutView.swift`
**File**: `MoveAI/Features/Sessions/VideoReviewLayoutView.swift`

**Remove**:
- Line 29: `@State private var cueOverlay: CoachingCueOverlay?`
- Line 30: `@State private var pausedCueTask: Task<Void, Never>?`
- Lines 383-398: `schedulePausedCueCheck()` method
- Lines 400-407: `visibleCueOverlay` computed property

**Add**:
- New `@StateObject`: `@StateObject private var cueController = CueController()`

**Update `onReceive(playback.$currentTime)`** (lines 185-192):
Current:
```swift
.onReceive(playback.$currentTime) { newTime in
    reviewModel.updatePlayback(
        currentTime: newTime,
        isPlaying: playback.isPlaying,
        fps: playback.nominalFrameRate
    )
    schedulePausedCueCheck()
}
```

Change to:
```swift
.onReceive(playback.$currentTime) { newTime in
    reviewModel.updatePlayback(
        currentTime: newTime,
        isPlaying: playback.isPlaying,
        fps: playback.nominalFrameRate
    )
    if !playback.isPlaying {
        cueController.onPause(
            at: newTime,
            issues: reviewModel.issues,
            occurrenceFinder: reviewModel.occurrence(at:tolerance:),
            cueBuilder: { issue, occ in reviewModel.cueOverlay(for: issue, occurrence: occ) }
        )
    }
}
```

**Update `onReceive(playback.$isPlaying)`** (lines 193-203):
Current:
```swift
.onReceive(playback.$isPlaying) { _ in
    reviewModel.updatePlayback(...)
    if playback.isPlaying {
        cueOverlay = nil
    }
    schedulePausedCueCheck()
}
```

Change to:
```swift
.onReceive(playback.$isPlaying) { playing in
    reviewModel.updatePlayback(
        currentTime: playback.currentTime,
        isPlaying: playing,
        fps: playback.nominalFrameRate
    )
    if playing {
        cueController.onPlay()
    } else {
        cueController.onPause(
            at: playback.currentTime,
            issues: reviewModel.issues,
            occurrenceFinder: reviewModel.occurrence(at:tolerance:),
            cueBuilder: { issue, occ in reviewModel.cueOverlay(for: issue, occurrence: occ) }
        )
    }
}
```

**Update `handleIssueSelection`** (lines 359-364):
```swift
private func handleIssueSelection(_ issue: IssueSummary) {
    let time = issue.worstOccurrence.time
    playback.performSeek(to: time)
    reviewModel.seek(to: time, fps: playback.nominalFrameRate)
    cueController.onIssueSelected(issue, cue: reviewModel.cueOverlay(for: issue))
}
```

**Update `handleOccurrenceSelection`** (lines 366-372):
```swift
private func handleOccurrenceSelection(issue: IssueSummary, occurrence: IssueOccurrence, fromExplicitTap: Bool) {
    playback.performSeek(to: occurrence.time)
    reviewModel.seek(to: occurrence.time, fps: playback.nominalFrameRate)
    if fromExplicitTap {
        cueController.onOccurrenceSelected(
            issue: issue,
            occurrence: occurrence,
            cue: reviewModel.cueOverlay(for: issue, occurrence: occurrence)
        )
    }
}
```

**Update `handleMarkerTap`** (lines 374-381):
```swift
private func handleMarkerTap(_ marker: VideoTimelineView.IssueMarker) {
    playback.performSeek(to: marker.timestamp)
    reviewModel.seek(to: marker.timestamp, fps: playback.nominalFrameRate)
    cueController.onSeek(time: marker.timestamp)
    if let match = reviewModel.occurrence(at: marker.timestamp, tolerance: 0.2) {
        reviewModel.selectOccurrence(match.occurrence, issueId: match.issue.id)
        cueController.onMarkerTapped(
            issue: match.issue,
            occurrence: match.occurrence,
            cue: reviewModel.cueOverlay(for: match.issue, occurrence: match.occurrence)
        )
    }
}
```

**Update `visibleCueOverlay`** — replace with:
```swift
private var visibleCueOverlay: CoachingCueOverlay? {
    switch sheetState {
    case .collapsed:
        return cueController.activeCue
    case .medium, .expanded:
        return nil
    }
}
```

**Update `videoSection`** (line 227): This already passes `visibleCueOverlay` — no change needed since we replaced the computed property.

### 3. Track seeks for scrub suppression
Anywhere in `VideoReviewLayoutView` where `playback.performSeek(to:)` is called, also call `cueController.onSeek(time:)` **before** the seek. This applies to:
- `handleIssueSelection` (already handled above — explicit trigger, no onSeek needed since it shows immediately)
- `handleOccurrenceSelection` (same — explicit trigger)
- `handleMarkerTap` (already added `onSeek` above)

For timeline scrubbing: if `PlaybackControlsBar` triggers seeks via its drag gesture, the `onReceive(playback.$currentTime)` will catch the rapid time changes. The `onPause` debounce + scrub threshold handles this case.

## Patterns to Follow
- `@StateObject` for `CueController` (it's owned by this view)
- Use `Task` cancellation pattern (cancel previous before creating new) — same as the current approach
- Keep the view-layer cue visibility gate (`visibleCueOverlay`) in the view, not in `CueController`
- `CueController` should have no view or SwiftUI dependencies (only Foundation)

## Tests to Write
**File**: `MoveAITests/CueControllerTests.swift` (NEW)

These tests exercise `CueController` in isolation using mock data.

```swift
@MainActor
final class CueControllerTests: XCTestCase {

    func testPlayClearsCue() async {
        let controller = CueController()
        let mockCue = CoachingCueOverlay(
            title: "Test", severity: .warning,
            cue: CoachingCue(type: .action, shortText: "Push knees out"),
            rationale: nil
        )
        // Simulate issue selection (sets cue immediately)
        controller.onIssueSelected(mockIssue(), cue: mockCue)
        XCTAssertNotNil(controller.activeCue)

        // Play clears
        controller.onPlay()
        XCTAssertNil(controller.activeCue)
    }

    func testExplicitSelectionShowsCueImmediately() {
        let controller = CueController()
        let mockCue = CoachingCueOverlay(...)
        controller.onIssueSelected(mockIssue(), cue: mockCue)
        XCTAssertNotNil(controller.activeCue)
        XCTAssertEqual(controller.activeCue?.title, "Test Issue")
    }

    func testRapidSeeksSuppressPauseCue() async {
        let controller = CueController()

        // Simulate rapid seeks (3 seeks in 200ms)
        controller.onSeek(time: 1.0)
        try? await Task.sleep(nanoseconds: 70_000_000) // 70ms
        controller.onSeek(time: 2.0)
        try? await Task.sleep(nanoseconds: 70_000_000)
        controller.onSeek(time: 3.0)

        // Now pause — scrub threshold not met (last seek was <400ms ago)
        controller.onPause(
            at: 3.0,
            issues: [],
            occurrenceFinder: { _, _ in /* return a match */ },
            cueBuilder: { _, _ in /* return a cue */ }
        )

        // Wait for debounce
        try? await Task.sleep(nanoseconds: 500_000_000) // 500ms

        // Cue should NOT have fired (scrub suppression)
        XCTAssertNil(controller.activeCue)
    }

    func testPauseCueFiresAfterDelay() async {
        let controller = CueController()
        let mockCue = CoachingCueOverlay(...)

        controller.onPause(
            at: 5.0,
            issues: [mockIssue()],
            occurrenceFinder: { time, tolerance in (mockIssue(), mockOccurrence()) },
            cueBuilder: { _, _ in mockCue }
        )

        // Before delay: no cue
        XCTAssertNil(controller.activeCue)

        // After delay: cue appears
        try? await Task.sleep(nanoseconds: 500_000_000) // 500ms > 400ms delay
        XCTAssertNotNil(controller.activeCue)
    }

    func testMarkerTapShowsCueImmediately() {
        let controller = CueController()
        let mockCue = CoachingCueOverlay(...)
        controller.onMarkerTapped(
            issue: mockIssue(),
            occurrence: mockOccurrence(),
            cue: mockCue
        )
        XCTAssertNotNil(controller.activeCue)
    }
}
```

Create helper methods `mockIssue()` and `mockOccurrence()` that return valid test fixtures.

## Done When
- [ ] `CueController.swift` exists with all 6 public methods
- [ ] `VideoReviewLayoutView` no longer has `cueOverlay` @State, `pausedCueTask`, or `schedulePausedCueCheck()`
- [ ] `VideoReviewLayoutView` uses `@StateObject private var cueController`
- [ ] All explicit cue triggers (issue, occurrence, marker) go through `CueController`
- [ ] Play always clears cue via `cueController.onPlay()`
- [ ] Pause triggers debounced cue via `cueController.onPause()`
- [ ] `visibleCueOverlay` reads from `cueController.activeCue`
- [ ] All unit tests pass
- [ ] `xcodebuild build` succeeds
- [ ] `xcodebuild test -scheme MoveAI -only-testing:MoveAITests` passes
