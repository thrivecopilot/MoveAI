import Foundation

enum PoseOverlayHighlighting {
    static func activeHighlightedJoints(
        feedback: [FormFeedback],
        at time: TimeInterval,
        tolerance: TimeInterval = 0.2
    ) -> [BodyJoint: FeedbackSeverity] {
        var highlighted: [BodyJoint: FeedbackSeverity] = [:]

        for item in feedback {
            guard item.severity == .warning || item.severity == .critical else { continue }
            guard abs(item.timestamp - time) <= tolerance else { continue }
            guard let joints = item.affectedBodyJoints, !joints.isEmpty else { continue }

            for joint in joints {
                if let existing = highlighted[joint] {
                    // Precedence: critical > warning
                    if existing == .warning && item.severity == .critical {
                        highlighted[joint] = .critical
                    }
                } else {
                    highlighted[joint] = item.severity
                }
            }
        }

        return highlighted
    }
}
