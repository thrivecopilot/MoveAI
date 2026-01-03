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
    @State private var showingSessionDetail: Session?
    
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
        .sheet(item: $showingSessionDetail) { session in
            SessionDetailView(session: session, sessionManager: sessionManager)
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
                    SessionCard(session: session) {
                        showingSessionDetail = session
                    }
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
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
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
        .buttonStyle(.plain)
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
    @Environment(\.dismiss) var dismiss
    @State private var notes: String = ""
    @State private var isEditingNotes = false
    @State private var isVideoFullScreen = false
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    // Video Player
                    VideoPlayerView(
                        videoURL: session.videoURL,
                        poseData: session.poseData,
                        isRecordedLive: session.isRecordedLive,
                        onFullScreenToggle: {
                            isVideoFullScreen = true
                        }
                    )
                    
                    // Session Header
                    sessionHeader
                    
                    // Analysis Results
                    if let analysisResult = session.analysisResult {
                        // Use the unified AnalysisResultsView
                        let recording = createMovementRecording(from: session)
                        AnalysisResultsView(
                            recording: recording,
                            sessionId: session.id,
                            sessionManager: sessionManager,
                            existingAnalysisResult: analysisResult,
                            isEmbeddedInSessionDetail: true
                        )
                    } else {
                        pendingAnalysisSection
                    }
                    
                    // Notes Section
                    notesSection
                }
                .padding()
            }
            .navigationTitle(session.displayName)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
        .onAppear {
            notes = session.notes ?? ""
        }
        .sheet(isPresented: $isVideoFullScreen) {
            FullScreenVideoView(
                videoURL: session.videoURL,
                poseData: session.poseData,
                isRecordedLive: session.isRecordedLive
            )
        }
    }
    
    private var sessionHeader: some View {
        VStack(spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(session.displayName)
                        .font(.title3)
                        .fontWeight(.bold)
                    
                    Text(session.formattedDate)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                if let score = session.score {
                    VStack(alignment: .trailing, spacing: 4) {
                        Text("Score")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Text("\(Int(score))")
                            .font(.title3)
                            .fontWeight(.bold)
                            .foregroundColor(scoreColor(Int(score)))
                    }
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(Color(.systemGray6))
        .cornerRadius(8)
    }
    
    /// Create a MovementRecording from a Session for use with AnalysisResultsView
    private func createMovementRecording(from session: Session) -> MovementRecording {
        // Try to get video duration from the video file
        // Note: AVAsset.duration is synchronous but may return invalid time for some formats
        // We'll use a simple synchronous approach with a fallback
        let duration: TimeInterval
        let asset = AVAsset(url: session.videoURL)
        let assetDuration = asset.duration
        let durationSeconds = CMTimeGetSeconds(assetDuration)
        
        if durationSeconds.isFinite && durationSeconds > 0 {
            duration = durationSeconds
        } else {
            // Fallback to a default duration if we can't read the video
            // In practice, this should rarely happen as videos should have valid duration
            duration = 10.0
        }
        
        return MovementRecording(
            movementType: session.movementType,
            videoURL: session.videoURL,
            duration: duration,
            poseData: session.poseData
        )
    }
    
    private var pendingAnalysisSection: some View {
        VStack(spacing: 16) {
            Image(systemName: "clock")
                .font(.system(size: 40))
                .foregroundColor(.orange)
            
            Text("Analysis Pending")
                .font(.headline)
            
            Text("Your movement analysis is being processed. Check back soon!")
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(16)
    }
    
    private var notesSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Notes")
                    .font(.headline)
                
                Spacer()
                
                Button(isEditingNotes ? "Save" : "Edit") {
                    if isEditingNotes {
                        saveNotes()
                    }
                    isEditingNotes.toggle()
                }
                .font(.subheadline)
                .foregroundColor(.accentColor)
            }
            
            if isEditingNotes {
                TextField("Add notes about this session...", text: $notes, axis: .vertical)
                    .textFieldStyle(.roundedBorder)
                    .lineLimit(3...6)
            } else {
                Text(notes.isEmpty ? "No notes added" : notes)
                    .font(.body)
                    .foregroundColor(notes.isEmpty ? .secondary : .primary)
                    .padding()
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color(.systemGray6))
                    .cornerRadius(8)
            }
        }
    }
    
    private func saveNotes() {
        let updatedSession = Session(
            id: session.id,
            movementType: session.movementType,
            videoURL: session.videoURL,
            timestamp: session.timestamp,
            analysisResult: session.analysisResult,
            poseData: session.poseData,
            notes: notes.isEmpty ? nil : notes
        )
        sessionManager.updateSession(updatedSession)
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

struct FullScreenVideoView: View {
    let videoURL: URL
    let poseData: [PoseDetectionResult]?
    let isRecordedLive: Bool
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        NavigationStack {
            ZStack {
                Color.black.ignoresSafeArea()
                
                VideoPlayerView(
                    videoURL: videoURL,
                    poseData: poseData,
                    isRecordedLive: isRecordedLive,
                    isFullScreenMode: true
                )
                .ignoresSafeArea(.all, edges: .all)
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                    .foregroundColor(.white)
                }
            }
        }
    }
}

#Preview {
    SessionHistoryView(sessionManager: SessionManager())
}
