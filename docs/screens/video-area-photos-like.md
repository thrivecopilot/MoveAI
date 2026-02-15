# Video area: Photos-like look and feel

## Goal

- Video replay session looks **exactly like the Photos app view**, with our UI (top bar, playback bar, draggable sheet) **layered on top**.
- **Total video area** = the rect between top safe space and bottom safe space (one fixed region; nothing resizes or displaces it).

---

## Best practices (playback of user-captured video)

- **Display dimensions**: Use the video track's **display size**, not raw `naturalSize`. Apply `preferredTransform`: `size = naturalSize.applying(preferredTransform)` then `CGSize(width: abs(size.width), height: abs(size.height))`.
- **Single rect, single authority**: Give the player one view rect; set `videoGravity` (e.g. `.resizeAspect` or `.resizeAspectFill`) and do not apply a second scaling layer (e.g. SwiftUI `scaleEffect`) that contradicts it.
- **Pose overlay**: Place overlay in a view with the same frame as the aspect-fitted video content rect; pass `previewSize` = that rect's size so keypoints stay in sync.

---

## Why the video didn't match (before fix)

- Layout used device aspect ratio instead of the asset's display size (naturalSize + preferredTransform).
- Two competing sizing systems (our scale + AVPlayerViewController gravity).
- Pose overlay frame/previewSize must match the aspect-fitted content rect to avoid mismatch.

---

## Plan (video area)

1. **Expose video display size** from PlaybackController (naturalSize + preferredTransform, then abs width/height); publish `videoDisplaySize`.
2. **One rect**: Video area = rect between top and bottom safe space; sheet overlays on top.
3. **Aspect fit** in that rect using video display size; letterbox as needed; overlay frame and previewSize = content rect size.
4. **PlayerContainerView**: `videoGravity = .resizeAspect` when fullBleed.

---

## Validation: other devices and pose overlay

- Same approach works for videos from other devices (use asset dimensions; aspect fit).
- Pose overlay must use the aspect-fitted content rect for its frame and previewSize so transformations don't cause mismatch.

---

## Open / TODO

- **Video width on device**: Video rectangle still doesn't fill full screen horizontally like Photos; playbar extends further. Tried `.ignoresSafeArea(edges: .horizontal)` on GeometryReader and NavigationStack without effect. Consider explicit full-screen width (e.g. `UIScreen.main.bounds.width`) for the video container. See `tasks/todo.md`.
