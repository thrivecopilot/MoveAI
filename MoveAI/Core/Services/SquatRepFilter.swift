//
//  SquatRepFilter.swift
//  MoveAI
//
//  Keeps only the rep candidates that are actually squats. Port of the web
//  engine's rep-filter.js (prehab2perform: prototype/move-analyzer/rep-filter.js);
//  keep the two in step.
//

import Foundation
import CoreGraphics

/// The rep detector works from hip height alone, so walking the bar out,
/// re-racking it, or shifting about between reps can all look like a shallow
/// rep. This runs on camera-normalized poses (see `PoseNormalizer`), where
/// heights are measured from the feet in units of shin length, and applies two
/// tests a squat always passes and those movements do not:
///
/// - the hips drop by at least `minHipDrop` shin lengths, and
/// - a knee bends past `maxKneeAngle`.
///
/// It also re-judges "came back up" against the rep's own start, which is
/// steadier than comparing with the first frames of the clip.
enum SquatRepFilter {

    /// Shin lengths.
    static let minHipDrop: Double = 0.4
    /// Degrees; 180 is a straight leg.
    static let maxKneeAngle: Double = 130
    static let minReturnFraction: Double = 0.8

    static func keepSquatReps(_ reps: [SquatRep], poses: [PoseDetectionResult], smoothedHeights: [Double]) -> [SquatRep] {
        guard !smoothedHeights.isEmpty else { return [] }
        var kept: [SquatRep] = []
        for rep in reps {
            guard rep.startFrame >= 0, rep.startFrame < smoothedHeights.count,
                  rep.bottomFrame >= 0, rep.bottomFrame < smoothedHeights.count else { continue }
            let top = smoothedHeights[rep.startFrame]
            let bottom = smoothedHeights[rep.bottomFrame]
            let end = smoothedHeights[min(max(rep.endFrame, 0), smoothedHeights.count - 1)]
            let drop = top - bottom
            if drop / PoseNormalizer.shinRef < minHipDrop { continue }
            if minKneeAngle(in: poses, rep: rep) > maxKneeAngle { continue }
            let returnedToStart = end - bottom >= minReturnFraction * drop
            kept.append(SquatRep(
                repNumber: kept.count + 1,
                startFrame: rep.startFrame,
                endFrame: rep.endFrame,
                startTime: rep.startTime,
                endTime: rep.endTime,
                isFullRep: returnedToStart,
                bottomFrame: rep.bottomFrame,
                bottomTime: rep.bottomTime,
                reachedDepth: true,
                returnedToStart: returnedToStart
            ))
        }
        return kept
    }

    private static func minKneeAngle(in poses: [PoseDetectionResult], rep: SquatRep) -> Double {
        var smallest = 180.0
        guard !poses.isEmpty, rep.startFrame <= rep.endFrame else { return smallest }
        let last = min(rep.endFrame, poses.count - 1)
        guard rep.startFrame <= last else { return smallest }
        for index in max(rep.startFrame, 0)...last {
            let pose = poses[index]
            func position(_ name: String) -> CGPoint? {
                guard let keypoint = pose.keypoints.first(where: { $0.name == name }), keypoint.confidence >= 0.3 else { return nil }
                return keypoint.position
            }
            for side in ["left", "right"] {
                guard let hip = position("\(side)Hip"),
                      let knee = position("\(side)Knee"),
                      let ankle = position("\(side)Ankle") else { continue }
                smallest = min(smallest, PoseAnalysisHelpers.calculateAngle(point1: hip, point2: knee, point3: ankle))
            }
        }
        return smallest
    }
}
