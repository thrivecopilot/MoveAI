# Lessons Learned

## Pattern: Always confirm before implementing
- **Mistake**: Implemented layout/UX plan (video review sheet, play bar, full-bleed) without user approval; caused regression (play bar out of safe area, video displaced by sheet).
- **Rule**: Present the plan and get explicit "go" or "implement" before making code changes. Never implement layout, UX, or behavioral changes without user approval.
- **Iteration**: Added "Confirm Before Implementing" to `.cursor/rules/workflow-orchestration.mdc` so the agent always asks first.

## Pattern: Video area — Photos-like playback
- **What worked**: Video area between top and bottom safe space; correct aspect from asset (naturalSize + preferredTransform); aspect fit with letterboxing; pose overlay aligned by using the aspect-fitted content rect for overlay frame and previewSize.
- **Rule**: Use the video’s display size for layout (not device aspect). Give the player one rect and one videoGravity (.resizeAspect for fit). Place the pose overlay in a view with the same frame as the fitted content rect and pass previewSize = that rect’s size so keypoints stay in sync.

## Pattern: Validate build before asking user to test
- **Mistake**: Asked user to test after code changes without confirming the app builds; user hit compile errors (e.g. “Cannot find 'currentSession' in scope” in multiple places).
- **Rule**: Before saying “please test” or “you can verify,” ensure the project builds (run the build from the correct project root, or at least confirm there are no remaining scope/compile issues). Do not hand off to the user with unverified build status.

## Pattern: [Description]
- **Mistake**: What went wrong
- **Rule**: How to prevent it
- **Iteration**: Refinements
