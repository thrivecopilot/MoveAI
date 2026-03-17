import Foundation

struct FightStanceResolution {
    let stance: FightStance
    let confidence: Double
    let source: Source

    enum Source {
        case userSelected
        case autoInferred
        case fallbackUnknown
    }
}

enum FightStanceResolver {
    static func resolve(preferred: FightStance?, from poses: [PoseDetectionResult]) -> FightStanceResolution {
        if let preferred, preferred != .unknown {
            return FightStanceResolution(stance: preferred, confidence: 1.0, source: .userSelected)
        }

        let setupPoses = Array(poses.prefix(24))
        var orthodoxWeight = 0.0
        var southpawWeight = 0.0
        var evidenceFrames = 0

        for pose in setupPoses {
            let ankleVote = voteFromPair(
                left: keypoint(.leftAnkle, in: pose),
                right: keypoint(.rightAnkle, in: pose),
                minDelta: 0.035,
                maxDeltaForFullWeight: 0.12,
                weightScale: 1.0
            )

            let shoulderVote = voteFromPair(
                left: keypoint(.leftShoulder, in: pose),
                right: keypoint(.rightShoulder, in: pose),
                minDelta: 0.025,
                maxDeltaForFullWeight: 0.10,
                weightScale: 0.6
            )

            if let ankleVote, let shoulderVote,
               ankleVote.side != shoulderVote.side {
                continue
            }

            if let ankleVote {
                accumulate(ankleVote, orthodoxWeight: &orthodoxWeight, southpawWeight: &southpawWeight)
                evidenceFrames += 1
            }

            if shoulderVote != nil && ankleVote == nil, let shoulderVote {
                accumulate(shoulderVote, orthodoxWeight: &orthodoxWeight, southpawWeight: &southpawWeight)
                evidenceFrames += 1
            }
        }

        let totalWeight = orthodoxWeight + southpawWeight
        guard totalWeight > 0 else {
            return FightStanceResolution(stance: .unknown, confidence: 0.0, source: .fallbackUnknown)
        }

        let dominantWeight = max(orthodoxWeight, southpawWeight)
        let confidenceBase = dominantWeight / totalWeight
        let evidenceFactor = min(1.0, Double(evidenceFrames) / 8.0)
        let confidence = confidenceBase * evidenceFactor

        // Keep stance unknown when evidence is weak or the split is too close.
        if confidence < 0.62 || abs(orthodoxWeight - southpawWeight) / totalWeight < 0.15 {
            return FightStanceResolution(stance: .unknown, confidence: confidence, source: .fallbackUnknown)
        }

        let inferred: FightStance = orthodoxWeight > southpawWeight ? .orthodox : .southpaw
        return FightStanceResolution(stance: inferred, confidence: confidence, source: .autoInferred)
    }

    private struct Vote {
        let side: FightStance
        let weight: Double
    }

    private static func voteFromPair(
        left: PoseKeypoint?,
        right: PoseKeypoint?,
        minDelta: Double,
        maxDeltaForFullWeight: Double,
        weightScale: Double
    ) -> Vote? {
        guard let left,
              let right,
              left.confidence >= 0.3,
              right.confidence >= 0.3 else {
            return nil
        }

        let delta = Double(right.position.x - left.position.x)
        let absDelta = abs(delta)
        guard absDelta >= minDelta else {
            return nil
        }

        let normalized = min(1.0, absDelta / max(maxDeltaForFullWeight, 0.001))
        let weight = max(0.05, normalized * weightScale)
        let side: FightStance = delta >= 0 ? .orthodox : .southpaw
        return Vote(side: side, weight: weight)
    }

    private static func accumulate(
        _ vote: Vote,
        orthodoxWeight: inout Double,
        southpawWeight: inout Double
    ) {
        if vote.side == .orthodox {
            orthodoxWeight += vote.weight
        } else {
            southpawWeight += vote.weight
        }
    }

    private static func keypoint(_ joint: BodyJoint, in pose: PoseDetectionResult) -> PoseKeypoint? {
        PoseAnalysisHelpers.extractKeypoint(joint.rawValue, from: pose)
    }
}
