Video Review Screen Requirements

Desired Flow
1. Home screen → select exercise.
2. Sheet for camera/upload selection.
3. Navigation link to `VideoReviewLayoutView` for:
   - Upload existing video.
   - Record new video.
   - View old session.

Layout Requirements
1. Video covers the entire screen.
2. Playbar with timeline is always visible.
3. Top bar with title and “X” sits just beneath the safe area.
4. Draggable sheet handle is always visible, even fully collapsed.

Impacted Files
1. MoveAI/Features/Camera/CameraCaptureView.swift
2. MoveAI/Features/Camera/VideoImportView.swift
3. MoveAI/Features/Home/MovementMasteryHomeView.swift
4. MoveAI/Features/Movement/MovementSelectionView.swift
5. MoveAI/Features/Sessions/DraggableAnalysisSheet.swift
6. MoveAI/Features/Sessions/PlaybackControlsBar.swift
7. MoveAI/Features/Sessions/SessionHistoryView.swift
8. MoveAI/Features/Sessions/VideoPlayerView.swift
9. MoveAI/Features/Sessions/VideoReviewLayoutView.swift
