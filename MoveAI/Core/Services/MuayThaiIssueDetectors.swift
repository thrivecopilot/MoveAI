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
        stance: FightStance
    ) -> MuayThaiDetectionOutcome {
        let entries = MuayThaiIssueCatalog.entries(for: technique)
        let blockedEntries = entries.filter { $0.detectionSupport == .blocked }
        let activeEntries = entries.filter { $0.detectionSupport != .blocked }

        guard !poses.isEmpty, !attempts.isEmpty else {
            return MuayThaiDetectionOutcome(feedback: [], blockedEntries: blockedEntries, attemptsWithIssues: 0)
        }

        var feedback: [FormFeedback] = []
        var attemptsWithIssues = 0

        for attempt in attempts {
            guard let context = AttemptContext(poses: poses, attempt: attempt, stance: stance) else { continue }

            var issueDetectedForAttempt = false
            for entry in activeEntries {
                guard let detection = detect(entry: entry, context: context) else { continue }

                issueDetectedForAttempt = true
                let metrics = detection.metrics.isEmpty ? nil : detection.metrics
                let affectedJoints = detection.affectedJoints.isEmpty ? nil : detection.affectedJoints

                feedback.append(
                    FormFeedback(
                        category: detection.category,
                        message: detection.message,
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
        let joints: JointMap
        let startPose: PoseDetectionResult
        let peakPose: PoseDetectionResult
        let endPose: PoseDetectionResult
        let forwardDirection: Double

        var peakTime: TimeInterval {
            max(0, peakPose.timestamp.timeIntervalSince1970)
        }

        init?(poses: [PoseDetectionResult], attempt: TechniqueAttempt, stance: FightStance) {
            guard let startPose = poses[optional: attempt.startFrame],
                  let peakPose = poses[optional: attempt.peakFrame],
                  let endPose = poses[optional: attempt.endFrame] else {
                return nil
            }

            self.poses = poses
            self.attempt = attempt
            self.stance = stance
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
        guard let rearWrist = point(context.joints.rearWrist, in: context.peakPose),
              let rearElbow = point(context.joints.rearElbow, in: context.peakPose),
              let rearHip = point(context.joints.rearHip, in: context.peakPose),
              let nose = point(.nose, in: context.peakPose) else {
            return nil
        }

        let guardDistance = PoseAnalysisHelpers.distance(from: rearWrist, to: nose)
        let shoulderWidth = bilateralDistance(.leftShoulder, .rightShoulder, in: context.peakPose) ?? 0.2
        let guardRatio = guardDistance / max(shoulderWidth, 0.001)
        let elbowToRib = PoseAnalysisHelpers.distance(from: rearElbow, to: rearHip)

        guard rearWrist.y < nose.y - 0.03 || guardRatio > 0.9 || elbowToRib > 0.2 else {
            return nil
        }

        return Detection(
            severity: entry.severity,
            category: .safety,
            message: entry.cueDetailed,
            affectedJoints: [context.joints.rearWrist, context.joints.rearElbow, context.joints.rearShoulder, .nose],
            metrics: [
                FeedbackMetric(kind: .muayThaiRearHandGuardDistanceRatio, value: guardRatio, unit: .ratio)
            ]
        )
    }

    private static func detectJabLeaningForward(entry: MuayThaiIssueCatalogEntry, context: AttemptContext) -> Detection? {
        guard let torsoAngle = torsoForwardAngle(in: context.peakPose),
              let nose = point(.nose, in: context.peakPose),
              let leadKnee = point(context.joints.leadKnee, in: context.peakPose) else {
            return nil
        }

        let nosePastLeadKnee = forwardDelta(currentX: nose.x, referenceX: leadKnee.x, direction: context.forwardDirection) > 0.02
        guard torsoAngle > 20 && nosePastLeadKnee else { return nil }

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
                context.joints.leadKnee
            ],
            metrics: [
                FeedbackMetric(kind: .muayThaiTorsoForwardLeanDegrees, value: torsoAngle, unit: .degrees)
            ]
        )
    }

    private static func detectNoShoulderProtection(entry: MuayThaiIssueCatalogEntry, context: AttemptContext) -> Detection? {
        guard let leadShoulder = point(context.joints.leadShoulder, in: context.peakPose),
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
            affectedJoints: [context.joints.leadShoulder, .nose],
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
