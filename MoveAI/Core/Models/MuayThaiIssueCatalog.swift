import Foundation

enum MuayThaiDetectionSupport: String, Codable {
    case supported
    case partial
    case blocked
}

struct MuayThaiIssueCatalogEntry: Hashable {
    let technique: MuayThaiTechnique
    let category: MuayThaiTechniqueCategory
    let phase: String
    let issueKind: MovementIssueKind
    let description: String
    let poseDetectionHints: [String]
    let severity: FeedbackSeverity
    let cueShort: String
    let cueDetailed: String
    let recommendedDrills: [String]
    let detectionSupport: MuayThaiDetectionSupport
}

enum MuayThaiIssueCatalog {
    static let entries: [MuayThaiIssueCatalogEntry] = [
        make(
            technique: .jab,
            category: .punch,
            phase: "extension",
            issueKind: .muayThaiJabRearHandDropping,
            description: "rear hand leaves guard position during jab exposing the chin",
            hints: [
                "rear_wrist_below_chin",
                "rear_elbow_far_from_ribs",
                "rear_hand_distance_from_head > threshold"
            ],
            severity: "high",
            cueShort: "keep your rear hand on your cheek",
            cueDetailed: "your rear hand dropped during the jab. keep it glued to your cheek to protect your chin",
            drills: ["jab_shadowboxing_guard_check", "mirror_jab_drill"],
            support: .supported
        ),
        make(
            technique: .jab,
            category: .punch,
            phase: "extension",
            issueKind: .muayThaiPostureForwardOverBase,
            description: "head and torso drift too far forward over stance base during the strike",
            hints: [
                "head_advances_past_lead_base",
                "torso_angle_forward > threshold",
                "center_of_mass_beyond_support_base"
            ],
            severity: "medium",
            cueShort: "stay stacked over your base",
            cueDetailed: "keep your head and torso stacked over your stance as you strike. step in before extending if you're out of range",
            drills: ["slow_shadow_jab", "range_control_shadowboxing"],
            support: .supported
        ),
        make(
            technique: .jab,
            category: .punch,
            phase: "retraction",
            issueKind: .muayThaiJabPoorRetraction,
            description: "jab does not snap back quickly, leaving the hand extended",
            hints: [
                "end_extension_remains_high",
                "retraction_velocity_low",
                "striking_hand_lingers_after_peak"
            ],
            severity: "medium",
            cueShort: "snap your jab back to guard",
            cueDetailed: "your jab is pushing instead of snapping. pull it back quickly after extension to reset your defense",
            drills: ["snap_jab_return_drill", "double_jab_touch_and_return"],
            support: .supported
        ),
        make(
            technique: .cross,
            category: .punch,
            phase: "rotation",
            issueKind: .muayThaiCrossNoHipRotation,
            description: "cross thrown with the arm only without engaging hips",
            hints: [
                "hip_rotation < 15deg",
                "shoulder_rotation_small",
                "rear_knee_direction_unchanged"
            ],
            severity: "high",
            cueShort: "turn your hip through the punch",
            cueDetailed: "generate power by rotating your hips and shoulders together",
            drills: ["medicine_ball_rotational_throw", "slow_cross_shadowboxing"],
            support: .supported
        ),
        make(
            technique: .cross,
            category: .punch,
            phase: "rotation",
            issueKind: .muayThaiCrossRearHeelNotPivoting,
            description: "rear foot stays planted preventing full rotation",
            hints: ["rear_foot_angle_constant", "rear_heel_flat"],
            severity: "high",
            cueShort: "pivot your back foot",
            cueDetailed: "rotate on the ball of your rear foot when throwing the cross",
            drills: ["rear_foot_pivot_drill"],
            support: .blocked
        ),
        make(
            technique: .cross,
            category: .punch,
            phase: "extension",
            issueKind: .muayThaiPostureForwardOverBase,
            description: "head and torso drift too far forward over stance base during the strike",
            hints: [
                "head_advances_past_lead_base",
                "torso_angle_forward > threshold",
                "center_of_mass_beyond_support_base"
            ],
            severity: "medium",
            cueShort: "stay stacked over your base",
            cueDetailed: "keep your head and torso stacked over your stance as you strike. step in before extending if you're out of range",
            drills: ["slow_shadow_jab", "range_control_shadowboxing"],
            support: .partial
        ),
        make(
            technique: .leadHook,
            category: .punch,
            phase: "rotation",
            issueKind: .muayThaiLeadHookArmOnly,
            description: "hook thrown with the arm without hip rotation",
            hints: [
                "shoulder_rotation_small",
                "hip_rotation_small",
                "elbow_moves_independent_of_torso"
            ],
            severity: "medium",
            cueShort: "throw the hook with your hips",
            cueDetailed: "generate hook power by rotating your hips and shoulders",
            drills: ["hook_rotation_shadowboxing"],
            support: .supported
        ),
        make(
            technique: .leadHook,
            category: .punch,
            phase: "extension",
            issueKind: .muayThaiLeadHookTooWide,
            description: "hook travels in a wide arc reducing speed",
            hints: ["elbow_arc_large", "hand_path_outside_shoulder_line"],
            severity: "medium",
            cueShort: "keep your hook tight",
            cueDetailed: "shorten the arc of the hook to increase speed and protection",
            drills: ["tight_hook_pad_drill"],
            support: .supported
        ),
        make(
            technique: .roundhouseKick,
            category: .kick,
            phase: "rotation",
            issueKind: .muayThaiRoundhouseNoSupportFootPivot,
            description: "support foot does not pivot preventing hip rotation",
            hints: ["support_foot_angle_change < 10deg", "heel_facing_forward"],
            severity: "high",
            cueShort: "pivot your support foot",
            cueDetailed: "turn your support foot so your heel faces the target during the kick",
            drills: ["kick_pivot_drill", "slow_shadow_kicks"],
            support: .blocked
        ),
        make(
            technique: .roundhouseKick,
            category: .kick,
            phase: "impact",
            issueKind: .muayThaiRoundhouseNoHipTurnover,
            description: "hips fail to rotate fully into the kick",
            hints: ["pelvis_rotation_small", "shoulders_not_following_hips"],
            severity: "high",
            cueShort: "turn your hip over",
            cueDetailed: "rotate your hip fully through the target for power",
            drills: ["hip_rotation_kick_drill"],
            support: .supported
        ),
        make(
            technique: .roundhouseKick,
            category: .kick,
            phase: "impact",
            issueKind: .muayThaiRoundhouseKickingWithFoot,
            description: "kick lands with the foot rather than the shin",
            hints: ["impact_point_near_foot", "shin_not_aligned_with_target"],
            severity: "medium",
            cueShort: "strike with your shin",
            cueDetailed: "make contact with the shin rather than the foot",
            drills: ["shin_contact_heavy_bag"],
            support: .blocked
        ),
        make(
            technique: .roundhouseKick,
            category: .kick,
            phase: "rotation",
            issueKind: .muayThaiRoundhouseNoArmCounterbalance,
            description: "arms do not swing to maintain balance",
            hints: ["lead_arm_static", "arm_angles_constant_during_kick"],
            severity: "medium",
            cueShort: "swing your arm for balance",
            cueDetailed: "use your arms to counterbalance and generate rotational force",
            drills: ["arm_swing_shadow_kicks"],
            support: .supported
        ),
        make(
            technique: .teep,
            category: .kick,
            phase: "chamber",
            issueKind: .muayThaiTeepNoKneeChamber,
            description: "kick begins without lifting the knee first",
            hints: ["knee_lift < hip_height", "leg_extends_directly_from_stance"],
            severity: "medium",
            cueShort: "lift your knee first",
            cueDetailed: "start the teep by lifting your knee before extending the leg",
            drills: ["chamber_hold_drill"],
            support: .supported
        ),
        make(
            technique: .teep,
            category: .kick,
            phase: "extension",
            issueKind: .muayThaiTeepFallingForward,
            description: "torso leans forward during teep",
            hints: ["spine_angle_forward", "head_passes_support_knee"],
            severity: "medium",
            cueShort: "lean back slightly",
            cueDetailed: "lean slightly backward to maintain balance during the teep",
            drills: ["wall_teep_balance"],
            support: .supported
        ),
        make(
            technique: .straightKnee,
            category: .knee,
            phase: "extension",
            issueKind: .muayThaiStraightKneeTravelVertical,
            description: "knee travels upward instead of forward",
            hints: ["knee_vector_vertical", "hip_forward_translation_small"],
            severity: "medium",
            cueShort: "drive your knee forward",
            cueDetailed: "aim your knee forward through the target",
            drills: ["knee_drive_heavy_bag"],
            support: .supported
        ),
        make(
            technique: .straightKnee,
            category: .knee,
            phase: "impact",
            issueKind: .muayThaiStraightKneeNoHipThrust,
            description: "knee strike lacks hip extension",
            hints: ["pelvis_translation_small", "hips_behind_torso"],
            severity: "high",
            cueShort: "thrust your hips",
            cueDetailed: "drive your hips forward into the knee strike",
            drills: ["hip_thrust_knee_drill"],
            support: .supported
        ),
        make(
            technique: .horizontalElbow,
            category: .elbow,
            phase: "extension",
            issueKind: .muayThaiHorizontalElbowTooWide,
            description: "elbow travels in a wide arc",
            hints: ["elbow_arc_large", "path_outside_shoulder_line"],
            severity: "medium",
            cueShort: "keep the elbow tight",
            cueDetailed: "shorten the elbow arc for speed and protection",
            drills: ["tight_elbow_pad_drill"],
            support: .supported
        ),
        make(
            technique: .horizontalElbow,
            category: .elbow,
            phase: "rotation",
            issueKind: .muayThaiHorizontalElbowNoBodyRotation,
            description: "elbow thrown without torso rotation",
            hints: ["shoulder_line_static", "hip_line_static"],
            severity: "medium",
            cueShort: "rotate your body",
            cueDetailed: "generate power by rotating your torso with the elbow",
            drills: ["shadow_elbow_rotation"],
            support: .supported
        ),
        make(
            technique: .movement,
            category: .footwork,
            phase: "movement",
            issueKind: .muayThaiMovementCrossingFeet,
            description: "feet cross during movement causing balance loss",
            hints: ["ankles_cross", "step_path_intersects_stance_line"],
            severity: "high",
            cueShort: "don't cross your feet",
            cueDetailed: "slide your feet while maintaining stance width",
            drills: ["lateral_slide_drill"],
            support: .supported
        ),
        make(
            technique: .movement,
            category: .footwork,
            phase: "movement",
            issueKind: .muayThaiMovementFlatFooted,
            description: "fighter stands heavy on heels reducing mobility",
            hints: ["heels_planted_during_movement"],
            severity: "medium",
            cueShort: "stay light on your feet",
            cueDetailed: "keep weight on the balls of your feet for quicker movement",
            drills: ["bounce_shadowboxing"],
            support: .blocked
        ),
    ]

    static func entry(for kind: MovementIssueKind) -> MuayThaiIssueCatalogEntry? {
        entries.first { $0.issueKind == kind }
    }

    static func entries(for technique: MuayThaiTechnique) -> [MuayThaiIssueCatalogEntry] {
        entries.filter { $0.technique == technique }
    }

    static func blockedEntries(for technique: MuayThaiTechnique) -> [MuayThaiIssueCatalogEntry] {
        entries(for: technique).filter { $0.detectionSupport == .blocked }
    }

    private static func make(
        technique: MuayThaiTechnique,
        category: MuayThaiTechniqueCategory,
        phase: String,
        issueKind: MovementIssueKind,
        description: String,
        hints: [String],
        severity: String,
        cueShort: String,
        cueDetailed: String,
        drills: [String],
        support: MuayThaiDetectionSupport
    ) -> MuayThaiIssueCatalogEntry {
        MuayThaiIssueCatalogEntry(
            technique: technique,
            category: category,
            phase: phase,
            issueKind: issueKind,
            description: description,
            poseDetectionHints: hints,
            severity: severity == "high" ? .critical : .warning,
            cueShort: cueShort,
            cueDetailed: cueDetailed,
            recommendedDrills: drills,
            detectionSupport: support
        )
    }
}
