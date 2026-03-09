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
            return "Movement"
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
