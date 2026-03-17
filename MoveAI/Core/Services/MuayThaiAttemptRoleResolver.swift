import CoreGraphics
import Foundation

enum MuayThaiPunchRoleSource {
    case motionInferred
    case stanceMapped
    case fallback
}

struct MuayThaiPunchRoleResolution {
    let strikingWrist: BodyJoint
    let guardWrist: BodyJoint
    let strikingElbow: BodyJoint
    let guardElbow: BodyJoint
    let strikingShoulder: BodyJoint
    let guardShoulder: BodyJoint
    let confidence: Double
    let source: MuayThaiPunchRoleSource
}

enum MuayThaiAttemptRoleResolver {
    private enum Side {
        case left
        case right

        var opposite: Side {
            switch self {
            case .left:
                return .right
            case .right:
                return .left
            }
        }
    }

    private static let minimumDominantTravel: Double = 0.03
    private static let minimumDominantGap: Double = 0.012

    static func resolvePunchRoles(
        technique: MuayThaiTechnique,
        startPose: PoseDetectionResult,
        peakPose: PoseDetectionResult,
        stance: FightStance,
        preferStanceMapping: Bool = false
    ) -> MuayThaiPunchRoleResolution {
        let leftScore = strikingMotionScore(side: .left, startPose: startPose, peakPose: peakPose)
        let rightScore = strikingMotionScore(side: .right, startPose: startPose, peakPose: peakPose)

        MuayThaiDebug.log(
            "RoleResolver: technique=\(technique.rawValue) stance=\(stance.rawValue) leftScore=\(MuayThaiDebug.format(leftScore, decimals: 4)) rightScore=\(MuayThaiDebug.format(rightScore, decimals: 4))"
        )

        if preferStanceMapping,
           let stanceSide = strikingSideFromStance(technique: technique, stance: stance) {
            let resolved = buildResolution(
                strikingSide: stanceSide,
                confidence: 0.8,
                source: .stanceMapped
            )
            MuayThaiDebug.log(
                "RoleResolver: source=stanceMapped(preferred) striking=\(resolved.strikingWrist.rawValue) guard=\(resolved.guardWrist.rawValue) confidence=\(MuayThaiDebug.format(resolved.confidence, decimals: 3))"
            )
            return resolved
        }

        if let inferred = inferDominantStrikingSide(leftScore: leftScore, rightScore: rightScore) {
            let resolved = buildResolution(
                strikingSide: inferred.side,
                confidence: inferred.confidence,
                source: .motionInferred
            )
            MuayThaiDebug.log(
                "RoleResolver: source=motionInferred striking=\(resolved.strikingWrist.rawValue) guard=\(resolved.guardWrist.rawValue) confidence=\(MuayThaiDebug.format(resolved.confidence, decimals: 3))"
            )
            return resolved
        }

        if let stanceSide = strikingSideFromStance(technique: technique, stance: stance) {
            let resolved = buildResolution(
                strikingSide: stanceSide,
                confidence: 0.55,
                source: .stanceMapped
            )
            MuayThaiDebug.log(
                "RoleResolver: source=stanceMapped striking=\(resolved.strikingWrist.rawValue) guard=\(resolved.guardWrist.rawValue) confidence=\(MuayThaiDebug.format(resolved.confidence, decimals: 3))"
            )
            return resolved
        }

        let fallbackSide: Side = leftScore >= rightScore ? .left : .right
        let resolved = buildResolution(strikingSide: fallbackSide, confidence: 0.0, source: .fallback)
        MuayThaiDebug.log(
            "RoleResolver: source=fallback striking=\(resolved.strikingWrist.rawValue) guard=\(resolved.guardWrist.rawValue) confidence=0"
        )
        return resolved
    }

    private static func buildResolution(
        strikingSide: Side,
        confidence: Double,
        source: MuayThaiPunchRoleSource
    ) -> MuayThaiPunchRoleResolution {
        let guardSide = strikingSide.opposite

        return MuayThaiPunchRoleResolution(
            strikingWrist: wrist(for: strikingSide),
            guardWrist: wrist(for: guardSide),
            strikingElbow: elbow(for: strikingSide),
            guardElbow: elbow(for: guardSide),
            strikingShoulder: shoulder(for: strikingSide),
            guardShoulder: shoulder(for: guardSide),
            confidence: max(0, min(confidence, 1)),
            source: source
        )
    }

    private static func inferDominantStrikingSide(
        leftScore: Double,
        rightScore: Double
    ) -> (side: Side, confidence: Double)? {
        let maxScore = max(leftScore, rightScore)
        let minScore = min(leftScore, rightScore)
        let gap = maxScore - minScore

        guard maxScore >= minimumDominantTravel, gap >= minimumDominantGap else {
            MuayThaiDebug.log(
                "RoleResolver: motion inference rejected max=\(MuayThaiDebug.format(maxScore, decimals: 4)) gap=\(MuayThaiDebug.format(gap, decimals: 4))"
            )
            return nil
        }

        let dominant: Side = leftScore >= rightScore ? .left : .right
        let confidence = gap / max(maxScore, 0.001)
        return (dominant, confidence)
    }

    private static func strikingSideFromStance(
        technique: MuayThaiTechnique,
        stance: FightStance
    ) -> Side? {
        guard stance != .unknown else { return nil }

        switch technique {
        case .cross:
            return stance == .southpaw ? .left : .right
        case .movement:
            return nil
        default:
            return stance == .southpaw ? .right : .left
        }
    }

    private static func strikingMotionScore(
        side: Side,
        startPose: PoseDetectionResult,
        peakPose: PoseDetectionResult
    ) -> Double {
        let wristDisplacement = displacement(
            joint: wrist(for: side),
            startPose: startPose,
            peakPose: peakPose
        )
        let elbowDisplacement = displacement(
            joint: elbow(for: side),
            startPose: startPose,
            peakPose: peakPose
        )
        let lateralTravel = abs(deltaX(
            joint: wrist(for: side),
            startPose: startPose,
            peakPose: peakPose
        ))

        let shoulderToWristStart = distanceBetween(
            first: shoulder(for: side),
            second: wrist(for: side),
            in: startPose
        )
        let shoulderToWristPeak = distanceBetween(
            first: shoulder(for: side),
            second: wrist(for: side),
            in: peakPose
        )
        let extensionGain = max(0, shoulderToWristPeak - shoulderToWristStart)

        return wristDisplacement +
            (elbowDisplacement * 0.35) +
            (extensionGain * 0.90) +
            (lateralTravel * 0.20)
    }

    private static func displacement(
        joint: BodyJoint,
        startPose: PoseDetectionResult,
        peakPose: PoseDetectionResult
    ) -> Double {
        guard let start = point(for: joint, in: startPose),
              let peak = point(for: joint, in: peakPose) else {
            return 0
        }

        return PoseAnalysisHelpers.distance(from: start, to: peak)
    }

    private static func distanceBetween(
        first: BodyJoint,
        second: BodyJoint,
        in pose: PoseDetectionResult
    ) -> Double {
        guard let firstPoint = point(for: first, in: pose),
              let secondPoint = point(for: second, in: pose) else {
            return 0
        }

        return PoseAnalysisHelpers.distance(from: firstPoint, to: secondPoint)
    }

    private static func deltaX(
        joint: BodyJoint,
        startPose: PoseDetectionResult,
        peakPose: PoseDetectionResult
    ) -> Double {
        guard let start = point(for: joint, in: startPose),
              let peak = point(for: joint, in: peakPose) else {
            return 0
        }

        return Double(peak.x - start.x)
    }

    private static func wrist(for side: Side) -> BodyJoint {
        side == .left ? .leftWrist : .rightWrist
    }

    private static func elbow(for side: Side) -> BodyJoint {
        side == .left ? .leftElbow : .rightElbow
    }

    private static func shoulder(for side: Side) -> BodyJoint {
        side == .left ? .leftShoulder : .rightShoulder
    }

    private static func point(for joint: BodyJoint, in pose: PoseDetectionResult) -> CGPoint? {
        PoseAnalysisHelpers.extractKeypoint(joint.rawValue, from: pose)?.position
    }
}
