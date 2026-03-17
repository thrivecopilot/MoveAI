import Foundation

enum MuayThaiAnalyzer {
    static func analyze(
        poses: [PoseDetectionResult],
        technique: MuayThaiTechnique,
        fightStance: FightStance?,
        detectedTechnique: MuayThaiTechnique? = nil,
        detectionConfidence: Double? = nil
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
            stance: stanceResolution.stance,
            stanceSource: stanceResolution.source
        )

        return buildResult(
            stanceResolution: stanceResolution,
            outcome: outcome,
            attemptCount: attempts.count,
            detectedTechnique: detectedTechnique,
            detectionConfidence: detectionConfidence,
            debugContext: "technique=\(technique.rawValue)"
        )
    }

    static func analyzeCombo(
        poses: [PoseDetectionResult],
        comboDetection: MuayThaiComboDetection
    ) -> AnalysisResult {
        let stanceResolution = comboDetection.stanceResolution
        let classifiedAttempts = comboDetection.attempts

        let outcome = MuayThaiIssueDetectors.evaluate(
            poses: poses,
            classifiedAttempts: classifiedAttempts,
            stance: stanceResolution.stance,
            stanceSource: stanceResolution.source
        )

        let uniqueTechniques = Set(classifiedAttempts.map(\.technique))
        let dominantTechnique = comboDetection.dominantTechnique
        let dominantShare = comboDetection.dominantTechniqueShare ?? 0
        let dominantConfidence = comboDetection.dominantTechniqueConfidence

        // Blend two dominance views:
        // 1) count dominance (stable when attempts are clean)
        // 2) confidence-weighted dominance (robust when windows are noisy/mixed)
        let attemptsByTechnique = Dictionary(grouping: classifiedAttempts, by: \.technique)
        let weightedScores = attemptsByTechnique.mapValues { attempts in
            attempts.reduce(0.0) { $0 + max(0, $1.confidence) }
        }
        let totalWeightedScore = weightedScores.values.reduce(0.0, +)
        let weightedDominant = weightedScores.max { lhs, rhs in
            if lhs.value == rhs.value {
                return (attemptsByTechnique[lhs.key]?.count ?? 0) < (attemptsByTechnique[rhs.key]?.count ?? 0)
            }
            return lhs.value < rhs.value
        }

        let weightedTechnique = weightedDominant?.key
        let weightedShare = totalWeightedScore > 0
            ? (weightedDominant?.value ?? 0) / totalWeightedScore
            : 0
        let weightedConfidence: Double?
        if let technique = weightedTechnique,
           let attempts = attemptsByTechnique[technique],
           !attempts.isEmpty {
            weightedConfidence = attempts.reduce(0.0) { $0 + $1.confidence } / Double(attempts.count)
        } else {
            weightedConfidence = nil
        }

        // In mixed-attempt clips, still surface a detected technique when one technique
        // clearly dominates by count or weighted confidence.
        let shouldSurfaceDominant =
            uniqueTechniques.count == 1 ||
            dominantShare >= 0.5 ||
            weightedShare >= 0.38

        let resolvedDetectedTechnique = shouldSurfaceDominant
            ? (weightedTechnique ?? dominantTechnique)
            : nil
        let resolvedConfidence = shouldSurfaceDominant
            ? (weightedConfidence ?? dominantConfidence)
            : nil

        let techniquesLabel = classifiedAttempts
            .map { $0.technique.rawValue }
            .joined(separator: ",")

        return buildResult(
            stanceResolution: stanceResolution,
            outcome: outcome,
            attemptCount: classifiedAttempts.count,
            detectedTechnique: resolvedDetectedTechnique,
            detectionConfidence: resolvedConfidence,
            debugContext: "combo=\(techniquesLabel)"
        )
    }

    private static func buildResult(
        stanceResolution: FightStanceResolution,
        outcome: MuayThaiDetectionOutcome,
        attemptCount: Int,
        detectedTechnique: MuayThaiTechnique?,
        detectionConfidence: Double?,
        debugContext: String
    ) -> AnalysisResult {
        var feedback = outcome.feedback

        let coverageNote = coverageNote(
            stanceResolution: stanceResolution,
            blockedEntries: outcome.blockedEntries
        )

        if let coverageNote {
            feedback.append(
                FormFeedback(
                    category: .safety,
                    message: coverageNote,
                    severity: .warning,
                    timestamp: 0,
                    repNumber: nil,
                    issueKind: .muayThaiAnalysisCoverageLimited,
                    metrics: nil,
                    affectedBodyJoints: nil
                )
            )
        }

        let score = MuayThaiScoring.score(feedback: feedback, attemptsCount: attemptCount)
        let analysisSummary = AnalysisSummaryBuilder.build(
            movementType: .muayThai,
            feedback: feedback,
            reps: nil,
            depthMetrics: nil,
            attemptsCount: attemptCount,
            attemptsNeedingAttention: outcome.attemptsWithIssues
        )

        let triggered = feedback.compactMap { $0.issueKind?.rawValue }.joined(separator: ", ")
        MuayThaiDebug.log(
            "MuayThaiAnalyzer: \(debugContext) stance=\(stanceResolution.stance.rawValue) confidence=\(MuayThaiDebug.format(stanceResolution.confidence, decimals: 2)) attempts=\(attemptCount) attemptsWithIssues=\(outcome.attemptsWithIssues) blockedChecks=\(outcome.blockedEntries.count) score=\(score) issues=[\(triggered)]"
        )

        return AnalysisResult(
            score: score,
            feedback: feedback.sorted { $0.timestamp < $1.timestamp },
            analysisSummary: analysisSummary,
            detectedTechnique: detectedTechnique,
            detectionConfidence: detectionConfidence
        )
    }

    private static func coverageNote(
        stanceResolution: FightStanceResolution,
        blockedEntries: [MuayThaiIssueCatalogEntry]
    ) -> String? {
        var notes: [String] = []

        if stanceResolution.stance == .unknown {
            notes.append("stance could not be inferred")
        }

        if !blockedEntries.isEmpty {
            let blockedNames = blockedEntries
                .map { humanReadableIssueName($0.issueKind) }
                .sorted()
                .joined(separator: ", ")
            notes.append("blocked checks: \(blockedNames)")
        }

        guard !notes.isEmpty else { return nil }
        return "Analysis coverage limited (\(notes.joined(separator: "; ")))."
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
