import Foundation

extension MovementIssueKind {
    static let muayThaiJabRearHandDropping = MovementIssueKind(rawValue: "muay_thai.jab.rear_hand_dropping")
    static let muayThaiJabLeaningForward = MovementIssueKind(rawValue: "muay_thai.jab.leaning_forward")
    static let muayThaiJabNoShoulderProtection = MovementIssueKind(rawValue: "muay_thai.jab.no_shoulder_protection")

    static let muayThaiCrossNoHipRotation = MovementIssueKind(rawValue: "muay_thai.cross.no_hip_rotation")
    static let muayThaiCrossRearHeelNotPivoting = MovementIssueKind(rawValue: "muay_thai.cross.rear_heel_not_pivoting")
    static let muayThaiCrossOverreaching = MovementIssueKind(rawValue: "muay_thai.cross.overreaching")

    static let muayThaiLeadHookArmOnly = MovementIssueKind(rawValue: "muay_thai.lead_hook.arm_only_hook")
    static let muayThaiLeadHookTooWide = MovementIssueKind(rawValue: "muay_thai.lead_hook.hook_too_wide")

    static let muayThaiRoundhouseNoSupportFootPivot = MovementIssueKind(rawValue: "muay_thai.roundhouse_kick.no_support_foot_pivot")
    static let muayThaiRoundhouseNoHipTurnover = MovementIssueKind(rawValue: "muay_thai.roundhouse_kick.no_hip_turnover")
    static let muayThaiRoundhouseKickingWithFoot = MovementIssueKind(rawValue: "muay_thai.roundhouse_kick.kicking_with_foot")
    static let muayThaiRoundhouseNoArmCounterbalance = MovementIssueKind(rawValue: "muay_thai.roundhouse_kick.no_arm_counterbalance")

    static let muayThaiTeepNoKneeChamber = MovementIssueKind(rawValue: "muay_thai.teep.no_knee_chamber")
    static let muayThaiTeepFallingForward = MovementIssueKind(rawValue: "muay_thai.teep.falling_forward")

    static let muayThaiStraightKneeTravelVertical = MovementIssueKind(rawValue: "muay_thai.straight_knee.knee_travel_vertical")
    static let muayThaiStraightKneeNoHipThrust = MovementIssueKind(rawValue: "muay_thai.straight_knee.no_hip_thrust")

    static let muayThaiHorizontalElbowTooWide = MovementIssueKind(rawValue: "muay_thai.horizontal_elbow.elbow_too_wide")
    static let muayThaiHorizontalElbowNoBodyRotation = MovementIssueKind(rawValue: "muay_thai.horizontal_elbow.no_body_rotation")

    static let muayThaiMovementCrossingFeet = MovementIssueKind(rawValue: "muay_thai.movement.crossing_feet")
    static let muayThaiMovementFlatFooted = MovementIssueKind(rawValue: "muay_thai.movement.flat_footed")

    static let muayThaiAnalysisCoverageLimited = MovementIssueKind(rawValue: "muay_thai.analysis_coverage_limited")

    static var muayThaiCases: [MovementIssueKind] {
        [
            .muayThaiJabRearHandDropping,
            .muayThaiJabLeaningForward,
            .muayThaiJabNoShoulderProtection,
            .muayThaiCrossNoHipRotation,
            .muayThaiCrossRearHeelNotPivoting,
            .muayThaiCrossOverreaching,
            .muayThaiLeadHookArmOnly,
            .muayThaiLeadHookTooWide,
            .muayThaiRoundhouseNoSupportFootPivot,
            .muayThaiRoundhouseNoHipTurnover,
            .muayThaiRoundhouseKickingWithFoot,
            .muayThaiRoundhouseNoArmCounterbalance,
            .muayThaiTeepNoKneeChamber,
            .muayThaiTeepFallingForward,
            .muayThaiStraightKneeTravelVertical,
            .muayThaiStraightKneeNoHipThrust,
            .muayThaiHorizontalElbowTooWide,
            .muayThaiHorizontalElbowNoBodyRotation,
            .muayThaiMovementCrossingFeet,
            .muayThaiMovementFlatFooted,
            .muayThaiAnalysisCoverageLimited,
        ]
    }
}
