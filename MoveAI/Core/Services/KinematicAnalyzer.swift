//
//  KinematicAnalyzer.swift
//  MoveAI
//
//  Created by Dave Mathew on 1/19/25.
//

import Foundation
import CoreGraphics

/// Computes observed kinematics from pose data with smoothing and velocity calculation
struct KinematicAnalyzer {
    
    /// Observed kinematics for a rep
    struct ObservedKinematics {
        let torsoAngles: [Double]           // Per frame
        let shinAngles: [Double]            // Per frame
        let hipAngles: [Double]?            // If computable
        let kneeAngles: [Double]?           // If computable
        let ankleAngles: [Double]?          // If computable
        let comProxy: [CGPoint]             // Center of mass proxy
        let depths: [Double]                // Normalized depth [0,1]
        let hipVelocities: [CGPoint]        // Hip velocities
        let shoulderVelocities: [CGPoint]  // Shoulder velocities
        let frameIndices: [Int]             // Corresponding frame indices
        let repNumber: Int
    }
    
    /// Calculate observed kinematics for a rep
    /// Leverages existing smoothed heights and rep boundaries
    static func calculateObservedKinematics(
        poses: [PoseDetectionResult],
        rep: SquatRep,
        smoothedHeights: [Double],
        repStartHeight: Double,
        repBottomHeight: Double
    ) -> ObservedKinematics? {
        // Extract frames for this rep
        let repFrames = rep.startFrame...rep.endFrame
        guard repFrames.lowerBound >= 0 && repFrames.upperBound < poses.count else {
            print("    ⚠️ Invalid rep frame range: \(repFrames)")
            return nil
        }
        
        let repPoses = Array(poses[repFrames])
        let repSmoothedHeights = Array(smoothedHeights[repFrames])
        print("    📊 Processing \(repPoses.count) frames for kinematics...")
        
        var torsoAngles: [Double] = []
        var shinAngles: [Double] = []
        var hipAngles: [Double] = []
        var kneeAngles: [Double] = []
        var ankleAngles: [Double] = []
        var comProxy: [CGPoint] = []
        var depths: [Double] = []
        var hipPositions: [CGPoint] = []
        var shoulderPositions: [CGPoint] = []
        var frameIndices: [Int] = []
        
        for (localIndex, pose) in repPoses.enumerated() {
            let globalIndex = rep.startFrame + localIndex
            frameIndices.append(globalIndex)
            
            // Extract keypoints
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
            
            // Calculate positions (prefer same side, fall back to average)
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
            
            let kneePos: CGPoint?
            if let leftKnee = leftKnee, let rightKnee = rightKnee {
                kneePos = PoseAnalysisHelpers.averagePosition(leftKnee, rightKnee)
            } else {
                kneePos = leftKnee?.position ?? rightKnee?.position
            }
            
            let anklePos: CGPoint?
            if let leftAnkle = leftAnkle, let rightAnkle = rightAnkle {
                anklePos = PoseAnalysisHelpers.averagePosition(leftAnkle, rightAnkle)
            } else {
                anklePos = leftAnkle?.position ?? rightAnkle?.position
            }
            
            guard let hip = hipPos, let shoulder = shoulderPos else {
                continue  // Skip frame if essential keypoints missing
            }
            
            // Calculate torso angle (shoulder-hip line relative to vertical)
            let torsoAngle = PoseAnalysisHelpers.calculateVerticalAngle(
                from: shoulder,
                to: hip
            )
            torsoAngles.append(torsoAngle)
            
            // Calculate shin angle (ankle-knee line relative to vertical)
            if let knee = kneePos, let ankle = anklePos {
                let shinAngle = PoseAnalysisHelpers.calculateVerticalAngle(
                    from: ankle,
                    to: knee
                )
                shinAngles.append(shinAngle)
            } else {
                shinAngles.append(0.0)  // Default if missing
            }
            
            // Calculate joint angles if possible
            if let knee = kneePos, let ankle = anklePos, let hip = hipPos {
                // Hip angle (hip-knee-ankle)
                let hipAngle = PoseAnalysisHelpers.calculateAngle(
                    point1: hip,
                    point2: knee,
                    point3: ankle
                )
                hipAngles.append(hipAngle)
                
                // Knee angle (hip-knee-ankle, but knee is vertex)
                let kneeAngle = PoseAnalysisHelpers.calculateAngle(
                    point1: hip,
                    point2: knee,
                    point3: ankle
                )
                kneeAngles.append(kneeAngle)
            } else {
                hipAngles.append(0.0)
                kneeAngles.append(0.0)
            }
            
            // Ankle angle (if we have foot keypoints, otherwise skip)
            ankleAngles.append(0.0)  // Placeholder
            
            // Calculate COM proxy
            let comX = SquatMechanicsConfig.comHipWeight * hip.x + SquatMechanicsConfig.comShoulderWeight * shoulder.x
            let comY = SquatMechanicsConfig.comHipWeight * hip.y + SquatMechanicsConfig.comShoulderWeight * shoulder.y
            comProxy.append(CGPoint(x: comX, y: comY))
            
            // Calculate normalized depth [0,1]
            // Reuse existing depth calculation logic
            let currentHipY = Double(hip.y)
            let depth = computeNormalizedDepth(
                hipY: currentHipY,
                repStartHeight: repStartHeight,
                repBottomHeight: repBottomHeight
            )
            depths.append(depth)
            
            // Store positions for velocity calculation
            hipPositions.append(hip)
            shoulderPositions.append(shoulder)
        }
        
        guard !torsoAngles.isEmpty else {
            print("    ⚠️ No torso angles computed - insufficient keypoints")
            return nil
        }
        
        print("    ✓ Computed \(torsoAngles.count) torso angles, \(shinAngles.count) shin angles")
        
        // Smooth angles before computing velocities
        let smoothedTorsoAngles = PoseAnalysisHelpers.smoothValues(torsoAngles, windowSize: 5)
        let smoothedShinAngles = PoseAnalysisHelpers.smoothValues(shinAngles, windowSize: 5)
        
        // Smooth positions before computing velocities
        let smoothedHipPositions = smoothPositions(hipPositions)
        let smoothedShoulderPositions = smoothPositions(shoulderPositions)
        
        // Compute velocities using central difference
        let hipVelocities = computeVelocities(
            positions: smoothedHipPositions,
            timestamps: repPoses.map { $0.timestamp }
        )
        let shoulderVelocities = computeVelocities(
            positions: smoothedShoulderPositions,
            timestamps: repPoses.map { $0.timestamp }
        )
        
        print("    ✓ Computed velocities: \(hipVelocities.count) hip, \(shoulderVelocities.count) shoulder")
        
        return ObservedKinematics(
            torsoAngles: smoothedTorsoAngles,
            shinAngles: smoothedShinAngles,
            hipAngles: hipAngles.isEmpty ? nil : hipAngles,
            kneeAngles: kneeAngles.isEmpty ? nil : kneeAngles,
            ankleAngles: ankleAngles.isEmpty ? nil : ankleAngles,
            comProxy: comProxy,
            depths: depths,
            hipVelocities: hipVelocities,
            shoulderVelocities: shoulderVelocities,
            frameIndices: frameIndices,
            repNumber: rep.repNumber
        )
    }
    
    /// Compute normalized depth [0,1] using existing depth calculation logic
    private static func computeNormalizedDepth(
        hipY: Double,
        repStartHeight: Double,
        repBottomHeight: Double
    ) -> Double {
        // Same formula as existing depth calculation
        // depth = (hip_y - hip_y_top) / (hip_y_bottom - hip_y_top)
        // Clamp to [0, 1]
        let depth = (hipY - repStartHeight) / (repBottomHeight - repStartHeight)
        return max(0.0, min(1.0, depth))
    }
    
    /// Smooth positions using moving average (reuse existing smoothing)
    private static func smoothPositions(_ positions: [CGPoint]) -> [CGPoint] {
        guard positions.count >= 3 else { return positions }
        
        var smoothed: [CGPoint] = []
        let windowSize = 5
        
        for i in 0..<positions.count {
            let start = max(0, i - windowSize / 2)
            let end = min(positions.count, i + windowSize / 2 + 1)
            let window = positions[start..<end]
            
            let avgX = window.map { $0.x }.reduce(0, +) / Double(window.count)
            let avgY = window.map { $0.y }.reduce(0, +) / Double(window.count)
            smoothed.append(CGPoint(x: avgX, y: avgY))
        }
        
        return smoothed
    }
    
    /// Compute velocities using central difference
    private static func computeVelocities(
        positions: [CGPoint],
        timestamps: [Date]
    ) -> [CGPoint] {
        guard positions.count == timestamps.count, positions.count >= 2 else {
            return Array(repeating: CGPoint.zero, count: positions.count)
        }
        
        var velocities: [CGPoint] = []
        
        for i in 0..<positions.count {
            let velocity: CGPoint
            
            if i == 0 {
                // Forward difference at start
                let dt = timestamps[1].timeIntervalSince(timestamps[0])
                guard dt > 0 else {
                    velocities.append(.zero)
                    continue
                }
                let dx = positions[1].x - positions[0].x
                let dy = positions[1].y - positions[0].y
                velocity = CGPoint(x: dx / dt, y: dy / dt)
            } else if i == positions.count - 1 {
                // Backward difference at end
                let dt = timestamps[i].timeIntervalSince(timestamps[i - 1])
                guard dt > 0 else {
                    velocities.append(.zero)
                    continue
                }
                let dx = positions[i].x - positions[i - 1].x
                let dy = positions[i].y - positions[i - 1].y
                velocity = CGPoint(x: dx / dt, y: dy / dt)
            } else {
                // Central difference
                let dt = timestamps[i + 1].timeIntervalSince(timestamps[i - 1])
                guard dt > 0 else {
                    velocities.append(.zero)
                    continue
                }
                let dx = positions[i + 1].x - positions[i - 1].x
                let dy = positions[i + 1].y - positions[i - 1].y
                velocity = CGPoint(x: dx / dt, y: dy / dt)
            }
            
            velocities.append(velocity)
        }
        
        return velocities
    }
}
