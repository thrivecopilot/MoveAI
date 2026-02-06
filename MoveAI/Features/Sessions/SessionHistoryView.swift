//
//  SessionHistoryView.swift
//  MoveAI
//
//  Created by Dave Mathew on 10/11/25.
//

import SwiftUI
import AVFoundation

struct SessionHistoryView: View {
    @ObservedObject var sessionManager: SessionManager
    @State private var selectedMovement: MovementType?
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Movement Filter
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        FilterButton(
                            title: "All",
                            isSelected: selectedMovement == nil,
                            action: { selectedMovement = nil }
                        )
                        
                        ForEach(MovementType.allCases) { movement in
                            FilterButton(
                                title: movement.displayName,
                                isSelected: selectedMovement == movement,
                                action: { selectedMovement = movement }
                            )
                        }
                    }
                    .padding(.horizontal)
                }
                .padding(.vertical, 8)
                
                Divider()
                
                // Sessions List
                if filteredSessions.isEmpty {
                    emptyStateView
                } else {
                    sessionsList
                }
            }
            .navigationTitle("Session History")
            .navigationBarTitleDisplayMode(.large)
        }
    }
    
    private var filteredSessions: [Session] {
        if let selectedMovement = selectedMovement {
            return sessionManager.sessionsForMovement(selectedMovement)
        } else {
            return sessionManager.sessions.sorted { $0.timestamp > $1.timestamp }
        }
    }
    
    private var emptyStateView: some View {
        VStack(spacing: 20) {
            Spacer()
            
            Image(systemName: "video.fill")
                .font(.system(size: 60))
                .foregroundColor(.secondary)
            
            Text("No Sessions Yet")
                .font(.title2)
                .fontWeight(.semibold)
            
            Text("Start recording your movements to see your progress here")
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
            
            Spacer()
        }
    }
    
    private var sessionsList: some View {
        ScrollView {
            LazyVStack(spacing: 12) {
                ForEach(filteredSessions) { session in
                    NavigationLink(destination: SessionDetailView(session: session, sessionManager: sessionManager, onExit: nil)) {
                        SessionCard(session: session)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding()
        }
    }
}

struct FilterButton: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.subheadline)
                .fontWeight(.medium)
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(isSelected ? Color.accentColor : Color(.systemGray5))
                .foregroundColor(isSelected ? .white : .primary)
                .cornerRadius(20)
        }
        .buttonStyle(.plain)
    }
}

struct SessionCard: View {
    let session: Session
    
    var body: some View {
        HStack(spacing: 16) {
            // Movement Icon
            Image(systemName: session.movementType.icon)
                .font(.title2)
                .foregroundColor(.accentColor)
                .frame(width: 40)
            
            // Session Info
            VStack(alignment: .leading, spacing: 4) {
                Text(session.displayName)
                    .font(.headline)
                    .foregroundColor(.primary)
                
                Text(session.formattedDate)
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                if let notes = session.notes, !notes.isEmpty {
                    Text(notes)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }
            }
            
            Spacer()
            
            // Score Badge
            if let score = session.score {
                VStack(spacing: 2) {
                    Text("\(Int(score))")
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(scoreColor(Int(score)))
                    
                    Text("Score")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(Color(.systemGray6))
                .cornerRadius(8)
            } else {
                VStack(spacing: 2) {
                    Image(systemName: "clock")
                        .font(.title3)
                        .foregroundColor(.orange)
                    
                    Text("Pending")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(Color(.systemGray6))
                .cornerRadius(8)
            }
            
            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.05), radius: 2, x: 0, y: 1)
    }
    
    private func scoreColor(_ score: Int) -> Color {
        if score >= 80 {
            return .green
        } else if score >= 60 {
            return .orange
        } else {
            return .red
        }
    }
}

struct SessionDetailView: View {
    let session: Session
    @ObservedObject var sessionManager: SessionManager
    let onExit: (() -> Void)?
    
    var body: some View {
        let currentSession = sessionManager.sessions.first(where: { $0.id == session.id }) ?? session
        VideoReviewLayoutView(
            session: currentSession,
            sessionManager: sessionManager,
            onExit: onExit
        )
    }
}

struct FullScreenVideoView: View {
    let videoURL: URL
    let poseData: [PoseDetectionResult]?
    let isRecordedLive: Bool
    let sessionTitle: String?
    let playback: PlaybackController
    @Environment(\.dismiss) var dismiss
    
    init(videoURL: URL, poseData: [PoseDetectionResult]?, isRecordedLive: Bool, sessionTitle: String? = nil, playback: PlaybackController) {
        self.videoURL = videoURL
        self.poseData = poseData
        self.isRecordedLive = isRecordedLive
        self.sessionTitle = sessionTitle
        self.playback = playback
    }
    
    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            
            VideoPlayerView(
                videoURL: videoURL,
                poseData: poseData,
                isRecordedLive: isRecordedLive,
                isFullScreenMode: true,
                playback: playback,
                onExitFullScreen: { dismiss() },
                fullScreenTitle: sessionTitle
            )
            .ignoresSafeArea(.all, edges: .all)
            
            VStack {
                Spacer()
                PlaybackControlsBar(
                    playback: playback,
                    analysisResult: nil,
                    highlightedFeedbackIds: [],
                    onFullScreenToggle: nil
                )
            }
        }
        .statusBar(hidden: true)
    }
}

#Preview {
    SessionHistoryView(sessionManager: SessionManager())
        .environmentObject(TabBarVisibility())
}

#if DEBUG
#Preview("Session detail (standalone)") {
    SessionDetailView(
        session: PreviewData.sessionWithAnalysis(),
        sessionManager: SessionManager(),
        onExit: nil
    )
    .environmentObject(TabBarVisibility())
}
#endif
