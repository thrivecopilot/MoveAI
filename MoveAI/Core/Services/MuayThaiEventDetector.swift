import CoreGraphics
import Foundation

struct TechniqueAttempt: Hashable {
    let startFrame: Int
    let endFrame: Int
    let peakFrame: Int
    let peakTimestamp: TimeInterval
}

enum MuayThaiEventDetector {
    private static let minimumPeakGapFrames = 14
    private static let peakRelativeThreshold = 0.42
    private static let speedSmoothingRadius = 1

    static func detectAttempts(
        poses: [PoseDetectionResult],
        technique: MuayThaiTechnique,
        stance: FightStance
    ) -> [TechniqueAttempt] {
        guard poses.count >= 3 else {
            MuayThaiDebug.log("MuayThaiEventDetector: technique=\(technique.rawValue) stance=\(stance.rawValue) frames=\(poses.count) -> default (too few frames)")
            return defaultAttempt(for: poses)
        }

        if (technique == .jab || technique == .cross),
           let punchAttempts = detectPunchAttempts(poses: poses, technique: technique, stance: stance),
           !punchAttempts.isEmpty {
            return punchAttempts
        }

        let rawSpeeds = motionSpeeds(poses: poses, technique: technique, stance: stance)
        let speeds = smoothSignal(rawSpeeds, radius: speedSmoothingRadius)
        let maxSpeed = speeds.max() ?? 0

        guard maxSpeed > 0 else {
            MuayThaiDebug.log("MuayThaiEventDetector: technique=\(technique.rawValue) stance=\(stance.rawValue) maxSpeed=0 -> default")
            return defaultAttempt(for: poses)
        }

        let baseThreshold = technique == .movement ? 0.012 : 0.018
        let threshold = max(baseThreshold, maxSpeed * peakRelativeThreshold)

        var peakFrames: [Int] = []
        for index in 1..<(speeds.count - 1) {
            let current = speeds[index]
            guard current >= threshold else { continue }
            guard isLocalPeak(speeds: speeds, index: index) else { continue }

            if let last = peakFrames.last, index - last < minimumPeakGapFrames {
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

        let rawMaxSpeed = rawSpeeds.max() ?? 0
        MuayThaiDebug.log("MuayThaiEventDetector: technique=\(technique.rawValue) stance=\(stance.rawValue) maxSpeedRaw=\(MuayThaiDebug.format(rawMaxSpeed, decimals: 4)) maxSpeedSmoothed=\(MuayThaiDebug.format(maxSpeed, decimals: 4)) threshold=\(MuayThaiDebug.format(threshold, decimals: 4)) peaks=\(peakFrames)")

        let attempts = peakFrames.map { peakFrame -> TechniqueAttempt in
            let start = max(0, peakFrame - 6)
            let end = min(poses.count - 1, peakFrame + 6)
            let ts = poses[safe: peakFrame]?.timestamp.timeIntervalSince1970 ?? 0
            return TechniqueAttempt(startFrame: start, endFrame: end, peakFrame: peakFrame, peakTimestamp: ts)
        }

        if attempts.isEmpty {
            MuayThaiDebug.log("MuayThaiEventDetector: technique=\(technique.rawValue) no peaks -> default")
            return defaultAttempt(for: poses)
        }

        MuayThaiDebug.log("MuayThaiEventDetector: technique=\(technique.rawValue) attempts=\(attempts.map { attempt in "[\(attempt.startFrame)-\(attempt.peakFrame)-\(attempt.endFrame)]" }.joined(separator: ","))")

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

    private static func motionSpeeds(
        poses: [PoseDetectionResult],
        technique: MuayThaiTechnique,
        stance: FightStance
    ) -> [Double] {
        if technique == .jab || technique == .cross {
            let primaryWrist: BodyJoint = {
                if technique == .jab {
                    return leadJoint(left: .leftWrist, right: .rightWrist, stance: stance)
                }
                return rearJoint(left: .leftWrist, right: .rightWrist, stance: stance)
            }()
            let secondaryWrist: BodyJoint = primaryWrist == .leftWrist ? .rightWrist : .leftWrist

            let primarySignal = punchSignalQuality(poses: poses, wrist: primaryWrist)
            let secondarySignal = punchSignalQuality(poses: poses, wrist: secondaryWrist)
            let useSecondary = shouldUseSecondaryPunchWrist(primary: primarySignal, secondary: secondarySignal)
            let trackedWrist = useSecondary ? secondaryWrist : primaryWrist
            let trackedSpeeds = useSecondary
                ? secondarySignal.speeds
                : primarySignal.speeds

            MuayThaiDebug.log(
                "MuayThaiEventDetector: \(technique.rawValue) wrist=\(trackedWrist.rawValue) " +
                "primary(extAmp=\(MuayThaiDebug.format(primarySignal.extensionAmplitude, decimals: 3)), coverage=\(MuayThaiDebug.format(primarySignal.coverageRatio, decimals: 2)), speedMax=\(MuayThaiDebug.format(primarySignal.maxSpeed, decimals: 4))) " +
                "secondary(extAmp=\(MuayThaiDebug.format(secondarySignal.extensionAmplitude, decimals: 3)), coverage=\(MuayThaiDebug.format(secondarySignal.coverageRatio, decimals: 2)), speedMax=\(MuayThaiDebug.format(secondarySignal.maxSpeed, decimals: 4)))"
            )

            return trackedSpeeds
        }

        let trackedPoints = poses.map { trackedPoint(in: $0, technique: technique, stance: stance) }
        return speeds(from: trackedPoints, frameCount: poses.count)
    }

    private static func speeds(from points: [CGPoint?], frameCount: Int) -> [Double] {
        var speeds = Array(repeating: 0.0, count: frameCount)
        guard frameCount >= 2 else { return speeds }

        for index in 1..<frameCount {
            guard let previous = points[index - 1],
                  let current = points[index] else {
                continue
            }

            speeds[index] = PoseAnalysisHelpers.distance(from: previous, to: current)
        }
        return speeds
    }

    private static func smoothSignal(_ values: [Double], radius: Int) -> [Double] {
        guard radius > 0, values.count >= 3 else { return values }
        var smoothed = Array(repeating: 0.0, count: values.count)

        for index in values.indices {
            let start = max(values.startIndex, index - radius)
            let end = min(values.count - 1, index + radius)
            let window = values[start...end]
            smoothed[index] = window.reduce(0.0, +) / Double(window.count)
        }

        return smoothed
    }

    private static func isLocalPeak(speeds: [Double], index: Int) -> Bool {
        let radius = speeds.count >= 7 ? 2 : 1
        let start = max(0, index - radius)
        let end = min(speeds.count - 1, index + radius)
        let current = speeds[index]

        for neighbor in start...end where neighbor != index {
            if current < speeds[neighbor] {
                return false
            }
        }
        return true
    }

    private static func point(for joint: BodyJoint, in pose: PoseDetectionResult) -> CGPoint? {
        PoseAnalysisHelpers.extractKeypoint(joint.rawValue, from: pose)?.position
    }

    private struct PunchSignal {
        let speeds: [Double]
        let maxSpeed: Double
        let extensionSignal: [Double]
        let extensionAmplitude: Double
        let coverageRatio: Double
    }

    private static func punchSignalQuality(poses: [PoseDetectionResult], wrist: BodyJoint) -> PunchSignal {
        let points = poses.map { point(for: wrist, in: $0) }
        let speeds = speeds(from: points, frameCount: poses.count)
        let maxSpeed = speeds.max() ?? 0

        let shoulder = shoulderForWrist(wrist)
        var extensionValues: [Double] = []
        var extensionByFrame = Array(repeating: Double.nan, count: poses.count)
        extensionValues.reserveCapacity(poses.count)

        for (index, pose) in poses.enumerated() {
            guard let wristPoint = point(for: wrist, in: pose),
                  let shoulderPoint = point(for: shoulder, in: pose),
                  let shoulderWidth = bilateralDistance(.leftShoulder, .rightShoulder, in: pose),
                  shoulderWidth > 0.04 else {
                continue
            }

            let reach = PoseAnalysisHelpers.distance(from: shoulderPoint, to: wristPoint)
            let extensionRatio = reach / shoulderWidth
            extensionValues.append(extensionRatio)
            extensionByFrame[index] = extensionRatio
        }

        let coverageRatio = poses.isEmpty ? 0 : Double(extensionValues.count) / Double(poses.count)
        let extensionAmplitude = max(0, percentile(extensionValues, p: 0.90) - percentile(extensionValues, p: 0.10))
        let filledExtensionSignal = fillMissingSamples(extensionByFrame)

        return PunchSignal(
            speeds: speeds,
            maxSpeed: maxSpeed,
            extensionSignal: filledExtensionSignal,
            extensionAmplitude: extensionAmplitude,
            coverageRatio: coverageRatio
        )
    }

    private static func shouldUseSecondaryPunchWrist(primary: PunchSignal, secondary: PunchSignal) -> Bool {
        let primaryDominance = punchSignalDominanceScore(primary)
        let secondaryDominance = punchSignalDominanceScore(secondary)

        if secondaryDominance > primaryDominance * 1.20,
           secondary.coverageRatio >= primary.coverageRatio - 0.12,
           secondary.extensionAmplitude > primary.extensionAmplitude + 0.02 {
            return true
        }

        if primary.coverageRatio < 0.35, secondary.coverageRatio > primary.coverageRatio + 0.15 {
            return true
        }

        if primary.extensionAmplitude < 0.10, secondary.extensionAmplitude > primary.extensionAmplitude + 0.05 {
            return true
        }

        if secondary.extensionAmplitude > max(primary.extensionAmplitude * 1.75, primary.extensionAmplitude + 0.08),
           secondary.maxSpeed > max(primary.maxSpeed * 1.20, primary.maxSpeed + 0.004),
           secondary.extensionAmplitude > 0.14 {
            return true
        }

        return false
    }

    private static func punchSignalDominanceScore(_ signal: PunchSignal) -> Double {
        (signal.extensionAmplitude * 1.15) + (signal.maxSpeed * 11.0) + (signal.coverageRatio * 0.05)
    }

    private static func shoulderForWrist(_ wrist: BodyJoint) -> BodyJoint {
        switch wrist {
        case .rightWrist:
            return .rightShoulder
        case .leftWrist:
            return .leftShoulder
        default:
            return .leftShoulder
        }
    }

    private static func bilateralDistance(_ left: BodyJoint, _ right: BodyJoint, in pose: PoseDetectionResult) -> Double? {
        guard let leftPoint = point(for: left, in: pose),
              let rightPoint = point(for: right, in: pose) else {
            return nil
        }
        return PoseAnalysisHelpers.distance(from: leftPoint, to: rightPoint)
    }

    private static func detectPunchAttempts(
        poses: [PoseDetectionResult],
        technique: MuayThaiTechnique,
        stance: FightStance
    ) -> [TechniqueAttempt]? {
        let primaryWrist: BodyJoint = {
            if technique == .jab {
                return leadJoint(left: .leftWrist, right: .rightWrist, stance: stance)
            }
            return rearJoint(left: .leftWrist, right: .rightWrist, stance: stance)
        }()
        let secondaryWrist: BodyJoint = primaryWrist == .leftWrist ? .rightWrist : .leftWrist

        let primarySignal = punchSignalQuality(poses: poses, wrist: primaryWrist)
        let secondarySignal = punchSignalQuality(poses: poses, wrist: secondaryWrist)
        let useSecondary = shouldUseSecondaryPunchWrist(primary: primarySignal, secondary: secondarySignal)
        let trackedWrist = useSecondary ? secondaryWrist : primaryWrist
        let trackedSignal = useSecondary ? secondarySignal : primarySignal

        let smoothedExtension = smoothSignal(trackedSignal.extensionSignal, radius: 2)
        let baseline = percentile(smoothedExtension, p: 0.20)
        let top = percentile(smoothedExtension, p: 0.95)
        let amplitude = max(0, top - baseline)

        guard amplitude > 0.08 else {
            MuayThaiDebug.log("MuayThaiEventDetector: \(technique.rawValue) extension fallback (low amplitude=\(MuayThaiDebug.format(amplitude, decimals: 3)))")
            return nil
        }

        let threshold = baseline + max(0.08, amplitude * 0.44)
        let minimumGap = 10

        var peakFrames: [Int] = []
        for index in 1..<(smoothedExtension.count - 1) {
            let current = smoothedExtension[index]
            guard current >= threshold else { continue }
            guard isLocalPeak(speeds: smoothedExtension, index: index) else { continue }

            if let last = peakFrames.last {
                let valley = smoothedExtension[last...index].min() ?? smoothedExtension[last]
                let recovery = min(smoothedExtension[last], current) - valley

                if index - last < minimumGap || recovery < max(0.018, amplitude * 0.14) {
                    if current > smoothedExtension[last] {
                        peakFrames[peakFrames.count - 1] = index
                    }
                    continue
                }
            }

            peakFrames.append(index)
        }

        guard !peakFrames.isEmpty else {
            MuayThaiDebug.log("MuayThaiEventDetector: \(technique.rawValue) extension fallback (no peaks)")
            return nil
        }

        MuayThaiDebug.log(
            "MuayThaiEventDetector: technique=\(technique.rawValue) stance=\(stance.rawValue) " +
            "signal=extension wrist=\(trackedWrist.rawValue) baseline=\(MuayThaiDebug.format(baseline, decimals: 3)) " +
            "top=\(MuayThaiDebug.format(top, decimals: 3)) threshold=\(MuayThaiDebug.format(threshold, decimals: 3)) peaks=\(peakFrames)"
        )

        return peakFrames.map { peakFrame in
            let start = max(0, peakFrame - 6)
            let end = min(poses.count - 1, peakFrame + 6)
            let ts = poses[safe: peakFrame]?.timestamp.timeIntervalSince1970 ?? 0
            return TechniqueAttempt(startFrame: start, endFrame: end, peakFrame: peakFrame, peakTimestamp: ts)
        }
    }

    private static func fillMissingSamples(_ values: [Double]) -> [Double] {
        guard !values.isEmpty else { return [] }

        var filled = values
        var lastFinite: Double?
        for index in filled.indices {
            if filled[index].isFinite {
                lastFinite = filled[index]
                continue
            }
            if let lastFinite {
                filled[index] = lastFinite
            }
        }

        var nextFinite: Double?
        for index in filled.indices.reversed() {
            if filled[index].isFinite {
                nextFinite = filled[index]
                continue
            }
            if let nextFinite {
                filled[index] = nextFinite
            }
        }

        for index in filled.indices where !filled[index].isFinite {
            filled[index] = 0
        }

        return filled
    }

    private static func percentile(_ values: [Double], p: Double) -> Double {
        guard !values.isEmpty else { return 0 }
        let sorted = values.sorted()
        let clamped = max(0, min(1, p))
        let index = Int(round(clamped * Double(sorted.count - 1)))
        return sorted[index]
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
