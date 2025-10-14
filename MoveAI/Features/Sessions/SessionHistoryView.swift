//
//  SessionHistoryView.swift
//  MoveAI
//
//  Created by Dave Mathew on 10/11/25.
//

import SwiftUI

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
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    // Session Header
                    sessionHeader
                    
                    // Analysis Results
                    if let analysisResult = session.analysisResult {
                        analysisSection(analysisResult)
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
    }
    
    private var sessionHeader: some View {
        VStack(spacing: 16) {
            Image(systemName: session.movementType.icon)
                .font(.system(size: 60))
                .foregroundColor(.accentColor)
            
            Text(session.displayName)
                .font(.title2)
                .fontWeight(.bold)
            
            Text(session.formattedDate)
                .font(.subheadline)
                .foregroundColor(.secondary)
            
            if let score = session.score {
                Text("\(Int(score))")
                    .font(.system(size: 60, weight: .bold, design: .rounded))
                    .foregroundColor(scoreColor(Int(score)))
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(16)
    }
    
    private func analysisSection(_ analysisResult: AnalysisResult) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Analysis Results")
                .font(.headline)
            
            ForEach(analysisResult.feedback) { feedback in
                HStack(alignment: .top, spacing: 12) {
                    Image(systemName: "lightbulb.fill")
                        .foregroundColor(Color(feedback.severity.color))
                        .font(.headline)
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text("At \(String(format: "%.1f", feedback.timestamp))s:")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Text(feedback.message)
                            .font(.body)
                    }
                    
                    Spacer()
                }
                .padding()
                .background(Color(.systemGray6))
                .cornerRadius(12)
            }
        }
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

#Preview {
    SessionHistoryView(sessionManager: SessionManager())
}
