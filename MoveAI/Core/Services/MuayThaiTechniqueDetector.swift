import CoreGraphics
import Foundation

struct MuayThaiTechniqueDetection {
    let technique: MuayThaiTechnique
    let confidence: Double
    let attemptsCount: Int
    let stanceResolution: FightStanceResolution
}

enum MuayThaiTechniqueDetector {
    static let minimumConfidence = 0.35
    private static let minimumMotionActivity = 0.0015
    private static let punchTechniques: Set<MuayThaiTechnique> = [
        .jab, .cross, .leadHook, .horizontalElbow,
    ]
    private static let unknownStanceJabCrossTieMargin = 0.50
    private static let unknownStanceJabRotationCutoff = 0.50
    private static let unknownStanceCrossRotationCutoff = 0.62
    private static let jabFavorRotationCutoff = 0.58
    private static let punchFavorRelativeScoreFloor = 0.72

    static func detect(
        poses: [PoseDetectionResult],
        preferredStance: FightStance?
    ) -> MuayThaiTechniqueDetection? {
        evaluate(poses: poses, preferredStance: preferredStance, requireMinimumConfidence: true)
    }

    static func detectBestEffort(
        poses: [PoseDetectionResult],
        preferredStance: FightStance?
    ) -> MuayThaiTechniqueDetection? {
        evaluate(poses: poses, preferredStance: preferredStance, requireMinimumConfidence: false)
    }

    private static func evaluate(
        poses: [PoseDetectionResult],
        preferredStance: FightStance?,
        requireMinimumConfidence: Bool
    ) -> MuayThaiTechniqueDetection? {
        guard poses.count >= 6 else {
            MuayThaiDebug.log("TechniqueDetector: insufficient frames=\(poses.count)")
            return nil
        }

        let stanceResolution = FightStanceResolver.resolve(preferred: preferredStance, from: poses)
        MuayThaiDebug.log("TechniqueDetector: frames=\(poses.count) preferredStance=\(preferredStance?.rawValue ?? "nil") resolvedStance=\(stanceResolution.stance.rawValue) source=\(String(describing: stanceResolution.source)) confidence=\(MuayThaiDebug.format(stanceResolution.confidence))")
        let trackedJoints: [BodyJoint] = [
            .leftWrist, .rightWrist,
            .leftElbow, .rightElbow,
            .leftKnee, .rightKnee,
            .leftAnkle, .rightAnkle,
            .root,
        ]
        let statsByJoint = Dictionary(uniqueKeysWithValues: trackedJoints.map { joint in
            (joint, motionStats(for: joint, poses: poses))
        })
        let ankleMid = midpointMotionStats(first: .leftAnkle, second: .rightAnkle, poses: poses)
        let root = statsByJoint[.root] ?? .zero

        let leftWristSpeed = statsByJoint[.leftWrist]?.meanSpeed ?? 0
        let rightWristSpeed = statsByJoint[.rightWrist]?.meanSpeed ?? 0
        let leftElbowSpeed = statsByJoint[.leftElbow]?.meanSpeed ?? 0
        let rightElbowSpeed = statsByJoint[.rightElbow]?.meanSpeed ?? 0
        let leftKneeSpeed = statsByJoint[.leftKnee]?.meanSpeed ?? 0
        let rightKneeSpeed = statsByJoint[.rightKnee]?.meanSpeed ?? 0
        let leftAnkleSpeed = statsByJoint[.leftAnkle]?.meanSpeed ?? 0
        let rightAnkleSpeed = statsByJoint[.rightAnkle]?.meanSpeed ?? 0

        let maxSpeed = max(
            max(max(leftWristSpeed, rightWristSpeed), max(leftElbowSpeed, rightElbowSpeed)),
            max(
                max(max(leftKneeSpeed, rightKneeSpeed), max(leftAnkleSpeed, rightAnkleSpeed)),
                max(ankleMid.meanSpeed, root.meanSpeed)
            )
        )

        guard maxSpeed >= minimumMotionActivity else {
            MuayThaiDebug.log("TechniqueDetector: rejected low motion maxSpeed=\(MuayThaiDebug.format(maxSpeed, decimals: 4)) threshold=\(MuayThaiDebug.format(minimumMotionActivity, decimals: 4))")
            return nil
        }

        let hipRotationN = clamp(pelvisRotationMagnitude(poses: poses) / 35.0)
        let torsoRotationN = clamp(shoulderRotationMagnitude(poses: poses) / 35.0)

        let candidateLeadSides = leadSidesToEvaluate(stanceResolution: stanceResolution)
        MuayThaiDebug.log("TechniqueDetector: maxSpeed=\(MuayThaiDebug.format(maxSpeed, decimals: 4)) hipRotationN=\(MuayThaiDebug.format(hipRotationN)) torsoRotationN=\(MuayThaiDebug.format(torsoRotationN)) candidateLeadSides=\(candidateLeadSides.map(leadSideLabel).joined(separator: ","))")
        let attemptCountsByLeadSide = Dictionary(uniqueKeysWithValues: candidateLeadSides.map { leadSide in
            let counts = attemptCounts(poses: poses, stance: stance(for: leadSide))
            return (leadSide, counts)
        })

        let hypotheses = candidateLeadSides.map { leadSide -> ScoredHypothesis in
            let jointMap = JointMap.forLeadSide(leadSide)
            var scores = scoreTechniques(
                joints: jointMap,
                statsByJoint: statsByJoint,
                ankleMid: ankleMid,
                hipRotationN: hipRotationN,
                torsoRotationN: torsoRotationN,
                maxSpeed: maxSpeed
            )

            let attemptCounts = attemptCountsByLeadSide[leadSide] ?? [:]
            for technique in MuayThaiTechnique.allCases {
                let count = attemptCounts[technique] ?? 0
                let density = clamp(Double(count) / 4.0)
                scores[technique, default: 0] += density * 0.15
            }
            return ScoredHypothesis(
                leadSide: leadSide,
                scores: scores,
                attemptCounts: attemptCounts
            )
        }

        for hypothesis in hypotheses {
            MuayThaiDebug.log("TechniqueDetector: hypothesis lead=\(leadSideLabel(hypothesis.leadSide)) scores=\(scoreSnapshot(hypothesis.scores)) attempts=\(attemptSnapshot(hypothesis.attemptCounts))")
        }

        let rankedCandidates = hypotheses.compactMap(topCandidate(from:))
        guard !rankedCandidates.isEmpty else {
            MuayThaiDebug.log("TechniqueDetector: no ranked candidates (all scores <= 0)")
            return nil
        }

        var winner = rankedCandidates.max(by: { $0.topScore < $1.topScore })!
        winner = resolvePunchAmbiguity(
            winner: winner,
            candidates: rankedCandidates,
            hipRotationN: hipRotationN
        )

        MuayThaiDebug.log("TechniqueDetector: winnerAfterAmbiguity lead=\(leadSideLabel(winner.leadSide)) technique=\(winner.technique.rawValue) top=\(MuayThaiDebug.format(winner.topScore)) second=\(MuayThaiDebug.format(winner.secondScore))")

        let activityN = clamp(maxSpeed / 0.03)
        let marginN = clamp((winner.topScore - winner.secondScore) / max(winner.topScore, 0.001))
        var confidence = clamp(0.25 + (marginN * 0.5) + (activityN * 0.25))

        if stanceResolution.stance == .unknown, punchTechniques.contains(winner.technique) {
            confidence = clamp(confidence - 0.04)
        }

        if requireMinimumConfidence, confidence < minimumConfidence {
            MuayThaiDebug.log("TechniqueDetector: rejected low confidence confidence=\(MuayThaiDebug.format(confidence)) threshold=\(MuayThaiDebug.format(minimumConfidence)) winner=\(winner.technique.rawValue)")
            return nil
        }

        MuayThaiDebug.log("TechniqueDetector: accepted technique=\(winner.technique.rawValue) confidence=\(MuayThaiDebug.format(confidence)) attempts=\(winner.attemptCounts[winner.technique] ?? 0)")

        return MuayThaiTechniqueDetection(
            technique: winner.technique,
            confidence: confidence,
            attemptsCount: winner.attemptCounts[winner.technique] ?? 0,
            stanceResolution: stanceResolution
        )
    }

    private struct ScoredHypothesis {
        let leadSide: LeadSide
        let scores: [MuayThaiTechnique: Double]
        let attemptCounts: [MuayThaiTechnique: Int]
    }

    private struct RankedCandidate {
        let leadSide: LeadSide
        let technique: MuayThaiTechnique
        let topScore: Double
        let secondScore: Double
        let attemptCounts: [MuayThaiTechnique: Int]
    }

    private enum LeadSide: CaseIterable, Hashable {
        case left
        case right
    }

    private struct JointMap {
        let leadWrist: BodyJoint
        let rearWrist: BodyJoint
        let leadElbow: BodyJoint
        let leadKnee: BodyJoint
        let rearKnee: BodyJoint
        let leadAnkle: BodyJoint
        let rearAnkle: BodyJoint

        static func forLeadSide(_ leadSide: LeadSide) -> JointMap {
            switch leadSide {
            case .left:
                return JointMap(
                    leadWrist: .leftWrist,
                    rearWrist: .rightWrist,
                    leadElbow: .leftElbow,
                    leadKnee: .leftKnee,
                    rearKnee: .rightKnee,
                    leadAnkle: .leftAnkle,
                    rearAnkle: .rightAnkle
                )
            case .right:
                return JointMap(
                    leadWrist: .rightWrist,
                    rearWrist: .leftWrist,
                    leadElbow: .rightElbow,
                    leadKnee: .rightKnee,
                    rearKnee: .leftKnee,
                    leadAnkle: .rightAnkle,
                    rearAnkle: .leftAnkle
                )
            }
        }

        static func forStance(_ stance: FightStance) -> JointMap {
            switch stance {
            case .southpaw:
                return forLeadSide(.right)
            case .orthodox, .unknown:
                return forLeadSide(.left)
            }
        }
    }

    private struct MotionStats {
        let meanSpeed: Double
        let rangeX: Double
        let rangeY: Double
        let forwardTravel: Double

        static let zero = MotionStats(meanSpeed: 0, rangeX: 0, rangeY: 0, forwardTravel: 0)
    }

    private static func leadSidesToEvaluate(stanceResolution: FightStanceResolution) -> [LeadSide] {
        guard stanceResolution.source == .userSelected,
              let selectedLead = leadSide(for: stanceResolution.stance) else {
            return LeadSide.allCases
        }

        return [selectedLead]
    }

    private static func leadSide(for stance: FightStance) -> LeadSide? {
        switch stance {
        case .orthodox:
            return .left
        case .southpaw:
            return .right
        case .unknown:
            return nil
        }
    }

    private static func stance(for leadSide: LeadSide) -> FightStance {
        switch leadSide {
        case .left:
            return .orthodox
        case .right:
            return .southpaw
        }
    }

    private static func attemptCounts(
        poses: [PoseDetectionResult],
        stance: FightStance
    ) -> [MuayThaiTechnique: Int] {
        Dictionary(uniqueKeysWithValues: MuayThaiTechnique.allCases.map { technique in
            let attempts = MuayThaiEventDetector.detectAttempts(
                poses: poses,
                technique: technique,
                stance: stance
            )
            return (technique, attempts.count)
        })
    }

    private static func topCandidate(from hypothesis: ScoredHypothesis) -> RankedCandidate? {
        guard let top = hypothesis.scores.max(by: { $0.value < $1.value }), top.value > 0 else {
            return nil
        }

        let second = hypothesis.scores
            .filter { $0.key != top.key }
            .map(\.value)
            .max() ?? 0

        return RankedCandidate(
            leadSide: hypothesis.leadSide,
            technique: top.key,
            topScore: top.value,
            secondScore: second,
            attemptCounts: hypothesis.attemptCounts
        )
    }

    private static func resolvePunchAmbiguity(
        winner: RankedCandidate,
        candidates: [RankedCandidate],
        hipRotationN: Double
    ) -> RankedCandidate {
        guard winner.technique == .jab || winner.technique == .cross else { return winner }

        guard
            let jab = candidates.first(where: { $0.technique == .jab }),
            let cross = candidates.first(where: { $0.technique == .cross })
        else {
            return winner
        }

        let jabCloseEnough = jab.topScore >= (cross.topScore * punchFavorRelativeScoreFloor)
        let crossCloseEnough = cross.topScore >= (jab.topScore * punchFavorRelativeScoreFloor)

        MuayThaiDebug.log("TechniqueDetector: jabCross ambiguity winner=\(winner.technique.rawValue) jabTop=\(MuayThaiDebug.format(jab.topScore)) crossTop=\(MuayThaiDebug.format(cross.topScore)) hipRotationN=\(MuayThaiDebug.format(hipRotationN))")

        if hipRotationN <= jabFavorRotationCutoff, jabCloseEnough {
            return jab
        }

        if hipRotationN >= unknownStanceCrossRotationCutoff, crossCloseEnough {
            return cross
        }

        let scoreGap = abs(jab.topScore - cross.topScore)
        guard scoreGap <= unknownStanceJabCrossTieMargin else {
            return winner
        }

        if hipRotationN <= unknownStanceJabRotationCutoff {
            return jab
        }

        if hipRotationN >= unknownStanceCrossRotationCutoff {
            return cross
        }

        return winner
    }

    private static func scoreTechniques(
        joints: JointMap,
        statsByJoint: [BodyJoint: MotionStats],
        ankleMid: MotionStats,
        hipRotationN: Double,
        torsoRotationN: Double,
        maxSpeed: Double
    ) -> [MuayThaiTechnique: Double] {
        let leadWrist = statsByJoint[joints.leadWrist] ?? .zero
        let rearWrist = statsByJoint[joints.rearWrist] ?? .zero
        let leadElbow = statsByJoint[joints.leadElbow] ?? .zero
        let leadKnee = statsByJoint[joints.leadKnee] ?? .zero
        let rearKnee = statsByJoint[joints.rearKnee] ?? .zero
        let leadAnkle = statsByJoint[joints.leadAnkle] ?? .zero
        let rearAnkle = statsByJoint[joints.rearAnkle] ?? .zero
        let leftWristAbsolute = statsByJoint[.leftWrist] ?? .zero
        let rightWristAbsolute = statsByJoint[.rightWrist] ?? .zero
        let leftAnkle = statsByJoint[.leftAnkle] ?? .zero
        let rightAnkle = statsByJoint[.rightAnkle] ?? .zero
        let root = statsByJoint[.root] ?? .zero

        let normalize: (Double) -> Double = { value in
            guard maxSpeed > 0 else { return 0 }
            return clamp(value / maxSpeed)
        }

        let leadWristN = normalize(leadWrist.meanSpeed)
        let rearWristN = normalize(rearWrist.meanSpeed)
        let leadElbowN = normalize(leadElbow.meanSpeed)
        let leadKneeN = normalize(leadKnee.meanSpeed)
        let rearKneeN = normalize(rearKnee.meanSpeed)
        let leadAnkleN = normalize(leadAnkle.meanSpeed)
        let rearAnkleN = normalize(rearAnkle.meanSpeed)
        let ankleMidN = normalize(ankleMid.meanSpeed)
        let rootN = normalize(root.meanSpeed)
        let wristDominance = max(leadWristN, rearWristN)
        let kickDominance = max(max(leadKneeN, leadAnkleN), max(rearKneeN, rearAnkleN))
        let bilateralFootworkN = clamp((leadAnkleN + rearAnkleN + (rearKneeN * 0.5)) / 2.5)

        let leadWristForwardN = clamp(abs(leadWrist.forwardTravel) / 0.12)
        let rearWristForwardN = clamp(abs(rearWrist.forwardTravel) / 0.12)
        let leftStraightN = clamp((normalize(leftWristAbsolute.meanSpeed) * 0.75) + (clamp(abs(leftWristAbsolute.forwardTravel) / 0.12) * 0.25))
        let rightStraightN = clamp((normalize(rightWristAbsolute.meanSpeed) * 0.75) + (clamp(abs(rightWristAbsolute.forwardTravel) / 0.12) * 0.25))
        let dominantStraightN = max(leftStraightN, rightStraightN)
        let straightAsymmetryN = clamp(abs(leftStraightN - rightStraightN))
        let lateralWristRatio = leadWrist.rangeX / max(leadWrist.rangeY, 0.001)
        let lateralElbowRatio = leadElbow.rangeX / max(leadElbow.rangeY, 0.001)
        let ankleToKneeSpeedRatio = leadAnkle.meanSpeed / max(leadKnee.meanSpeed, 0.001)
        let ankleSweepN = clamp(max(leadAnkle.rangeX, leadAnkle.rangeY) / 0.2)
        let kneeLiftN = clamp(leadKnee.rangeY / 0.16)
        let bilateralShiftN = clamp(((leftAnkle.rangeX + rightAnkle.rangeX) * 0.5) / 0.14)
        let roundhouseSignalN = clamp(
            (kickDominance * 0.55) +
            (ankleSweepN * 0.45) +
            (hipRotationN * 0.25) -
            (wristDominance * 0.20)
        )
        let jabKickPenalty = roundhouseSignalN * 0.55
        let crossKickPenalty = roundhouseSignalN * 0.95

        var scores: [MuayThaiTechnique: Double] = [:]
        scores[.jab] =
            (leadWristN * 1.25) +
            (max(0, leadWristN - rearWristN) * 0.8) +
            (leadWristForwardN * 0.4) -
            (kickDominance * 0.25) -
            jabKickPenalty

        scores[.cross] =
            (rearWristN * 1.25) +
            (max(0, rearWristN - leadWristN) * 0.8) +
            (rearWristForwardN * 0.4) +
            (hipRotationN * 0.25) -
            crossKickPenalty

        let jabInvariantBoost =
            (dominantStraightN * (1.0 - hipRotationN) * 0.85) +
            (straightAsymmetryN * 0.30)
        let crossInvariantBoost =
            (dominantStraightN * hipRotationN * (1.0 - (roundhouseSignalN * 0.5)) * 0.85) +
            (torsoRotationN * 0.25)

        scores[.jab, default: 0] += jabInvariantBoost
        scores[.cross, default: 0] += crossInvariantBoost

        scores[.leadHook] =
            (max(leadWristN, leadElbowN) * 1.1) +
            (clamp(lateralWristRatio / 2.0) * 0.5) +
            (max(0, leadWristN - rearWristN) * 0.3)

        scores[.horizontalElbow] =
            (leadElbowN * 1.2) +
            (clamp(lateralElbowRatio / 2.0) * 0.5) +
            (torsoRotationN * 0.25) -
            (leadWristN * 0.15)

        scores[.roundhouseKick] =
            (leadAnkleN * 1.3) +
            (ankleSweepN * 0.35) +
            (hipRotationN * 0.35) +
            (kickDominance * 0.45) +
            (roundhouseSignalN * 0.35) -
            (rearAnkleN * 0.45)

        scores[.teep] =
            (leadKneeN * 1.05) +
            (min(1.0, ankleToKneeSpeedRatio) * 0.30) +
            (kneeLiftN * 0.35) -
            (hipRotationN * 0.15) -
            (rearKneeN * 0.20)

        scores[.straightKnee] =
            (leadKneeN * 1.15) +
            (clamp(1.0 - ankleToKneeSpeedRatio) * 0.45) +
            (clamp(abs(root.forwardTravel) / 0.1) * 0.25) -
            (rearKneeN * 0.15)

        scores[.movement] =
            (ankleMidN * 1.1) +
            (bilateralFootworkN * 0.9) +
            (rootN * 0.55) +
            (bilateralShiftN * 0.45) -
            (wristDominance * 0.3)

        return scores
    }

    private static func motionStats(for joint: BodyJoint, poses: [PoseDetectionResult]) -> MotionStats {
        let points = poses.compactMap { point(for: joint, in: $0) }
        return motionStats(points: points)
    }

    private static func midpointMotionStats(
        first: BodyJoint,
        second: BodyJoint,
        poses: [PoseDetectionResult]
    ) -> MotionStats {
        let points = poses.compactMap { pose -> CGPoint? in
            guard let p1 = point(for: first, in: pose),
                  let p2 = point(for: second, in: pose) else {
                return nil
            }
            return PoseAnalysisHelpers.midpoint(p1, p2)
        }
        return motionStats(points: points)
    }

    private static func motionStats(points: [CGPoint]) -> MotionStats {
        guard points.count >= 2 else {
            return MotionStats(meanSpeed: 0, rangeX: 0, rangeY: 0, forwardTravel: 0)
        }

        var totalSpeed = 0.0
        var sampleCount = 0

        for index in 1..<points.count {
            totalSpeed += PoseAnalysisHelpers.distance(from: points[index - 1], to: points[index])
            sampleCount += 1
        }

        let xs = points.map { Double($0.x) }
        let ys = points.map { Double($0.y) }
        let rangeX = (xs.max() ?? 0) - (xs.min() ?? 0)
        let rangeY = (ys.max() ?? 0) - (ys.min() ?? 0)
        let forwardTravel = Double(points.last!.x - points.first!.x)

        return MotionStats(
            meanSpeed: sampleCount > 0 ? totalSpeed / Double(sampleCount) : 0,
            rangeX: rangeX,
            rangeY: rangeY,
            forwardTravel: forwardTravel
        )
    }

    private static func pelvisRotationMagnitude(poses: [PoseDetectionResult]) -> Double {
        angularRange(
            poses: poses,
            first: .leftHip,
            second: .rightHip
        )
    }

    private static func shoulderRotationMagnitude(poses: [PoseDetectionResult]) -> Double {
        angularRange(
            poses: poses,
            first: .leftShoulder,
            second: .rightShoulder
        )
    }

    private static func angularRange(
        poses: [PoseDetectionResult],
        first: BodyJoint,
        second: BodyJoint
    ) -> Double {
        let angles = poses.compactMap { pose -> Double? in
            guard let p1 = point(for: first, in: pose),
                  let p2 = point(for: second, in: pose) else {
                return nil
            }
            return abs(atan2(Double(p2.y - p1.y), Double(p2.x - p1.x)) * 180.0 / .pi)
        }

        guard let min = angles.min(), let max = angles.max() else {
            return 0
        }

        return max - min
    }

    private static func point(for joint: BodyJoint, in pose: PoseDetectionResult) -> CGPoint? {
        PoseAnalysisHelpers.extractKeypoint(joint.rawValue, from: pose)?.position
    }

    private static func leadSideLabel(_ side: LeadSide) -> String {
        switch side {
        case .left:
            return "left"
        case .right:
            return "right"
        }
    }

    private static func scoreSnapshot(_ scores: [MuayThaiTechnique: Double]) -> String {
        let top = scores
            .sorted { $0.value > $1.value }
            .prefix(3)
            .map { "\($0.key.rawValue)=\(MuayThaiDebug.format($0.value))" }
            .joined(separator: ",")

        let jab = MuayThaiDebug.format(scores[.jab] ?? 0)
        let cross = MuayThaiDebug.format(scores[.cross] ?? 0)
        return "top=[\(top)] jab=\(jab) cross=\(cross)"
    }

    private static func attemptSnapshot(_ attempts: [MuayThaiTechnique: Int]) -> String {
        MuayThaiTechnique.allCases
            .map { technique in "\(technique.rawValue)=\(attempts[technique] ?? 0)" }
            .joined(separator: ",")
    }

    private static func clamp(_ value: Double, min lower: Double = 0, max upper: Double = 1) -> Double {
        Swift.max(lower, Swift.min(upper, value))
    }
}
