import CoreGraphics
import Foundation

struct MuayThaiDetectionOutcome {
    let feedback: [FormFeedback]
    let blockedEntries: [MuayThaiIssueCatalogEntry]
    let attemptsWithIssues: Int
}

enum MuayThaiIssueDetectors {
    static func evaluate(
        poses: [PoseDetectionResult],
        attempts: [TechniqueAttempt],
        technique: MuayThaiTechnique,
        stance: FightStance,
        stanceSource: FightStanceResolution.Source = .autoInferred
    ) -> MuayThaiDetectionOutcome {
        let classifiedAttempts = attempts.map {
            MuayThaiClassifiedAttempt(attempt: $0, technique: technique, confidence: 1.0)
        }

        return evaluate(
            poses: poses,
            classifiedAttempts: classifiedAttempts,
            stance: stance,
            stanceSource: stanceSource
        )
    }

    static func evaluate(
        poses: [PoseDetectionResult],
        classifiedAttempts: [MuayThaiClassifiedAttempt],
        stance: FightStance,
        stanceSource: FightStanceResolution.Source = .autoInferred
    ) -> MuayThaiDetectionOutcome {
        guard !poses.isEmpty, !classifiedAttempts.isEmpty else {
            return MuayThaiDetectionOutcome(feedback: [], blockedEntries: [], attemptsWithIssues: 0)
        }

        let techniques = Set(classifiedAttempts.map(\.technique))
        MuayThaiDebug.log("IssueDetectors: attempts=\(classifiedAttempts.count) techniques=\(techniques.map(\.rawValue).sorted()) stance=\(stance.rawValue)")
        let blockedEntries = uniqueBlockedEntries(for: techniques)
        let mixedTechniques = techniques.count > 1

        var feedback: [FormFeedback] = []
        var attemptsWithIssues = 0

        for (attemptIndex, classifiedAttempt) in classifiedAttempts.enumerated() {
            let entries = MuayThaiIssueCatalog.entries(for: classifiedAttempt.technique)
            let activeEntries = entries.filter { $0.detectionSupport != .blocked }

            guard let context = AttemptContext(
                poses: poses,
                attempt: classifiedAttempt.attempt,
                attemptTechnique: classifiedAttempt.technique,
                attemptConfidence: classifiedAttempt.confidence,
                mixedTechniques: mixedTechniques,
                stance: stance,
                stanceSource: stanceSource
            ) else {
                MuayThaiDebug.log("IssueDetectors: skipped attempt \(attemptIndex + 1) \(classifiedAttempt.technique.rawValue) (invalid frame window)")
                continue
            }

            let attemptFrameCount = max(0, classifiedAttempt.attempt.endFrame - classifiedAttempt.attempt.startFrame + 1)
            guard attemptFrameCount >= 4 else {
                MuayThaiDebug.log("IssueDetectors: skipped attempt \(attemptIndex + 1) \(classifiedAttempt.technique.rawValue) (too few frames=\(attemptFrameCount))")
                continue
            }

            MuayThaiDebug.log("IssueDetectors: attempt \(attemptIndex + 1) technique=\(classifiedAttempt.technique.rawValue) frames=[\(classifiedAttempt.attempt.startFrame)-\(classifiedAttempt.attempt.peakFrame)-\(classifiedAttempt.attempt.endFrame)] peakTime=\(MuayThaiDebug.format(context.peakTime, decimals: 3)) fwd=\(MuayThaiDebug.format(context.forwardDirection, decimals: 2))")

            var issueDetectedForAttempt = false
            for entry in activeEntries {
                guard let detection = detect(entry: entry, context: context) else { continue }

                issueDetectedForAttempt = true
                let metrics = detection.metrics.isEmpty ? nil : detection.metrics
                let affectedJoints = detection.affectedJoints.isEmpty ? nil : detection.affectedJoints
                let message = contextualMessage(
                    base: detection.message,
                    attemptIndex: attemptIndex,
                    technique: classifiedAttempt.technique,
                    mixedTechniques: mixedTechniques
                )

                MuayThaiDebug.log("IssueDetectors: triggered issue=\(entry.issueKind.rawValue) severity=\(detection.severity.rawValue) attempt=\(attemptIndex + 1)")

                feedback.append(
                    FormFeedback(
                        category: detection.category,
                        message: message,
                        severity: detection.severity,
                        timestamp: context.peakTime,
                        repNumber: nil,
                        issueKind: entry.issueKind,
                        metrics: metrics,
                        affectedBodyJoints: affectedJoints
                    )
                )
            }

            if issueDetectedForAttempt {
                attemptsWithIssues += 1
            }
        }

        let crossFilteredFeedback = applyCrossNoHipRotationPersistenceGate(
            feedback: feedback,
            classifiedAttempts: classifiedAttempts
        )
        let mixedTechniqueFilteredFeedback = applyMixedTechniqueJabNoiseGate(
            feedback: crossFilteredFeedback,
            classifiedAttempts: classifiedAttempts
        )
        let jabPrioritizedFeedback = applyJabForwardOverBasePriorityGate(
            feedback: mixedTechniqueFilteredFeedback,
            classifiedAttempts: classifiedAttempts
        )
        let jabDisambiguatedFeedback = applyJabIssueDisambiguationGate(
            feedback: jabPrioritizedFeedback,
            classifiedAttempts: classifiedAttempts
        )
        let filteredFeedback = applyRoundhouseNoArmCounterbalancePersistenceGate(
            feedback: jabDisambiguatedFeedback,
            classifiedAttempts: classifiedAttempts
        )

        return MuayThaiDetectionOutcome(
            feedback: filteredFeedback.sorted { $0.timestamp < $1.timestamp },
            blockedEntries: blockedEntries,
            attemptsWithIssues: attemptsWithIssues
        )
    }

    private static func applyCrossNoHipRotationPersistenceGate(
        feedback: [FormFeedback],
        classifiedAttempts: [MuayThaiClassifiedAttempt]
    ) -> [FormFeedback] {
        let crossAttempts = classifiedAttempts.reduce(into: 0) { partial, classifiedAttempt in
            if classifiedAttempt.technique == .cross {
                partial += 1
            }
        }
        guard crossAttempts > 0 else { return feedback }

        let noHipRotationCount = feedback.reduce(into: 0) { partial, item in
            if item.issueKind == .muayThaiCrossNoHipRotation {
                partial += 1
            }
        }
        guard noHipRotationCount > 0 else { return feedback }

        let persistenceRatio = Double(noHipRotationCount) / Double(crossAttempts)
        // Keep the issue when it persists across a meaningful share of cross attempts.
        // This preserves clear "arm-only" crosses while filtering one-off false positives.
        let keepIssue = noHipRotationCount >= 2 && persistenceRatio >= 0.30
        guard !keepIssue else { return feedback }

        MuayThaiDebug.log(
            "CrossNoHipRotation: gated by persistence count=\(noHipRotationCount) crossAttempts=\(crossAttempts) ratio=\(MuayThaiDebug.format(persistenceRatio))"
        )
        return feedback.filter { $0.issueKind != .muayThaiCrossNoHipRotation }
    }

    private static func applyJabForwardOverBasePriorityGate(
        feedback: [FormFeedback],
        classifiedAttempts: [MuayThaiClassifiedAttempt]
    ) -> [FormFeedback] {
        guard !feedback.isEmpty else { return feedback }

        let techniqueSet = Set(classifiedAttempts.map(\.technique))
        guard techniqueSet.count == 1, techniqueSet.contains(.jab) else {
            return feedback
        }

        let jabAttempts = classifiedAttempts.reduce(into: 0) { partial, attempt in
            if attempt.technique == .jab {
                partial += 1
            }
        }
        guard jabAttempts > 0 else { return feedback }

        let forwardOverBaseCount = feedback.reduce(into: 0) { partial, item in
            if item.issueKind == .muayThaiPostureForwardOverBase {
                partial += 1
            }
        }
        guard forwardOverBaseCount >= 2 else { return feedback }

        let rearHandDropCount = feedback.reduce(into: 0) { partial, item in
            if item.issueKind == .muayThaiJabRearHandDropping {
                partial += 1
            }
        }
        let poorRetractionCount = feedback.reduce(into: 0) { partial, item in
            if item.issueKind == .muayThaiJabPoorRetraction {
                partial += 1
            }
        }

        let forwardRatio = Double(forwardOverBaseCount) / Double(jabAttempts)
        let shouldSuppressSecondaryWarnings = forwardRatio >= 0.20 &&
            rearHandDropCount > 0 &&
            rearHandDropCount <= forwardOverBaseCount + 1
        guard shouldSuppressSecondaryWarnings else { return feedback }

        MuayThaiDebug.log(
            "JabForwardOverBase: prioritized posture warning count=\(forwardOverBaseCount) ratio=\(MuayThaiDebug.format(forwardRatio)) suppressing rearHand=\(rearHandDropCount) poorRetraction=\(poorRetractionCount)"
        )

        return feedback.filter {
            $0.issueKind != .muayThaiJabRearHandDropping &&
            $0.issueKind != .muayThaiJabPoorRetraction
        }
    }

    private static func applyMixedTechniqueJabNoiseGate(
        feedback: [FormFeedback],
        classifiedAttempts: [MuayThaiClassifiedAttempt]
    ) -> [FormFeedback] {
        guard !feedback.isEmpty else { return feedback }

        let techniqueSet = Set(classifiedAttempts.map(\.technique))
        guard techniqueSet.count > 1 else { return feedback }

        let jabAttempts = classifiedAttempts.reduce(into: 0) { partial, attempt in
            if attempt.technique == .jab {
                partial += 1
            }
        }
        guard jabAttempts > 0 else { return feedback }

        var filtered = feedback
        let mixedThreshold = 0.20

        let rearHandCount = filtered.reduce(into: 0) { partial, item in
            if item.issueKind == .muayThaiJabRearHandDropping {
                partial += 1
            }
        }
        let rearHandRatio = Double(rearHandCount) / Double(jabAttempts)
        if rearHandCount > 0 && (rearHandCount < 2 || rearHandRatio < mixedThreshold) {
            MuayThaiDebug.log(
                "MixedTechniqueJabNoise: suppressing rear-hand-drop count=\(rearHandCount) jabAttempts=\(jabAttempts) ratio=\(MuayThaiDebug.format(rearHandRatio))"
            )
            filtered.removeAll { $0.issueKind == .muayThaiJabRearHandDropping }
        }

        let poorRetractionCount = filtered.reduce(into: 0) { partial, item in
            if item.issueKind == .muayThaiJabPoorRetraction {
                partial += 1
            }
        }
        let poorRetractionRatio = Double(poorRetractionCount) / Double(jabAttempts)
        if poorRetractionCount > 0 && (poorRetractionCount < 2 || poorRetractionRatio < mixedThreshold) {
            MuayThaiDebug.log(
                "MixedTechniqueJabNoise: suppressing poor-retraction count=\(poorRetractionCount) jabAttempts=\(jabAttempts) ratio=\(MuayThaiDebug.format(poorRetractionRatio))"
            )
            filtered.removeAll { $0.issueKind == .muayThaiJabPoorRetraction }
        }

        return filtered
    }

    private static func applyRoundhouseNoArmCounterbalancePersistenceGate(
        feedback: [FormFeedback],
        classifiedAttempts: [MuayThaiClassifiedAttempt]
    ) -> [FormFeedback] {
        guard !feedback.isEmpty else { return feedback }

        let roundhouseAttempts = classifiedAttempts.reduce(into: 0) { partial, attempt in
            if attempt.technique == .roundhouseKick {
                partial += 1
            }
        }
        guard roundhouseAttempts >= 6 else { return feedback }

        let counterbalanceCount = feedback.reduce(into: 0) { partial, item in
            if item.issueKind == .muayThaiRoundhouseNoArmCounterbalance {
                partial += 1
            }
        }
        guard counterbalanceCount > 0 else { return feedback }

        let counterbalanceRatio = Double(counterbalanceCount) / Double(roundhouseAttempts)
        let keepIssue = counterbalanceCount >= 2 && counterbalanceRatio >= 0.10
        guard !keepIssue else { return feedback }

        MuayThaiDebug.log(
            "RoundhouseNoArmCounterbalance: gated by persistence count=\(counterbalanceCount) attempts=\(roundhouseAttempts) ratio=\(MuayThaiDebug.format(counterbalanceRatio))"
        )
        return feedback.filter { $0.issueKind != .muayThaiRoundhouseNoArmCounterbalance }
    }

    private static func applyJabIssueDisambiguationGate(
        feedback: [FormFeedback],
        classifiedAttempts: [MuayThaiClassifiedAttempt]
    ) -> [FormFeedback] {
        guard !feedback.isEmpty else { return feedback }

        let techniqueSet = Set(classifiedAttempts.map(\.technique))
        guard techniqueSet.count == 1, techniqueSet.contains(.jab) else {
            return feedback
        }

        var filtered = feedback

        let rearHandCount = filtered.reduce(into: 0) { partial, item in
            if item.issueKind == .muayThaiJabRearHandDropping {
                partial += 1
            }
        }
        let poorRetractionCount = filtered.reduce(into: 0) { partial, item in
            if item.issueKind == .muayThaiJabPoorRetraction {
                partial += 1
            }
        }
        let forwardOverBaseCount = filtered.reduce(into: 0) { partial, item in
            if item.issueKind == .muayThaiPostureForwardOverBase {
                partial += 1
            }
        }

        // If rear-hand-drop is dominant and poor retraction is a one-off,
        // keep the dominant safety warning and drop the tempo side-warning.
        if rearHandCount >= 1 && poorRetractionCount == 1 && forwardOverBaseCount == 0 {
            MuayThaiDebug.log(
                "JabDisambiguation: suppressing singleton poor-retraction with rear-hand-drop count=\(rearHandCount)"
            )
            filtered.removeAll { $0.issueKind == .muayThaiJabPoorRetraction }
        }

        // If poor retraction is dominant and rear-hand-drop is a one-off,
        // keep the retraction warning and drop the guard side-warning.
        if poorRetractionCount >= 2 && rearHandCount == 1 && forwardOverBaseCount == 0 {
            MuayThaiDebug.log(
                "JabDisambiguation: suppressing singleton rear-hand-drop with poor-retraction count=\(poorRetractionCount)"
            )
            filtered.removeAll { $0.issueKind == .muayThaiJabRearHandDropping }
        }

        return filtered
    }

    private static func uniqueBlockedEntries(for techniques: Set<MuayThaiTechnique>) -> [MuayThaiIssueCatalogEntry] {
        guard !techniques.isEmpty else { return [] }

        var deduped: [MovementIssueKind: MuayThaiIssueCatalogEntry] = [:]
        for technique in techniques {
            for entry in MuayThaiIssueCatalog.entries(for: technique) where entry.detectionSupport == .blocked {
                deduped[entry.issueKind] = entry
            }
        }

        return deduped.values.sorted { $0.issueKind.rawValue < $1.issueKind.rawValue }
    }

    private static func contextualMessage(
        base: String,
        attemptIndex: Int,
        technique: MuayThaiTechnique,
        mixedTechniques: Bool
    ) -> String {
        guard mixedTechniques else { return base }
        return "Strike \(attemptIndex + 1) (\(technique.displayName)): \(base)"
    }

    private struct Detection {
        let severity: FeedbackSeverity
        let category: FeedbackCategory
        let message: String
        let affectedJoints: [BodyJoint]
        let metrics: [FeedbackMetric]
    }

    private struct JointMap {
        let leadShoulder: BodyJoint
        let rearShoulder: BodyJoint
        let leadElbow: BodyJoint
        let rearElbow: BodyJoint
        let leadWrist: BodyJoint
        let rearWrist: BodyJoint
        let leadHip: BodyJoint
        let rearHip: BodyJoint
        let leadKnee: BodyJoint
        let rearKnee: BodyJoint
        let leadAnkle: BodyJoint
        let rearAnkle: BodyJoint

        static func forStance(_ stance: FightStance) -> JointMap {
            switch stance {
            case .southpaw:
                return JointMap(
                    leadShoulder: .rightShoulder,
                    rearShoulder: .leftShoulder,
                    leadElbow: .rightElbow,
                    rearElbow: .leftElbow,
                    leadWrist: .rightWrist,
                    rearWrist: .leftWrist,
                    leadHip: .rightHip,
                    rearHip: .leftHip,
                    leadKnee: .rightKnee,
                    rearKnee: .leftKnee,
                    leadAnkle: .rightAnkle,
                    rearAnkle: .leftAnkle
                )
            case .orthodox, .unknown:
                return JointMap(
                    leadShoulder: .leftShoulder,
                    rearShoulder: .rightShoulder,
                    leadElbow: .leftElbow,
                    rearElbow: .rightElbow,
                    leadWrist: .leftWrist,
                    rearWrist: .rightWrist,
                    leadHip: .leftHip,
                    rearHip: .rightHip,
                    leadKnee: .leftKnee,
                    rearKnee: .rightKnee,
                    leadAnkle: .leftAnkle,
                    rearAnkle: .rightAnkle
                )
            }
        }
    }

    private struct AttemptContext {
        let poses: [PoseDetectionResult]
        let attempt: TechniqueAttempt
        let attemptTechnique: MuayThaiTechnique
        let attemptConfidence: Double
        let mixedTechniques: Bool
        let stance: FightStance
        let stanceSource: FightStanceResolution.Source
        let joints: JointMap
        let startPose: PoseDetectionResult
        let peakPose: PoseDetectionResult
        let endPose: PoseDetectionResult
        let forwardDirection: Double

        var peakTime: TimeInterval {
            max(0, peakPose.timestamp.timeIntervalSince1970)
        }

        init?(
            poses: [PoseDetectionResult],
            attempt: TechniqueAttempt,
            attemptTechnique: MuayThaiTechnique,
            attemptConfidence: Double,
            mixedTechniques: Bool,
            stance: FightStance,
            stanceSource: FightStanceResolution.Source
        ) {
            guard let startPose = poses[optional: attempt.startFrame],
                  let peakPose = poses[optional: attempt.peakFrame],
                  let endPose = poses[optional: attempt.endFrame] else {
                return nil
            }

            self.poses = poses
            self.attempt = attempt
            self.attemptTechnique = attemptTechnique
            self.attemptConfidence = attemptConfidence
            self.mixedTechniques = mixedTechniques
            self.stance = stance
            self.stanceSource = stanceSource
            self.joints = JointMap.forStance(stance)
            self.startPose = startPose
            self.peakPose = peakPose
            self.endPose = endPose
            self.forwardDirection = AttemptContext.computeForwardDirection(joints: self.joints, peakPose: peakPose)
        }

        private static func computeForwardDirection(joints: JointMap, peakPose: PoseDetectionResult) -> Double {
            if let leadAnkle = point(joints.leadAnkle, in: peakPose),
               let rearAnkle = point(joints.rearAnkle, in: peakPose) {
                let delta = Double(leadAnkle.x - rearAnkle.x)
                if abs(delta) > 0.001 {
                    return delta > 0 ? 1.0 : -1.0
                }
            }

            if let leadShoulder = point(joints.leadShoulder, in: peakPose),
               let rearShoulder = point(joints.rearShoulder, in: peakPose) {
                let delta = Double(leadShoulder.x - rearShoulder.x)
                if abs(delta) > 0.001 {
                    return delta > 0 ? 1.0 : -1.0
                }
            }

            return 1.0
        }
    }

    private static func detect(entry: MuayThaiIssueCatalogEntry, context: AttemptContext) -> Detection? {
        switch entry.issueKind {
        case .muayThaiJabRearHandDropping:
            return detectRearHandDropping(entry: entry, context: context)
        case .muayThaiPostureForwardOverBase:
            switch entry.technique {
            case .jab:
                return detectForwardOverBaseForJab(entry: entry, context: context)
            case .cross:
                return detectForwardOverBaseForCross(entry: entry, context: context)
            default:
                return nil
            }
        case .muayThaiJabPoorRetraction:
            return detectPoorRetraction(entry: entry, context: context)
        case .muayThaiCrossNoHipRotation:
            return detectNoHipRotation(entry: entry, context: context)
        case .muayThaiLeadHookArmOnly:
            return detectArmOnlyHook(entry: entry, context: context)
        case .muayThaiLeadHookTooWide:
            return detectHookTooWide(entry: entry, context: context)
        case .muayThaiRoundhouseNoHipTurnover:
            return detectNoHipTurnover(entry: entry, context: context)
        case .muayThaiRoundhouseNoArmCounterbalance:
            return detectNoArmCounterbalance(entry: entry, context: context)
        case .muayThaiTeepNoKneeChamber:
            return detectNoKneeChamber(entry: entry, context: context)
        case .muayThaiTeepFallingForward:
            return detectTeepFallingForward(entry: entry, context: context)
        case .muayThaiStraightKneeTravelVertical:
            return detectKneeTravelVertical(entry: entry, context: context)
        case .muayThaiStraightKneeNoHipThrust:
            return detectNoHipThrust(entry: entry, context: context)
        case .muayThaiHorizontalElbowTooWide:
            return detectElbowTooWide(entry: entry, context: context)
        case .muayThaiHorizontalElbowNoBodyRotation:
            return detectNoBodyRotation(entry: entry, context: context)
        case .muayThaiMovementCrossingFeet:
            return detectCrossingFeet(entry: entry, context: context)
        default:
            return nil
        }
    }

    private static func detectRearHandDropping(
        entry: MuayThaiIssueCatalogEntry,
        context: AttemptContext,
        allowClipFallback: Bool = true
    ) -> Detection? {
        var roles = MuayThaiAttemptRoleResolver.resolvePunchRoles(
            technique: .jab,
            startPose: context.startPose,
            peakPose: context.peakPose,
            stance: context.stance
        )

        var selectedInference: (strikingWrist: BodyJoint, confidence: Double)?
        if let clipInference = inferDominantPunchSideAcrossClip(poses: context.poses) {
            selectedInference = clipInference
        }
        if let attemptInference = inferDominantPunchSideAcrossAttempt(context: context) {
            if let existingInference = selectedInference {
                if attemptInference.confidence > existingInference.confidence + 0.05 {
                    selectedInference = attemptInference
                }
            } else {
                selectedInference = attemptInference
            }
        }

        if let selectedInference,
           selectedInference.strikingWrist != roles.strikingWrist,
           shouldOverridePunchRoleResolution(
               existing: roles,
               attemptInferenceConfidence: selectedInference.confidence,
               stanceSource: context.stanceSource
           ) {
            roles = punchRoleResolution(
                strikingWrist: selectedInference.strikingWrist,
                confidence: max(0.40, selectedInference.confidence),
                source: .motionInferred
            )
            MuayThaiDebug.log(
                "RearHandDrop: overriding roles via attempt-window inference striking=\(roles.strikingWrist.rawValue) guard=\(roles.guardWrist.rawValue) confidence=\(MuayThaiDebug.format(roles.confidence))"
            )
        }

        MuayThaiDebug.log("RearHandDrop: role source=\(String(describing: roles.source)) striking=\(roles.strikingWrist.rawValue) guard=\(roles.guardWrist.rawValue) confidence=\(MuayThaiDebug.format(roles.confidence))")

        let allowFallbackRoles = context.stanceSource == .userSelected
        if roles.source != .motionInferred && !allowFallbackRoles {
            MuayThaiDebug.log("RearHandDrop: skipped (role source \(String(describing: roles.source)) is not motionInferred)")
            return nil
        }

        // Low-confidence role inference is a common source of false positives where
        // the jabbing hand gets mistaken for the rear guard hand.
        if roles.source == .motionInferred && roles.confidence < 0.35 {
            MuayThaiDebug.log("RearHandDrop: skipped (low role confidence=\(MuayThaiDebug.format(roles.confidence)))")
            return nil
        }

        if context.mixedTechniques && context.attemptConfidence < 0.60 {
            MuayThaiDebug.log(
                "RearHandDrop: skipped (mixed-technique low attempt confidence=\(MuayThaiDebug.format(context.attemptConfidence)))"
            )
            return nil
        }

        let baselineSignal = rearHandDropSignal(
            in: context.startPose,
            guardWrist: roles.guardWrist,
            guardElbow: roles.guardElbow
        )
        let baselineExtension = strikingExtensionRatio(
            in: context.startPose,
            strikingWrist: roles.strikingWrist,
            strikingShoulder: roles.strikingShoulder
        ) ?? 0

        var extensionFrames = 0
        var droppedFrames = 0
        var maxGuardRatio = 0.0
        var maxExtensionRatio = 0.0
        var archerFrames = 0
        var maxArcherRetreatRatio = 0.0

        let baselineGuardWristX = point(roles.guardWrist, in: context.startPose)?.x

        for frame in context.attempt.startFrame...context.attempt.endFrame {
            guard let pose = context.poses[optional: frame],
                  let signal = rearHandDropSignal(
                    in: pose,
                    guardWrist: roles.guardWrist,
                    guardElbow: roles.guardElbow
                  ),
                  let extensionRatio = strikingExtensionRatio(
                    in: pose,
                    strikingWrist: roles.strikingWrist,
                    strikingShoulder: roles.strikingShoulder
                  ) else {
                continue
            }

            let extensionDelta = extensionRatio - baselineExtension
            let isExtensionFrame = extensionDelta > 0.10 || extensionRatio > 1.14
            let baselineRatio = baselineSignal?.guardRatio ?? signal.guardRatio
            let guardDelta = signal.guardRatio - baselineRatio
            let handFarFromGuard = signal.guardRatio > 0.98 || guardDelta > 0.34
            var retreatRatio = 0.0

            if let baselineGuardWristX,
               let currentGuardWrist = point(roles.guardWrist, in: pose),
               let shoulderWidth = bilateralDistance(.leftShoulder, .rightShoulder, in: pose) {
                let retreatDistance = forwardDelta(
                    currentX: baselineGuardWristX,
                    referenceX: currentGuardWrist.x,
                    direction: context.forwardDirection
                )
                retreatRatio = retreatDistance / max(shoulderWidth, 0.001)
                maxArcherRetreatRatio = max(maxArcherRetreatRatio, retreatRatio)
            }

            let archerGuardLoss = retreatRatio > 0.26
            let archerFrameQualified = archerGuardLoss && (signal.guardRatio > 0.88 || guardDelta > 0.22)

            if isExtensionFrame {
                extensionFrames += 1
                maxGuardRatio = max(maxGuardRatio, signal.guardRatio)
                maxExtensionRatio = max(maxExtensionRatio, extensionRatio)

                let guardDropped =
                    archerFrameQualified ||
                    (handFarFromGuard && signal.wristDroppedBelowChin) ||
                    (handFarFromGuard && signal.elbowFlared && signal.guardRatio > 1.02)
                if guardDropped {
                    droppedFrames += 1
                    if retreatRatio > 0.26 {
                        archerFrames += 1
                    }
                }
                continue
            }

            if archerFrameQualified {
                droppedFrames += 1
                if retreatRatio > 0.26 {
                    archerFrames += 1
                }
                maxGuardRatio = max(maxGuardRatio, signal.guardRatio)
            }
        }

        let archerPatternDetected = archerFrames >= 2 && maxArcherRetreatRatio > 0.24
        let archerSevereDetected =
            maxArcherRetreatRatio > 0.34 &&
            droppedFrames >= 1 &&
            maxGuardRatio > 0.95
        let archerLikeDetected = archerPatternDetected || archerSevereDetected

        guard extensionFrames >= 2 || archerLikeDetected else {
            MuayThaiDebug.log("RearHandDrop: skipped (insufficient extension frames=\(extensionFrames))")
            return nil
        }

        guard maxExtensionRatio >= 1.20 || archerLikeDetected else {
            MuayThaiDebug.log("RearHandDrop: skipped (insufficient jab extension maxExtensionRatio=\(MuayThaiDebug.format(maxExtensionRatio)))")
            return nil
        }

        let droppedRatio = Double(droppedFrames) / Double(extensionFrames)
        MuayThaiDebug.log("RearHandDrop: extensionFrames=\(extensionFrames) droppedFrames=\(droppedFrames) droppedRatio=\(MuayThaiDebug.format(droppedRatio)) maxGuardRatio=\(MuayThaiDebug.format(maxGuardRatio)) maxExtensionRatio=\(MuayThaiDebug.format(maxExtensionRatio))")

        let baselineGuardRatio = baselineSignal?.guardRatio ?? max(0, maxGuardRatio - 0.1)
        let guardLift = max(0, maxGuardRatio - baselineGuardRatio)
        let severeGuardDropDetected =
            droppedFrames >= 1 &&
            maxGuardRatio > 1.28 &&
            guardLift > 0.36
        let rearGuardDropDetected =
            (
                (droppedFrames >= 5 || (droppedFrames >= 4 && extensionFrames <= 5)) &&
                droppedRatio >= 0.78 &&
                maxGuardRatio > 1.12 &&
                guardLift > 0.30
            ) ||
            (archerPatternDetected &&
             droppedFrames >= 2 &&
             maxGuardRatio > 0.90 &&
             guardLift > 0.10) ||
            archerSevereDetected ||
            severeGuardDropDetected
        let leadReturnExposure = detectLeadHandChinExposure(context: context)
        let leadReturnOnlyDetected =
            !rearGuardDropDetected &&
            leadReturnExposure != nil &&
            maxExtensionRatio > 1.42 &&
            droppedRatio > 0.72 &&
            guardLift > 0.28

        if !(rearGuardDropDetected || leadReturnOnlyDetected) {
            if allowClipFallback,
               context.stanceSource == .userSelected,
               (context.attempt.startFrame > 0 || context.attempt.endFrame < context.poses.count - 1),
               let clipContext = clipWideAttemptContext(from: context) {
                MuayThaiDebug.log("RearHandDrop: retrying with clip-wide window")
                return detectRearHandDropping(
                    entry: entry,
                    context: clipContext,
                    allowClipFallback: false
                )
            }
            MuayThaiDebug.log("RearHandDrop: not triggered")
            return nil
        }

        let message: String
        if archerLikeDetected {
            message = "your rear hand pulled back like drawing a bow during the jab. keep it on your cheek and return the jab straight back to guard"
        } else if leadReturnOnlyDetected {
            message = "your jab hand returned wide and left your chin exposed. retract it straight back to your guard line"
        } else {
            message = entry.cueDetailed
        }

        MuayThaiDebug.log("RearHandDrop: triggered")

        var affectedJoints: [BodyJoint] = [roles.guardWrist, roles.guardElbow, roles.guardShoulder, .nose]
        var metrics: [FeedbackMetric] = []
        if rearGuardDropDetected {
            metrics.append(
                FeedbackMetric(kind: .muayThaiRearHandGuardDistanceRatio, value: maxGuardRatio, unit: .ratio)
            )
        }
        if let leadReturnExposure {
            affectedJoints.append(contentsOf: leadReturnExposure.affectedJoints)
            metrics.append(contentsOf: leadReturnExposure.metrics)
        }
        affectedJoints = Array(Set(affectedJoints))

        return Detection(
            severity: entry.severity,
            category: .safety,
            message: message,
            affectedJoints: affectedJoints,
            metrics: metrics
        )
    }

    private static func shouldOverridePunchRoleResolution(
        existing: MuayThaiPunchRoleResolution,
        attemptInferenceConfidence: Double,
        stanceSource: FightStanceResolution.Source
    ) -> Bool {
        if attemptInferenceConfidence < 0.18 {
            return false
        }
        if existing.source != .motionInferred {
            return true
        }
        if attemptInferenceConfidence > existing.confidence + 0.02 {
            return true
        }
        return stanceSource == .userSelected && attemptInferenceConfidence >= 0.22
    }

    private static func punchRoleResolution(
        strikingWrist: BodyJoint,
        confidence: Double,
        source: MuayThaiPunchRoleSource
    ) -> MuayThaiPunchRoleResolution {
        let clampedConfidence = max(0, min(confidence, 1))
        switch strikingWrist {
        case .leftWrist:
            return MuayThaiPunchRoleResolution(
                strikingWrist: .leftWrist,
                guardWrist: .rightWrist,
                strikingElbow: .leftElbow,
                guardElbow: .rightElbow,
                strikingShoulder: .leftShoulder,
                guardShoulder: .rightShoulder,
                confidence: clampedConfidence,
                source: source
            )
        case .rightWrist:
            return MuayThaiPunchRoleResolution(
                strikingWrist: .rightWrist,
                guardWrist: .leftWrist,
                strikingElbow: .rightElbow,
                guardElbow: .leftElbow,
                strikingShoulder: .rightShoulder,
                guardShoulder: .leftShoulder,
                confidence: clampedConfidence,
                source: source
            )
        default:
            return MuayThaiPunchRoleResolution(
                strikingWrist: .leftWrist,
                guardWrist: .rightWrist,
                strikingElbow: .leftElbow,
                guardElbow: .rightElbow,
                strikingShoulder: .leftShoulder,
                guardShoulder: .rightShoulder,
                confidence: clampedConfidence,
                source: source
            )
        }
    }

    private static func inferDominantPunchSideAcrossAttempt(
        context: AttemptContext
    ) -> (strikingWrist: BodyJoint, confidence: Double)? {
        inferDominantPunchSide(
            poses: context.poses,
            frameRange: context.attempt.startFrame...context.attempt.endFrame
        )
    }

    private static func inferDominantPunchSideAcrossClip(
        poses: [PoseDetectionResult]
    ) -> (strikingWrist: BodyJoint, confidence: Double)? {
        guard !poses.isEmpty else { return nil }
        return inferDominantPunchSide(poses: poses, frameRange: 0...(poses.count - 1))
    }

    private static func inferDominantPunchSide(
        poses: [PoseDetectionResult],
        frameRange: ClosedRange<Int>
    ) -> (strikingWrist: BodyJoint, confidence: Double)? {
        var leftTravel = 0.0
        var rightTravel = 0.0
        var leftExtensionGain = 0.0
        var rightExtensionGain = 0.0

        var previousLeftWrist: CGPoint?
        var previousRightWrist: CGPoint?

        var leftReachMin = Double.greatestFiniteMagnitude
        var leftReachMax = 0.0
        var rightReachMin = Double.greatestFiniteMagnitude
        var rightReachMax = 0.0

        for frame in frameRange {
            guard let pose = poses[optional: frame] else { continue }

            if let leftWrist = point(.leftWrist, in: pose) {
                if let previousLeftWrist {
                    leftTravel += PoseAnalysisHelpers.distance(from: previousLeftWrist, to: leftWrist)
                }
                previousLeftWrist = leftWrist
            }

            if let rightWrist = point(.rightWrist, in: pose) {
                if let previousRightWrist {
                    rightTravel += PoseAnalysisHelpers.distance(from: previousRightWrist, to: rightWrist)
                }
                previousRightWrist = rightWrist
            }

            if let leftReach = strikingExtensionRatio(
                in: pose,
                strikingWrist: .leftWrist,
                strikingShoulder: .leftShoulder
            ) {
                leftReachMin = min(leftReachMin, leftReach)
                leftReachMax = max(leftReachMax, leftReach)
            }

            if let rightReach = strikingExtensionRatio(
                in: pose,
                strikingWrist: .rightWrist,
                strikingShoulder: .rightShoulder
            ) {
                rightReachMin = min(rightReachMin, rightReach)
                rightReachMax = max(rightReachMax, rightReach)
            }
        }

        if leftReachMin < Double.greatestFiniteMagnitude {
            leftExtensionGain = max(0, leftReachMax - leftReachMin)
        }
        if rightReachMin < Double.greatestFiniteMagnitude {
            rightExtensionGain = max(0, rightReachMax - rightReachMin)
        }

        let leftScore = leftTravel + (leftExtensionGain * 0.80)
        let rightScore = rightTravel + (rightExtensionGain * 0.80)
        let maxScore = max(leftScore, rightScore)
        let gap = abs(leftScore - rightScore)
        guard maxScore > 0.10, gap > 0.02 else {
            return nil
        }

        let confidence = max(0, min(gap / max(maxScore, 0.001), 1))
        let strikingWrist: BodyJoint = leftScore >= rightScore ? .leftWrist : .rightWrist
        return (strikingWrist: strikingWrist, confidence: confidence)
    }

    private static func clipWideAttemptContext(from context: AttemptContext) -> AttemptContext? {
        guard !context.poses.isEmpty else { return nil }
        let peakFrame = max(0, min(context.attempt.peakFrame, context.poses.count - 1))
        let peakTimestamp = context.poses[optional: peakFrame]?.timestamp.timeIntervalSince1970 ?? context.attempt.peakTimestamp
        let clipAttempt = TechniqueAttempt(
            startFrame: 0,
            endFrame: context.poses.count - 1,
            peakFrame: peakFrame,
            peakTimestamp: peakTimestamp
        )

        return AttemptContext(
            poses: context.poses,
            attempt: clipAttempt,
            attemptTechnique: context.attemptTechnique,
            attemptConfidence: context.attemptConfidence,
            mixedTechniques: context.mixedTechniques,
            stance: context.stance,
            stanceSource: context.stanceSource
        )
    }

    private static func rearHandDropSignal(
        in pose: PoseDetectionResult,
        guardWrist: BodyJoint,
        guardElbow: BodyJoint
    ) -> (guardRatio: Double, wristDroppedBelowChin: Bool, elbowFlared: Bool)? {
        guard let wrist = point(guardWrist, in: pose),
              let elbow = point(guardElbow, in: pose),
              let hip = point(sameSideHip(for: guardWrist), in: pose),
              let nose = point(.nose, in: pose) else {
            return nil
        }

        let guardDistance = PoseAnalysisHelpers.distance(from: wrist, to: nose)
        let shoulderWidth = bilateralDistance(.leftShoulder, .rightShoulder, in: pose) ?? 0.2
        let guardRatio = guardDistance / max(shoulderWidth, 0.001)
        let elbowToRib = PoseAnalysisHelpers.distance(from: elbow, to: hip)

        return (
            guardRatio: guardRatio,
            wristDroppedBelowChin: wrist.y < nose.y - 0.03,
            elbowFlared: elbowToRib > 0.2
        )
    }

    private static func strikingExtensionRatio(
        in pose: PoseDetectionResult,
        strikingWrist: BodyJoint,
        strikingShoulder: BodyJoint
    ) -> Double? {
        guard let wrist = point(strikingWrist, in: pose),
              let shoulder = point(strikingShoulder, in: pose) else {
            return nil
        }

        let shoulderWidth = bilateralDistance(.leftShoulder, .rightShoulder, in: pose) ?? 0.2
        let armReach = PoseAnalysisHelpers.distance(from: shoulder, to: wrist)
        return armReach / max(shoulderWidth, 0.001)
    }

    private static func detectForwardOverBaseForJab(entry: MuayThaiIssueCatalogEntry, context: AttemptContext) -> Detection? {
        let roles = MuayThaiAttemptRoleResolver.resolvePunchRoles(
            technique: .jab,
            startPose: context.startPose,
            peakPose: context.peakPose,
            stance: context.stance
        )
        let strikingKnee = roles.source == .fallback
            ? context.joints.leadKnee
            : sameSideKnee(for: roles.strikingWrist)

        MuayThaiDebug.log("JabLean: role source=\(String(describing: roles.source)) strikingWrist=\(roles.strikingWrist.rawValue) strikingKnee=\(strikingKnee.rawValue) fwd=\(MuayThaiDebug.format(context.forwardDirection, decimals: 2))")

        let strikingShoulder = roles.source == .fallback ? context.joints.leadShoulder : roles.strikingShoulder
        let baselineExtension = strikingExtensionRatio(
            in: context.startPose,
            strikingWrist: roles.strikingWrist,
            strikingShoulder: strikingShoulder
        ) ?? 0
        let baselineNoseDelta: Double = {
            guard let startNose = point(.nose, in: context.startPose),
                  let startKnee = point(strikingKnee, in: context.startPose) else {
                return 0
            }
            return forwardDelta(currentX: startNose.x, referenceX: startKnee.x, direction: context.forwardDirection)
        }()

        var triggeredFrames = 0
        var extensionFrames = 0
        var maxTorsoAngle = 0.0
        var maxNoseAdvance = 0.0

        for frame in context.attempt.startFrame...context.attempt.endFrame {
            guard let pose = context.poses[optional: frame],
                  let torsoAngle = torsoForwardAngle(in: pose),
                  let extensionRatio = strikingExtensionRatio(
                    in: pose,
                    strikingWrist: roles.strikingWrist,
                    strikingShoulder: strikingShoulder
                  ),
                  let nose = point(.nose, in: pose),
                  let leadKnee = point(strikingKnee, in: pose) else {
                continue
            }

            let extensionDelta = extensionRatio - baselineExtension
            let isExtensionFrame = extensionDelta > 0.12 || extensionRatio > 1.18
            guard isExtensionFrame else { continue }
            extensionFrames += 1

            let noseDelta = forwardDelta(currentX: nose.x, referenceX: leadKnee.x, direction: context.forwardDirection)
            let noseAdvance = noseDelta - baselineNoseDelta
            let leaning = torsoAngle > 34 && noseAdvance > 0.038 && noseDelta > 0.05
            guard leaning else { continue }

            triggeredFrames += 1
            maxTorsoAngle = max(maxTorsoAngle, torsoAngle)
            maxNoseAdvance = max(maxNoseAdvance, noseAdvance)
        }

        let triggeredRatio = extensionFrames > 0
            ? Double(triggeredFrames) / Double(extensionFrames)
            : 0
        MuayThaiDebug.log("JabLean: extensionFrames=\(extensionFrames) triggeredFrames=\(triggeredFrames) triggeredRatio=\(MuayThaiDebug.format(triggeredRatio)) maxTorsoAngle=\(MuayThaiDebug.format(maxTorsoAngle)) maxNoseAdvance=\(MuayThaiDebug.format(maxNoseAdvance))")
        guard triggeredFrames >= 2,
              triggeredRatio >= 0.55,
              maxTorsoAngle > 36 || maxNoseAdvance > 0.055 else {
            MuayThaiDebug.log("JabLean: not triggered")
            return nil
        }

        MuayThaiDebug.log("JabLean: triggered")

        return Detection(
            severity: entry.severity,
            category: .posture,
            message: entry.cueDetailed,
            affectedJoints: [
                context.joints.leadShoulder,
                context.joints.rearShoulder,
                context.joints.leadHip,
                context.joints.rearHip,
                .nose,
                strikingKnee
            ],
            metrics: [
                FeedbackMetric(kind: .muayThaiTorsoForwardLeanDegrees, value: maxTorsoAngle, unit: .degrees)
            ]
        )
    }

    private static func detectLeadHandChinExposure(
        context: AttemptContext
    ) -> (affectedJoints: [BodyJoint], metrics: [FeedbackMetric])? {
        let roles = MuayThaiAttemptRoleResolver.resolvePunchRoles(
            technique: .jab,
            startPose: context.startPose,
            peakPose: context.peakPose,
            stance: context.stance
        )
        let strikingShoulder = roles.source == .fallback ? context.joints.leadShoulder : roles.strikingShoulder
        let strikingElbow = roles.source == .fallback ? context.joints.leadElbow : roles.strikingElbow
        let strikingWrist = roles.source == .fallback ? context.joints.leadWrist : roles.strikingWrist

        guard let startWrist = point(strikingWrist, in: context.startPose),
              let peakWrist = point(strikingWrist, in: context.peakPose),
              let startNose = point(.nose, in: context.startPose) else {
            return nil
        }

        let baselineExtension = strikingExtensionRatio(
            in: context.startPose,
            strikingWrist: strikingWrist,
            strikingShoulder: strikingShoulder
        ) ?? 0
        let peakExtension = strikingExtensionRatio(
            in: context.peakPose,
            strikingWrist: strikingWrist,
            strikingShoulder: strikingShoulder
        ) ?? baselineExtension
        let extensionAmplitude = peakExtension - baselineExtension
        guard extensionAmplitude > 0.24 || peakExtension > 1.30 else {
            return nil
        }

        let startShoulderWidth = bilateralDistance(.leftShoulder, .rightShoulder, in: context.startPose) ?? 0.2
        let baselineGuardRatio = PoseAnalysisHelpers.distance(from: startWrist, to: startNose) / max(startShoulderWidth, 0.001)

        var retractionFrames = 0
        var chinExposureFrames = 0
        var offLineFrames = 0
        var maxGapRatio = 0.0
        var maxReturnPathDeviationRatio = 0.0

        let retractionStart = max(context.attempt.peakFrame, context.attempt.startFrame)
        for frame in retractionStart...context.attempt.endFrame {
            guard let pose = context.poses[optional: frame],
                  let wrist = point(strikingWrist, in: pose),
                  let shoulder = point(strikingShoulder, in: pose),
                  let nose = point(.nose, in: pose),
                  let shoulderWidth = bilateralDistance(.leftShoulder, .rightShoulder, in: pose),
                  let extensionRatio = strikingExtensionRatio(
                    in: pose,
                    strikingWrist: strikingWrist,
                    strikingShoulder: strikingShoulder
                  ) else {
                continue
            }

            let extensionProgress = (extensionRatio - baselineExtension) / max(extensionAmplitude, 0.001)
            let inRetractionWindow = extensionProgress > 0.20 || frame >= context.attempt.endFrame - 1
            guard inRetractionWindow else { continue }

            retractionFrames += 1

            let guardGap = Double(nose.y - shoulder.y)
            let gapRatio = guardGap / max(shoulderWidth, 0.001)
            let guardDistanceRatio = PoseAnalysisHelpers.distance(from: wrist, to: nose) / max(shoulderWidth, 0.001)
            let returnPathDeviationRatio = pointToLineDistance(point: wrist, lineStart: peakWrist, lineEnd: startWrist) / max(shoulderWidth, 0.001)

            maxGapRatio = max(maxGapRatio, gapRatio)
            maxReturnPathDeviationRatio = max(maxReturnPathDeviationRatio, returnPathDeviationRatio)

            let chinExposed = guardDistanceRatio > max(0.68, baselineGuardRatio + 0.09) && gapRatio > 0.27
            if chinExposed {
                chinExposureFrames += 1
            }

            if returnPathDeviationRatio > 0.19 {
                offLineFrames += 1
            }
        }

        guard retractionFrames >= 6 else { return nil }
        let exposureRatio = Double(chinExposureFrames) / Double(retractionFrames)
        let offLineRatio = Double(offLineFrames) / Double(retractionFrames)
        guard chinExposureFrames >= 3,
              offLineFrames >= 4,
              exposureRatio >= 0.52,
              offLineRatio >= 0.62,
              maxGapRatio > 0.36,
              maxReturnPathDeviationRatio > 0.30 else { return nil }

        return (
            affectedJoints: [strikingShoulder, strikingElbow, strikingWrist, .nose],
            metrics: [
                FeedbackMetric(kind: .muayThaiShoulderGuardGapRatio, value: maxGapRatio, unit: .ratio),
                FeedbackMetric(kind: .muayThaiJabReturnPathDeviationRatio, value: maxReturnPathDeviationRatio, unit: .ratio)
            ]
        )
    }

    private static func detectPoorRetraction(entry: MuayThaiIssueCatalogEntry, context: AttemptContext) -> Detection? {
        let roles = MuayThaiAttemptRoleResolver.resolvePunchRoles(
            technique: .jab,
            startPose: context.startPose,
            peakPose: context.peakPose,
            stance: context.stance
        )
        let strikingShoulder = roles.source == .fallback ? context.joints.leadShoulder : roles.strikingShoulder
        let strikingElbow = roles.source == .fallback ? context.joints.leadElbow : roles.strikingElbow
        let strikingWrist = roles.source == .fallback ? context.joints.leadWrist : roles.strikingWrist

        let baselineExtension = strikingExtensionRatio(
            in: context.startPose,
            strikingWrist: strikingWrist,
            strikingShoulder: strikingShoulder
        ) ?? 0

        var peakExtension = baselineExtension
        var peakFrame = context.attempt.peakFrame

        for frame in context.attempt.startFrame...context.attempt.endFrame {
            guard let pose = context.poses[optional: frame],
                  let extensionRatio = strikingExtensionRatio(
                    in: pose,
                    strikingWrist: strikingWrist,
                    strikingShoulder: strikingShoulder
                  ) else {
                continue
            }

            if extensionRatio > peakExtension {
                peakExtension = extensionRatio
                peakFrame = frame
            }
        }

        let extensionAmplitude = peakExtension - baselineExtension
        guard extensionAmplitude > 0.22 || peakExtension > 1.28 else {
            return nil
        }

        var retractionFrames = 0
        var lagFrames = 0
        var endExtension = baselineExtension

        for frame in max(peakFrame, context.attempt.startFrame)...context.attempt.endFrame {
            guard let pose = context.poses[optional: frame],
                  let extensionRatio = strikingExtensionRatio(
                    in: pose,
                    strikingWrist: strikingWrist,
                    strikingShoulder: strikingShoulder
                  ) else {
                continue
            }

            retractionFrames += 1
            endExtension = extensionRatio

            let lagRatio = max(0, (extensionRatio - baselineExtension) / max(extensionAmplitude, 0.001))
            if lagRatio > 0.60 {
                lagFrames += 1
            }
        }

        guard retractionFrames >= 4 else { return nil }

        let endLagRatio = max(0, (endExtension - baselineExtension) / max(extensionAmplitude, 0.001))
        let lagPersistenceRatio = Double(lagFrames) / Double(retractionFrames)
        guard lagFrames >= 3, endLagRatio > 0.58, lagPersistenceRatio > 0.68 else {
            return nil
        }

        return Detection(
            severity: entry.severity,
            category: .tempo,
            message: entry.cueDetailed,
            affectedJoints: [strikingShoulder, strikingElbow, strikingWrist],
            metrics: [
                FeedbackMetric(kind: .muayThaiJabRetractionLagRatio, value: endLagRatio, unit: .ratio)
            ]
        )
    }

    private static func detectNoHipRotation(entry: MuayThaiIssueCatalogEntry, context: AttemptContext) -> Detection? {
        let roles = MuayThaiAttemptRoleResolver.resolvePunchRoles(
            technique: .cross,
            startPose: context.startPose,
            peakPose: context.peakPose,
            stance: context.stance
        )
        let strikingShoulder = roles.source == .fallback ? context.joints.rearShoulder : roles.strikingShoulder
        let strikingWrist = roles.source == .fallback ? context.joints.rearWrist : roles.strikingWrist

        let startExtension = strikingExtensionRatio(
            in: context.startPose,
            strikingWrist: strikingWrist,
            strikingShoulder: strikingShoulder
        ) ?? 0
        let startRearHip = point(context.joints.rearHip, in: context.startPose)

        struct RotationSample {
            let frame: Int
            let extensionRatio: Double
            let hipRotation: Double
            let shoulderRotation: Double
        }

        var maxExtension = startExtension
        var maxRearHipDrive = 0.0
        var rotationSamples: [RotationSample] = []
        for frame in context.attempt.startFrame...context.attempt.endFrame {
            guard let pose = context.poses[optional: frame],
                  let shoulderWidth = bilateralDistance(.leftShoulder, .rightShoulder, in: pose),
                  shoulderWidth > 0.06,
                  let extensionRatioAtFrame = strikingExtensionRatio(
                    in: pose,
                    strikingWrist: strikingWrist,
                    strikingShoulder: strikingShoulder
                  ) else {
                continue
            }

            // Side-angle tracking can briefly collapse shoulder width and produce
            // impossible extension spikes. Ignore those for rotation checks.
            guard extensionRatioAtFrame <= 2.6 else { continue }

            if extensionRatioAtFrame > maxExtension {
                maxExtension = extensionRatioAtFrame
            }

            if let startRearHip,
               let rearHip = point(context.joints.rearHip, in: pose) {
                let rearHipDrive = forwardDelta(
                    currentX: rearHip.x,
                    referenceX: startRearHip.x,
                    direction: context.forwardDirection
                ) / max(shoulderWidth, 0.001)
                maxRearHipDrive = max(maxRearHipDrive, rearHipDrive)
            }

            guard let hipRotation = lineRotation(
                startA: point(.leftHip, in: context.startPose),
                startB: point(.rightHip, in: context.startPose),
                endA: point(.leftHip, in: pose),
                endB: point(.rightHip, in: pose)
            ),
            let shoulderRotation = lineRotation(
                startA: point(.leftShoulder, in: context.startPose),
                startB: point(.rightShoulder, in: context.startPose),
                endA: point(.leftShoulder, in: pose),
                endB: point(.rightShoulder, in: pose)
            ) else {
                continue
            }

            rotationSamples.append(
                RotationSample(
                    frame: frame,
                    extensionRatio: extensionRatioAtFrame,
                    hipRotation: hipRotation,
                    shoulderRotation: shoulderRotation
                )
            )
        }

        let extensionDelta = maxExtension - startExtension
        guard extensionDelta > 0.10 || maxExtension > 1.18 else {
            return nil
        }

        guard !rotationSamples.isEmpty else { return nil }

        let nearPeakFloor = max(startExtension + 0.08, maxExtension - 0.18)
        let nearPeakSamples = rotationSamples.filter { $0.extensionRatio >= nearPeakFloor }
        let selectedSamples = nearPeakSamples.isEmpty ? rotationSamples : nearPeakSamples

        let hipRotation = percentile(selectedSamples.map(\.hipRotation), percentile: 0.30)
        let shoulderRotation = percentile(selectedSamples.map(\.shoulderRotation), percentile: 0.30)
        let representativeFrame = selectedSamples
            .min { ($0.hipRotation + $0.shoulderRotation) < ($1.hipRotation + $1.shoulderRotation) }?
            .frame ?? context.attempt.peakFrame

        guard let endHipRotation = lineRotation(
            startA: point(.leftHip, in: context.startPose),
            startB: point(.rightHip, in: context.startPose),
            endA: point(.leftHip, in: context.endPose),
            endB: point(.rightHip, in: context.endPose)
        ),
        let endShoulderRotation = lineRotation(
            startA: point(.leftShoulder, in: context.startPose),
            startB: point(.rightShoulder, in: context.startPose),
            endA: point(.leftShoulder, in: context.endPose),
            endB: point(.rightShoulder, in: context.endPose)
        ) else {
            return nil
        }

        MuayThaiDebug.log(
            "CrossNoHipRotation: startExt=\(MuayThaiDebug.format(startExtension)) maxExt=\(MuayThaiDebug.format(maxExtension)) delta=\(MuayThaiDebug.format(extensionDelta)) repFrame=\(representativeFrame) hipRotP35=\(MuayThaiDebug.format(hipRotation)) shoulderRotP35=\(MuayThaiDebug.format(shoulderRotation)) endHip=\(MuayThaiDebug.format(endHipRotation)) endShoulder=\(MuayThaiDebug.format(endShoulderRotation)) rearHipDrive=\(MuayThaiDebug.format(maxRearHipDrive)) samples=\(selectedSamples.count)"
        )

        guard hipRotation < 5.2,
              shoulderRotation < 8.2,
              endHipRotation < 7.2,
              endShoulderRotation < 10.2,
              maxRearHipDrive < 0.009 else { return nil }

        return Detection(
            severity: entry.severity,
            category: .posture,
            message: entry.cueDetailed,
            affectedJoints: [.leftHip, .rightHip, .leftShoulder, .rightShoulder],
            metrics: [
                FeedbackMetric(kind: .muayThaiHipRotationDegrees, value: hipRotation, unit: .degrees),
                FeedbackMetric(kind: .muayThaiShoulderRotationDegrees, value: shoulderRotation, unit: .degrees)
            ]
        )
    }

    private static func detectForwardOverBaseForCross(entry: MuayThaiIssueCatalogEntry, context: AttemptContext) -> Detection? {
        guard let startNose = point(.nose, in: context.startPose),
              let startLeadAnkle = point(context.joints.leadAnkle, in: context.startPose),
              let startRearAnkle = point(context.joints.rearAnkle, in: context.startPose) else {
            return nil
        }

        let roles = MuayThaiAttemptRoleResolver.resolvePunchRoles(
            technique: .cross,
            startPose: context.startPose,
            peakPose: context.peakPose,
            stance: context.stance
        )
        let strikingShoulder = roles.source == .fallback ? context.joints.rearShoulder : roles.strikingShoulder
        let baselineExtension = strikingExtensionRatio(
            in: context.startPose,
            strikingWrist: roles.strikingWrist,
            strikingShoulder: strikingShoulder
        ) ?? 0

        let baselineStanceWidth = max(abs(Double(startLeadAnkle.x - startRearAnkle.x)), 0.001)
        let baselineRatio = forwardDelta(
            currentX: startNose.x,
            referenceX: startLeadAnkle.x,
            direction: context.forwardDirection
        ) / baselineStanceWidth

        var extensionFrames = 0
        var triggeredFrames = 0
        var maxOverreachRatio = 0.0
        var maxTorsoAngle = 0.0

        for frame in context.attempt.startFrame...context.attempt.endFrame {
            guard let pose = context.poses[optional: frame],
                  let extensionRatio = strikingExtensionRatio(
                    in: pose,
                    strikingWrist: roles.strikingWrist,
                    strikingShoulder: strikingShoulder
                  ),
                  let torsoAngle = torsoForwardAngle(in: pose),
                  let nose = point(.nose, in: pose),
                  let leadAnkle = point(context.joints.leadAnkle, in: pose),
                  let rearAnkle = point(context.joints.rearAnkle, in: pose) else {
                continue
            }

            let extensionDelta = extensionRatio - baselineExtension
            let isExtensionFrame = extensionDelta > 0.10 || extensionRatio > 1.18
            guard isExtensionFrame else { continue }
            extensionFrames += 1

            let stanceWidth = max(abs(Double(leadAnkle.x - rearAnkle.x)), 0.001)
            let overreachRatio = forwardDelta(
                currentX: nose.x,
                referenceX: leadAnkle.x,
                direction: context.forwardDirection
            ) / stanceWidth

            let overreachDelta = overreachRatio - baselineRatio
            let leaning = torsoAngle > 30 && overreachDelta > 0.12 && overreachRatio > 0.06
            if leaning {
                triggeredFrames += 1
                maxOverreachRatio = max(maxOverreachRatio, overreachDelta)
                maxTorsoAngle = max(maxTorsoAngle, torsoAngle)
            }
        }

        let triggeredRatio = extensionFrames > 0
            ? Double(triggeredFrames) / Double(extensionFrames)
            : 0
        guard triggeredFrames >= 2, triggeredRatio >= 0.45, maxOverreachRatio > 0.16 else { return nil }

        return Detection(
            severity: entry.severity,
            category: .safety,
            message: entry.cueDetailed,
            affectedJoints: [
                .nose,
                context.joints.rearShoulder,
                context.joints.leadAnkle,
                context.joints.rearAnkle
            ],
            metrics: [
                FeedbackMetric(kind: .muayThaiOverreachRatio, value: maxOverreachRatio, unit: .ratio),
                FeedbackMetric(kind: .muayThaiTorsoForwardLeanDegrees, value: maxTorsoAngle, unit: .degrees)
            ]
        )
    }

    private static func detectArmOnlyHook(entry: MuayThaiIssueCatalogEntry, context: AttemptContext) -> Detection? {
        guard let hipRotation = lineRotation(
            startA: point(.leftHip, in: context.startPose),
            startB: point(.rightHip, in: context.startPose),
            endA: point(.leftHip, in: context.peakPose),
            endB: point(.rightHip, in: context.peakPose)
        ),
        let shoulderRotation = lineRotation(
            startA: point(.leftShoulder, in: context.startPose),
            startB: point(.rightShoulder, in: context.startPose),
            endA: point(.leftShoulder, in: context.peakPose),
            endB: point(.rightShoulder, in: context.peakPose)
        ),
        let startElbow = point(context.joints.leadElbow, in: context.startPose),
        let peakElbow = point(context.joints.leadElbow, in: context.peakPose) else {
            return nil
        }

        let elbowTravel = PoseAnalysisHelpers.distance(from: startElbow, to: peakElbow)
        guard hipRotation < 12 && shoulderRotation < 14 && elbowTravel > 0.08 else { return nil }

        return Detection(
            severity: entry.severity,
            category: .posture,
            message: entry.cueDetailed,
            affectedJoints: [context.joints.leadElbow, context.joints.leadShoulder, context.joints.leadHip, context.joints.rearHip],
            metrics: [
                FeedbackMetric(kind: .muayThaiBodyRotationDegrees, value: shoulderRotation, unit: .degrees)
            ]
        )
    }

    private static func detectHookTooWide(entry: MuayThaiIssueCatalogEntry, context: AttemptContext) -> Detection? {
        guard let leadShoulder = point(context.joints.leadShoulder, in: context.peakPose),
              let leadElbow = point(context.joints.leadElbow, in: context.peakPose),
              let leadWrist = point(context.joints.leadWrist, in: context.peakPose) else {
            return nil
        }

        let elbowRadius = PoseAnalysisHelpers.distance(from: leadShoulder, to: leadElbow)
        let wristRadius = PoseAnalysisHelpers.distance(from: leadShoulder, to: leadWrist)
        let arcRatio = wristRadius / max(elbowRadius, 0.001)

        guard arcRatio > 2.1 else { return nil }

        return Detection(
            severity: entry.severity,
            category: .tempo,
            message: entry.cueDetailed,
            affectedJoints: [context.joints.leadShoulder, context.joints.leadElbow, context.joints.leadWrist],
            metrics: [
                FeedbackMetric(kind: .muayThaiLeadArmArcRatio, value: arcRatio, unit: .ratio)
            ]
        )
    }

    private static func detectNoHipTurnover(entry: MuayThaiIssueCatalogEntry, context: AttemptContext) -> Detection? {
        guard let startKickAnkle = point(context.joints.leadAnkle, in: context.startPose),
              let peakKickAnkle = point(context.joints.leadAnkle, in: context.peakPose) else {
            return nil
        }

        let kickTravel = PoseAnalysisHelpers.distance(from: startKickAnkle, to: peakKickAnkle)
        guard kickTravel > 0.05 else { return nil }

        guard let hipRotation = lineRotation(
            startA: point(.leftHip, in: context.startPose),
            startB: point(.rightHip, in: context.startPose),
            endA: point(.leftHip, in: context.peakPose),
            endB: point(.rightHip, in: context.peakPose)
        ),
        let shoulderRotation = lineRotation(
            startA: point(.leftShoulder, in: context.startPose),
            startB: point(.rightShoulder, in: context.startPose),
            endA: point(.leftShoulder, in: context.peakPose),
            endB: point(.rightShoulder, in: context.peakPose)
        ),
        let endHipRotation = lineRotation(
            startA: point(.leftHip, in: context.startPose),
            startB: point(.rightHip, in: context.startPose),
            endA: point(.leftHip, in: context.endPose),
            endB: point(.rightHip, in: context.endPose)
        ),
        let endShoulderRotation = lineRotation(
            startA: point(.leftShoulder, in: context.startPose),
            startB: point(.rightShoulder, in: context.startPose),
            endA: point(.leftShoulder, in: context.endPose),
            endB: point(.rightShoulder, in: context.endPose)
        ) else {
            return nil
        }

        guard hipRotation < 15,
              shoulderRotation < 15,
              endHipRotation < 18,
              endShoulderRotation < 18 else { return nil }

        return Detection(
            severity: entry.severity,
            category: .posture,
            message: entry.cueDetailed,
            affectedJoints: [.leftHip, .rightHip, .leftShoulder, .rightShoulder, context.joints.leadKnee],
            metrics: [
                FeedbackMetric(kind: .muayThaiHipRotationDegrees, value: hipRotation, unit: .degrees),
                FeedbackMetric(kind: .muayThaiShoulderRotationDegrees, value: shoulderRotation, unit: .degrees)
            ]
        )
    }

    private static func detectNoArmCounterbalance(entry: MuayThaiIssueCatalogEntry, context: AttemptContext) -> Detection? {
        guard let startLeadWrist = point(context.joints.leadWrist, in: context.startPose),
              let startRearWrist = point(context.joints.rearWrist, in: context.startPose),
              let startKickAnkle = point(context.joints.leadAnkle, in: context.startPose),
              let peakKickAnkle = point(context.joints.leadAnkle, in: context.peakPose) else {
            return nil
        }

        let kickTravel = PoseAnalysisHelpers.distance(from: startKickAnkle, to: peakKickAnkle)
        guard kickTravel > 0.05 else { return nil }

        var maxLeadMove = 0.0
        var maxRearMove = 0.0

        for frame in context.attempt.startFrame...context.attempt.endFrame {
            guard let pose = context.poses[optional: frame],
                  let leadWrist = point(context.joints.leadWrist, in: pose),
                  let rearWrist = point(context.joints.rearWrist, in: pose) else {
                continue
            }

            maxLeadMove = max(maxLeadMove, PoseAnalysisHelpers.distance(from: startLeadWrist, to: leadWrist))
            maxRearMove = max(maxRearMove, PoseAnalysisHelpers.distance(from: startRearWrist, to: rearWrist))
        }

        let maxMove = max(maxLeadMove, maxRearMove)

        let armToKickMotionRatio = maxMove / max(kickTravel, 0.001)
        guard maxMove < 0.10, armToKickMotionRatio < 0.7 else { return nil }

        return Detection(
            severity: entry.severity,
            category: .stability,
            message: entry.cueDetailed,
            affectedJoints: [context.joints.leadWrist, context.joints.rearWrist, context.joints.leadShoulder, context.joints.rearShoulder],
            metrics: []
        )
    }

    private static func detectNoKneeChamber(entry: MuayThaiIssueCatalogEntry, context: AttemptContext) -> Detection? {
        var maxKneeLift = -Double.infinity

        for frame in context.attempt.startFrame...context.attempt.peakFrame {
            guard let pose = context.poses[optional: frame],
                  let kickKnee = point(context.joints.leadKnee, in: pose),
                  let kickHip = point(context.joints.leadHip, in: pose) else {
                continue
            }
            maxKneeLift = max(maxKneeLift, Double(kickKnee.y - kickHip.y))
        }

        guard maxKneeLift.isFinite, maxKneeLift < 0.03 else { return nil }

        return Detection(
            severity: entry.severity,
            category: .rangeOfMotion,
            message: entry.cueDetailed,
            affectedJoints: [context.joints.leadHip, context.joints.leadKnee, context.joints.leadAnkle],
            metrics: [
                FeedbackMetric(kind: .muayThaiKneeChamberRatio, value: maxKneeLift, unit: .ratio)
            ]
        )
    }

    private static func detectTeepFallingForward(entry: MuayThaiIssueCatalogEntry, context: AttemptContext) -> Detection? {
        guard let torsoAngle = torsoForwardAngle(in: context.peakPose),
              let nose = point(.nose, in: context.peakPose),
              let supportKnee = point(context.joints.rearKnee, in: context.peakPose) else {
            return nil
        }

        let nosePastSupport = forwardDelta(currentX: nose.x, referenceX: supportKnee.x, direction: context.forwardDirection) > 0.02
        guard torsoAngle > 18 && nosePastSupport else { return nil }

        return Detection(
            severity: entry.severity,
            category: .stability,
            message: entry.cueDetailed,
            affectedJoints: [
                context.joints.leadShoulder,
                context.joints.rearShoulder,
                context.joints.leadHip,
                context.joints.rearHip,
                .nose,
                context.joints.rearKnee
            ],
            metrics: [
                FeedbackMetric(kind: .muayThaiTorsoForwardLeanDegrees, value: torsoAngle, unit: .degrees)
            ]
        )
    }

    private static func detectKneeTravelVertical(entry: MuayThaiIssueCatalogEntry, context: AttemptContext) -> Detection? {
        guard let startKnee = point(context.joints.leadKnee, in: context.startPose),
              let peakKnee = point(context.joints.leadKnee, in: context.peakPose) else {
            return nil
        }

        let deltaX = abs(Double(peakKnee.x - startKnee.x))
        let deltaY = abs(Double(peakKnee.y - startKnee.y))
        let forwardRatio = deltaX / max(deltaY, 0.001)

        guard deltaY > 0.03 && forwardRatio < 0.65 else { return nil }

        return Detection(
            severity: entry.severity,
            category: .posture,
            message: entry.cueDetailed,
            affectedJoints: [context.joints.leadHip, context.joints.leadKnee],
            metrics: [
                FeedbackMetric(kind: .muayThaiKneeDriveForwardRatio, value: forwardRatio, unit: .ratio)
            ]
        )
    }

    private static func detectNoHipThrust(entry: MuayThaiIssueCatalogEntry, context: AttemptContext) -> Detection? {
        guard let startHipMid = bilateralMidpoint(context.joints.leadHip, context.joints.rearHip, in: context.startPose),
              let peakHipMid = bilateralMidpoint(context.joints.leadHip, context.joints.rearHip, in: context.peakPose),
              let leadAnkle = point(context.joints.leadAnkle, in: context.peakPose),
              let rearAnkle = point(context.joints.rearAnkle, in: context.peakPose) else {
            return nil
        }

        let stanceWidth = max(abs(Double(leadAnkle.x - rearAnkle.x)), 0.001)
        let forwardTravel = forwardDelta(currentX: peakHipMid.x, referenceX: startHipMid.x, direction: context.forwardDirection)
        let thrustRatio = forwardTravel / stanceWidth

        guard thrustRatio < 0.10 else { return nil }

        return Detection(
            severity: entry.severity,
            category: .posture,
            message: entry.cueDetailed,
            affectedJoints: [context.joints.leadHip, context.joints.rearHip, .root],
            metrics: [
                FeedbackMetric(kind: .muayThaiHipThrustRatio, value: thrustRatio, unit: .ratio)
            ]
        )
    }

    private static func detectElbowTooWide(entry: MuayThaiIssueCatalogEntry, context: AttemptContext) -> Detection? {
        guard let leadShoulder = point(context.joints.leadShoulder, in: context.peakPose),
              let leadElbow = point(context.joints.leadElbow, in: context.peakPose),
              let shoulderWidth = bilateralDistance(.leftShoulder, .rightShoulder, in: context.peakPose) else {
            return nil
        }

        let elbowArcRatio = PoseAnalysisHelpers.distance(from: leadShoulder, to: leadElbow) / max(shoulderWidth, 0.001)
        guard elbowArcRatio > 0.75 else { return nil }

        return Detection(
            severity: entry.severity,
            category: .tempo,
            message: entry.cueDetailed,
            affectedJoints: [context.joints.leadShoulder, context.joints.leadElbow, context.joints.leadWrist],
            metrics: [
                FeedbackMetric(kind: .muayThaiLeadArmArcRatio, value: elbowArcRatio, unit: .ratio)
            ]
        )
    }

    private static func detectNoBodyRotation(entry: MuayThaiIssueCatalogEntry, context: AttemptContext) -> Detection? {
        guard let hipRotation = lineRotation(
            startA: point(.leftHip, in: context.startPose),
            startB: point(.rightHip, in: context.startPose),
            endA: point(.leftHip, in: context.peakPose),
            endB: point(.rightHip, in: context.peakPose)
        ),
        let shoulderRotation = lineRotation(
            startA: point(.leftShoulder, in: context.startPose),
            startB: point(.rightShoulder, in: context.startPose),
            endA: point(.leftShoulder, in: context.peakPose),
            endB: point(.rightShoulder, in: context.peakPose)
        ) else {
            return nil
        }

        guard hipRotation < 10 && shoulderRotation < 12 else { return nil }

        return Detection(
            severity: entry.severity,
            category: .posture,
            message: entry.cueDetailed,
            affectedJoints: [.leftHip, .rightHip, .leftShoulder, .rightShoulder, context.joints.leadElbow],
            metrics: [
                FeedbackMetric(kind: .muayThaiBodyRotationDegrees, value: shoulderRotation, unit: .degrees)
            ]
        )
    }

    private static func detectCrossingFeet(entry: MuayThaiIssueCatalogEntry, context: AttemptContext) -> Detection? {
        guard let startLeft = point(.leftAnkle, in: context.startPose),
              let startRight = point(.rightAnkle, in: context.startPose) else {
            return nil
        }

        let startOrderLeftFirst = startLeft.x <= startRight.x
        let baselineSeparation = abs(Double(startRight.x - startLeft.x))

        var minSeparation = baselineSeparation
        var crossed = false

        for frame in context.attempt.startFrame...context.attempt.endFrame {
            guard let pose = context.poses[optional: frame],
                  let left = point(.leftAnkle, in: pose),
                  let right = point(.rightAnkle, in: pose) else {
                continue
            }

            let separation = abs(Double(right.x - left.x))
            minSeparation = min(minSeparation, separation)

            let currentOrderLeftFirst = left.x <= right.x
            if currentOrderLeftFirst != startOrderLeftFirst {
                crossed = true
            }
        }

        let crossRatio = minSeparation / max(baselineSeparation, 0.001)
        guard crossed || minSeparation < 0.03 || crossRatio < 0.4 else { return nil }

        return Detection(
            severity: entry.severity,
            category: .safety,
            message: entry.cueDetailed,
            affectedJoints: [.leftAnkle, .rightAnkle, .leftKnee, .rightKnee],
            metrics: [
                FeedbackMetric(kind: .muayThaiAnkleCrossRatio, value: crossRatio, unit: .ratio)
            ]
        )
    }

    private static func pointToLineDistance(point: CGPoint, lineStart: CGPoint, lineEnd: CGPoint) -> Double {
        let dx = Double(lineEnd.x - lineStart.x)
        let dy = Double(lineEnd.y - lineStart.y)
        let denominator = (dx * dx) + (dy * dy)

        guard denominator > 1e-6 else {
            return PoseAnalysisHelpers.distance(from: point, to: lineStart)
        }

        let t = (
            (Double(point.x - lineStart.x) * dx) +
            (Double(point.y - lineStart.y) * dy)
        ) / denominator
        let clampedT = max(0, min(1, t))

        let projection = CGPoint(
            x: lineStart.x + CGFloat(clampedT) * (lineEnd.x - lineStart.x),
            y: lineStart.y + CGFloat(clampedT) * (lineEnd.y - lineStart.y)
        )
        return PoseAnalysisHelpers.distance(from: point, to: projection)
    }

    private static func sameSideHip(for wrist: BodyJoint) -> BodyJoint {
        switch wrist {
        case .leftWrist:
            return .leftHip
        case .rightWrist:
            return .rightHip
        default:
            return .leftHip
        }
    }

    private static func sameSideKnee(for wrist: BodyJoint) -> BodyJoint {
        switch wrist {
        case .leftWrist:
            return .leftKnee
        case .rightWrist:
            return .rightKnee
        default:
            return .leftKnee
        }
    }

    private static func point(_ joint: BodyJoint, in pose: PoseDetectionResult) -> CGPoint? {
        PoseAnalysisHelpers.extractKeypoint(joint.rawValue, from: pose)?.position
    }

    private static func bilateralMidpoint(_ left: BodyJoint, _ right: BodyJoint, in pose: PoseDetectionResult) -> CGPoint? {
        guard let leftPoint = point(left, in: pose), let rightPoint = point(right, in: pose) else {
            return point(left, in: pose) ?? point(right, in: pose)
        }
        return PoseAnalysisHelpers.midpoint(leftPoint, rightPoint)
    }

    private static func bilateralDistance(_ left: BodyJoint, _ right: BodyJoint, in pose: PoseDetectionResult) -> Double? {
        guard let leftPoint = point(left, in: pose), let rightPoint = point(right, in: pose) else {
            return nil
        }
        return PoseAnalysisHelpers.distance(from: leftPoint, to: rightPoint)
    }

    private static func torsoForwardAngle(in pose: PoseDetectionResult) -> Double? {
        guard let shoulders = bilateralMidpoint(.leftShoulder, .rightShoulder, in: pose),
              let hips = bilateralMidpoint(.leftHip, .rightHip, in: pose) else {
            return nil
        }

        return PoseAnalysisHelpers.calculateVerticalAngle(from: hips, to: shoulders)
    }

    private static func lineRotation(
        startA: CGPoint?,
        startB: CGPoint?,
        endA: CGPoint?,
        endB: CGPoint?
    ) -> Double? {
        guard let startA, let startB, let endA, let endB else { return nil }
        let startAngle = lineAngle(from: startA, to: startB)
        let endAngle = lineAngle(from: endA, to: endB)

        // Treat body lines as undirected segments. Side-angle tracking can swap
        // left/right keypoints across frames, which otherwise appears as ~180°
        // rotation and suppresses valid no-rotation detections.
        let directedDelta = abs(angleDelta(from: startAngle, to: endAngle))
        let flippedDelta = abs(angleDelta(from: startAngle, to: endAngle + 180))
        return min(directedDelta, flippedDelta)
    }

    private static func lineAngle(from p1: CGPoint, to p2: CGPoint) -> Double {
        atan2(Double(p2.y - p1.y), Double(p2.x - p1.x)) * 180.0 / .pi
    }

    private static func angleDelta(from start: Double, to end: Double) -> Double {
        let wrapped = (end - start + 540).truncatingRemainder(dividingBy: 360) - 180
        return wrapped
    }

    private static func percentile(_ values: [Double], percentile: Double) -> Double {
        guard !values.isEmpty else { return 0 }
        let sorted = values.sorted()
        let clamped = max(0, min(1, percentile))
        let index = Int(round(clamped * Double(sorted.count - 1)))
        return sorted[index]
    }

    private static func forwardDelta(currentX: CGFloat, referenceX: CGFloat, direction: Double) -> Double {
        Double(currentX - referenceX) * direction
    }
}

private extension Array {
    subscript(optional index: Int) -> Element? {
        guard indices.contains(index) else { return nil }
        return self[index]
    }
}
