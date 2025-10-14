//
//  AnalysisResultsView.swift
//  MoveAI
//
//  Created by Dave Mathew on 10/11/25.
//

import SwiftUI

struct AnalysisResultsView: View {
    let recording: MovementRecording
    @State private var analysisResult: AnalysisResult?
    @State private var isLoading = true
    @State private var errorMessage: String?
    
    @Environment(\.dismiss) private var dismiss
    
    private let analysisService = MockAnalysisService()
    
    var body: some View {
        NavigationView {
            ZStack {
                if isLoading {
                    loadingView
                } else if let errorMessage = errorMessage {
                    errorView(errorMessage)
                } else if let result = analysisResult {
                    resultsView(result)
                }
            }
            .navigationTitle("Analysis Results")
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
            performAnalysis()
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
        VStack(spacing: 20) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 50))
                .foregroundColor(.orange)
            
            Text("Analysis Failed")
                .font(.headline)
            
            Text(message)
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
            
            Button("Try Again") {
                performAnalysis()
            }
            .buttonStyle(.borderedProminent)
        }
        .padding()
    }
    
    private func resultsView(_ result: AnalysisResult) -> some View {
        ScrollView {
            VStack(spacing: 24) {
                // Overall Score
                scoreCard(result.score)
                
                // Feedback Items
                feedbackSection(result.feedback)
                
                // Recording Info
                recordingInfoCard()
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
        
        Task {
            do {
                let result = try await analysisService.analyzeMovement(recording)
                await MainActor.run {
                    self.analysisResult = result
                    self.isLoading = false
                }
            } catch {
                await MainActor.run {
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
        case .excellent:
            return .green
        case .good:
            return .blue
        case .warning:
            return .orange
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
    AnalysisResultsView(
        recording: MovementRecording(
            movementType: .squat,
            videoURL: URL(fileURLWithPath: "/tmp/test.mov"),
            duration: 15.5
        )
    )
}

