import CoreGraphics
import Foundation

struct TechniqueAttempt: Hashable {
    let startFrame: Int
    let endFrame: Int
    let peakFrame: Int
    let peakTimestamp: TimeInterval
}

enum MuayThaiEventDetector {
    static func detectAttempts(
        poses: [PoseDetectionResult],
        technique: MuayThaiTechnique,
        stance: FightStance
    ) -> [TechniqueAttempt] {
        guard poses.count >= 3 else {
            return defaultAttempt(for: poses)
        }

        let trackedPoints = poses.map { trackedPoint(in: $0, technique: technique, stance: stance) }
        var speeds = Array(repeating: 0.0, count: poses.count)
        var maxSpeed = 0.0

        for index in 1..<poses.count {
            guard let previous = trackedPoints[index - 1],
                  let current = trackedPoints[index] else {
                continue
            }
            let speed = PoseAnalysisHelpers.distance(from: previous, to: current)
            speeds[index] = speed
            maxSpeed = max(maxSpeed, speed)
        }

        guard maxSpeed > 0 else {
            return defaultAttempt(for: poses)
        }

        let baseThreshold = technique == .movement ? 0.012 : 0.018
        let threshold = max(baseThreshold, maxSpeed * 0.45)

        var peakFrames: [Int] = []
        for index in 1..<(speeds.count - 1) {
            let current = speeds[index]
            guard current >= threshold else { continue }
            guard current >= speeds[index - 1], current >= speeds[index + 1] else { continue }

            if let last = peakFrames.last, index - last < 8 {
                if current > speeds[last] {
                    peakFrames[peakFrames.count - 1] = index
                }
            } else {
                peakFrames.append(index)
            }
        }

        if peakFrames.isEmpty {
            if let maxIndex = speeds.enumerated().max(by: { $0.element < $1.element })?.offset {
                peakFrames = [maxIndex]
            }
        }

        let attempts = peakFrames.map { peakFrame -> TechniqueAttempt in
            let start = max(0, peakFrame - 6)
            let end = min(poses.count - 1, peakFrame + 6)
            let ts = poses[safe: peakFrame]?.timestamp.timeIntervalSince1970 ?? 0
            return TechniqueAttempt(startFrame: start, endFrame: end, peakFrame: peakFrame, peakTimestamp: ts)
        }

        if attempts.isEmpty {
            return defaultAttempt(for: poses)
        }

        return attempts
    }

    private static func defaultAttempt(for poses: [PoseDetectionResult]) -> [TechniqueAttempt] {
        guard !poses.isEmpty else { return [] }
        let peak = poses.count / 2
        let ts = poses[safe: peak]?.timestamp.timeIntervalSince1970 ?? 0
        return [TechniqueAttempt(startFrame: 0, endFrame: poses.count - 1, peakFrame: peak, peakTimestamp: ts)]
    }

    private static func trackedPoint(
        in pose: PoseDetectionResult,
        technique: MuayThaiTechnique,
        stance: FightStance
    ) -> CGPoint? {
        switch technique {
        case .jab:
            return point(for: leadJoint(left: .leftWrist, right: .rightWrist, stance: stance), in: pose)
        case .cross:
            return point(for: rearJoint(left: .leftWrist, right: .rightWrist, stance: stance), in: pose)
        case .leadHook:
            return point(for: leadJoint(left: .leftElbow, right: .rightElbow, stance: stance), in: pose)
        case .roundhouseKick:
            return point(for: leadJoint(left: .leftAnkle, right: .rightAnkle, stance: stance), in: pose)
        case .teep:
            return point(for: leadJoint(left: .leftKnee, right: .rightKnee, stance: stance), in: pose)
        case .straightKnee:
            return point(for: leadJoint(left: .leftKnee, right: .rightKnee, stance: stance), in: pose)
        case .horizontalElbow:
            return point(for: leadJoint(left: .leftElbow, right: .rightElbow, stance: stance), in: pose)
        case .movement:
            guard let left = point(for: .leftAnkle, in: pose),
                  let right = point(for: .rightAnkle, in: pose) else {
                return point(for: .root, in: pose)
            }
            return PoseAnalysisHelpers.midpoint(left, right)
        }
    }

    private static func point(for joint: BodyJoint, in pose: PoseDetectionResult) -> CGPoint? {
        PoseAnalysisHelpers.extractKeypoint(joint.rawValue, from: pose)?.position
    }

    private static func leadJoint(left: BodyJoint, right: BodyJoint, stance: FightStance) -> BodyJoint {
        switch stance {
        case .southpaw:
            return right
        case .orthodox, .unknown:
            return left
        }
    }

    private static func rearJoint(left: BodyJoint, right: BodyJoint, stance: FightStance) -> BodyJoint {
        switch stance {
        case .southpaw:
            return left
        case .orthodox, .unknown:
            return right
        }
    }
}

private extension Array {
    subscript(safe index: Int) -> Element? {
        guard indices.contains(index) else { return nil }
        return self[index]
    }
}
