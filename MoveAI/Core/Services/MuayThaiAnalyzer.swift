import Foundation
import CoreGraphics

enum MuayThaiAnalyzer {
    private enum DetectionStatus: String {
        case ready = "Ready"
        case limited = "Limited"
        case failed = "Failed"
    }

    private struct PreflightAssessment {
        let status: DetectionStatus
        let reasons: [String]
        let visibilityRatio: Double
        let averageConfidence: Double
        let confidenceStability: Double
        let motionRange: Double

        var isReady: Bool { status == .ready }
        var shouldSuppressFormWarnings: Bool { status == .failed }
    }

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

        let techniques: Set<MuayThaiTechnique> = [technique]
        let preflight = preflightAssessment(
            poses: poses,
            stanceResolution: stanceResolution,
            attemptCount: attempts.count
        )

        let outcome: MuayThaiDetectionOutcome
        if !preflight.shouldSuppressFormWarnings {
            outcome = MuayThaiIssueDetectors.evaluate(
                poses: poses,
                attempts: attempts,
                technique: technique,
                stance: stanceResolution.stance,
                stanceSource: stanceResolution.source
            )
        } else {
            outcome = MuayThaiDetectionOutcome(
                feedback: [],
                blockedEntries: blockedEntries(for: techniques),
                attemptsWithIssues: 0
            )
        }

        return buildResult(
            stanceResolution: stanceResolution,
            outcome: outcome,
            attemptCount: attempts.count,
            detectedTechnique: detectedTechnique,
            detectionConfidence: detectionConfidence,
            preflight: preflight,
            debugContext: "technique=\(technique.rawValue)"
        )
    }

    static func analyzeCombo(
        poses: [PoseDetectionResult],
        comboDetection: MuayThaiComboDetection
    ) -> AnalysisResult {
        let stanceResolution = comboDetection.stanceResolution
        let classifiedAttempts = comboDetection.attempts

        let uniqueTechniques = Set(classifiedAttempts.map(\.technique))
        let preflight = preflightAssessment(
            poses: poses,
            stanceResolution: stanceResolution,
            attemptCount: classifiedAttempts.count
        )

        let outcome: MuayThaiDetectionOutcome
        if !preflight.shouldSuppressFormWarnings {
            outcome = MuayThaiIssueDetectors.evaluate(
                poses: poses,
                classifiedAttempts: classifiedAttempts,
                stance: stanceResolution.stance,
                stanceSource: stanceResolution.source
            )
        } else {
            outcome = MuayThaiDetectionOutcome(
                feedback: [],
                blockedEntries: blockedEntries(for: uniqueTechniques),
                attemptsWithIssues: 0
            )
        }

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
            preflight: preflight,
            debugContext: "combo=\(techniquesLabel)"
        )
    }

    private static func buildResult(
        stanceResolution: FightStanceResolution,
        outcome: MuayThaiDetectionOutcome,
        attemptCount: Int,
        detectedTechnique: MuayThaiTechnique?,
        detectionConfidence: Double?,
        preflight: PreflightAssessment,
        debugContext: String
    ) -> AnalysisResult {
        var feedback = outcome.feedback

        if let qualityFeedback = qualityFeedback(for: preflight) {
            feedback.append(qualityFeedback)
        }

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
            "MuayThaiAnalyzer: \(debugContext) preflight=\(preflight.status.rawValue) stance=\(stanceResolution.stance.rawValue) confidence=\(MuayThaiDebug.format(stanceResolution.confidence, decimals: 2)) attempts=\(attemptCount) attemptsWithIssues=\(outcome.attemptsWithIssues) blockedChecks=\(outcome.blockedEntries.count) score=\(score) issues=[\(triggered)]"
        )

        return AnalysisResult(
            score: score,
            feedback: feedback.sorted { $0.timestamp < $1.timestamp },
            analysisSummary: analysisSummary,
            detectedTechnique: detectedTechnique,
            detectionConfidence: detectionConfidence
        )
    }

    private static func blockedEntries(for techniques: Set<MuayThaiTechnique>) -> [MuayThaiIssueCatalogEntry] {
        guard !techniques.isEmpty else { return [] }

        var deduped: [MovementIssueKind: MuayThaiIssueCatalogEntry] = [:]
        for technique in techniques {
            for entry in MuayThaiIssueCatalog.entries(for: technique) where entry.detectionSupport == .blocked {
                deduped[entry.issueKind] = entry
            }
        }

        return deduped.values.sorted { $0.issueKind.rawValue < $1.issueKind.rawValue }
    }

    private static func preflightAssessment(
        poses: [PoseDetectionResult],
        stanceResolution: FightStanceResolution,
        attemptCount: Int
    ) -> PreflightAssessment {
        guard !poses.isEmpty else {
            return PreflightAssessment(
                status: .failed,
                reasons: ["no pose frames were available"],
                visibilityRatio: 0,
                averageConfidence: 0,
                confidenceStability: 0,
                motionRange: 0
            )
        }

        let requiredJoints: [BodyJoint] = [
            .nose,
            .leftShoulder, .rightShoulder,
            .leftHip, .rightHip,
            .leftKnee, .rightKnee,
            .leftAnkle, .rightAnkle,
        ]
        let motionJoints: [BodyJoint] = [
            .leftWrist, .rightWrist,
            .leftAnkle, .rightAnkle,
            .nose,
        ]

        // Side-angle mobile footage can drop occluded joints; keep thresholds permissive enough
        // to avoid suppressing all form analysis in otherwise usable clips.
        let minConfidence: Float = 0.2
        let minRequiredJointsPerFrame = 6
        var visibleFrames = 0
        var frameConfidenceAverages: [Double] = []
        var motionBounds: [BodyJoint: (minX: CGFloat, maxX: CGFloat, minY: CGFloat, maxY: CGFloat)] = [:]

        for pose in poses {
            var presentCount = 0
            var confidences: [Double] = []

            for joint in requiredJoints {
                guard let keypoint = keypoint(joint, in: pose),
                      keypoint.confidence >= minConfidence else {
                    continue
                }
                presentCount += 1
                confidences.append(Double(keypoint.confidence))
            }

            if presentCount >= minRequiredJointsPerFrame {
                visibleFrames += 1
            }

            if !confidences.isEmpty {
                frameConfidenceAverages.append(confidences.reduce(0, +) / Double(confidences.count))
            }

            for joint in motionJoints {
                guard let point = point(joint, in: pose) else { continue }
                if let existing = motionBounds[joint] {
                    motionBounds[joint] = (
                        minX: min(existing.minX, point.x),
                        maxX: max(existing.maxX, point.x),
                        minY: min(existing.minY, point.y),
                        maxY: max(existing.maxY, point.y)
                    )
                } else {
                    motionBounds[joint] = (point.x, point.x, point.y, point.y)
                }
            }
        }

        let frameCount = Double(max(poses.count, 1))
        let visibilityRatio = Double(visibleFrames) / frameCount
        let averageConfidence = frameConfidenceAverages.isEmpty
            ? 0
            : frameConfidenceAverages.reduce(0, +) / Double(frameConfidenceAverages.count)

        let confidenceStability: Double
        if frameConfidenceAverages.count < 2 {
            confidenceStability = 0
        } else {
            let mean = averageConfidence
            let variance = frameConfidenceAverages
                .map { value in
                    let delta = value - mean
                    return delta * delta
                }
                .reduce(0, +) / Double(frameConfidenceAverages.count)
            confidenceStability = sqrt(variance)
        }

        let motionRange = motionBounds.values
            .map { bounds in
                max(
                    Double(bounds.maxX - bounds.minX),
                    Double(bounds.maxY - bounds.minY)
                )
            }
            .max() ?? 0

        var failedReasons: [String] = []
        var limitedReasons: [String] = []

        if attemptCount == 0 {
            failedReasons.append("no strike attempts were detected")
        }

        if visibilityRatio < 0.18 {
            failedReasons.append("full-body visibility was too low")
        } else if visibilityRatio < 0.45 {
            limitedReasons.append("full-body visibility was inconsistent")
        }

        if averageConfidence < 0.20 {
            failedReasons.append("keypoint confidence was too low")
        } else if averageConfidence < 0.35 {
            limitedReasons.append("keypoint confidence was unstable")
        }

        if confidenceStability > 0.35 {
            failedReasons.append("keypoint confidence varied too sharply")
        } else if confidenceStability > 0.22 {
            limitedReasons.append("keypoint confidence varied across frames")
        }

        if motionRange < 0.03 {
            failedReasons.append("insufficient movement for reliable strike analysis")
        } else if motionRange < 0.06 {
            limitedReasons.append("movement amplitude was limited")
        }

        if stanceResolution.source != .userSelected {
            if stanceResolution.confidence < 0.10 {
                failedReasons.append("stance confidence was too low")
            } else if stanceResolution.confidence < 0.30 || stanceResolution.stance == .unknown {
                limitedReasons.append("stance inference confidence was limited")
            }
        }

        let status: DetectionStatus
        let reasons: [String]
        if !failedReasons.isEmpty {
            status = .failed
            reasons = failedReasons
        } else if !limitedReasons.isEmpty {
            status = .limited
            reasons = limitedReasons
        } else {
            status = .ready
            reasons = []
        }

        MuayThaiDebug.log(
            "MuayThaiPreflight: status=\(status.rawValue) visibility=\(MuayThaiDebug.format(visibilityRatio)) avgConf=\(MuayThaiDebug.format(averageConfidence)) confSigma=\(MuayThaiDebug.format(confidenceStability)) motion=\(MuayThaiDebug.format(motionRange)) attempts=\(attemptCount) reasons=[\(reasons.joined(separator: "; "))]"
        )

        return PreflightAssessment(
            status: status,
            reasons: reasons,
            visibilityRatio: visibilityRatio,
            averageConfidence: averageConfidence,
            confidenceStability: confidenceStability,
            motionRange: motionRange
        )
    }

    private static func qualityFeedback(for assessment: PreflightAssessment) -> FormFeedback? {
        guard assessment.status != .ready else { return nil }

        let message: String
        if assessment.status == .failed {
            if assessment.reasons.isEmpty {
                message = "Detection failed. Form warnings were suppressed for this clip."
            } else {
                message = "Detection failed (\(assessment.reasons.joined(separator: "; "))). Form warnings were suppressed for this clip."
            }
        } else {
            if assessment.reasons.isEmpty {
                message = "Detection quality limited. Some form warnings may be less reliable."
            } else {
                message = "Detection quality limited (\(assessment.reasons.joined(separator: "; "))). Some form warnings may be less reliable."
            }
        }

        return FormFeedback(
            category: .safety,
            message: message,
            severity: assessment.status == .failed ? .critical : .warning,
            timestamp: 0,
            repNumber: nil,
            issueKind: .muayThaiCaptureQualityLimited,
            metrics: nil,
            affectedBodyJoints: nil
        )
    }

    private static func keypoint(_ joint: BodyJoint, in pose: PoseDetectionResult) -> PoseKeypoint? {
        PoseAnalysisHelpers.extractKeypoint(joint.rawValue, from: pose)
    }

    private static func point(_ joint: BodyJoint, in pose: PoseDetectionResult) -> CGPoint? {
        keypoint(joint, in: pose)?.position
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
