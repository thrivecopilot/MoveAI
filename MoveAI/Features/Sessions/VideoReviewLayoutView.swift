//
//  VideoReviewLayoutView.swift
//  MoveAI
//
//  Video + timeline + tabs (Overview / Issues / Notes). Designed to be
//  presented in the native system sheet (same as first-results after upload)
//  so the sheet’s presentationDetents provide the draggable behavior.
//

import SwiftUI
import AVFoundation

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
    @State private var isVideoFullScreen = false
    @State private var notes: String = ""
    @State private var isEditingNotes = false
    @State private var isAnalyzing = false
    @State private var analysisErrorMessage: String?
    
    @StateObject private var playback: PlaybackController
    
    private let backgroundColor = Color(red: 0.04, green: 0.05, blue: 0.07)
    @State private var controlsBarHeight: CGFloat = 0
    private let analysisService: AnalysisServiceProtocol = PoseBasedAnalysisService()
    
    init(session: Session, sessionManager: SessionManager, onExit: (() -> Void)? = nil) {
        self.session = session
        self.sessionManager = sessionManager
        self.onExit = onExit
        _playback = StateObject(wrappedValue: PlaybackController(videoURL: session.videoURL))
    }
    
    var body: some View {
        NavigationStack {
            GeometryReader { geometry in
                let totalHeight = geometry.size.height
                let currentSheetHeight = sheetHeight(for: sheetState, totalHeight: totalHeight)
                let collapsedHeight = sheetHeight(for: .collapsed, totalHeight: totalHeight)
                let expandedHeight = sheetHeight(for: .expanded, totalHeight: totalHeight)
                let maxUp = -(expandedHeight - currentSheetHeight)
                let maxDown = max(0, currentSheetHeight - collapsedHeight)
                
                ZStack(alignment: .bottom) {
                    backgroundColor
                        .ignoresSafeArea()
                    
                    videoSection(constrainedHeight: totalHeight)
                        .frame(height: totalHeight)
                        .frame(maxWidth: .infinity)
                        .ignoresSafeArea()
                    
                    if dragOffset != 0 {
                        Color(red: 0.06, green: 0.08, blue: 0.11)
                            .frame(height: currentSheetHeight)
                            .frame(maxWidth: .infinity)
                            .offset(y: dragOffset)
                            .padding(.bottom, controlsBarHeight)
                    }
                    
                    analysisSheet(maxUp: maxUp, maxDown: maxDown)
                    .frame(height: currentSheetHeight)
                    .frame(maxWidth: .infinity)
                    .animation(.interactiveSpring(), value: sheetState)
                    .padding(.bottom, controlsBarHeight)
                }
                .overlay(alignment: .top) {
                    topBar
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar(.hidden, for: .navigationBar)
            .toolbar(.hidden, for: .tabBar)
            .overlay(alignment: .bottom) {
                PlaybackControlsBar(
                    playback: playback,
                    analysisResult: session.analysisResult,
                    highlightedFeedbackIds: [],
                    onFullScreenToggle: { isVideoFullScreen = true }
                )
                .background(
                    GeometryReader { proxy in
                        Color.clear
                            .preference(key: ControlsBarHeightKey.self, value: proxy.size.height)
                    }
                )
            }
            .onPreferenceChange(ControlsBarHeightKey.self) { newValue in
                controlsBarHeight = newValue
            }
        }
        .onAppear {
            notes = session.notes ?? ""
            tabBarVisibility.isHidden = true
        }
        .onDisappear {
            tabBarVisibility.isHidden = false
        }
        .task(id: session.analysisResult?.score ?? -1) {
            await maybeStartAnalysis()
        }
        .fullScreenCover(isPresented: $isVideoFullScreen) {
            FullScreenVideoView(
                videoURL: session.videoURL,
                poseData: session.poseData,
                isRecordedLive: session.isRecordedLive,
                sessionTitle: session.displayName,
                playback: playback
            )
        }
    }
    
    private func videoSection(constrainedHeight: CGFloat) -> some View {
        VideoPlayerView(
            videoURL: session.videoURL,
            poseData: session.poseData,
            isRecordedLive: session.isRecordedLive,
            analysisResult: session.analysisResult,
            constrainedHeight: constrainedHeight,
            maxVisibleHeightRatio: sheetState == .hidden ? 1.0 : 0.85,
            seekToTime: $seekToTime,
            onFullScreenToggle: { isVideoFullScreen = true },
            playback: playback
        )
        .clipped()
    }

    private var topBar: some View {
        HStack(spacing: 12) {
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
            }
            
            Spacer()
            
            Text(session.displayName)
                .font(.headline)
                .foregroundColor(.white)
                .lineLimit(1)
            
            Spacer()
            
            Color.clear
                .frame(width: 32, height: 32)
        }
        .padding(.horizontal, 16)
        .padding(.top, 10)
        .padding(.bottom, 12)
        .background(
            LinearGradient(
                colors: [Color.black.opacity(0.65), Color.black.opacity(0.0)],
                startPoint: .top,
                endPoint: .bottom
            )
        )
    }

    private func analysisSheet(maxUp: CGFloat, maxDown: CGFloat) -> some View {
        DraggableAnalysisSheet(
            sheetState: $sheetState,
            selectedTab: $selectedTab,
            dragOffset: $dragOffset,
            maxUp: maxUp,
            maxDown: maxDown,
            overviewContent: { overviewTabContent },
            issuesContent: {
                if let result = session.analysisResult {
                    GroupedIssuesTabView(
                        analysisResult: result,
                        onSeekToTime: { seekToTime = $0 }
                    )
                } else {
                    Text("No analysis yet")
                        .foregroundColor(.secondary)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
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
        let updated = Session(
            id: session.id,
            movementType: session.movementType,
            videoURL: session.videoURL,
            timestamp: session.timestamp,
            analysisResult: session.analysisResult,
            poseData: session.poseData,
            notes: notes.isEmpty ? nil : notes,
            isRecordedLive: session.isRecordedLive
        )
        sessionManager.updateSession(updated)
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
        guard session.analysisResult == nil else { return }
        guard let poseData = session.poseData, !poseData.isEmpty else { return }
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
    
    private func sheetHeight(for state: AnalysisSheetState, totalHeight: CGFloat) -> CGFloat {
        if state == .hidden {
            return 30
        }
        let baseHeight = totalHeight * state.sheetFraction
        return max(180, min(totalHeight * 0.9, baseHeight))
    }
}

private struct ControlsBarHeightKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = max(value, nextValue())
    }
}

#if DEBUG
#Preview("Session detail") {
    VideoReviewLayoutView(
        session: PreviewData.sessionWithAnalysis(),
        sessionManager: SessionManager()
    )
    .environmentObject(TabBarVisibility())
}

#Preview("Session detail (no analysis)") {
    VideoReviewLayoutView(
        session: PreviewData.sessionWithoutAnalysis(),
        sessionManager: SessionManager()
    )
    .environmentObject(TabBarVisibility())
}
#endif
