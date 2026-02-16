# Phase 4 — Video Layout Polish

## Goal
Verify and refine the Photos-like full-bleed video layout now that the sheet detent heights have changed (Phase 1). With collapsed at 36pt, the video should fill nearly the entire screen. Confirm edge-to-edge rendering, safe area behavior, and playback bar positioning.

## Prerequisites
**Phase 1 must be complete** (new sheet detent heights).

## Context
The video review screen uses:
- `VideoPlayerView` in full-bleed mode (`isFullBleed: true`, `maxVisibleHeightRatio: 1.0`)
- `.safeAreaInset(edge: .bottom)` for `PlaybackControlsBar`
- `.safeAreaInset(edge: .top)` for the gradient top bar
- `.ignoresSafeArea(edges: .horizontal)` on the video section
- Black background behind letterboxing

With the old collapsed height at 20% (~170pt), the video had meaningful space taken from it. With 36pt collapsed, the video should now feel like iOS Photos or YouTube — nearly full screen with just the handle peeking up from the bottom.

## Verification Tasks

### 1. Video fills correctly at collapsed state
**File**: `MoveAI/Features/Sessions/VideoReviewLayoutView.swift`

With collapsed sheet at 36pt:
- `effectiveSheetHeight` (line 86) should be ~36pt
- The video section frame (line 93-95) with `maxHeight: .infinity` should take all remaining space
- Verify the ZStack alignment (`.bottom`, line 88) positions the sheet at the bottom with video behind

**What to check**: Run the app or use a preview. In collapsed state, the video should be visible from the top bar gradient all the way down to just above the 36pt handle.

### 2. Top bar gradient still overlaps video
**File**: `MoveAI/Features/Sessions/VideoReviewLayoutView.swift` (lines 234-281)

The top bar uses a `LinearGradient` from `black.opacity(0.6)` to clear. It's placed via `.safeAreaInset(edge: .top)` (line 133). This should still work correctly — verify the gradient fades over the video content without clipping.

### 3. Playback bar in bottom safe area
**File**: `MoveAI/Features/Sessions/PlaybackControlsBar.swift`

The bar background uses `.ignoresSafeArea(.container, edges: .bottom)` (line 62 per the earlier exploration). This means the dark bar background extends through the home indicator region.

**Optional enhancement**: Consider enabling time labels by changing `showTimeLabels` from `false` to `true` to give the persistent playbar a more complete feel (like YouTube's playbar showing elapsed/remaining time). This is a minor polish item — check if the parameter exists and is easy to toggle.

### 4. No corner radius in full-bleed video mode
**File**: `MoveAI/Features/Sessions/VideoPlayerView.swift`

The full-bleed branch should have `cornerRadius(0)` applied. Verify this exists and that the video renders with sharp corners edge-to-edge.

### 5. Black letterbox background
**File**: `MoveAI/Features/Sessions/VideoPlayerView.swift`

When the video doesn't fill the entire area (aspect ratio mismatch), the space should be filled with `Color.black`, not the app background color. This prevents any colored bands appearing above/below the video in portrait mode with landscape video content. Verify `Color.black` is the background in the full-bleed branch.

### 6. Device edge cases
- **iPhone SE (no bottom safe area)**: The playback bar should not look cramped. There's no home indicator region, so the bar sits flush at the bottom.
- **Dynamic Island devices**: The top bar should account for the top safe area inset. Since it's placed via `.safeAreaInset(edge: .top)`, it should automatically sit below the Dynamic Island.

## Changes (if needed)

Most of this phase is **verification**, not code changes. Likely changes:

1. **If time labels should be enabled** in `PlaybackControlsBar`:
   - Find the `showTimeLabels` parameter and set it to `true`
   - Ensure the time label text is styled to match the telemetry design (white, caption font)

2. **If video doesn't properly fill on collapsed**:
   - The issue would be in `videoSection(constrainedHeight:)` (line 215) — the `constrainedHeight` parameter receives `totalHeight` which is the GeometryReader's full height. This should be correct but verify.

3. **If top bar gradient is clipped or misaligned**:
   - Adjust padding values in `topBar(topInset:)` (line 234)

## Tests
Run the existing screenshot pipeline to verify visual correctness across detent states:

```bash
bash scripts/capture_screenshots.sh
```

This captures screenshots for:
- `videoReviewOverviewCollapsed` — should show nearly full-screen video
- `videoReviewOverviewMedium` — video takes top ~62% of screen
- `videoReviewOverviewExpanded` — video compressed to top ~12%

Additionally, run the existing structural UI tests:
```bash
bash scripts/run_structural_tests.sh
```

These verify layout probe values (video position, container dimensions) match expected ranges.

## Done When
- [ ] Collapsed state shows video filling nearly the full screen (handle + playbar only below)
- [ ] No visible gaps or color banding between video and sheet
- [ ] Top bar gradient renders correctly over the video
- [ ] Playback bar extends through bottom safe area on Face ID devices
- [ ] Playback bar doesn't look cramped on SE-style devices
- [ ] Video has no corner radius in full-bleed mode
- [ ] Black letterbox fills any aspect ratio mismatch
- [ ] Existing screenshot and structural UI tests pass
- [ ] `xcodebuild build` succeeds
