import Foundation

extension MovementIssueKind {
    static let runningLowCadence = MovementIssueKind(rawValue: "running.cadence.low")
    static let runningExcessiveForwardLean = MovementIssueKind(rawValue: "running.posture.excessive_forward_lean")
    static let runningExcessiveVerticalOscillation = MovementIssueKind(rawValue: "running.posture.excessive_vertical_oscillation")
    static let runningAsymmetricStride = MovementIssueKind(rawValue: "running.stride.asymmetry")
    static let runningOverstriding = MovementIssueKind(rawValue: "running.stride.overstriding")
    static let runningCaptureQualityLimited = MovementIssueKind(rawValue: "running.capture_quality_limited")

    static var runningCases: [MovementIssueKind] {
        [
            .runningLowCadence,
            .runningExcessiveForwardLean,
            .runningExcessiveVerticalOscillation,
            .runningAsymmetricStride,
            .runningOverstriding,
            .runningCaptureQualityLimited,
        ]
    }
}
