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
    let onSeekToTime: ((TimeInterval) -> Void)?  // Optional callback to scrub video to timestamp (SessionDetailView only)
    
    @State private var analysisResult: AnalysisResult?
    @State private var isLoading = true
    @State private var errorMessage: String?
    @State private var lastError: Error?
    @State private var showScoreInfo = false
    
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme
    
    init(recording: MovementRecording, sessionId: UUID? = nil, sessionManager: SessionManager, existingAnalysisResult: AnalysisResult? = nil, isEmbeddedInSessionDetail: Bool = false, onSeekToTime: ((TimeInterval) -> Void)? = nil) {
        self.recording = recording
        self.sessionId = sessionId
        self.sessionManager = sessionManager
        self.existingAnalysisResult = existingAnalysisResult
        self.isEmbeddedInSessionDetail = isEmbeddedInSessionDetail
        self.onSeekToTime = onSeekToTime
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
        .coachScreenContainer()
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
                    .buttonStyle(CoachPrimaryButtonStyle())
                    .controlSize(.large)
                    
                    Button("Back to Recording") {
                        dismiss()
                    }
                    .buttonStyle(CoachSecondaryButtonStyle())
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
        .background(CoachTheme.Palette.secondarySurface(for: colorScheme))
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
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
        .background(CoachTheme.Palette.secondarySurface(for: colorScheme))
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
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
            VStack(spacing: 28) {
                compactScoreSection(result.score)
                compactRepSummary(result.feedback)
                compactFeedbackSection(result.feedback)
                if !isEmbeddedInSessionDetail {
                    compactRecordingInfo()
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 24)
        }
        .sheet(isPresented: $showScoreInfo) {
            ScoreInfoSheet()
        }
    }
    
    private func compactScoreSection(_ score: Double) -> some View {
        VStack(spacing: 6) {
            Button(action: { showScoreInfo = true }) {
                Text("\(Int(score))")
                    .font(.system(size: 56, weight: .semibold))
                    .foregroundColor(scoreColor(score))
            }
            .buttonStyle(.plain)
            Text("Score")
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
    }
    
    private func compactRepSummary(_ feedback: [FormFeedback]) -> some View {
        let summary = analysisResult?.analysisSummary ?? AnalysisSummaryBuilder.build(
            movementType: recording.movementType,
            feedback: feedback,
            reps: analysisResult?.reps,
            depthMetrics: analysisResult?.depthMetrics
        )

        guard let summary, summary.totalUnits > 0 || summary.warningEvents > 0 else {
            return AnyView(EmptyView())
        }

        return AnyView(
            VStack(alignment: .leading, spacing: 8) {
                Text(summary.unitKind.summaryTitle.uppercased())
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundColor(.secondary)
                Text(compactSummaryText(summary))
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        )
    }

    private func compactSummaryText(_ summary: AnalysisSummary) -> String {
        var text = "\(summary.totalUnits) total  ·  \(summary.goodUnits) good  ·  \(summary.unitsNeedingAttention) need attention"
        if summary.warningEvents > 0 {
            let label = summary.warningEvents == 1 ? "warning" : "warnings"
            text += "  ·  \(summary.warningEvents) \(label)"
        }
        return text
    }

    private func compactFeedbackSection(_ feedback: [FormFeedback]) -> some View {
        let issues = feedback.filter { $0.severity == .warning || $0.severity == .critical }
        let wins = feedback.filter { $0.severity == .excellent || $0.severity == .good }
        if issues.isEmpty && wins.isEmpty { return AnyView(EmptyView()) }
        return AnyView(
            VStack(alignment: .leading, spacing: 12) {
                Text("TOP FIXES")
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundColor(.secondary)
                VStack(alignment: .leading, spacing: 0) {
                    ForEach(issues.prefix(3)) { item in
                        compactFeedbackRow(item)
                        if item.id != issues.prefix(3).last?.id {
                            Divider().padding(.vertical, 8)
                        }
                    }
                    ForEach(wins.prefix(2)) { item in
                        if !issues.prefix(3).isEmpty { Divider().padding(.vertical, 8) }
                        compactFeedbackRow(item)
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        )
    }
    
    private func compactFeedbackRow(_ item: FormFeedback) -> some View {
        let icon: String
        let color: Color
        switch item.severity {
        case .excellent, .good: icon = "checkmark.circle.fill"; color = .green
        case .warning, .critical: icon = "exclamationmark.triangle.fill"; color = .orange
        }
        return HStack(alignment: .top, spacing: 10) {
            Image(systemName: icon)
                .font(.caption)
                .foregroundColor(color)
                .frame(width: 20, alignment: .center)
            VStack(alignment: .leading, spacing: 2) {
                Text(item.message)
                    .font(.subheadline)
                    .foregroundColor(.primary)
                if let onSeek = onSeekToTime, let _ = item.repNumber {
                    Button(action: { onSeek(item.timestamp) }) {
                        Text(formatTimestampForFeedback(item.timestamp))
                            .font(.caption)
                            .foregroundColor(.accentColor)
                    }
                    .buttonStyle(.plain)
                }
            }
            Spacer(minLength: 0)
        }
    }
    
    private func formatTimestampForFeedback(_ t: TimeInterval) -> String {
        let m = Int(t) / 60
        let s = Int(t) % 60
        return String(format: "%d:%02d", m, s)
    }
    
    private func compactRecordingInfo() -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("RECORDING")
                .font(.caption)
                .fontWeight(.medium)
                .foregroundColor(.secondary)
            Text(recording.movementType.displayName)
                .font(.subheadline)
            Text(formatDurationForRecording(recording.duration))
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
    
    private func formatDurationForRecording(_ duration: TimeInterval) -> String {
        let m = Int(duration) / 60
        let s = Int(duration) % 60
        return String(format: "%d:%02d", m, s)
    }
    
    private func calculateRepStatistics(_ feedback: [FormFeedback], reps: [SquatRep]? = nil, depthMetrics: [DepthAnalysis]? = nil) -> (totalReps: Int, goodReps: Int, warningReps: Int) {
        // Use reps array as primary source (since feedback is now aggregated and doesn't have rep numbers)
        guard let reps = reps, !reps.isEmpty else {
            // Fallback: try to get rep numbers from feedback if reps array is not available (legacy support)
            let repNumbers = Set(feedback.compactMap { $0.repNumber })
            let totalReps = repNumbers.count
            if totalReps > 0 {
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
            return (totalReps: 0, goodReps: 0, warningReps: 0)
        }
        
        let totalReps = reps.count
        var goodReps = 0
        var warningReps = 0
        
        // Group depth metrics by rep number (there can be multiple metrics per rep - one per frame)
        let depthByRep: [Int: [DepthAnalysis]] = Dictionary(
            grouping: (depthMetrics ?? []).compactMap { metric -> DepthAnalysis? in
                guard metric.repNumber != nil else { return nil }
                return metric
            },
            by: { $0.repNumber! }
        )
        
        // Categorize reps based on whether they're full reps AND reached proper depth
        // A rep needs attention if:
        // 1. It's not a full rep (didn't complete full range of motion), OR
        // 2. It didn't reach proper depth (isAtDepth=false from depth metrics)
        for rep in reps {
            // Check if rep reached proper depth using depth metrics
            // Use the deepest point (maximum depthPercentage) - this is the bottom of the rep
            var reachedProperDepth = true
            if let repDepthMetrics = depthByRep[rep.repNumber], !repDepthMetrics.isEmpty {
                // Find the deepest point (where depthPercentage is maximum)
                if let deepestPoint = repDepthMetrics.max(by: { $0.depthPercentage < $1.depthPercentage }) {
                    reachedProperDepth = deepestPoint.isAtDepth
                }
            }
            
            // Rep needs attention if it's incomplete OR shallow
            if rep.isFullRep && reachedProperDepth {
                goodReps += 1
            } else {
                warningReps += 1
            }
        }
        
        return (totalReps: totalReps, goodReps: goodReps, warningReps: warningReps)
    }
    
    @State private var expandedCategories: [FeedbackCategory: Bool] = [:]
    
    private func feedbackSection(_ feedback: [FormFeedback]) -> some View {
        let grouped = Dictionary(grouping: feedback, by: { $0.category })
        
        return VStack(alignment: .leading, spacing: 16) {
            Text("Form Feedback")
                .font(.headline)
            
            ForEach(FeedbackCategory.allCases, id: \.self) { category in
                if let categoryFeedback = grouped[category], !categoryFeedback.isEmpty {
                    DisclosureGroup(
                        isExpanded: Binding(
                            get: { expandedCategories[category] ?? false },
                            set: { expandedCategories[category] = $0 }
                        )
                    ) {
                        VStack(alignment: .leading, spacing: 8) {
                            ForEach(categoryFeedback) { item in
                                FeedbackCard(feedback: item, onSeekToTime: onSeekToTime)
                            }
                        }
                        .padding(.leading, 8)
                    } label: {
                        HStack {
                            Image(systemName: category.icon)
                                .foregroundColor(categoryColor(categoryFeedback))
                                .frame(width: 24)
                            
                            Text(category.displayName)
                                .font(.subheadline)
                                .fontWeight(.medium)
                            
                            Spacer()
                            
                            Text("(\(categoryFeedback.count))")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                }
            }
        }
    }
    
    private func categoryColor(_ feedback: [FormFeedback]) -> Color {
        // Use the worst severity color for the category icon
        let worstSeverity = feedback.map { $0.severity }.max { severity1, severity2 in
            switch (severity1, severity2) {
            case (.critical, _): return false
            case (_, .critical): return true
            case (.warning, _): return false
            case (_, .warning): return true
            case (.good, _): return false
            case (_, .good): return true
            case (.excellent, _): return false
            }
        }
        
        switch worstSeverity {
        case .excellent, .good:
            return .green
        case .warning:
            return .orange
        case .critical:
            return .red
        case .none:
            return .gray  // Default color when no severity found
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
        .background(CoachTheme.Palette.secondarySurface(for: colorScheme))
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
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
                                technique: existingSession.technique,
                                fightStance: existingSession.fightStance,
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

struct ScoreInfoSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    // Introduction
                    VStack(alignment: .leading, spacing: 8) {
                        Text("How Your Score is Calculated")
                            .font(.title2)
                            .fontWeight(.bold)
                        
                        Text("Your overall score (0-100) is the average of all rep scores. Each rep starts at 100 points and penalties are subtracted based on form quality.")
                            .font(.body)
                            .foregroundColor(.secondary)
                    }
                    
                    // Calculation Method
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Calculation Method")
                            .font(.headline)
                        
                        HStack(alignment: .top, spacing: 8) {
                            Text("•")
                                .foregroundColor(.blue)
                            Text("Each rep is scored individually (0-100)")
                        }
                        
                        HStack(alignment: .top, spacing: 8) {
                            Text("•")
                                .foregroundColor(.blue)
                            Text("Overall score = Average of all rep scores")
                        }
                        
                        HStack(alignment: .top, spacing: 8) {
                            Text("•")
                                .foregroundColor(.blue)
                            Text("Example: Rep 1 (70) + Rep 2 (90) = 80 overall")
                        }
                    }
                    .padding()
                    .background(CoachTheme.Palette.secondarySurface(for: colorScheme))
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    
                    // Factors Considered
                    VStack(alignment: .leading, spacing: 16) {
                        Text("Factors Considered")
                            .font(.headline)
                        
                        // Range of Motion
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Image(systemName: "arrow.up.arrow.down")
                                    .foregroundColor(.orange)
                                Text("Range of Motion")
                                    .font(.subheadline)
                                    .fontWeight(.semibold)
                            }
                            
                            Text("Incomplete rep (doesn't return to start): -20 points")
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .padding(.leading, 24)
                        }
                        
                        Divider()
                        
                        // Depth
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Image(systemName: "arrow.down.circle")
                                    .foregroundColor(.blue)
                                Text("Depth")
                                    .font(.subheadline)
                                    .fontWeight(.semibold)
                            }
                            
                            VStack(alignment: .leading, spacing: 4) {
                                Text("• Excellent depth (hip below knee): No penalty")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                Text("• Good depth (>80%): -5 points")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                Text("• Moderate depth (60-80%): -15 points")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                Text("• Shallow depth (<60%): -30 points")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            .padding(.leading, 24)
                        }
                        
                        Divider()
                        
                        // Knee Tracking
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Image(systemName: "figure.walk")
                                    .foregroundColor(.green)
                                Text("Knee Tracking")
                                    .font(.subheadline)
                                    .fontWeight(.semibold)
                            }
                            
                            Text("Knees caving inward (valgus): -20 points")
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .padding(.leading, 24)
                        }
                        
                        Divider()
                        
                        // Back Position
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Image(systemName: "figure.walk")
                                    .foregroundColor(.red)
                                Text("Back Position")
                                    .font(.subheadline)
                                    .fontWeight(.semibold)
                            }
                            
                            VStack(alignment: .leading, spacing: 4) {
                                Text("• Mild back rounding: -10 points")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                Text("• Moderate back rounding: -25 points")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                Text("• Severe back rounding: -40 points")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            .padding(.leading, 24)
                        }
                    }
                    .padding()
                    .background(CoachTheme.Palette.secondarySurface(for: colorScheme))
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    
                    // Example
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Example Calculation")
                            .font(.headline)
                        
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Rep 1:")
                                .font(.subheadline)
                                .fontWeight(.semibold)
                            Text("  100 (start) - 20 (incomplete) - 10 (mild back rounding) = 70")
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .padding(.leading, 12)
                            
                            Text("Rep 2:")
                                .font(.subheadline)
                                .fontWeight(.semibold)
                            Text("  100 (start) - 5 (good depth) = 95")
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .padding(.leading, 12)
                            
                            Divider()
                            
                            Text("Overall Score: (70 + 95) ÷ 2 = 82.5")
                                .font(.subheadline)
                                .fontWeight(.semibold)
                                .foregroundColor(.blue)
                        }
                    }
                    .padding()
                    .background(CoachTheme.Palette.secondarySurface(for: colorScheme))
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                }
                .padding()
            }
            .navigationTitle("Score Information")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
}

struct FeedbackCard: View {
    let feedback: FormFeedback
    @Environment(\.colorScheme) private var colorScheme
    var onSeekToTime: ((TimeInterval) -> Void)? = nil
    
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: feedback.category.icon)
                .foregroundColor(severityColor)
                .frame(width: 24)
            
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(feedback.repNumber != nil ? "\(feedback.category.displayName) (Rep \(feedback.repNumber!))" : feedback.category.displayName)
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
                
                // Only show timestamp for rep-specific feedback (not aggregated)
                // When onSeekToTime is provided, make it a tappable link to scrub video
                if feedback.repNumber != nil {
                    if let onSeekToTime = onSeekToTime {
                        Button(action: { onSeekToTime(feedback.timestamp) }) {
                            Text("at \(formatTimestamp(feedback.timestamp))")
                                .font(.caption)
                                .foregroundColor(.accentColor)
                                .underline()
                        }
                        .buttonStyle(.plain)
                    } else {
                        Text("at \(formatTimestamp(feedback.timestamp))")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }
        }
        .padding()
        .background(CoachTheme.Palette.secondarySurface(for: colorScheme))
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
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

