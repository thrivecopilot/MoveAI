//
//  SessionHistoryView.swift
//  MoveAI
//
//  Created by Dave Mathew on 10/11/25.
//  Requirements: docs/screens/video-review.md
//

import SwiftUI
import AVFoundation

struct SessionHistoryView: View {
    @ObservedObject var sessionManager: SessionManager
    @State private var selectedMovement: MovementType?
    let errorMessage: String?
    let notesLineLimit: Int?

    init(sessionManager: SessionManager) {
        self.sessionManager = sessionManager
        self.errorMessage = nil
        self.notesLineLimit = 1
    }

    init(sessionManager: SessionManager, errorMessage: String? = nil, notesLineLimit: Int? = 1) {
        self.sessionManager = sessionManager
        self.errorMessage = errorMessage
        self.notesLineLimit = notesLineLimit
    }
    
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
                if let errorMessage = errorMessage {
                    errorStateView(errorMessage)
                } else if filteredSessions.isEmpty {
                    emptyStateView
                } else {
                    sessionsList
                }
            }
            .navigationTitle("Session History")
            .navigationBarTitleDisplayMode(.large)
            .accessibilityIdentifier("SessionHistoryView")
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
        .accessibilityIdentifier("SessionHistoryEmptyState")
        .accessibilityElement(children: .contain)
    }
    
    private var sessionsList: some View {
        ScrollView {
            LazyVStack(spacing: 12) {
                ForEach(filteredSessions) { session in
                    NavigationLink(destination: SessionDetailView(session: session, sessionManager: sessionManager, onExit: nil)) {
                        SessionCard(session: session, notesLineLimit: notesLineLimit)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding()
        }
        .accessibilityIdentifier("SessionHistoryList")
        .accessibilityElement(children: .contain)
    }

    private func errorStateView(_ message: String) -> some View {
        VStack(spacing: 16) {
            Spacer()

            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 50))
                .foregroundColor(.orange)

            Text("Unable to Load Sessions")
                .font(.title2)
                .fontWeight(.semibold)

            Text(message)
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)

            Button("Try Again") {
                // Placeholder for real retry action in production flows.
            }
            .buttonStyle(.bordered)

            Spacer()
        }
        .padding()
        .accessibilityIdentifier("SessionHistoryErrorState")
        .accessibilityElement(children: .contain)
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
    let notesLineLimit: Int?

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
                        .lineLimit(notesLineLimit)
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
