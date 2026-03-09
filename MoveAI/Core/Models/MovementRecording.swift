//
//  MovementRecording.swift
//  MoveAI
//
//  Created by Dave Mathew on 10/11/25.
//

import Foundation
import UIKit

struct MovementRecording: Identifiable, Codable {
    let id: UUID
    let movementType: MovementType
    let technique: MuayThaiTechnique?
    let fightStance: FightStance?
    let videoURL: URL
    let timestamp: Date
    let duration: TimeInterval
    let poseData: [PoseDetectionResult]?
    var analysisResult: AnalysisResult?

    init(
        movementType: MovementType,
        technique: MuayThaiTechnique? = nil,
        fightStance: FightStance? = nil,
        videoURL: URL,
        duration: TimeInterval,
        poseData: [PoseDetectionResult]? = nil
    ) {
        self.id = UUID()
        self.movementType = movementType
        self.technique = technique
        self.fightStance = fightStance
        self.videoURL = videoURL
        self.timestamp = Date()
        self.duration = duration
        self.poseData = poseData
        self.analysisResult = nil
    }
}

struct AnalysisResult: Codable {
    let score: Double // 0-100 overall form score
    let feedback: [FormFeedback]
    let timestamp: Date
    let reps: [SquatRep]? // Optional for backward compatibility
    let depthMetrics: [DepthAnalysis]? // Optional depth metrics for shallow rep detection

    init(score: Double, feedback: [FormFeedback], reps: [SquatRep]? = nil, depthMetrics: [DepthAnalysis]? = nil) {
        self.score = score
        self.feedback = feedback
        self.timestamp = Date()
        self.reps = reps
        self.depthMetrics = depthMetrics
    }
}

/// Stable issue identifier for coaching content (cues/correctives/UI), independent of analyzer message strings.
///
/// Notes:
/// - Backward compatible: optional on `FormFeedback`.
/// - Forward compatible: decodes unknown raw values without failing the overall decode.
struct MovementIssueKind: RawRepresentable, Codable, Hashable, CaseIterable {
    let rawValue: String

    init(rawValue: String) {
        self.rawValue = rawValue
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        self.rawValue = try container.decode(String.self)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(rawValue)
    }

    // MARK: - Squat
    static let squatKneeValgus = MovementIssueKind(rawValue: "squat.knee_valgus")
    static let squatHeelsLift = MovementIssueKind(rawValue: "squat.heels_lift")
    static let squatForwardLean = MovementIssueKind(rawValue: "squat.forward_lean")
    static let squatButtWink = MovementIssueKind(rawValue: "squat.butt_wink")
    static let squatHipShift = MovementIssueKind(rawValue: "squat.hip_shift")
    static let squatBraceLeak = MovementIssueKind(rawValue: "squat.brace_leak")
    static let squatKneesStayedBack = MovementIssueKind(rawValue: "squat.knees_stayed_back")
    static let squatFootCollapse = MovementIssueKind(rawValue: "squat.foot_collapse")
    static let squatDepthTooShallow = MovementIssueKind(rawValue: "squat.depth_too_shallow")
    static let squatIncompleteROM = MovementIssueKind(rawValue: "squat.incomplete_rom")
    static let squatDepthInconsistent = MovementIssueKind(rawValue: "squat.depth_inconsistent")
    static let squatCameraAngleLimited = MovementIssueKind(rawValue: "squat.camera_angle_limited")

    static var squatCases: [MovementIssueKind] {
        [
            .squatKneeValgus,
            .squatHeelsLift,
            .squatForwardLean,
            .squatButtWink,
            .squatHipShift,
            .squatBraceLeak,
            .squatKneesStayedBack,
            .squatFootCollapse,
            .squatDepthTooShallow,
            .squatIncompleteROM,
            .squatDepthInconsistent,
            .squatCameraAngleLimited,
        ]
    }

    static var allCases: [MovementIssueKind] {
        squatCases + muayThaiCases
    }

    var isSquatIssue: Bool {
        rawValue.hasPrefix("squat.")
    }

    var isMuayThaiIssue: Bool {
        rawValue.hasPrefix("muay_thai.")
    }
}

/// Structured measurement attached to a feedback item (e.g. torso bias degrees).
///
/// Stored as forward-compatible raw identifiers so adding new metric kinds does not break decoding.
struct FeedbackMetricKind: RawRepresentable, Codable, Hashable {
    let rawValue: String

    init(rawValue: String) {
        self.rawValue = rawValue
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        self.rawValue = try container.decode(String.self)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(rawValue)
    }

    // MARK: - Squat
    static let squatTorsoBiasDegrees = FeedbackMetricKind(rawValue: "squat.torso_bias_degrees")
    static let squatTorsoInstabilityDegrees = FeedbackMetricKind(rawValue: "squat.torso_instability_degrees")
    static let squatBalanceDriftShinLengths = FeedbackMetricKind(rawValue: "squat.balance_drift_shin_lengths")
}

enum FeedbackMetricUnit: String, Codable {
    case degrees
    case shinLengths
    case percent
    case ratio
    case count
    case unknown

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let raw = (try? container.decode(String.self)) ?? "unknown"
        self = FeedbackMetricUnit(rawValue: raw) ?? .unknown
    }
}

struct FeedbackMetric: Codable, Hashable {
    let kind: FeedbackMetricKind
    let value: Double
    let unit: FeedbackMetricUnit
    let phase: SquatPhaseType?
    let notes: String?

    init(kind: FeedbackMetricKind, value: Double, unit: FeedbackMetricUnit, phase: SquatPhaseType? = nil, notes: String? = nil) {
        self.kind = kind
        self.value = value
        self.unit = unit
        self.phase = phase
        self.notes = notes
    }
}

struct FormFeedback: Codable, Identifiable {
    let id: UUID
    let category: FeedbackCategory
    let message: String
    let issueKind: MovementIssueKind?
    let metrics: [FeedbackMetric]?
    let severity: FeedbackSeverity
    let timestamp: TimeInterval // When in the video this applies
    let repNumber: Int? // Which rep this feedback applies to (1-indexed)
    let affectedBodyJoints: [BodyJoint]? // Body joints affected by this feedback

    init(category: FeedbackCategory, message: String, severity: FeedbackSeverity, timestamp: TimeInterval, repNumber: Int? = nil, issueKind: MovementIssueKind? = nil, metrics: [FeedbackMetric]? = nil, affectedBodyJoints: [BodyJoint]? = nil) {
        self.id = UUID()
        self.category = category
        self.message = message
        self.issueKind = issueKind
        self.metrics = metrics
        self.severity = severity
        self.timestamp = timestamp
        self.repNumber = repNumber
        self.affectedBodyJoints = affectedBodyJoints
    }
}

enum FeedbackCategory: String, CaseIterable, Codable {
    case posture = "posture"
    case rangeOfMotion = "range_of_motion"
    case tempo = "tempo"
    case stability = "stability"
    case safety = "safety"

    var displayName: String {
        switch self {
        case .posture:
            return "Posture"
        case .rangeOfMotion:
            return "Range of Motion"
        case .tempo:
            return "Tempo"
        case .stability:
            return "Stability"
        case .safety:
            return "Safety"
        }
    }

    var icon: String {
        switch self {
        case .posture:
            return "figure.walk"
        case .rangeOfMotion:
            return "arrow.up.arrow.down"
        case .tempo:
            return "metronome"
        case .stability:
            return "balance"
        case .safety:
            return "exclamationmark.triangle"
        }
    }
}

enum FeedbackSeverity: String, CaseIterable, Codable {
    case excellent = "excellent"
    case good = "good"
    case warning = "warning"
    case critical = "critical"

    var displayName: String {
        switch self {
        case .excellent:
            return "Excellent"
        case .good:
            return "Good"
        case .warning:
            return "Needs Improvement"
        case .critical:
            return "Critical Issue"
        }
    }

    var color: String {
        switch self {
        case .excellent:
            return "green"
        case .good:
            return "blue"
        case .warning:
            return "orange"
        case .critical:
            return "red"
        }
    }
}
