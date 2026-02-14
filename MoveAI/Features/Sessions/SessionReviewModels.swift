import Foundation

enum CoachingCueType: String {
    case action
    case constraint
    case attention
}

struct CoachingCue: Identifiable {
    let id: UUID
    let type: CoachingCueType
    let shortText: String
    let rationale: String?
    
    init(type: CoachingCueType, shortText: String, rationale: String? = nil) {
        self.id = UUID()
        self.type = type
        self.shortText = shortText
        self.rationale = rationale
    }
}

struct IssueOccurrence: Identifiable {
    let id: UUID
    let time: TimeInterval
    let severity: FeedbackSeverity
}

struct IssueSummary: Identifiable {
    let id: UUID
    let title: String
    let category: FeedbackCategory
    let severity: FeedbackSeverity
    let occurrences: [IssueOccurrence]
    let worstOccurrence: IssueOccurrence
    let worstValue: String?
    let cues: [CoachingCue]
    
    var momentsCount: Int { occurrences.count }
}

struct CoachingCueOverlay {
    let title: String
    let severity: FeedbackSeverity
    let cue: CoachingCue
    let rationale: String?
}

struct ReviewMarker: Identifiable {
    let id: UUID
    let issueId: UUID
    let time: TimeInterval
    let severity: FeedbackSeverity
}
