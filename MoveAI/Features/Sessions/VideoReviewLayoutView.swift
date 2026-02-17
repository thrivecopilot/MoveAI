//
//  VideoReviewLayoutView.swift
//  MoveAI
//
//  Video + timeline + tabs (Overview / Issues / Notes). Designed to be
//  presented in the native system sheet (same as first-results after upload)
//  so the sheet’s presentationDetents provide the draggable behavior.
//  Requirements: docs/screens/video-review.md
//

import SwiftUI
import AVFoundation

enum SheetDetentLayoutCalculator {
    static func sheetHeight(
        for state: AnalysisSheetState,
        availableHeight: CGFloat,
        minCollapsedHeight: CGFloat
    ) -> CGFloat {
        let handleMinHeight = max(minCollapsedHeight, DragHandleMetrics.minCollapsedHeight)

        switch state {
        case .collapsed:
            return handleMinHeight
        case .medium:
            let minMedium: CGFloat = 300
            let baseHeight = availableHeight * state.sheetFraction
            return min(availableHeight * 0.95, max(minMedium, baseHeight))
        case .expanded:
            return availableHeight * state.sheetFraction
        }
    }
}

struct VideoReviewLayoutView: View {
    let session: Session
    @ObservedObject var sessionManager: SessionManager
    let onExit: (() -> Void)?
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject private var tabBarVisibility: TabBarVisibility
    
    @State private var selectedTab: AnalysisSheetTab = .overview
    @State private var sheetState: AnalysisSheetState = .medium
    @State private var dragOffset: CGFloat = 0
    @State private var seekToTime: TimeInterval?
    @State private var notes: String = ""
    @State private var isEditingNotes = false
    @State private var isAnalyzing = false
    @State private var analysisErrorMessage: String?
    @State private var cueOverlay: CoachingCueOverlay?
    @State private var pausedCueTask: Task<Void, Never>?
    @State private var playbackBarHeight: CGFloat = 0
    @State private var minCollapsedHeight: CGFloat = DragHandleMetrics.minCollapsedHeight
    @State private var videoSurfaceFrame: CGRect = .zero
    
    @StateObject private var playback: PlaybackController
    @StateObject private var reviewModel: SessionReviewViewModel
    
    private static let layoutCoordinateSpaceName = "VideoReview.LayoutSpace"
    private let backgroundColor = Color(red: 0.04, green: 0.05, blue: 0.07)
    private let analysisService: AnalysisServiceProtocol = PoseBasedAnalysisService()
    
    init(
        session: Session,
        sessionManager: SessionManager,
        onExit: (() -> Void)? = nil,
        initialSheetState: AnalysisSheetState = .medium,
        initialTab: AnalysisSheetTab = .overview
    ) {
        self.session = session
        self.sessionManager = sessionManager
        self.onExit = onExit
        _sheetState = State(initialValue: initialSheetState)
        _selectedTab = State(initialValue: initialTab)
        _playback = StateObject(wrappedValue: PlaybackController(videoURL: session.videoURL))
        _reviewModel = StateObject(wrappedValue: SessionReviewViewModel(analysisResult: session.analysisResult))
    }
    
    var body: some View {
        let currentSession = sessionManager.sessions.first(where: { $0.id == session.id }) ?? session
        return NavigationStack {
            GeometryReader { geometry in
                let totalHeight = geometry.size.height
                let topInset = geometry.safeAreaInsets.top
                let bottomInset = geometry.safeAreaInsets.bottom
                let probeValue = layoutProbeValue(
                    containerSize: geometry.size,
                    safeTop: topInset,
                    safeBottom: bottomInset
                )
                let topBarHeight: CGFloat = 54
                let estimatedBarHeight: CGFloat = 72
                let playbackHeight = max(playbackBarHeight, estimatedBarHeight)
                let availableSheetHeight = max(0, totalHeight - playbackHeight)
                let collapsedHeight = sheetHeight(for: .collapsed, availableHeight: availableSheetHeight)
                let mediumHeight = sheetHeight(for: .medium, availableHeight: availableSheetHeight)
                let expandedHeight = sheetHeight(for: .expanded, availableHeight: availableSheetHeight)
                let currentSheetHeight = sheetHeight(for: sheetState, availableHeight: availableSheetHeight)
                let maxUp = -(expandedHeight - currentSheetHeight)
                let maxDown = max(0, currentSheetHeight - collapsedHeight)
                let detentHeights: [AnalysisSheetState: CGFloat] = [
                    .collapsed: collapsedHeight,
                    .medium: mediumHeight,
                    .expanded: expandedHeight
                ]
                
                let effectiveSheetHeight = max(0, currentSheetHeight - dragOffset)
                
                ZStack(alignment: .bottom) {
                    backgroundColor
                        .ignoresSafeArea()
                    
                    // Video fills the band edge-to-edge horizontally (Photos-like).
                    videoSection(constrainedHeight: totalHeight, cueTopPadding: topBarHeight + 12)
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                        .clipped()
                        .ignoresSafeArea(edges: .horizontal)
                        .background(
                            GeometryReader { proxy in
                                Color.clear.preference(
                                    key: VideoSurfaceFrameKey.self,
                                    value: proxy.frame(in: .named(Self.layoutCoordinateSpaceName))
                                )
                            }
                        )
                    
                    VStack(spacing: 0) {
                        analysisSheet(
                            maxUp: maxUp,
                            maxDown: maxDown,
                            currentHeight: currentSheetHeight,
                            detentHeights: detentHeights,
                            sessionForContent: currentSession
                        )
                            .frame(height: effectiveSheetHeight)
                            .frame(maxWidth: .infinity)
                            .accessibilityIdentifier(AccessibilityID.VideoReview.sheet)
                            .accessibilityElement(children: .contain)
                            .animation(.interactiveSpring(), value: sheetState)
                    }
                    .frame(maxWidth: .infinity)
                }
                .coordinateSpace(name: Self.layoutCoordinateSpaceName)
                .overlay(alignment: .topLeading) {
                    Color.clear
                        .frame(width: 1, height: 1)
                        .accessibilityElement(children: .ignore)
                        .accessibilityIdentifier("VideoReview.LayoutProbe")
                        .accessibilityLabel("Video Review Layout Probe")
                        .accessibilityValue(probeValue)
                }
            }
            .ignoresSafeArea(edges: .horizontal)
            .safeAreaInset(edge: .top) {
                topBar(topInset: 0)
            }
            .safeAreaInset(edge: .bottom) {
                PlaybackControlsBar(
                    playback: playback,
                    analysisResult: currentSession.analysisResult,
                    issueMarkers: reviewModel.markers().map {
                        VideoTimelineView.IssueMarker(
                            id: $0.id,
                            timestamp: $0.time,
                            label: nil,
                            severity: $0.severity
                        )
                    },
                    highlightedFeedbackIds: reviewModel.highlightedMarkerIds(),
                    onMarkerTap: handleMarkerTap(_:)
                )
                .background(
                    GeometryReader { proxy in
                        Color.clear.preference(key: PlaybackBarHeightKey.self, value: proxy.size.height)
                    }
                )
            }
            .onPreferenceChange(PlaybackBarHeightKey.self) { newValue in
                if newValue > 0 {
                    playbackBarHeight = newValue
                }
            }
            .onPreferenceChange(VideoSurfaceFrameKey.self) { newValue in
                guard newValue.width > 0, newValue.height > 0 else { return }
                videoSurfaceFrame = newValue
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar(.hidden, for: .navigationBar)
            .toolbar(.hidden, for: .tabBar)
            .accessibilityIdentifier(AccessibilityID.VideoReview.root)
            .accessibilityElement(children: .contain)
        }
        .ignoresSafeArea(edges: .horizontal)
        .onAppear {
            notes = session.notes ?? ""
            tabBarVisibility.isHidden = true
            // Sync issues from store when view appears (e.g. after analysis completes or when returning).
            let current = sessionManager.sessions.first(where: { $0.id == session.id }) ?? session
            if let result = current.analysisResult {
                reviewModel.setAnalysisResult(result)
            }
        }
        .onDisappear {
            tabBarVisibility.isHidden = false
        }
        .onReceive(playback.$currentTime) { newTime in
            reviewModel.updatePlayback(
                currentTime: newTime,
                isPlaying: playback.isPlaying,
                fps: playback.nominalFrameRate
            )
            schedulePausedCueCheck()
        }
        .onReceive(playback.$isPlaying) { _ in
            reviewModel.updatePlayback(
                currentTime: playback.currentTime,
                isPlaying: playback.isPlaying,
                fps: playback.nominalFrameRate
            )
            if playback.isPlaying {
                cueOverlay = nil
            }
            schedulePausedCueCheck()
        }
        .onChange(of: currentSession.analysisResult?.score ?? -1) { _ in
            reviewModel.setAnalysisResult(currentSession.analysisResult)
        }
        .task(id: currentSession.analysisResult?.score ?? -1) {
            if let result = currentSession.analysisResult {
                reviewModel.setAnalysisResult(result)
            }
            await maybeStartAnalysis()
        }
    }
    
    private func videoSection(constrainedHeight: CGFloat, cueTopPadding: CGFloat) -> some View {
        let current = sessionManager.sessions.first(where: { $0.id == session.id }) ?? session
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
            isFullBleed: true
        )
        .clipped()
    }

    private func topBar(topInset: CGFloat) -> some View {
        let current = sessionManager.sessions.first(where: { $0.id == session.id }) ?? session
        return HStack(spacing: 12) {
            Button(action: {
                if let onExit = onExit {
                    onExit()
                } else {
                    dismiss()
                }
            }) {
                Image(systemName: "xmark")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.white)
                    .frame(width: 32, height: 32)
                    .background(Color.black.opacity(0.45))
                    .clipShape(Circle())
                    .frame(width: 44, height: 44)
            }
            .accessibilityIdentifier(AccessibilityID.VideoReview.closeButton)
            .accessibilityLabel("Close")

            Spacer()
            
            Text(current.displayName)
                .font(.headline)
                .foregroundColor(.white)
                .lineLimit(1)
                .shadow(color: .black.opacity(0.4), radius: 2, x: 0, y: 1)
                .accessibilityIdentifier(AccessibilityID.VideoReview.sessionTitle)
            
            Spacer()
            
            Color.clear
                .frame(width: 32, height: 32)
        }
        .padding(.horizontal, 16)
        .padding(.top, topInset)
        .padding(.bottom, 8)
        .background(
            LinearGradient(
                colors: [Color.black.opacity(0.6), Color.black.opacity(0.0)],
                startPoint: .top,
                endPoint: .bottom
            )
        )
        .accessibilityIdentifier("VideoReview.TopBar")
        .accessibilityElement(children: .contain)
    }

    private func analysisSheet(
        maxUp: CGFloat,
        maxDown: CGFloat,
        currentHeight: CGFloat,
        detentHeights: [AnalysisSheetState: CGFloat],
        sessionForContent: Session
    ) -> some View {
        DraggableAnalysisSheet(
            sheetState: $sheetState,
            selectedTab: $selectedTab,
            dragOffset: $dragOffset,
            minCollapsedHeight: $minCollapsedHeight,
            currentHeight: currentHeight,
            detentHeights: detentHeights,
            maxUp: maxUp,
            maxDown: maxDown,
            overviewContent: { overviewTabContent(using: sessionForContent) },
            issuesContent: {
                IssueSummaryTabView(
                    issues: reviewModel.issues,
                    selectedIssueId: reviewModel.selectedIssueId,
                    onSelectIssue: { issue in
                        reviewModel.selectIssue(issue)
                        handleIssueSelection(issue)
                    },
                    onSelectOccurrence: { issue, occurrence in
                        reviewModel.selectOccurrence(occurrence, issueId: issue.id)
                        handleOccurrenceSelection(issue: issue, occurrence: occurrence, fromExplicitTap: true)
                    }
                )
            },
            notesContent: {
                NotesTabView(
                    notes: $notes,
                    isEditing: $isEditingNotes,
                    onSave: saveNotes
                )
            }
        )
    }
    
    @ViewBuilder
    private var overviewTabContent: some View {
        overviewTabContent(using: session)
    }

    @ViewBuilder
    private func overviewTabContent(using session: Session) -> some View {
        if let result = session.analysisResult {
            OverviewTabView(analysisResult: result)
        } else if isAnalyzing {
            analysisLoadingView
        } else if analysisErrorMessage != nil {
            analysisErrorView
        } else {
            Text("No analysis yet")
                .foregroundColor(.secondary)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }
    
    private func saveNotes() {
        let current = sessionManager.sessions.first(where: { $0.id == session.id }) ?? session
        let updated = Session(
            id: current.id,
            movementType: current.movementType,
            videoURL: current.videoURL,
            timestamp: current.timestamp,
            analysisResult: current.analysisResult,
            poseData: current.poseData,
            notes: notes.isEmpty ? nil : notes,
            isRecordedLive: current.isRecordedLive
        )
        sessionManager.updateSession(updated)
    }

    private func handleIssueSelection(_ issue: IssueSummary) {
        let time = issue.worstOccurrence.time
        playback.performSeek(to: time)
        reviewModel.seek(to: time, fps: playback.nominalFrameRate)
        cueOverlay = reviewModel.cueOverlay(for: issue)
    }
    
    private func handleOccurrenceSelection(issue: IssueSummary, occurrence: IssueOccurrence, fromExplicitTap: Bool) {
        playback.performSeek(to: occurrence.time)
        reviewModel.seek(to: occurrence.time, fps: playback.nominalFrameRate)
        if fromExplicitTap {
            cueOverlay = reviewModel.cueOverlay(for: issue, occurrence: occurrence)
        }
    }
    
    private func handleMarkerTap(_ marker: VideoTimelineView.IssueMarker) {
        playback.performSeek(to: marker.timestamp)
        reviewModel.seek(to: marker.timestamp, fps: playback.nominalFrameRate)
        if let match = reviewModel.occurrence(at: marker.timestamp, tolerance: 0.2) {
            reviewModel.selectOccurrence(match.occurrence, issueId: match.issue.id)
            cueOverlay = reviewModel.cueOverlay(for: match.issue, occurrence: match.occurrence)
        }
    }
    
    private func schedulePausedCueCheck() {
        pausedCueTask?.cancel()
        guard !playback.isPlaying else { return }
        let pausedTime = playback.currentTime
        
        pausedCueTask = Task {
            try? await Task.sleep(nanoseconds: 300_000_000)
            await MainActor.run {
                guard !playback.isPlaying else { return }
                guard abs(playback.currentTime - pausedTime) < 0.05 else { return }
                if let match = reviewModel.occurrence(at: pausedTime, tolerance: 0.2) {
                    cueOverlay = reviewModel.cueOverlay(for: match.issue, occurrence: match.occurrence)
                }
            }
        }
    }

    private var visibleCueOverlay: CoachingCueOverlay? {
        switch sheetState {
        case .collapsed:
            return cueOverlay
        case .medium, .expanded:
            return nil
        }
    }
    
    private var analysisLoadingView: some View {
        VStack(spacing: 16) {
            ProgressView()
                .scaleEffect(1.2)
            Text("Analyzing your movement...")
                .font(.headline)
                .foregroundColor(.primary)
            Text("This may take a few moments")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    private var analysisErrorView: some View {
        VStack(spacing: 16) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 32))
                .foregroundColor(.orange)
            Text("Analysis failed")
                .font(.headline)
            if let message = analysisErrorMessage {
                Text(message)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 24)
            }
            Button("Try Again") {
                Task { await maybeStartAnalysis(force: true) }
            }
            .buttonStyle(.borderedProminent)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    private func maybeStartAnalysis(force: Bool = false) async {
        let current = sessionManager.sessions.first(where: { $0.id == session.id }) ?? session
        guard current.analysisResult == nil else { return }
        guard let poseData = current.poseData, !poseData.isEmpty else { return }
        guard force || !isAnalyzing else { return }
        
        await MainActor.run {
            isAnalyzing = true
            analysisErrorMessage = nil
        }
        do {
            let recording = MovementRecording(
                movementType: session.movementType,
                videoURL: session.videoURL,
                duration: 0,
                poseData: poseData
            )
            let result = try await analysisService.analyzeMovement(recording)
            let updated = Session(
                id: session.id,
                movementType: session.movementType,
                videoURL: session.videoURL,
                timestamp: session.timestamp,
                analysisResult: result,
                poseData: session.poseData,
                notes: session.notes,
                isRecordedLive: session.isRecordedLive
            )
            await MainActor.run {
                sessionManager.updateSession(updated)
            }
        } catch {
            await MainActor.run {
                analysisErrorMessage = error.localizedDescription
            }
        }
        await MainActor.run {
            isAnalyzing = false
        }
    }
    
    private func sheetHeight(for state: AnalysisSheetState, availableHeight: CGFloat) -> CGFloat {
        SheetDetentLayoutCalculator.sheetHeight(
            for: state,
            availableHeight: availableHeight,
            minCollapsedHeight: minCollapsedHeight
        )
    }

    private func layoutProbeValue(containerSize: CGSize, safeTop: CGFloat, safeBottom: CGFloat) -> String {
        let ready =
            containerSize.width > 0 &&
            containerSize.height > 0 &&
            videoSurfaceFrame.width > 0 &&
            videoSurfaceFrame.height > 0 &&
            videoSurfaceFrame.minX.isFinite &&
            videoSurfaceFrame.maxX.isFinite &&
            videoSurfaceFrame.minY.isFinite &&
            videoSurfaceFrame.maxY.isFinite

        let frame = ready ? videoSurfaceFrame : .zero
        let payload = VideoReviewLayoutProbePayload(
            schemaVersion: 1,
            ready: ready,
            containerWidth: roundedToTenth(containerSize.width),
            containerHeight: roundedToTenth(containerSize.height),
            safeTop: roundedToTenth(safeTop),
            safeBottom: roundedToTenth(safeBottom),
            videoMinX: roundedToTenth(frame.minX),
            videoMaxX: roundedToTenth(frame.maxX),
            videoMinY: roundedToTenth(frame.minY),
            videoMaxY: roundedToTenth(frame.maxY)
        )

        let encoder = JSONEncoder()
        guard
            let data = try? encoder.encode(payload),
            let json = String(data: data, encoding: .utf8)
        else {
            return "{\"schemaVersion\":1,\"ready\":false}"
        }
        return json
    }

    private func roundedToTenth(_ value: CGFloat) -> Double {
        guard value.isFinite else { return 0 }
        return (Double(value) * 10).rounded() / 10
    }
}

private struct PlaybackBarHeightKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = max(value, nextValue())
    }
}

private struct VideoSurfaceFrameKey: PreferenceKey {
    static var defaultValue: CGRect = .zero

    static func reduce(value: inout CGRect, nextValue: () -> CGRect) {
        let next = nextValue()
        if next.width > 0, next.height > 0 {
            value = next
        }
    }
}

private struct VideoReviewLayoutProbePayload: Encodable {
    let schemaVersion: Int
    let ready: Bool
    let containerWidth: Double
    let containerHeight: Double
    let safeTop: Double
    let safeBottom: Double
    let videoMinX: Double
    let videoMaxX: Double
    let videoMinY: Double
    let videoMaxY: Double
}

#if DEBUG
#Preview("Session detail") {
    let session = PreviewData.sessionWithAnalysis()
    let manager = SessionManager()
    manager.addSession(session)
    return VideoReviewLayoutView(
        session: session,
        sessionManager: manager
    )
    .environmentObject(TabBarVisibility())
    .frame(width: 393, height: 852)
}

#Preview("Session detail (no analysis)") {
    let session = PreviewData.sessionWithoutAnalysis()
    let manager = SessionManager()
    manager.addSession(session)
    return VideoReviewLayoutView(
        session: session,
        sessionManager: manager
    )
    .environmentObject(TabBarVisibility())
    .frame(width: 393, height: 852)
}
#endif
