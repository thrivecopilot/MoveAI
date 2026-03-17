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
                stance: stance,
                stanceSource: stanceSource
            ) else {
                MuayThaiDebug.log("IssueDetectors: skipped attempt \(attemptIndex + 1) \(classifiedAttempt.technique.rawValue) (invalid frame window)")
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

        return MuayThaiDetectionOutcome(
            feedback: feedback.sorted { $0.timestamp < $1.timestamp },
            blockedEntries: blockedEntries,
            attemptsWithIssues: attemptsWithIssues
        )
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
        case .muayThaiJabLeaningForward:
            return detectJabLeaningForward(entry: entry, context: context)
        case .muayThaiJabNoShoulderProtection:
            return detectNoShoulderProtection(entry: entry, context: context)
        case .muayThaiCrossNoHipRotation:
            return detectNoHipRotation(entry: entry, context: context)
        case .muayThaiCrossOverreaching:
            return detectOverreaching(entry: entry, context: context)
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

    private static func detectRearHandDropping(entry: MuayThaiIssueCatalogEntry, context: AttemptContext) -> Detection? {
        let roles = MuayThaiAttemptRoleResolver.resolvePunchRoles(
            technique: .jab,
            startPose: context.startPose,
            peakPose: context.peakPose,
            stance: context.stance
        )

        MuayThaiDebug.log("RearHandDrop: role source=\(String(describing: roles.source)) striking=\(roles.strikingWrist.rawValue) guard=\(roles.guardWrist.rawValue) confidence=\(MuayThaiDebug.format(roles.confidence))")

        if roles.source != .motionInferred {
            MuayThaiDebug.log("RearHandDrop: skipped (role source \(String(describing: roles.source)) is not motionInferred)")
            return nil
        }

        // Low-confidence role inference is a common source of false positives where
        // the jabbing hand gets mistaken for the rear guard hand.
        if roles.source == .motionInferred && roles.confidence < 0.35 {
            MuayThaiDebug.log("RearHandDrop: skipped (low role confidence=\(MuayThaiDebug.format(roles.confidence)))")
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
            let isExtensionFrame = extensionDelta > 0.10 || extensionRatio > 1.15
            guard isExtensionFrame else { continue }

            extensionFrames += 1
            maxGuardRatio = max(maxGuardRatio, signal.guardRatio)
            maxExtensionRatio = max(maxExtensionRatio, extensionRatio)

            let baselineRatio = baselineSignal?.guardRatio ?? signal.guardRatio
            let guardDelta = signal.guardRatio - baselineRatio
            let handFarFromGuard = signal.guardRatio > 0.65 || guardDelta > 0.12
            let guardDropped = handFarFromGuard && (signal.wristDroppedBelowChin || signal.elbowFlared)

            if guardDropped {
                droppedFrames += 1
            }
        }

        guard extensionFrames >= 2 else {
            MuayThaiDebug.log("RearHandDrop: skipped (insufficient extension frames=\(extensionFrames))")
            return nil
        }

        guard maxExtensionRatio >= 1.20 else {
            MuayThaiDebug.log("RearHandDrop: skipped (insufficient jab extension maxExtensionRatio=\(MuayThaiDebug.format(maxExtensionRatio)))")
            return nil
        }

        let droppedRatio = Double(droppedFrames) / Double(extensionFrames)
        MuayThaiDebug.log("RearHandDrop: extensionFrames=\(extensionFrames) droppedFrames=\(droppedFrames) droppedRatio=\(MuayThaiDebug.format(droppedRatio)) maxGuardRatio=\(MuayThaiDebug.format(maxGuardRatio)) maxExtensionRatio=\(MuayThaiDebug.format(maxExtensionRatio))")

        guard droppedFrames >= 2 || droppedRatio >= 0.4 else {
            MuayThaiDebug.log("RearHandDrop: not triggered")
            return nil
        }

        MuayThaiDebug.log("RearHandDrop: triggered")

        return Detection(
            severity: entry.severity,
            category: .safety,
            message: entry.cueDetailed,
            affectedJoints: [roles.guardWrist, roles.guardElbow, roles.guardShoulder, .nose],
            metrics: [
                FeedbackMetric(kind: .muayThaiRearHandGuardDistanceRatio, value: maxGuardRatio, unit: .ratio)
            ]
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

    private static func detectJabLeaningForward(entry: MuayThaiIssueCatalogEntry, context: AttemptContext) -> Detection? {
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

        guard let torsoAngle = torsoForwardAngle(in: context.peakPose) else {
            MuayThaiDebug.log("JabLean: skipped (missing torso angle)")
            return nil
        }

        guard let nose = point(.nose, in: context.peakPose),
              let leadKnee = point(strikingKnee, in: context.peakPose) else {
            MuayThaiDebug.log("JabLean: skipped (missing nose or \(strikingKnee.rawValue))")
            return nil
        }

        let noseDelta = forwardDelta(currentX: nose.x, referenceX: leadKnee.x, direction: context.forwardDirection)
        let nosePastLeadKnee = noseDelta > 0.02
        MuayThaiDebug.log("JabLean: torsoAngle=\(MuayThaiDebug.format(torsoAngle)) noseDelta=\(MuayThaiDebug.format(noseDelta)) thresholdAngle=20 thresholdDelta=0.02")
        guard torsoAngle > 20 && nosePastLeadKnee else {
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
                FeedbackMetric(kind: .muayThaiTorsoForwardLeanDegrees, value: torsoAngle, unit: .degrees)
            ]
        )
    }

    private static func detectNoShoulderProtection(entry: MuayThaiIssueCatalogEntry, context: AttemptContext) -> Detection? {
        let roles = MuayThaiAttemptRoleResolver.resolvePunchRoles(
            technique: .jab,
            startPose: context.startPose,
            peakPose: context.peakPose,
            stance: context.stance
        )
        let strikingShoulder = roles.source == .fallback ? context.joints.leadShoulder : roles.strikingShoulder

        guard let leadShoulder = point(strikingShoulder, in: context.peakPose),
              let nose = point(.nose, in: context.peakPose) else {
            return nil
        }

        let guardGap = Double(nose.y - leadShoulder.y)
        let shoulderWidth = bilateralDistance(.leftShoulder, .rightShoulder, in: context.peakPose) ?? 0.2
        let gapRatio = guardGap / max(shoulderWidth, 0.001)

        guard guardGap > 0.08 else { return nil }

        return Detection(
            severity: entry.severity,
            category: .safety,
            message: entry.cueDetailed,
            affectedJoints: [strikingShoulder, .nose],
            metrics: [
                FeedbackMetric(kind: .muayThaiShoulderGuardGapRatio, value: gapRatio, unit: .ratio)
            ]
        )
    }

    private static func detectNoHipRotation(entry: MuayThaiIssueCatalogEntry, context: AttemptContext) -> Detection? {
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

        guard hipRotation < 15 && shoulderRotation < 18 else { return nil }

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

    private static func detectOverreaching(entry: MuayThaiIssueCatalogEntry, context: AttemptContext) -> Detection? {
        guard let nose = point(.nose, in: context.peakPose),
              let leadAnkle = point(context.joints.leadAnkle, in: context.peakPose),
              let rearAnkle = point(context.joints.rearAnkle, in: context.peakPose) else {
            return nil
        }

        let stanceWidth = max(abs(Double(leadAnkle.x - rearAnkle.x)), 0.001)
        let overreachRatio = forwardDelta(currentX: nose.x, referenceX: leadAnkle.x, direction: context.forwardDirection) / stanceWidth
        guard overreachRatio > 0.15 else { return nil }

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
                FeedbackMetric(kind: .muayThaiOverreachRatio, value: overreachRatio, unit: .ratio)
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

        guard hipRotation < 15 && shoulderRotation < 15 else { return nil }

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
              let peakLeadWrist = point(context.joints.leadWrist, in: context.peakPose),
              let startRearWrist = point(context.joints.rearWrist, in: context.startPose),
              let peakRearWrist = point(context.joints.rearWrist, in: context.peakPose) else {
            return nil
        }

        let leadMove = PoseAnalysisHelpers.distance(from: startLeadWrist, to: peakLeadWrist)
        let rearMove = PoseAnalysisHelpers.distance(from: startRearWrist, to: peakRearWrist)
        let maxMove = max(leadMove, rearMove)

        guard maxMove < 0.06 else { return nil }

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
        return abs(angleDelta(from: startAngle, to: endAngle))
    }

    private static func lineAngle(from p1: CGPoint, to p2: CGPoint) -> Double {
        atan2(Double(p2.y - p1.y), Double(p2.x - p1.x)) * 180.0 / .pi
    }

    private static func angleDelta(from start: Double, to end: Double) -> Double {
        let wrapped = (end - start + 540).truncatingRemainder(dividingBy: 360) - 180
        return wrapped
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
