import Foundation

enum AnalysisSummaryBuilder {
    private static let excludedWarningIssueKinds: Set<MovementIssueKind> = [
        .muayThaiCaptureQualityLimited,
        .muayThaiAnalysisCoverageLimited,
        .squatCameraAngleLimited,
        .runningCaptureQualityLimited,
    ]

    static func build(
        movementType: MovementType,
        feedback: [FormFeedback],
        reps: [SquatRep]?,
        depthMetrics: [DepthAnalysis]?,
        attemptsCount: Int? = nil,
        attemptsNeedingAttention: Int? = nil
    ) -> AnalysisSummary? {
        switch movementType {
        case .muayThai:
            return buildStrikeSummary(
                feedback: feedback,
                attemptsCount: attemptsCount,
                attemptsNeedingAttention: attemptsNeedingAttention
            )
        case .running:
            return buildAttemptSummary(feedback: feedback)
        case .squat, .deadlift, .benchPress:
            return buildRepSummary(
                feedback: feedback,
                reps: reps,
                depthMetrics: depthMetrics
            )
        }
    }

    static func buildLegacy(from result: AnalysisResult) -> AnalysisSummary? {
        if let summary = result.analysisSummary {
            return summary
        }

        return buildRepSummary(
            feedback: result.feedback,
            reps: result.reps,
            depthMetrics: result.depthMetrics
        )
    }

    private static func buildRepSummary(
        feedback: [FormFeedback],
        reps: [SquatRep]?,
        depthMetrics: [DepthAnalysis]?
    ) -> AnalysisSummary? {
        let warningEvents = warningFeedback(from: feedback).count

        if let reps, !reps.isEmpty {
            let depthByRep: [Int: [DepthAnalysis]] = Dictionary(
                grouping: (depthMetrics ?? []).compactMap { metric in
                    guard metric.repNumber != nil else { return nil }
                    return metric
                },
                by: { $0.repNumber! }
            )

            var unitsNeedingAttention = 0
            for rep in reps {
                var reachedProperDepth = true
                if let repDepthMetrics = depthByRep[rep.repNumber],
                   let deepestPoint = repDepthMetrics.max(by: { $0.depthPercentage < $1.depthPercentage }) {
                    reachedProperDepth = deepestPoint.isAtDepth
                }

                if !(rep.isFullRep && reachedProperDepth) {
                    unitsNeedingAttention += 1
                }
            }

            let totalUnits = reps.count
            let goodUnits = max(0, totalUnits - unitsNeedingAttention)
            return AnalysisSummary(
                unitKind: .rep,
                totalUnits: totalUnits,
                goodUnits: goodUnits,
                unitsNeedingAttention: unitsNeedingAttention,
                warningEvents: warningEvents
            )
        }

        let repNumbers = Set(feedback.compactMap(\.repNumber))
        guard !repNumbers.isEmpty else {
            return nil
        }

        let unitsNeedingAttention = repNumbers.reduce(into: 0) { count, repNumber in
            let hasWarnings = feedback.contains {
                $0.repNumber == repNumber && isWarningFeedback($0)
            }
            if hasWarnings {
                count += 1
            }
        }

        let totalUnits = repNumbers.count
        let goodUnits = max(0, totalUnits - unitsNeedingAttention)
        return AnalysisSummary(
            unitKind: .rep,
            totalUnits: totalUnits,
            goodUnits: goodUnits,
            unitsNeedingAttention: unitsNeedingAttention,
            warningEvents: warningEvents
        )
    }

    private static func buildStrikeSummary(
        feedback: [FormFeedback],
        attemptsCount: Int?,
        attemptsNeedingAttention: Int?
    ) -> AnalysisSummary? {
        let warningItems = warningFeedback(from: feedback)

        let totalUnits = max(0, attemptsCount ?? 0)
        let inferredUnitsNeedingAttention = Set(warningItems.map { timestampBucket($0.timestamp) }).count
        let unitsNeedingAttention = min(
            totalUnits,
            max(0, attemptsNeedingAttention ?? inferredUnitsNeedingAttention)
        )

        // For strike summaries we still show coverage even when no issues were detected.
        if totalUnits == 0 && warningItems.isEmpty {
            return nil
        }

        let goodUnits = max(0, totalUnits - unitsNeedingAttention)
        return AnalysisSummary(
            unitKind: .strike,
            totalUnits: totalUnits,
            goodUnits: goodUnits,
            unitsNeedingAttention: unitsNeedingAttention,
            warningEvents: warningItems.count
        )
    }

    private static func buildAttemptSummary(feedback: [FormFeedback]) -> AnalysisSummary? {
        guard !feedback.isEmpty else {
            return nil
        }

        let actionableFeedback = feedback.filter { item in
            guard let kind = item.issueKind else { return true }
            return !excludedWarningIssueKinds.contains(kind)
        }

        let warningItems = warningFeedback(from: actionableFeedback)
        let totalUnits = max(1, Set(actionableFeedback.map { timestampBucket($0.timestamp) / 500 }).count)
        let unitsNeedingAttention = min(totalUnits, Set(warningItems.map { timestampBucket($0.timestamp) / 500 }).count)
        let goodUnits = max(0, totalUnits - unitsNeedingAttention)

        return AnalysisSummary(
            unitKind: .attempt,
            totalUnits: totalUnits,
            goodUnits: goodUnits,
            unitsNeedingAttention: unitsNeedingAttention,
            warningEvents: warningItems.count
        )
    }

    private static func warningFeedback(from feedback: [FormFeedback]) -> [FormFeedback] {
        feedback.filter(isWarningFeedback)
    }

    private static func isWarningFeedback(_ feedback: FormFeedback) -> Bool {
        guard feedback.severity == .warning || feedback.severity == .critical else {
            return false
        }

        if let kind = feedback.issueKind, excludedWarningIssueKinds.contains(kind) {
            return false
        }

        return true
    }

    private static func timestampBucket(_ timestamp: TimeInterval) -> Int {
        Int((timestamp * 1000).rounded())
    }
}
