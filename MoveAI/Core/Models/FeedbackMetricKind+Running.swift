import Foundation

extension FeedbackMetricKind {
    static let runningCadenceSpm = FeedbackMetricKind(rawValue: "running.cadence_spm")
    static let runningTorsoLeanDegrees = FeedbackMetricKind(rawValue: "running.torso_lean_degrees")
    static let runningVerticalOscillationRatio = FeedbackMetricKind(rawValue: "running.vertical_oscillation_ratio")
    static let runningStrideSymmetryRatio = FeedbackMetricKind(rawValue: "running.stride_symmetry_ratio")
    static let runningOverstrideRatio = FeedbackMetricKind(rawValue: "running.overstride_ratio")
}
