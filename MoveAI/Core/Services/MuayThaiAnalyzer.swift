import Foundation

enum MuayThaiAnalyzer {
    static func analyze(
        poses: [PoseDetectionResult],
        technique: MuayThaiTechnique,
        fightStance: FightStance?
    ) -> AnalysisResult {
        let stanceResolution = FightStanceResolver.resolve(preferred: fightStance, from: poses)
        let attempts = MuayThaiEventDetector.detectAttempts(
            poses: poses,
            technique: technique,
            stance: stanceResolution.stance
        )

        let outcome = MuayThaiIssueDetectors.evaluate(
            poses: poses,
            attempts: attempts,
            technique: technique,
            stance: stanceResolution.stance
        )

        var feedback = outcome.feedback
        var coverageNotes: [String] = []

        if stanceResolution.stance == .unknown {
            coverageNotes.append("stance could not be inferred")
        }

        if !outcome.blockedEntries.isEmpty {
            let blockedNames = outcome.blockedEntries
                .map { humanReadableIssueName($0.issueKind) }
                .sorted()
                .joined(separator: ", ")
            coverageNotes.append("blocked checks: \(blockedNames)")
        }

        if !coverageNotes.isEmpty {
            let note = "Analysis coverage limited (\(coverageNotes.joined(separator: "; ")))."
            feedback.append(
                FormFeedback(
                    category: .safety,
                    message: note,
                    severity: .warning,
                    timestamp: 0,
                    repNumber: nil,
                    issueKind: .muayThaiAnalysisCoverageLimited,
                    metrics: nil,
                    affectedBodyJoints: nil
                )
            )
        }

        let score = MuayThaiScoring.score(feedback: feedback, attemptsCount: attempts.count)
        let analysisSummary = AnalysisSummaryBuilder.build(
            movementType: .muayThai,
            feedback: feedback,
            reps: nil,
            depthMetrics: nil,
            attemptsCount: attempts.count,
            attemptsNeedingAttention: outcome.attemptsWithIssues
        )

#if DEBUG
        if ProcessInfo.processInfo.environment["MOVEAI_POSE_DEBUG"] == "1" {
            let triggered = feedback.compactMap { $0.issueKind?.rawValue }.joined(separator: ", ")
            let confidenceText = String(format: "%.2f", stanceResolution.confidence)
            print("MuayThaiAnalyzer: technique=\(technique.rawValue) stance=\(stanceResolution.stance.rawValue) confidence=\(confidenceText) attempts=\(attempts.count) issues=[\(triggered)]")
        }
#endif

        return AnalysisResult(
            score: score,
            feedback: feedback.sorted { $0.timestamp < $1.timestamp },
            analysisSummary: analysisSummary
        )
    }

    private static func humanReadableIssueName(_ kind: MovementIssueKind) -> String {
        kind.rawValue
            .split(separator: ".")
            .last
            .map { $0.replacingOccurrences(of: "_", with: " ") }
            .map { $0.split(separator: " ").map { $0.capitalized }.joined(separator: " ") }
            ?? kind.rawValue
    }
}
