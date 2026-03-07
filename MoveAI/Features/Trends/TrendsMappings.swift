import Foundation

enum MovementQualityDimension: String, CaseIterable, Identifiable {
    case balance
    case depth
    case kneeTracking
    case torsoControl
    case footStability

    var id: String { rawValue }

    var title: String {
        switch self {
        case .balance:
            return "Balance"
        case .depth:
            return "Depth"
        case .kneeTracking:
            return "Knee Tracking"
        case .torsoControl:
            return "Torso Control"
        case .footStability:
            return "Foot Stability"
        }
    }
}

struct TrendsIssueMetadata {
    let impactStatement: String
    let targetGoal: String
    let frequencyRecommendation: String
    let dimensions: [MovementQualityDimension]
}

enum TrendsMappings {
    static func metadata(for kind: MovementIssueKind) -> TrendsIssueMetadata {
        switch kind {
        case .squatHeelsLift:
            return TrendsIssueMetadata(
                impactStatement: "Can reduce depth consistency and shift pressure forward.",
                targetGoal: "Keep full-foot pressure through descent and bottom.",
                frequencyRecommendation: "3x/week before squat sessions",
                dimensions: [.balance, .depth, .footStability]
            )
        case .squatKneeValgus:
            return TrendsIssueMetadata(
                impactStatement: "Can affect knee tracking and load distribution under fatigue.",
                targetGoal: "Track knees over 2nd/3rd toe through the full rep.",
                frequencyRecommendation: "3x/week on lower-body days",
                dimensions: [.kneeTracking, .balance, .footStability]
            )
        case .squatForwardLean:
            return TrendsIssueMetadata(
                impactStatement: "Can reduce bracing quality and transfer load away from quads.",
                targetGoal: "Maintain torso angle and brace out of the hole.",
                frequencyRecommendation: "2-3x/week in warm-up or accessories",
                dimensions: [.torsoControl, .balance]
            )
        case .squatButtWink:
            return TrendsIssueMetadata(
                impactStatement: "Can reduce bottom-position stability and repeatability.",
                targetGoal: "Hit controllable depth with a stable pelvis.",
                frequencyRecommendation: "2-3x/week with tempo/paused work",
                dimensions: [.depth, .torsoControl]
            )
        case .squatHipShift:
            return TrendsIssueMetadata(
                impactStatement: "Can overload one side and reduce force symmetry.",
                targetGoal: "Stay centered with even pressure through both feet.",
                frequencyRecommendation: "3x/week with unilateral accessories",
                dimensions: [.balance, .kneeTracking]
            )
        case .squatBraceLeak:
            return TrendsIssueMetadata(
                impactStatement: "Can reduce trunk stiffness and movement consistency under load.",
                targetGoal: "Create a 360-degree brace before each rep.",
                frequencyRecommendation: "2-3x/week plus pre-set breathing reps",
                dimensions: [.torsoControl]
            )
        case .squatKneesStayedBack:
            return TrendsIssueMetadata(
                impactStatement: "Can limit depth and shift the squat into an inefficient hinge pattern.",
                targetGoal: "Allow controlled knee travel while keeping full-foot contact.",
                frequencyRecommendation: "3x/week in warm-up sets",
                dimensions: [.depth, .footStability]
            )
        case .squatFootCollapse:
            return TrendsIssueMetadata(
                impactStatement: "Can increase instability and contribute to knee drift.",
                targetGoal: "Maintain a stable tripod foot throughout the rep.",
                frequencyRecommendation: "3x/week before lower-body sessions",
                dimensions: [.footStability, .kneeTracking, .balance]
            )
        case .squatDepthTooShallow:
            return TrendsIssueMetadata(
                impactStatement: "Can reduce training stimulus and squat carryover.",
                targetGoal: "Reach repeatable target depth each rep.",
                frequencyRecommendation: "2-3x/week with depth-target drills",
                dimensions: [.depth]
            )
        case .squatIncompleteROM:
            return TrendsIssueMetadata(
                impactStatement: "Can reduce quality per rep and slow skill progression.",
                targetGoal: "Complete full ROM: controlled depth and full stand.",
                frequencyRecommendation: "2-3x/week with tempo control",
                dimensions: [.depth]
            )
        case .squatDepthInconsistent:
            return TrendsIssueMetadata(
                impactStatement: "Can make progress harder to measure and repeat.",
                targetGoal: "Match bottom position consistently rep to rep.",
                frequencyRecommendation: "2-3x/week with paused squat sets",
                dimensions: [.depth, .balance]
            )
        case .squatCameraAngleLimited:
            return TrendsIssueMetadata(
                impactStatement: "Limits analysis reliability and trend confidence.",
                targetGoal: "Capture full body from stable side or front angle.",
                frequencyRecommendation: "Every session",
                dimensions: [.balance, .depth, .kneeTracking, .torsoControl, .footStability]
            )
        default:
            return TrendsIssueMetadata(
                impactStatement: "A recurring movement pattern is reducing form quality.",
                targetGoal: "Improve control in this movement pattern.",
                frequencyRecommendation: "2-3x/week",
                dimensions: [.balance]
            )
        }
    }

    static func dimensions(for kind: MovementIssueKind) -> [MovementQualityDimension] {
        metadata(for: kind).dimensions
    }

    static func impactStatement(for kind: MovementIssueKind) -> String {
        metadata(for: kind).impactStatement
    }

    static func targetGoal(for kind: MovementIssueKind) -> String {
        metadata(for: kind).targetGoal
    }

    static func frequencyRecommendation(for kind: MovementIssueKind) -> String {
        metadata(for: kind).frequencyRecommendation
    }
}
