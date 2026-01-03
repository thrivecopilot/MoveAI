//
//  AnalysisResultsView.swift
//  MoveAI
//
//  Created by Dave Mathew on 10/11/25.
//

import SwiftUI

struct AnalysisResultsView: View {
    let recording: MovementRecording
    let sessionId: UUID?
    let sessionManager: SessionManager
    let existingAnalysisResult: AnalysisResult?  // Optional existing analysis to display
    let isEmbeddedInSessionDetail: Bool  // True when shown in SessionDetailView (hide duplicate info)
    
    @State private var analysisResult: AnalysisResult?
    @State private var isLoading = true
    @State private var errorMessage: String?
    @State private var lastError: Error?
    
    @Environment(\.dismiss) private var dismiss
    
    init(recording: MovementRecording, sessionId: UUID? = nil, sessionManager: SessionManager, existingAnalysisResult: AnalysisResult? = nil, isEmbeddedInSessionDetail: Bool = false) {
        self.recording = recording
        self.sessionId = sessionId
        self.sessionManager = sessionManager
        self.existingAnalysisResult = existingAnalysisResult
        self.isEmbeddedInSessionDetail = isEmbeddedInSessionDetail
    }
    
    private let analysisService: AnalysisServiceProtocol = {
        // Use pose-based analysis for movements with pose data
        // Fall back to mock for other movement types or testing
        return PoseBasedAnalysisService()
    }()
    
    var body: some View {
        ZStack {
            if isLoading {
                loadingView
            } else if let errorMessage = errorMessage {
                errorView(errorMessage)
            } else if let result = analysisResult {
                resultsView(result)
            }
        }
        .onAppear {
            // If we have existing analysis, use it directly
            if let existing = existingAnalysisResult {
                analysisResult = existing
                isLoading = false
            } else {
                // Otherwise, perform new analysis
                performAnalysis()
            }
        }
    }
    
    private var loadingView: some View {
        VStack(spacing: 20) {
            ProgressView()
                .scaleEffect(1.5)
            
            Text("Analyzing your movement...")
                .font(.headline)
            
            Text("This may take a few moments")
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }
    
    private func errorView(_ message: String) -> some View {
        ScrollView {
            VStack(spacing: 24) {
                // Error Icon and Title
                VStack(spacing: 12) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.system(size: 50))
                        .foregroundColor(.orange)
                    
                    Text("Analysis Failed")
                        .font(.title2)
                        .fontWeight(.semibold)
                    
                    Text(message)
                        .font(.body)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                }
                
                // Error Details Section
                if let detailedError = lastError as? DetailedError {
                    errorDetailsSection(detailedError)
                }
                
                // User Tips Section
                if let detailedError = lastError as? DetailedError, !detailedError.userTips.isEmpty {
                    userTipsSection(detailedError.userTips)
                }
                
                // Recovery Suggestion
                if let detailedError = lastError as? DetailedError, let suggestion = detailedError.recoverySuggestion {
                    recoverySuggestionCard(suggestion)
                }
                
                // Action Buttons
                VStack(spacing: 12) {
                    Button("Try Again") {
                        performAnalysis()
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                    
                    Button("Back to Recording") {
                        dismiss()
                    }
                    .buttonStyle(.bordered)
                }
            }
            .padding()
        }
    }
    
    private func errorDetailsSection(_ error: DetailedError) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "info.circle.fill")
                    .foregroundColor(.blue)
                Text("Details")
                    .font(.headline)
            }
            
            if let diagnosticInfo = error.diagnosticInfo {
                Text(diagnosticInfo)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .padding(.leading, 24)
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
    
    private func userTipsSection(_ tips: [String]) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "lightbulb.fill")
                    .foregroundColor(.yellow)
                Text("Tips for Better Results")
                    .font(.headline)
            }
            
            VStack(alignment: .leading, spacing: 8) {
                ForEach(Array(tips.enumerated()), id: \.offset) { index, tip in
                    HStack(alignment: .top, spacing: 8) {
                        Text("•")
                            .foregroundColor(.secondary)
                        Text(tip)
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                }
            }
            .padding(.leading, 24)
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
    
    private func recoverySuggestionCard(_ suggestion: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: "arrow.clockwise.circle.fill")
                .foregroundColor(.green)
                .font(.title3)
            
            VStack(alignment: .leading, spacing: 4) {
                Text("Quick Fix")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                Text(suggestion)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
        }
        .padding()
        .background(Color.green.opacity(0.1))
        .cornerRadius(12)
    }
    
    private func resultsView(_ result: AnalysisResult) -> some View {
        ScrollView {
            VStack(spacing: 24) {
                // Overall Score (only show if not embedded in session detail)
                if !isEmbeddedInSessionDetail {
                    scoreCard(result.score)
                }
                
                // Rep Counter
                repCounterCard(result.feedback)
                
                // Feedback Items
                feedbackSection(result.feedback)
                
                // Recording Info (only show if not embedded in session detail)
                if !isEmbeddedInSessionDetail {
                    recordingInfoCard()
                }
            }
            .padding()
        }
    }
    
    private func scoreCard(_ score: Double) -> some View {
        VStack(spacing: 16) {
            Text("Overall Score")
                .font(.headline)
            
            ZStack {
                Circle()
                    .stroke(Color.gray.opacity(0.3), lineWidth: 8)
                    .frame(width: 120, height: 120)
                
                Circle()
                    .trim(from: 0, to: score / 100)
                    .stroke(scoreColor(score), lineWidth: 8)
                    .frame(width: 120, height: 120)
                    .rotationEffect(.degrees(-90))
                
                Text("\(Int(score))")
                    .font(.system(size: 36, weight: .bold))
                    .foregroundColor(scoreColor(score))
            }
            
            Text(scoreDescription(score))
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(16)
    }
    
    @ViewBuilder
    private func repCounterCard(_ feedback: [FormFeedback]) -> some View {
        let repStats = calculateRepStatistics(feedback, reps: analysisResult?.reps)
        
        // Only show rep counter if we have rep data
        if repStats.totalReps > 0 {
            VStack(spacing: 16) {
                Text("Rep Summary")
                    .font(.headline)
                
                HStack(spacing: 24) {
                    // Total Reps
                    VStack(spacing: 8) {
                        Text("\(repStats.totalReps)")
                            .font(.system(size: 32, weight: .bold))
                            .foregroundColor(.primary)
                        Text("Total Reps")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    Divider()
                        .frame(height: 50)
                    
                    // Good Reps
                    VStack(spacing: 8) {
                        HStack(spacing: 4) {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(.green)
                            Text("\(repStats.goodReps)")
                                .font(.system(size: 32, weight: .bold))
                                .foregroundColor(.green)
                        }
                        Text("Good Reps")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    Divider()
                        .frame(height: 50)
                    
                    // Warning Reps
                    VStack(spacing: 8) {
                        HStack(spacing: 4) {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .foregroundColor(repStats.warningReps > 0 ? .yellow : .gray)
                            Text("\(repStats.warningReps)")
                                .font(.system(size: 32, weight: .bold))
                                .foregroundColor(repStats.warningReps > 0 ? .yellow : .gray)
                        }
                        Text("Need Attention")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }
            .padding()
            .background(Color(.systemGray6))
            .cornerRadius(16)
        }
    }
    
    private func calculateRepStatistics(_ feedback: [FormFeedback], reps: [SquatRep]? = nil) -> (totalReps: Int, goodReps: Int, warningReps: Int) {
        // Get all unique rep numbers from feedback
        let repNumbers = Set(feedback.compactMap { $0.repNumber })
        let totalReps = repNumbers.count
        
        // Debug logging
        print("🔍 Rep Counting Debug:")
        print("  - Total feedback items: \(feedback.count)")
        print("  - Feedback items with rep numbers: \(feedback.filter { $0.repNumber != nil }.count)")
        print("  - Unique rep numbers found: \(repNumbers)")
        print("  - Rep numbers: \(Array(repNumbers).sorted())")
        print("  - Reps data available: \(reps != nil ? "Yes (\(reps!.count) reps)" : "No")")
        
        // If no rep numbers, return zeros
        guard totalReps > 0 else {
            print("  ⚠️ No rep numbers found in feedback")
            return (totalReps: 0, goodReps: 0, warningReps: 0)
        }
        
        var goodReps = 0
        var warningReps = 0
        
        // For each rep, check if it has any warnings or critical issues OR is not full
        for repNumber in repNumbers {
            let repFeedback = feedback.filter { $0.repNumber == repNumber }
            
            print("  - Rep \(repNumber): \(repFeedback.count) feedback items")
            
            // Check if rep is full
            let isFullRep = reps?.first(where: { $0.repNumber == repNumber })?.isFullRep ?? true
            
            // Check if this rep has any warnings or critical issues
            let hasWarnings = repFeedback.contains { $0.severity == .warning || $0.severity == .critical }
            
            if hasWarnings || !isFullRep {
                warningReps += 1
                print("    → Has warnings/critical issues or is not full (isFullRep=\(isFullRep))")
            } else {
                // Rep is good if it's full and only has excellent or good feedback (or no feedback)
                goodReps += 1
                print("    → Good rep")
            }
        }
        
        print("  ✅ Final stats: Total=\(totalReps), Good=\(goodReps), Warnings=\(warningReps)")
        
        return (totalReps: totalReps, goodReps: goodReps, warningReps: warningReps)
    }
    
    private func feedbackSection(_ feedback: [FormFeedback]) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Form Feedback")
                .font(.headline)
            
            ForEach(feedback) { item in
                FeedbackCard(feedback: item)
            }
        }
    }
    
    private func recordingInfoCard() -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Recording Details")
                .font(.headline)
            
            HStack {
                Text("Movement:")
                Spacer()
                Text(recording.movementType.displayName)
                    .foregroundColor(.secondary)
            }
            
            HStack {
                Text("Duration:")
                Spacer()
                Text(formatDuration(recording.duration))
                    .foregroundColor(.secondary)
            }
            
            HStack {
                Text("Date:")
                Spacer()
                Text(recording.timestamp.formatted(date: .abbreviated, time: .shortened))
                    .foregroundColor(.secondary)
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
    
    private func scoreColor(_ score: Double) -> Color {
        switch score {
        case 80...100:
            return .green
        case 60..<80:
            return .blue
        case 40..<60:
            return .orange
        default:
            return .red
        }
    }
    
    private func scoreDescription(_ score: Double) -> String {
        switch score {
        case 80...100:
            return "Excellent form!"
        case 60..<80:
            return "Good form with room for improvement"
        case 40..<60:
            return "Needs improvement"
        default:
            return "Requires attention"
        }
    }
    
    private func formatDuration(_ duration: TimeInterval) -> String {
        let minutes = Int(duration) / 60
        let seconds = Int(duration) % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }
    
    private func performAnalysis() {
        isLoading = true
        errorMessage = nil
        lastError = nil
        
        Task {
            do {
                let result = try await analysisService.analyzeMovement(recording)
                await MainActor.run {
                    self.analysisResult = result
                    self.isLoading = false
                    
                    // Only save analysis result if we don't already have one (new analysis)
                    // Don't save if we're displaying existing analysis
                    if existingAnalysisResult == nil, let sessionId = sessionId {
                        if let existingSession = sessionManager.sessions.first(where: { $0.id == sessionId }) {
                            let updatedSession = Session(
                                id: existingSession.id,
                                movementType: existingSession.movementType,
                                videoURL: existingSession.videoURL,
                                timestamp: existingSession.timestamp,
                                analysisResult: result,
                                poseData: existingSession.poseData,
                                notes: existingSession.notes,
                                isRecordedLive: existingSession.isRecordedLive
                            )
                            sessionManager.updateSession(updatedSession)
                            print("✅ AnalysisResultsView: Saved analysis result to session \(sessionId)")
                        } else {
                            print("⚠️ AnalysisResultsView: Session \(sessionId) not found in sessionManager")
                        }
                    }
                }
            } catch {
                await MainActor.run {
                    self.lastError = error
                    self.errorMessage = error.localizedDescription
                    self.isLoading = false
                }
            }
        }
    }
}

struct FeedbackCard: View {
    let feedback: FormFeedback
    
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: feedback.category.icon)
                .foregroundColor(severityColor)
                .frame(width: 24)
            
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(feedback.category.displayName)
                        .font(.subheadline)
                        .fontWeight(.medium)
                    
                    Spacer()
                    
                    Text(feedback.severity.displayName)
                        .font(.caption)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 2)
                        .background(severityColor.opacity(0.2))
                        .foregroundColor(severityColor)
                        .cornerRadius(4)
                }
                
                Text(feedback.message)
                    .font(.body)
                    .foregroundColor(.secondary)
                
                Text("at \(formatTimestamp(feedback.timestamp))")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
    
    private var severityColor: Color {
        switch feedback.severity {
        case .excellent, .good:
            return .green
        case .warning:
            return .yellow
        case .critical:
            return .red
        }
    }
    
    private func formatTimestamp(_ timestamp: TimeInterval) -> String {
        let minutes = Int(timestamp) / 60
        let seconds = Int(timestamp) % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }
}

#Preview {
    // Create mock feedback with multiple reps and different severity levels
    let mockFeedback: [FormFeedback] = [
        FormFeedback(
            category: .rangeOfMotion,
            message: "Excellent depth - hip crease below knee level on 1st rep (1.2 seconds)",
            severity: .excellent,
            timestamp: 1.2,
            repNumber: 1
        ),
        FormFeedback(
            category: .stability,
            message: "Good knee tracking throughout the movement on 1st rep (1.5 seconds)",
            severity: .good,
            timestamp: 1.5,
            repNumber: 1
        ),
        FormFeedback(
            category: .posture,
            message: "Excellent back position - neutral spine maintained on 1st rep (1.8 seconds)",
            severity: .excellent,
            timestamp: 1.8,
            repNumber: 1
        ),
        FormFeedback(
            category: .rangeOfMotion,
            message: "Good depth, but aim to get hip crease below knee level on 2nd rep (4.3 seconds)",
            severity: .good,
            timestamp: 4.3,
            repNumber: 2
        ),
        FormFeedback(
            category: .safety,
            message: "Knees caving inward detected - push knees out to align with toes on 2nd rep (4.8 seconds)",
            severity: .critical,
            timestamp: 4.8,
            repNumber: 2
        ),
        FormFeedback(
            category: .posture,
            message: "Moderate back rounding - focus on keeping chest up and core engaged on 3rd rep (7.2 seconds)",
            severity: .warning,
            timestamp: 7.2,
            repNumber: 3
        ),
        FormFeedback(
            category: .rangeOfMotion,
            message: "Need to go deeper - hip crease should be below knee level on 3rd rep (7.5 seconds)",
            severity: .warning,
            timestamp: 7.5,
            repNumber: 3
        ),
        FormFeedback(
            category: .posture,
            message: "Slight back rounding - maintain neutral spine position on 4th rep (10.1 seconds)",
            severity: .warning,
            timestamp: 10.1,
            repNumber: 4
        ),
        FormFeedback(
            category: .rangeOfMotion,
            message: "Excellent depth - hip crease below knee level on 4th rep (10.4 seconds)",
            severity: .excellent,
            timestamp: 10.4,
            repNumber: 4
        )
    ]
    
    // Helper function to calculate rep statistics
    func calculateRepStats(_ feedback: [FormFeedback]) -> (totalReps: Int, goodReps: Int, warningReps: Int) {
        let repNumbers = Set(feedback.compactMap { $0.repNumber })
        let totalReps = repNumbers.count
        
        guard totalReps > 0 else {
            return (totalReps: 0, goodReps: 0, warningReps: 0)
        }
        
        var goodReps = 0
        var warningReps = 0
        
        for repNumber in repNumbers {
            let repFeedback = feedback.filter { $0.repNumber == repNumber }
            let hasWarnings = repFeedback.contains { $0.severity == .warning || $0.severity == .critical }
            
            if hasWarnings {
                warningReps += 1
            } else {
                goodReps += 1
            }
        }
        
        return (totalReps: totalReps, goodReps: goodReps, warningReps: warningReps)
    }
    
    let repStats = calculateRepStats(mockFeedback)
    let mockResult = AnalysisResult(score: 75.0, feedback: mockFeedback)
    
    return NavigationView {
        ScrollView {
            VStack(spacing: 24) {
                // Overall Score
                VStack(spacing: 16) {
                    Text("Overall Score")
                        .font(.headline)
                    
                    ZStack {
                        Circle()
                            .stroke(Color.gray.opacity(0.3), lineWidth: 8)
                            .frame(width: 120, height: 120)
                        
                        Circle()
                            .trim(from: 0, to: mockResult.score / 100)
                            .stroke(.blue, lineWidth: 8)
                            .frame(width: 120, height: 120)
                            .rotationEffect(.degrees(-90))
                        
                        Text("\(Int(mockResult.score))")
                            .font(.system(size: 36, weight: .bold))
                            .foregroundColor(.blue)
                    }
                    
                    Text("Good form with room for improvement")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding()
                .background(Color(.systemGray6))
                .cornerRadius(16)
                
                // Rep Counter
                VStack(spacing: 16) {
                    Text("Rep Summary")
                        .font(.headline)
                    
                    HStack(spacing: 24) {
                        // Total Reps
                        VStack(spacing: 8) {
                            Text("\(repStats.totalReps)")
                                .font(.system(size: 32, weight: .bold))
                                .foregroundColor(.primary)
                            Text("Total Reps")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        
                        Divider()
                            .frame(height: 50)
                        
                        // Good Reps
                        VStack(spacing: 8) {
                            HStack(spacing: 4) {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundColor(.green)
                                Text("\(repStats.goodReps)")
                                    .font(.system(size: 32, weight: .bold))
                                    .foregroundColor(.green)
                            }
                            Text("Good Reps")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        
                        Divider()
                            .frame(height: 50)
                        
                        // Warning Reps
                        VStack(spacing: 8) {
                            HStack(spacing: 4) {
                                Image(systemName: "exclamationmark.triangle.fill")
                                    .foregroundColor(repStats.warningReps > 0 ? .yellow : .gray)
                                Text("\(repStats.warningReps)")
                                    .font(.system(size: 32, weight: .bold))
                                    .foregroundColor(repStats.warningReps > 0 ? .yellow : .gray)
                            }
                            Text("Need Attention")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                }
                .padding()
                .background(Color(.systemGray6))
                .cornerRadius(16)
                
                // Feedback Items
                VStack(alignment: .leading, spacing: 16) {
                    Text("Form Feedback")
                        .font(.headline)
                    
                    ForEach(mockFeedback) { item in
                        FeedbackCard(feedback: item)
                    }
                }
            }
            .padding()
        }
        .navigationTitle("Analysis Results")
        .navigationBarTitleDisplayMode(.inline)
    }
}

