//
//  AnthropometryEstimator.swift
//  MoveAI
//
//  Created by Dave Mathew on 1/19/25.
//

import Foundation
import CoreGraphics

/// Estimates normalized body segment lengths from pose detection data
/// Used for personalized biomechanical analysis
struct AnthropometryEstimator {
    
    /// Estimated segment lengths (normalized by shin length)
    struct SegmentLengths {
        let shinLength: Double      // Normalized (median = 1.0)
        let femurLength: Double    // Normalized
        let torsoLength: Double    // Normalized
        let femurShinRatio: Double
        let torsofemurRatio: Double
        
        init(shinLength: Double, femurLength: Double, torsoLength: Double) {
            self.shinLength = shinLength
            self.femurLength = femurLength
            self.torsoLength = torsoLength
            self.femurShinRatio = femurLength / shinLength
            self.torsofemurRatio = torsoLength / femurLength
        }
    }
    
    /// Estimate segment lengths from pose data
    /// Uses median values across all valid frames for robustness
    /// Handles side-view videos (single side visible) and front-view (both sides)
    static func estimateSegmentLengths(from poses: [PoseDetectionResult]) -> SegmentLengths? {
        guard !poses.isEmpty else {
            print("🔬 Anthropometry: No poses provided")
            return nil
        }
        
        print("🔬 Anthropometry: Estimating from \(poses.count) poses...")
        var shinLengths: [Double] = []
        var femurLengths: [Double] = []
        var torsoLengths: [Double] = []
        
        for pose in poses {
            // Extract keypoints (reuse existing helper)
            let (leftHip, rightHip) = PoseAnalysisHelpers.extractBilateralKeypoints(
                leftName: "leftHip",
                rightName: "rightHip",
                from: pose
            )
            let (leftKnee, rightKnee) = PoseAnalysisHelpers.extractBilateralKeypoints(
                leftName: "leftKnee",
                rightName: "rightKnee",
                from: pose
            )
            let (leftAnkle, rightAnkle) = PoseAnalysisHelpers.extractBilateralKeypoints(
                leftName: "leftAnkle",
                rightName: "rightAnkle",
                from: pose
            )
            let (leftShoulder, rightShoulder) = PoseAnalysisHelpers.extractBilateralKeypoints(
                leftName: "leftShoulder",
                rightName: "rightShoulder",
                from: pose
            )
            
            // Calculate shin length (ankle to knee)
            // Prefer same-side measurements, fall back to average if both sides available
            if let leftAnkle = leftAnkle, let leftKnee = leftKnee {
                let shinLength = PoseAnalysisHelpers.distance(
                    from: leftAnkle.position,
                    to: leftKnee.position
                )
                shinLengths.append(shinLength)
            }
            if let rightAnkle = rightAnkle, let rightKnee = rightKnee {
                let shinLength = PoseAnalysisHelpers.distance(
                    from: rightAnkle.position,
                    to: rightKnee.position
                )
                shinLengths.append(shinLength)
            }
            
            // Calculate femur length (knee to hip)
            if let leftKnee = leftKnee, let leftHip = leftHip {
                let femurLength = PoseAnalysisHelpers.distance(
                    from: leftKnee.position,
                    to: leftHip.position
                )
                femurLengths.append(femurLength)
            }
            if let rightKnee = rightKnee, let rightHip = rightHip {
                let femurLength = PoseAnalysisHelpers.distance(
                    from: rightKnee.position,
                    to: rightHip.position
                )
                femurLengths.append(femurLength)
            }
            
            // Calculate torso length (hip to shoulder)
            // Use average positions if both sides available, otherwise single side
            let hipPos: CGPoint?
            if let leftHip = leftHip, let rightHip = rightHip {
                hipPos = PoseAnalysisHelpers.averagePosition(leftHip, rightHip)
            } else {
                hipPos = leftHip?.position ?? rightHip?.position
            }
            
            let shoulderPos: CGPoint?
            if let leftShoulder = leftShoulder, let rightShoulder = rightShoulder {
                shoulderPos = PoseAnalysisHelpers.averagePosition(leftShoulder, rightShoulder)
            } else {
                shoulderPos = leftShoulder?.position ?? rightShoulder?.position
            }
            
            if let hipPos = hipPos, let shoulderPos = shoulderPos {
                let torsoLength = PoseAnalysisHelpers.distance(
                    from: hipPos,
                    to: shoulderPos
                )
                torsoLengths.append(torsoLength)
            }
        }
        
        // Need at least some measurements for each segment
        guard !shinLengths.isEmpty, !femurLengths.isEmpty, !torsoLengths.isEmpty else {
            print("🔬 Anthropometry: Missing measurements - shin:\(shinLengths.count), femur:\(femurLengths.count), torso:\(torsoLengths.count)")
            return nil
        }
        
        print("🔬 Anthropometry: Collected \(shinLengths.count) shin, \(femurLengths.count) femur, \(torsoLengths.count) torso measurements")
        
        // Use median for robustness against outliers
        let medianShinLength = median(shinLengths)
        let medianFemurLength = median(femurLengths)
        let medianTorsoLength = median(torsoLengths)
        
        print("🔬 Anthropometry: Raw medians - shin:\(String(format: "%.3f", medianShinLength)), femur:\(String(format: "%.3f", medianFemurLength)), torso:\(String(format: "%.3f", medianTorsoLength))")
        
        // Normalize by shin length (shin = 1.0)
        let normalizedShin = 1.0
        let normalizedFemur = medianFemurLength / medianShinLength
        let normalizedTorso = medianTorsoLength / medianShinLength
        
        return SegmentLengths(
            shinLength: normalizedShin,
            femurLength: normalizedFemur,
            torsoLength: normalizedTorso
        )
    }
    
    /// Calculate median of an array
    private static func median(_ values: [Double]) -> Double {
        let sorted = values.sorted()
        let count = sorted.count
        if count % 2 == 0 {
            return (sorted[count / 2 - 1] + sorted[count / 2]) / 2.0
        } else {
            return sorted[count / 2]
        }
    }
    
    /// Normalize a value by shin length
    static func normalizeByShinLength(_ value: Double, shinLength: Double) -> Double {
        guard shinLength > 0 else { return value }
        return value / shinLength
    }
}
