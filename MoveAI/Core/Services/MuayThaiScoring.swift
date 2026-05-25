import Foundation

enum MuayThaiScoring {
    static func score(feedback: [FormFeedback], attemptsCount: Int) -> Double {
        let attempts = max(attemptsCount, 1)

        let penalty = feedback.reduce(0.0) { partial, item in
            guard item.issueKind != .muayThaiAnalysisCoverageLimited,
                  item.issueKind != .muayThaiCaptureQualityLimited else {
                return partial
            }

            switch item.severity {
            case .critical:
                return partial + 12.0
            case .warning:
                return partial + 6.0
            case .good, .excellent:
                return partial
            }
        }

        let normalizedPenalty = penalty / Double(attempts)
        return max(0, min(100, 100 - normalizedPenalty))
    }
}
