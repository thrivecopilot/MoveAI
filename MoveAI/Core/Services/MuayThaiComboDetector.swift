import CoreGraphics
import Foundation

struct MuayThaiClassifiedAttempt: Hashable {
    let attempt: TechniqueAttempt
    let technique: MuayThaiTechnique
    let confidence: Double
}

struct MuayThaiComboDetection {
    let attempts: [MuayThaiClassifiedAttempt]
    let stanceResolution: FightStanceResolution

    private var groupedAttempts: [MuayThaiTechnique: [MuayThaiClassifiedAttempt]] {
        Dictionary(grouping: attempts, by: { $0.technique })
    }

    var dominantTechnique: MuayThaiTechnique? {
        guard !attempts.isEmpty else { return nil }

        return groupedAttempts
            .map { technique, values in
                let avgConfidence = values.reduce(0.0) { $0 + $1.confidence } / Double(values.count)
                return (technique: technique, count: values.count, avgConfidence: avgConfidence)
            }
            .sorted {
                if $0.count == $1.count {
                    return $0.avgConfidence > $1.avgConfidence
                }
                return $0.count > $1.count
            }
            .first?
            .technique
    }

    var dominantTechniqueConfidence: Double? {
        guard let dominant = dominantTechnique else { return nil }
        let dominantAttempts = groupedAttempts[dominant] ?? []
        guard !dominantAttempts.isEmpty else { return nil }

        return dominantAttempts.reduce(0.0) { $0 + $1.confidence } / Double(dominantAttempts.count)
    }

    var dominantTechniqueShare: Double? {
        guard let dominant = dominantTechnique else { return nil }
        let dominantAttempts = groupedAttempts[dominant] ?? []
        guard !attempts.isEmpty else { return nil }
        return Double(dominantAttempts.count) / Double(attempts.count)
    }

    var hasMixedTechniques: Bool {
        Set(attempts.map(\.technique)).count > 1
    }
}

enum MuayThaiComboDetector {
    private static let minimumPeakSpeed = 0.006
    private static let peakRelativeThreshold = 0.4
    private static let minimumClassifiedConfidence = 0.22
    private static let minimumPeakGapFrames = 6

    static func detect(
        poses: [PoseDetectionResult],
        preferredStance: FightStance?
    ) -> MuayThaiComboDetection? {
        guard poses.count >= 6 else { return nil }

        let stanceResolution = FightStanceResolver.resolve(preferred: preferredStance, from: poses)
        let motionSpeeds = computeMotionSpeeds(poses: poses)
        let maxSpeed = motionSpeeds.max() ?? 0

        guard maxSpeed >= minimumPeakSpeed else { return nil }

        let threshold = max(minimumPeakSpeed, maxSpeed * peakRelativeThreshold)
        var peakFrames = detectPeakFrames(speeds: motionSpeeds, threshold: threshold)

        if peakFrames.isEmpty,
           let strongest = motionSpeeds.enumerated().max(by: { $0.element < $1.element })?.offset,
           motionSpeeds[safely: strongest] ?? 0 > 0 {
            peakFrames = [strongest]
        }

        // Only hard-lock left/right interpretation when the user explicitly selected stance.
        let classificationPreferredStance = normalizedPreferredStance(preferredStance)
        MuayThaiDebug.log("ComboDetector: preferredStance=\(preferredStance?.rawValue ?? "nil") resolvedStance=\(stanceResolution.stance.rawValue) source=\(String(describing: stanceResolution.source)) classificationPreferred=\(classificationPreferredStance?.rawValue ?? "nil") peaks=\(peakFrames)")

        let classifiedAttempts = classifyAttempts(
            peakFrames: peakFrames,
            motionSpeeds: motionSpeeds,
            maxSpeed: maxSpeed,
            poses: poses,
            preferredStance: classificationPreferredStance
        )

        guard !classifiedAttempts.isEmpty else { return nil }

        return MuayThaiComboDetection(
            attempts: classifiedAttempts,
            stanceResolution: stanceResolution
        )
    }

    private static func computeMotionSpeeds(poses: [PoseDetectionResult]) -> [Double] {
        let trackedJoints: [BodyJoint] = [
            .leftWrist,
            .rightWrist,
            .leftElbow,
            .rightElbow,
            .leftKnee,
            .rightKnee,
            .leftAnkle,
            .rightAnkle,
            .root,
        ]

        var speeds = Array(repeating: 0.0, count: poses.count)
        guard poses.count >= 2 else { return speeds }

        for frame in 1..<poses.count {
            var frameMax = 0.0
            for joint in trackedJoints {
                guard let previous = point(for: joint, in: poses[frame - 1]),
                      let current = point(for: joint, in: poses[frame]) else {
                    continue
                }

                let displacement = PoseAnalysisHelpers.distance(from: previous, to: current)
                frameMax = max(frameMax, displacement)
            }
            speeds[frame] = frameMax
        }

        return speeds
    }

    private static func detectPeakFrames(speeds: [Double], threshold: Double) -> [Int] {
        guard speeds.count >= 3 else { return [] }

        var peaks: [Int] = []
        for index in 1..<(speeds.count - 1) {
            let current = speeds[index]
            guard current >= threshold else { continue }
            guard current >= speeds[index - 1], current >= speeds[index + 1] else { continue }

            if let last = peaks.last, index - last < minimumPeakGapFrames {
                if current > speeds[last] {
                    peaks[peaks.count - 1] = index
                }
            } else {
                peaks.append(index)
            }
        }

        return peaks
    }

    private static func classifyAttempts(
        peakFrames: [Int],
        motionSpeeds: [Double],
        maxSpeed: Double,
        poses: [PoseDetectionResult],
        preferredStance: FightStance?
    ) -> [MuayThaiClassifiedAttempt] {
        var attempts: [MuayThaiClassifiedAttempt] = []

        for peakFrame in peakFrames {
            let startFrame = max(0, peakFrame - 6)
            let endFrame = min(poses.count - 1, peakFrame + 6)

            let window = Array(poses[startFrame...endFrame])
            guard let classification = MuayThaiTechniqueDetector.detectBestEffort(
                poses: window,
                preferredStance: preferredStance
            ) else {
                continue
            }

            let peakSpeed = motionSpeeds[safely: peakFrame] ?? 0
            let motionConfidence = maxSpeed > 0 ? min(1.0, peakSpeed / maxSpeed) : 0
            let combinedConfidence = min(1.0, max(0.0, (classification.confidence * 0.75) + (motionConfidence * 0.25)))

            guard combinedConfidence >= minimumClassifiedConfidence else { continue }

            let peakTimestamp = poses[safely: peakFrame]?.timestamp.timeIntervalSince1970 ?? 0
            let attempt = TechniqueAttempt(
                startFrame: startFrame,
                endFrame: endFrame,
                peakFrame: peakFrame,
                peakTimestamp: peakTimestamp
            )

            attempts.append(
                MuayThaiClassifiedAttempt(
                    attempt: attempt,
                    technique: classification.technique,
                    confidence: combinedConfidence
                )
            )
        }

        return deduplicateNearAttempts(attempts.sorted { $0.attempt.peakFrame < $1.attempt.peakFrame })
    }

    private static func normalizedPreferredStance(_ preferredStance: FightStance?) -> FightStance? {
        guard let preferredStance, preferredStance != .unknown else {
            return nil
        }
        return preferredStance
    }

    private static func deduplicateNearAttempts(_ attempts: [MuayThaiClassifiedAttempt]) -> [MuayThaiClassifiedAttempt] {
        guard !attempts.isEmpty else { return [] }

        var filtered: [MuayThaiClassifiedAttempt] = []
        for candidate in attempts {
            guard let last = filtered.last else {
                filtered.append(candidate)
                continue
            }

            let peakGap = candidate.attempt.peakFrame - last.attempt.peakFrame
            if peakGap <= 4 {
                if candidate.confidence > last.confidence {
                    filtered[filtered.count - 1] = candidate
                }
                continue
            }

            filtered.append(candidate)
        }

        return filtered
    }

    private static func point(for joint: BodyJoint, in pose: PoseDetectionResult) -> CGPoint? {
        PoseAnalysisHelpers.extractKeypoint(joint.rawValue, from: pose)?.position
    }
}

private extension Array {
    subscript(safely index: Int) -> Element? {
        guard indices.contains(index) else { return nil }
        return self[index]
    }
}
