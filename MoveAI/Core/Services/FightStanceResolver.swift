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

        let setupPoses = Array(poses.prefix(20))
        var orthodoxVotes = 0
        var southpawVotes = 0

        for pose in setupPoses {
            guard let leftAnkle = keypoint(.leftAnkle, in: pose),
                  let rightAnkle = keypoint(.rightAnkle, in: pose),
                  leftAnkle.confidence >= 0.3,
                  rightAnkle.confidence >= 0.3 else {
                continue
            }

            // Camera-facing default: left foot leading implies orthodox.
            if leftAnkle.position.x <= rightAnkle.position.x {
                orthodoxVotes += 1
            } else {
                southpawVotes += 1
            }
        }

        let totalVotes = orthodoxVotes + southpawVotes
        guard totalVotes > 0 else {
            return FightStanceResolution(stance: .unknown, confidence: 0.0, source: .fallbackUnknown)
        }

        if orthodoxVotes == southpawVotes {
            return FightStanceResolution(stance: .unknown, confidence: 0.5, source: .fallbackUnknown)
        }

        let inferred: FightStance = orthodoxVotes > southpawVotes ? .orthodox : .southpaw
        let confidence = Double(max(orthodoxVotes, southpawVotes)) / Double(totalVotes)
        return FightStanceResolution(stance: inferred, confidence: confidence, source: .autoInferred)
    }

    private static func keypoint(_ joint: BodyJoint, in pose: PoseDetectionResult) -> PoseKeypoint? {
        PoseAnalysisHelpers.extractKeypoint(joint.rawValue, from: pose)
    }
}
