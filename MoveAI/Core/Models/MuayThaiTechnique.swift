import Foundation

enum MuayThaiTechnique: String, CaseIterable, Codable, Identifiable {
    case jab = "jab"
    case cross = "cross"
    case leadHook = "lead_hook"
    case roundhouseKick = "roundhouse_kick"
    case teep = "teep"
    case straightKnee = "straight_knee"
    case horizontalElbow = "horizontal_elbow"
    case movement = "movement"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .jab:
            return "Jab"
        case .cross:
            return "Cross"
        case .leadHook:
            return "Lead Hook"
        case .roundhouseKick:
            return "Roundhouse Kick"
        case .teep:
            return "Teep"
        case .straightKnee:
            return "Straight Knee"
        case .horizontalElbow:
            return "Horizontal Elbow"
        case .movement:
            return "Footwork"
        }
    }

    /// One-line filming guidance shown in the capture/upload flows. Angles match
    /// the reliability matrix in tasks/muay-thai-warning-flow-plan.md.
    var captureTip: String {
        switch self {
        case .jab, .cross, .leadHook:
            return "Film from your rear-hand side at a slight angle, head to feet in frame."
        case .roundhouseKick:
            return "Film from your support-leg side, head to feet in frame."
        case .teep, .straightKnee:
            return "Film from the side, head to feet in frame."
        case .horizontalElbow:
            return "Film from your rear side at a slight angle, head to feet in frame."
        case .movement:
            return "Film from the front or side with room to move, head to feet in frame."
        }
    }

    /// Capture guidance when no technique is chosen (auto-detect).
    static let autoDetectCaptureTip = "Keep your full body in frame; one primary strike pattern per clip detects best."

    /// How battle-tested this technique's analysis is. `validated` techniques
    /// have labeled-fixture regression coverage
    /// (MoveAITests/TestVideos/muay_thai_labeled_fixtures.json); update this
    /// when new fixtures land so the picker badge stays honest.
    var analysisDepth: MuayThaiAnalysisDepth {
        switch self {
        case .jab, .cross, .roundhouseKick:
            return .validated
        case .leadHook, .teep, .straightKnee, .horizontalElbow, .movement:
            return .early
        }
    }

    var category: MuayThaiTechniqueCategory {
        switch self {
        case .jab, .cross, .leadHook:
            return .punch
        case .roundhouseKick, .teep:
            return .kick
        case .straightKnee:
            return .knee
        case .horizontalElbow:
            return .elbow
        case .movement:
            return .footwork
        }
    }
}

enum MuayThaiAnalysisDepth {
    case validated
    case early
}

enum MuayThaiTechniqueCategory: String, CaseIterable, Codable, Identifiable {
    case punch
    case kick
    case knee
    case elbow
    case footwork

    var id: String { rawValue }

    var displayName: String {
        rawValue.capitalized
    }
}

enum FightStance: String, CaseIterable, Codable, Identifiable {
    case orthodox
    case southpaw
    case unknown

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .orthodox:
            return "Orthodox"
        case .southpaw:
            return "Southpaw"
        case .unknown:
            return "Unknown"
        }
    }
}
