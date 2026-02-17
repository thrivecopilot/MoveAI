import Foundation

@MainActor
final class SessionReviewViewModel: ObservableObject {
    @Published var currentTime: Double = 0
    @Published var currentFrameIndex: Int = 0
    @Published var isPlaying: Bool = false
    
    @Published var showSkeleton = false
    @Published var showAngles = false
    @Published var showPaths = false
    
    @Published var selectedIssueId: UUID?
    @Published var selectedOccurrenceId: UUID?
    
    @Published private(set) var issues: [IssueSummary] = []
    
    init(analysisResult: AnalysisResult?) {
        setAnalysisResult(analysisResult)
    }
    
    func setAnalysisResult(_ result: AnalysisResult?) {
        guard let result else {
            issues = []
            return
        }
        issues = IssueSummaryBuilder.from(result.feedback)
    }
    
    func updatePlayback(currentTime: Double, isPlaying: Bool, fps: Double) {
        self.currentTime = currentTime
        self.isPlaying = isPlaying
        self.currentFrameIndex = Int(round(currentTime * fps))
    }
    
    func seek(to time: Double, fps: Double) {
        currentTime = time
        currentFrameIndex = Int(round(time * fps))
    }
    
    func selectIssue(_ issue: IssueSummary) {
        selectedIssueId = issue.id
        selectedOccurrenceId = issue.worstOccurrence.id
    }
    
    func selectOccurrence(_ occurrence: IssueOccurrence, issueId: UUID) {
        selectedIssueId = issueId
        selectedOccurrenceId = occurrence.id
    }
    
    func occurrence(at time: TimeInterval, tolerance: TimeInterval) -> (issue: IssueSummary, occurrence: IssueOccurrence)? {
        for issue in issues {
            if let occ = issue.occurrences.first(where: { abs($0.time - time) <= tolerance }) {
                return (issue, occ)
            }
        }
        return nil
    }
    
    func markers() -> [ReviewMarker] {
        issues.flatMap { issue in
            issue.occurrences.map { occ in
                ReviewMarker(id: occ.id, issueId: issue.id, time: occ.time, severity: occ.severity)
            }
        }
        .sorted { $0.time < $1.time }
    }
    
    func highlightedMarkerIds() -> Set<UUID> {
        guard let selectedIssueId else { return [] }
        return Set(markers().filter { $0.issueId == selectedIssueId }.map(\.id))
    }
    
    func cueOverlay(for issue: IssueSummary) -> CoachingCueOverlay? {
        guard let cue = pickCue(for: issue) else { return nil }
        return CoachingCueOverlay(
            title: issue.title,
            severity: issue.severity,
            cue: cue,
            rationale: cue.rationale
        )
    }
    
    func cueOverlay(for issue: IssueSummary, occurrence: IssueOccurrence) -> CoachingCueOverlay? {
        guard let cue = pickCue(for: issue) else { return nil }
        return CoachingCueOverlay(
            title: issue.title,
            severity: occurrence.severity,
            cue: cue,
            rationale: cue.rationale
        )
    }
    
    private func pickCue(for issue: IssueSummary) -> CoachingCue? {
        switch issue.severity {
        case .warning, .critical:
            if let constraint = issue.cues.first(where: { $0.type == .constraint }) {
                return constraint
            }
            return issue.cues.first(where: { $0.type == .action }) ?? issue.cues.first
        case .good, .excellent:
            return nil
        }
    }
}

enum IssueSummaryBuilder {
    static func from(_ feedback: [FormFeedback]) -> [IssueSummary] {
        let grouped = Dictionary(grouping: feedback) { item in
            "\(item.category.rawValue)|\(item.message)|\(item.severity.rawValue)"
        }
        
        let issues = grouped.compactMap { _, items -> IssueSummary? in
            guard let first = items.first else { return nil }
            let occurrences = items.map {
                IssueOccurrence(
                    id: $0.id,
                    time: $0.timestamp,
                    severity: $0.severity,
                    affectedBodyJoints: $0.affectedBodyJoints ?? []
                )
            }
            .sorted { $0.time < $1.time }
            
            let worst = occurrences.max { a, b in
                severityOrder(a.severity) < severityOrder(b.severity)
            } ?? occurrences.first
            
            let cues = defaultCues(for: first)
            
            return IssueSummary(
                id: first.id,
                title: first.message,
                category: first.category,
                severity: first.severity,
                occurrences: occurrences,
                worstOccurrence: worst ?? occurrences.first!,
                worstValue: nil,
                cues: cues
            )
        }
        
        return issues.sorted { severityOrder($0.severity) > severityOrder($1.severity) }
    }
    
    private static func defaultCues(for feedback: FormFeedback) -> [CoachingCue] {
        switch feedback.severity {
        case .warning, .critical:
            return [
                CoachingCue(type: .constraint, shortText: feedback.message)
            ]
        case .good, .excellent:
            return []
        }
    }
    
    private static func severityOrder(_ s: FeedbackSeverity) -> Int {
        switch s {
        case .critical: return 4
        case .warning:  return 3
        case .good:     return 2
        case .excellent: return 1
        }
    }
}
