//
//  PoseNormalizer.swift
//  MoveAI
//
//  Camera normalization for pose frames. Port of the web engine's
//  normalize.js (prehab2perform: prototype/move-analyzer/normalize.js);
//  keep the two in step.
//

import Foundation
import CoreGraphics

/// Vision joint positions are normalized to the picture: x by its width, y by
/// its height. Used as-is, that has three problems on real phone footage:
///
/// 1. Shape. On any non-square video one unit of x is not one unit of y, so
///    every angle is wrong (a 28° torso lean reads as 43° in a 9:16 clip).
/// 2. Camera movement. Hip height "in the picture" changes whenever a handheld
///    camera pans or zooms, which merges or invents reps.
/// 3. Distance. Thresholds written as a fraction of the picture mean different
///    things for someone who fills the frame and someone far away.
///
/// `normalize` returns poses in a body-relative space instead:
/// - isotropic: x is multiplied by the aspect ratio (width / height)
/// - anchored: the feet sit at a fixed spot every frame. Height is measured
///   from the lower ankle (the foot on the floor), so lifting one foot to step
///   or kick does not read as the hips dropping
/// - scaled: the shin has a fixed length (`shinRef`). The shin's length in the
///   picture is taken as the longest it looks over a few seconds, so zooming
///   is removed but the shin tilting toward a front-on camera at the bottom of
///   a squat (which makes it look shorter) is not mistaken for it
///
/// Poses with no usable ankle or shin are dropped. The returned positions are
/// for analysis only; draw overlays from the original poses.
enum PoseNormalizer {

    /// Shin length in the normalized space.
    static let shinRef: Double = 0.2
    /// Where the feet sit in the normalized space.
    static let anchorX: Double = 0.5
    static let anchorY: Double = 0.15

    /// Torso width (hip width + shoulder width) in shin lengths. Side-on, hips
    /// and shoulders stack up (width near 0); front-on it is about 1.3 or more.
    /// Calibrated on a handful of clips; expect to tune these with more footage.
    static let viewSideMax: Double = 0.7
    static let viewFrontMin: Double = 1.2

    private static let minConfidence: Float = 0.3
    /// Half-width of the window the shin length is judged over (about 2 s at 30 fps).
    private static let scaleWindowFrames = 60
    private static let scalePercentile = 0.9

    private struct Measure {
        let ax: Double
        let ay: Double
        let shin: Double
    }

    // MARK: - Normalization

    static func normalize(_ poses: [PoseDetectionResult], aspect: Double) -> [PoseDetectionResult] {
        let ratio = (aspect.isFinite && aspect > 0) ? aspect : 1.0
        let measured = poses.map { measure($0, ratio: ratio) }

        var out: [PoseDetectionResult] = []
        out.reserveCapacity(poses.count)
        var lo = 0
        var hi = 0
        for i in poses.indices {
            guard let m = measured[i] else { continue }
            let frame = poses[i].frameIndex
            while lo < i && frame - poses[lo].frameIndex > scaleWindowFrames { lo += 1 }
            while hi < poses.count - 1 && poses[hi + 1].frameIndex - frame <= scaleWindowFrames { hi += 1 }

            var shins: [Double] = []
            for j in lo...max(lo, hi) {
                if let other = measured[j] { shins.append(other.shin) }
            }
            guard let shin = percentile(shins, scalePercentile), shin > 0 else { continue }
            let k = shinRef / shin

            let keypoints = poses[i].keypoints.map { keypoint -> PoseKeypoint in
                let x = anchorX + (Double(keypoint.position.x) * ratio - m.ax) * k
                let y = anchorY + (Double(keypoint.position.y) - m.ay) * k
                return PoseKeypoint(
                    name: keypoint.name,
                    position: CGPoint(x: x, y: y),
                    confidence: keypoint.confidence,
                    timestamp: keypoint.timestamp
                )
            }
            out.append(PoseDetectionResult(keypoints: keypoints, frameIndex: poses[i].frameIndex, timestamp: poses[i].timestamp))
        }
        return out
    }

    /// Foot anchor and shin length for one pose, in isotropic units.
    private static func measure(_ pose: PoseDetectionResult, ratio: Double) -> Measure? {
        func point(_ name: String) -> (x: Double, y: Double, w: Double)? {
            guard let keypoint = pose.keypoints.first(where: { $0.name == name }) else { return nil }
            return (Double(keypoint.position.x) * ratio, Double(keypoint.position.y), Double(max(keypoint.confidence, 0)))
        }
        let minWeight = Double(minConfidence)
        let leftAnkle = point("leftAnkle")
        let rightAnkle = point("rightAnkle")
        let leftKnee = point("leftKnee")
        let rightKnee = point("rightKnee")

        let ankles = [leftAnkle, rightAnkle].compactMap { $0 }.filter { $0.w >= minWeight }
        guard !ankles.isEmpty else { return nil }
        let total = ankles.reduce(0.0) { $0 + $1.w }
        let ax = ankles.reduce(0.0) { $0 + $1.x * $1.w } / total
        // y points up in Vision coordinates: the lowest ankle is the foot on the floor.
        let ay = ankles.map { $0.y }.min() ?? 0

        var shins: [Double] = []
        for (knee, ankle) in [(leftKnee, leftAnkle), (rightKnee, rightAnkle)] {
            guard let knee = knee, let ankle = ankle, knee.w >= minWeight, ankle.w >= minWeight else { continue }
            shins.append(hypot(knee.x - ankle.x, knee.y - ankle.y))
        }
        guard let shin = shins.max() else { return nil }
        return Measure(ax: ax, ay: ay, shin: shin)
    }

    // MARK: - View (side / front / diagonal)

    /// Judges the view from how wide the torso looks compared with the shin, in
    /// the normalized space, so it does not depend on how much of the picture
    /// the person fills. Call with poses returned by `normalize`.
    static func classifyView(_ poses: [PoseDetectionResult]) -> (angle: CameraAngle, confidence: Double, medianKneeSeparation: Double, bothSidesFrameRatio: Double) {
        var widths: [Double] = []
        var kneeSeparations: [Double] = []
        for pose in poses {
            func x(_ name: String) -> Double? {
                guard let keypoint = pose.keypoints.first(where: { $0.name == name }), keypoint.confidence >= minConfidence else { return nil }
                return Double(keypoint.position.x)
            }
            if let leftHip = x("leftHip"), let rightHip = x("rightHip"),
               let leftShoulder = x("leftShoulder"), let rightShoulder = x("rightShoulder") {
                widths.append((abs(leftHip - rightHip) + abs(leftShoulder - rightShoulder)) / shinRef)
            }
            if let leftKnee = x("leftKnee"), let rightKnee = x("rightKnee") {
                kneeSeparations.append(abs(leftKnee - rightKnee))
            }
        }
        let total = Double(max(1, poses.count))
        let kneeSeparation = percentile(kneeSeparations, 0.5) ?? 0
        let bothSides = Double(widths.count) / total

        // Not enough of the torso seen to judge: treat as a side view (one side hidden).
        guard let width = percentile(widths, 0.5), Double(widths.count) >= total * 0.3 else {
            return (.side, 0.5, kneeSeparation, bothSides)
        }
        if width < viewSideMax {
            let confidence = 0.6 + 0.4 * ((viewSideMax - width) / viewSideMax) * 2
            return (.side, min(1, max(0, confidence)), kneeSeparation, bothSides)
        }
        if width > viewFrontMin {
            let confidence = 0.6 + 0.4 * ((width - viewFrontMin) / 0.3)
            return (.front, min(1, max(0, confidence)), kneeSeparation, bothSides)
        }
        // In between: an angled view. Confidence stays low so the results say
        // that some checks were skipped.
        return (.diagonal, 0.5, kneeSeparation, bothSides)
    }

    // MARK: - Helpers

    private static func percentile(_ values: [Double], _ fraction: Double) -> Double? {
        guard !values.isEmpty else { return nil }
        let sorted = values.sorted()
        let index = min(sorted.count - 1, Int(Double(sorted.count) * fraction))
        return sorted[index]
    }
}
