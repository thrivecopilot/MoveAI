# Phase 1 — Sheet Detent Tuning

## Goal
Adjust the draggable analysis sheet so:
- **Collapsed** = handle only (~36pt), sitting directly above the playback bar
- **Medium** = score + rep summary visible (~38% of available height)
- **Expanded** = full content (~88% of available height)
- **Tap-to-expand**: tapping the handle when collapsed snaps to medium

## Context
The current collapsed state uses `sheetFraction: 0.20` which on a 852pt iPhone gives ~170pt — way too much for "handle only". The user wants collapsed to show just the drag handle (36pt) so the video fills nearly the entire screen (Photos-like).

The sheet is implemented as a custom `DraggableAnalysisSheet` (not system sheets). State is managed by `AnalysisSheetState` enum. Height calculations happen in `VideoReviewLayoutView.sheetHeight(for:availableHeight:)`.

## Files to Modify

### 1. Update `AnalysisSheetState.sheetFraction`
**File**: `MoveAI/Features/Sessions/DraggableAnalysisSheet.swift` (lines 22-28)

Current:
```swift
var sheetFraction: Double {
    switch self {
    case .collapsed: return 0.20
    case .medium:   return 0.50
    case .expanded: return 0.92
    }
}
```

Change to:
```swift
var sheetFraction: Double {
    switch self {
    case .collapsed: return 0.0  // Collapsed uses absolute height, not fraction
    case .medium:   return 0.38  // Tab bar + score + rep summary
    case .expanded: return 0.88  // Maps-style almost full screen
    }
}
```

Note: `.collapsed` fraction becomes 0.0 because the collapsed height is now driven by absolute `minCollapsedHeight`, not a fraction. This is handled in `sheetHeight()`.

### 2. Update `sheetHeight(for:availableHeight:)`
**File**: `MoveAI/Features/Sessions/VideoReviewLayoutView.swift` (lines 486-501)

Current:
```swift
private func sheetHeight(for state: AnalysisSheetState, availableHeight: CGFloat) -> CGFloat {
    let handleMinHeight = max(minCollapsedHeight, DragHandleMetrics.minCollapsedHeight)

    switch state {
    case .collapsed:
        return min(availableHeight * 0.95, handleMinHeight)
    case .medium:
        let minMedium: CGFloat = 300
        let baseHeight = availableHeight * state.sheetFraction
        return min(availableHeight * 0.95, max(minMedium, baseHeight))
    case .expanded:
        return availableHeight * 0.92
    }
}
```

Change to:
```swift
private func sheetHeight(for state: AnalysisSheetState, availableHeight: CGFloat) -> CGFloat {
    let handleMinHeight = max(minCollapsedHeight, DragHandleMetrics.minCollapsedHeight)

    switch state {
    case .collapsed:
        // Handle only — absolute height, not fraction-based
        return handleMinHeight
    case .medium:
        let minMedium: CGFloat = 300
        let baseHeight = availableHeight * state.sheetFraction
        return min(availableHeight * 0.95, max(minMedium, baseHeight))
    case .expanded:
        return availableHeight * state.sheetFraction
    }
}
```

Key changes:
- `.collapsed`: Returns `handleMinHeight` directly (36pt). Removed the `min(availableHeight * 0.95, ...)` wrapper — it was clamping to screen height which is unnecessary for a 36pt value.
- `.expanded`: Uses `state.sheetFraction` (0.88) instead of hardcoded 0.92 to keep the fraction as source of truth.

### 3. Add tap-to-expand gesture on drag handle
**File**: `MoveAI/Features/Sessions/DraggableAnalysisSheet.swift`

In the `dragHandle` view (lines 152-188), add an `onTapGesture` that expands to medium when collapsed:

After the `.accessibilityIdentifier(AccessibilityID.Tabs.dragHandle)` line (line 187), add:
```swift
.onTapGesture {
    if sheetState == .collapsed {
        withAnimation(.interactiveSpring()) {
            sheetState = .medium
        }
    }
}
```

**Important**: The `onTapGesture` must be placed BEFORE the parent's `DragGesture` in the view hierarchy. Since `dragHandle` is a child of the `VStack` that has the `DragGesture`, and SwiftUI gives priority to child gestures, this should work. But verify that tapping the handle doesn't also trigger the drag gesture's `onChanged`/`onEnded`.

### 4. Verify drag gesture `nearestDetent()` behavior
**File**: `MoveAI/Features/Sessions/DraggableAnalysisSheet.swift` (lines 236-241)

The `nearestDetent()` function finds the closest detent by height proximity. With collapsed at ~36pt and medium at ~300pt, there's a 264pt gap. The existing `predictedEndTranslation` in `onEnded` (line 135-136) accounts for flick velocity, so a fast upward flick from collapsed should predict a height near medium.

No code change needed, but **verify** with manual testing that:
- Slow drag up from collapsed: sheet follows finger, snaps to medium when past ~168pt (midpoint)
- Fast flick up from collapsed: predicted translation carries past medium threshold
- Slow drag down from medium: snaps back to medium or to collapsed depending on drag distance

### 5. Verify visual alignment
The collapsed handle should sit directly above the playback bar. In `VideoReviewLayoutView`, the sheet is in a `ZStack(alignment: .bottom)` (line 88), and the playback bar is placed via `.safeAreaInset(edge: .bottom)` (line 136). The sheet's bottom edge aligns with the content area's bottom edge (above the playback bar safe area inset). This should already be correct, but verify visually.

## Patterns to Follow
- Use `.interactiveSpring()` for all sheet state animations (matches existing pattern)
- Keep `DragHandleMetrics.minCollapsedHeight = 36` as the source of truth for collapsed height
- Don't change `DragHandleMetrics` values — they're already correct

## Tests to Write

### Unit test: `sheetHeight` calculations
**File**: `MoveAITests/SheetDetentTests.swift` (NEW)

```swift
func testCollapsedHeight() {
    // With minCollapsedHeight = 36 and available = 800
    // collapsed should return 36, not 160 (0.20 * 800)
    let height = sheetHeight(for: .collapsed, availableHeight: 800)
    XCTAssertEqual(height, 36, accuracy: 1)
}

func testMediumHeight() {
    // 800 * 0.38 = 304, which is > minMedium(300)
    let height = sheetHeight(for: .medium, availableHeight: 800)
    XCTAssertEqual(height, 304, accuracy: 1)
}

func testMediumHeightFloor() {
    // With small available height, medium should floor at 300
    let height = sheetHeight(for: .medium, availableHeight: 600)
    XCTAssertEqual(height, 300, accuracy: 1)
}

func testExpandedHeight() {
    let height = sheetHeight(for: .expanded, availableHeight: 800)
    XCTAssertEqual(height, 704, accuracy: 1) // 800 * 0.88
}
```

Note: `sheetHeight` is currently a `private` instance method on `VideoReviewLayoutView`. To unit test it, extract the calculation into a `static` or free function, or test it via the UI test layout probe.

**Alternative: UI test via layout probe** (preferred, avoids making private methods public):

Add a UI test in `MoveAIUITests/StructuralUITests.swift` or a new test file that:
1. Launches the scenario `videoReviewOverviewCollapsed`
2. Reads the `VideoReview.LayoutProbe` accessibility value (JSON)
3. Asserts that the sheet height matches the expected collapsed height (~36pt)

### UI test: detent states
Add ScenarioRouter scenarios if not already present for all 3 detent states:
- `videoReviewOverviewCollapsed` — verify handle-only visible
- `videoReviewOverviewMedium` — verify score + rep summary visible
- `videoReviewOverviewExpanded` — verify full content visible

These scenarios already exist in `ScenarioRouter.swift`. Run existing UI tests to verify no regressions.

## Done When
- [ ] Collapsed sheet height is ~36pt (handle only), not ~170pt
- [ ] Medium sheet shows score + rep summary at ~38% of available height
- [ ] Expanded sheet fills ~88% of available height
- [ ] Tapping the handle when collapsed animates to medium
- [ ] Drag gesture still works correctly for all state transitions
- [ ] Existing UI tests pass (`xcodebuild test -scheme MoveAI -only-testing:MoveAIUITests`)
- [ ] `xcodebuild build` succeeds
