# Plan: Video Aspect Ratio + Apple Maps–Style Sheet

## 1. Video aspect ratio (fullscreen)

**Current (after last change):** Fullscreen uses `.aspectRatio(16/9, contentMode: .fit)` — video is letterboxed and can look different from the rest of the app.

**Proposed:** Revert fullscreen to **aspect fill** so the video fills the screen and keeps the same treatment as before (no forced 16:9 letterboxing). Concretely:

- Use the same approach as the original fullscreen implementation: fill the screen (e.g. device aspect or content fill) and clip, so we **do not change the video’s aspect ratio** — we only control how the frame is presented (fill vs fit).
- If your intent is “never letterbox, always fill,” we’ll use **fill** in fullscreen. If you prefer “always show full frame (fit)” but with the video’s **native** aspect ratio (not forced 16:9), we can do fit to the video’s intrinsic aspect instead.

**Need your confirmation:** Should fullscreen be (A) **fill** (video fills screen, may crop), or (B) **fit to video’s native aspect** (no crop, possible letterboxing based on actual video dimensions)?

---

## 2. Draggable sheet — match Apple Maps

Goal: Make the analysis sheet look and feel like the Maps bottom sheet (from your screenshots) without adding clutter.

### 2.1 Handle

- **Current:** Pill + “Drag to resize” text.
- **Proposed:** Single **thin horizontal gray line** (grabber) centered at the top of the sheet, similar to Maps:
  - Width ~36–40 pt, height ~3–4 pt, rounded ends.
  - Color: `Color(.systemGray3)` or `Color(.systemGray4)`.
  - No text, no pill — just the line.

### 2.2 Sheet container

- **Background:** Keep `Color(.systemBackground)` so it adapts to light/dark. Optionally, a very slight translucency (e.g. `ultraThinMaterial`) only in **collapsed** state so the video is faintly visible behind; otherwise solid for readability.
- **Corners:** Keep rounded **top only**, radius ~20 pt (Maps-like).
- **Top edge:** Remove the current 1 pt separator line so the handle is the only top element (cleaner).
- **Shadow:** Keep subtle (e.g. radius 8–10, y: -2) so the sheet reads as floating without feeling heavy.

### 2.3 Content structure (no extra clutter)

- **Collapsed:** Only the **handle + tab bar** (Overview | Issues | Notes). No content preview, no extra labels.
- **Medium / Expanded:** Same tab content as now; keep section headings and spacing clear (Maps-style “Places” / “Recents” feel) without adding new controls or text.
- **Remove** the “Drag to resize” label everywhere.

### 2.4 What we are **not** adding

- No search bar (Maps has it; we don’t need it).
- No extra icons or buttons on the sheet header.
- No changes to tab content structure beyond ensuring it’s readable and well-spaced.

---

## 3. Summary

| Item | Action |
|------|--------|
| Fullscreen video | Revert to fill (or fit to native aspect — **your choice A or B above**). |
| Sheet handle | Replace with single thin gray horizontal line; remove “Drag to resize”. |
| Sheet background/corners/shadow | System background, top-only rounding ~20 pt, subtle shadow; remove top separator. |
| Collapsed sheet | Handle + tab bar only. |
| Optional | Slight translucency in collapsed state only. |

Once you confirm (1) fullscreen: A vs B, and (2) that this sheet direction matches what you want, we can implement and keep the UI minimal.
