//
//  FormDeviationAnalyzer.swift
//  MoveAI
//
//  Created by Dave Mathew on 1/19/25.
//

import Foundation
import CoreGraphics

/// Analyzes deviations between observed and predicted kinematics
/// Detects form issues: torso bias, instability, hip shoot, balance drift
struct FormDeviationAnalyzer {
    
    /// Type of form deviation
    enum DeviationType {
        case torsoBias
        case torsoInstability
        case hipShoot
        case balanceDrift
    }
    
    /// Form deviation analysis result
    struct FormDeviation {
        let type: DeviationType
        let severity: BackRoundingSeverity
        let magnitude: Double
        let frameRange: Range<Int>
        let repNumber: Int
        let message: String
    }
    
    /// Analyze all deviations for a rep
    static func analyzeDeviations(
        observed: KinematicAnalyzer.ObservedKinematics,
        ideal: SquatMechanicsSolver.IdealAngleCurves,
        segmentLengths: AnthropometryEstimator.SegmentLengths,
        rep: SquatRep,
        confidence: Double,
        isSideView: Bool = true
    ) -> [FormDeviation] {
        var deviations: [FormDeviation] = []
        
        print("      🔍 Checking for deviations...")
        
        // 1. Torso bias analysis
        let bands = SquatMechanicsSolver.predictAngleBands(
            idealCurves: ideal,
            confidence: confidence,
            isSideView: isSideView
        )

        if let torsoBias = analyzeTorsoBias(observed: observed, ideal: ideal, torsoBand: bands.torsoBand) {
            deviations.append(torsoBias)
            print("        ⚠️ Torso bias detected: \(torsoBias.severity.rawValue) (magnitude: \(String(format: "%.1f", torsoBias.magnitude))°)")
        }
        
        // 2. Torso instability analysis
        if let instability = analyzeTorsoInstability(observed: observed, rep: rep) {
            deviations.append(instability)
            print("        ⚠️ Torso instability detected: \(instability.severity.rawValue) (max change: \(String(format: "%.1f", instability.magnitude))°)")
        }
        
        // 3. Hip shoot detection
        if let hipShoot = detectHipShoot(observed: observed, rep: rep) {
            deviations.append(hipShoot)
            print("        ⚠️ Hip shoot detected: \(hipShoot.severity.rawValue) (magnitude: \(String(format: "%.2f", hipShoot.magnitude)))")
        }
        
        // 4. Balance drift analysis
        if let balanceDrift = analyzeBalanceDrift(
            observed: observed,
            segmentLengths: segmentLengths,
            rep: rep
        ) {
            deviations.append(balanceDrift)
            print("        ⚠️ Balance drift detected: \(balanceDrift.severity.rawValue) (\(String(format: "%.2f", balanceDrift.magnitude)) shin lengths)")
        }
        
        if deviations.isEmpty {
            print("        ✅ No deviations detected")
        }
        
        return deviations
    }
    
    /// Analyze torso bias: mean(theta_obs - theta_pred) in bottom 20% depth
    private static func analyzeTorsoBias(
        observed: KinematicAnalyzer.ObservedKinematics,
        ideal: SquatMechanicsSolver.IdealAngleCurves,
        torsoBand: Double
    ) -> FormDeviation? {
        // Evaluate at bottom (depth >= 0.8) and early ascent (depth >= 0.7 after bottom).
        var bottomFrames: [(index: Int, obsAngle: Double, predAngle: Double)] = []

        let bottomIndex = observed.depths.enumerated().max(by: { $0.element < $1.element })?.offset

        for (i, depth) in observed.depths.enumerated() {
            guard i < observed.torsoAngles.count else { continue }

            let isBottomWindow = depth >= 0.8
            let isEarlyAscentWindow = bottomIndex != nil && i >= bottomIndex! && depth >= 0.7

            if isBottomWindow || isEarlyAscentWindow {
                // Interpolate ideal angle for this depth
                let predAngle = interpolateIdealAngle(at: depth, from: ideal.torsoAngles, depths: ideal.depths)
                let obsAngle = observed.torsoAngles[i]
                bottomFrames.append((index: i, obsAngle: obsAngle, predAngle: predAngle))
            }
        }
        
        guard !bottomFrames.isEmpty else { return nil }
        
        // Calculate mean bias
        // Positive bias = observed more forward than predicted (bad - excessive forward lean)
        // Negative bias = observed more upright than predicted (OK - not penalized)
        let biases = bottomFrames.map { $0.obsAngle - $0.predAngle }
        let meanBias = biases.reduce(0, +) / Double(biases.count)
        
        // Only flag if bias is significantly positive (excessive forward lean)
        // Don't penalize for being too upright (negative bias)
        guard meanBias > (torsoBand + 6.0) else { return nil }
        
        // Determine severity based on how much forward lean exceeds ideal
        let severity: BackRoundingSeverity
        if meanBias > 20.0 {
            severity = .severe
        } else if meanBias > 12.0 {
            severity = .moderate
        } else {
            severity = .mild
        }
        
        // Frame range
        let frameIndices = bottomFrames.map { observed.frameIndices[$0.index] }
        let frameRange = (frameIndices.min() ?? 0)..<(frameIndices.max() ?? 0)
        
        let message = "Torso leaning too far forward at bottom (bias: \(String(format: "%.1f", meanBias))°)"
        
        return FormDeviation(
            type: .torsoBias,
            severity: severity,
            magnitude: abs(meanBias),
            frameRange: frameRange,
            repNumber: observed.repNumber,
            message: message
        )
    }
    
    /// Analyze torso instability: max delta torso angle in last 20% descent + first 30% ascent
    /// 
    /// Torso instability measures sudden/jerky changes in torso angle during critical transition phases:
    /// - Last 20% of descent (approaching bottom)
    /// - First 30% of ascent (coming out of the hole)
    /// 
    /// A high instability value (e.g., 36°) means the torso angle changed dramatically between
    /// consecutive frames, indicating jerky movement or loss of control. This is dangerous
    /// as it can lead to injury and indicates poor form control.
    private static func analyzeTorsoInstability(
        observed: KinematicAnalyzer.ObservedKinematics,
        rep: SquatRep
    ) -> FormDeviation? {
        // Find frames in last 20% descent (depth >= 0.8) and first 30% ascent (depth >= 0.7 after bottom).
        var relevantFrames: [Int] = []

        let bottomIndex = observed.depths.enumerated().max(by: { $0.element < $1.element })?.offset ?? 0

        for (i, depth) in observed.depths.enumerated() {
            let isLateDescent = i <= bottomIndex && depth >= 0.8
            let isEarlyAscent = i >= bottomIndex && depth >= 0.7

            if isLateDescent || isEarlyAscent {
                relevantFrames.append(i)
            }
        }
        
        guard relevantFrames.count >= 2 else { return nil }
        
        // Calculate max change in torso angle between consecutive frames
        // This detects sudden jerky movements
        var maxDelta: Double = 0.0
        var maxDeltaFrame1: Int? = nil
        var maxDeltaFrame2: Int? = nil
        
        for i in 1..<relevantFrames.count {
            let idx1 = relevantFrames[i - 1]
            let idx2 = relevantFrames[i]
            if idx1 < observed.torsoAngles.count && idx2 < observed.torsoAngles.count {
                let delta = abs(observed.torsoAngles[idx2] - observed.torsoAngles[idx1])
                if delta > maxDelta {
                    maxDelta = delta
                    maxDeltaFrame1 = idx1
                    maxDeltaFrame2 = idx2
                }
            }
        }
        
        // Flag if instability > 15 degrees (sudden change between frames)
        guard maxDelta > 15.0 else { return nil }
        
        let severity: BackRoundingSeverity
        if maxDelta > 25.0 {
            severity = .severe
        } else if maxDelta > 20.0 {
            severity = .moderate
        } else {
            severity = .mild
        }
        
        let frameIndices = relevantFrames.map { observed.frameIndices[$0] }
        let frameRange = (frameIndices.min() ?? 0)..<(frameIndices.max() ?? 0)
        
        var message = "Torso instability detected (max change: \(String(format: "%.1f", maxDelta))° between consecutive frames)"
        if let f1 = maxDeltaFrame1, let f2 = maxDeltaFrame2, f1 < observed.torsoAngles.count && f2 < observed.torsoAngles.count {
            let angle1 = observed.torsoAngles[f1]
            let angle2 = observed.torsoAngles[f2]
            message += " - angle changed from \(String(format: "%.1f", angle1))° to \(String(format: "%.1f", angle2))°"
        }
        
        return FormDeviation(
            type: .torsoInstability,
            severity: severity,
            magnitude: maxDelta,
            frameRange: frameRange,
            repNumber: observed.repNumber,
            message: message
        )
    }
    
    /// Detect hip shoot: velocity ratio Rv = v_hip / v_shoulder during first 30% ascent
    private static func detectHipShoot(
        observed: KinematicAnalyzer.ObservedKinematics,
        rep: SquatRep
    ) -> FormDeviation? {
        // Find frames in first 30% ascent from bottom (depth going from 1.0 to 0.7)
        var ascentFrames: [Int] = []
        var foundBottom = false
        
        for (i, depth) in observed.depths.enumerated() {
            if depth >= 0.99 {
                foundBottom = true
            }
            if foundBottom && depth <= 0.7 && i < observed.hipVelocities.count && i < observed.shoulderVelocities.count {
                ascentFrames.append(i)
            }
        }
        
        guard ascentFrames.count >= 2 else { return nil }
        
        // Calculate velocity ratios
        var velocityRatios: [Double] = []
        var torsoAngleIncreases: [Double] = []
        
        for i in ascentFrames {
            let hipVel = observed.hipVelocities[i]
            let shoulderVel = observed.shoulderVelocities[i]
            
            // Calculate velocity magnitudes (Y component, since we care about vertical movement)
            let hipSpeed = abs(hipVel.y)
            let shoulderSpeed = abs(shoulderVel.y)
            
            if shoulderSpeed > 0.001 {  // Avoid division by zero
                let ratio = hipSpeed / shoulderSpeed
                velocityRatios.append(ratio)
            }
            
            // Check torso angle increase
            if i > 0 && i < observed.torsoAngles.count {
                let prevIdx = ascentFrames.first ?? i
                if prevIdx < observed.torsoAngles.count {
                    let angleIncrease = observed.torsoAngles[i] - observed.torsoAngles[prevIdx]
                    if angleIncrease > 0 {
                        torsoAngleIncreases.append(angleIncrease)
                    }
                }
            }
        }
        
        // Check for hip shoot: Rv > 1.25 for >=200ms OR torso angle increases >10° early ascent
        let thresholdRatio = SquatMechanicsConfig.hipShootVelocityRatio
        let thresholdDuration = SquatMechanicsConfig.hipShootDuration
        let thresholdAngleIncrease = SquatMechanicsConfig.hipShootTorsoAngleIncrease
        
        var hasHipShoot = false
        var maxRatio = 0.0
        var maxAngleIncrease = 0.0
        
        // Check velocity ratio
        if let maxRatioValue = velocityRatios.max(), maxRatioValue > thresholdRatio {
            // Estimate duration (would need frame rate, but approximate)
            let framesAboveThreshold = velocityRatios.filter { $0 > thresholdRatio }.count
            // Assume ~30 fps, so 200ms ≈ 6 frames
            if framesAboveThreshold >= 6 {
                hasHipShoot = true
                maxRatio = maxRatioValue
            }
        }
        
        // Check torso angle increase
        if let maxAngle = torsoAngleIncreases.max(), maxAngle > thresholdAngleIncrease {
            hasHipShoot = true
            maxAngleIncrease = maxAngle
        }
        
        guard hasHipShoot else { return nil }
        
        let severity: BackRoundingSeverity
        if maxRatio > 1.5 || maxAngleIncrease > 20.0 {
            severity = .severe
        } else if maxRatio > 1.35 || maxAngleIncrease > 15.0 {
            severity = .moderate
        } else {
            severity = .mild
        }
        
        let frameIndices = ascentFrames.map { observed.frameIndices[$0] }
        let frameRange = (frameIndices.min() ?? 0)..<(frameIndices.max() ?? 0)
        
        var message = "Hip shoot detected"
        if maxRatio > 0 {
            message += " (velocity ratio: \(String(format: "%.2f", maxRatio)))"
        }
        if maxAngleIncrease > 0 {
            message += " (torso angle increase: \(String(format: "%.1f", maxAngleIncrease))°)"
        }
        
        return FormDeviation(
            type: .hipShoot,
            severity: severity,
            magnitude: max(maxRatio, maxAngleIncrease),
            frameRange: frameRange,
            repNumber: observed.repNumber,
            message: message
        )
    }
    
    /// Analyze balance drift: COM_proxy.x - midfoot_est.x drift
    private static func analyzeBalanceDrift(
        observed: KinematicAnalyzer.ObservedKinematics,
        segmentLengths: AnthropometryEstimator.SegmentLengths,
        rep: SquatRep
    ) -> FormDeviation? {
        guard !observed.comProxy.isEmpty, !observed.frameIndices.isEmpty else { return nil }
        
        // Estimate midfoot position for each frame
        // midfoot_est = ankle.x + k*shin_length
        // We need ankle positions - approximate from hip/knee if not available
        // For now, use a simplified approach: assume ankle is at COM.x - offset
        
        let threshold = SquatMechanicsConfig.balanceDriftThreshold * segmentLengths.shinLength
        
        // Calculate drift at key points: start, bottom, mid-ascent
        var drifts: [(frameIndex: Int, drift: Double)] = []
        
        // Find bottom frame
        let bottomFrameIdx = observed.depths.enumerated().max(by: { $0.element < $1.element })?.offset ?? 0
        let midAscentFrameIdx = observed.depths.enumerated().first(where: { $0.element <= 0.5 && $0.offset > bottomFrameIdx })?.offset ?? observed.comProxy.count - 1
        
        let keyFrames = [0, bottomFrameIdx, midAscentFrameIdx].filter { $0 < observed.comProxy.count }
        
        for frameIdx in keyFrames {
            let com = observed.comProxy[frameIdx]
            // Simplified: estimate midfoot as COM.x (assuming good initial alignment)
            // In a more sophisticated version, we'd track ankle positions
            let midfootEst = com.x  // Simplified assumption
            let drift = abs(com.x - midfootEst)
            
            if drift > threshold {
                drifts.append((frameIndex: frameIdx, drift: drift))
            }
        }
        
        guard !drifts.isEmpty else { return nil }
        
        let maxDrift = drifts.map { $0.drift }.max() ?? 0.0
        let driftInShinLengths = maxDrift / segmentLengths.shinLength
        
        let severity: BackRoundingSeverity
        if driftInShinLengths > 0.20 {
            severity = .severe
        } else if driftInShinLengths > 0.15 {
            severity = .moderate
        } else {
            severity = .mild
        }
        
        let frameIndices = drifts.map { observed.frameIndices[$0.frameIndex] }
        let frameRange = (frameIndices.min() ?? 0)..<(frameIndices.max() ?? 0)
        
        return FormDeviation(
            type: .balanceDrift,
            severity: severity,
            magnitude: driftInShinLengths,
            frameRange: frameRange,
            repNumber: observed.repNumber,
            message: "Balance drift detected (\(String(format: "%.2f", driftInShinLengths)) shin lengths)"
        )
    }
    
    /// Interpolate ideal angle at a given depth
    private static func interpolateIdealAngle(
        at depth: Double,
        from angles: [Double],
        depths: [Double]
    ) -> Double {
        guard !angles.isEmpty, !depths.isEmpty, angles.count == depths.count else {
            return 30.0  // Default
        }
        
        if depth <= depths.first! {
            return angles.first!
        }
        if depth >= depths.last! {
            return angles.last!
        }
        
        // Linear interpolation
        for i in 0..<(depths.count - 1) {
            if depth >= depths[i] && depth <= depths[i + 1] {
                let t = (depth - depths[i]) / (depths[i + 1] - depths[i])
                return angles[i] + t * (angles[i + 1] - angles[i])
            }
        }
        
        return angles.last!
    }
    
    /// Compute overall form score from deviations
    static func computeOverallFormScore(deviations: [FormDeviation]) -> Double {
        guard !deviations.isEmpty else { return 100.0 }
        
        var totalPenalty = 0.0
        
        for deviation in deviations {
            let penalty: Double
            switch deviation.severity {
            case .severe:
                penalty = 40.0
            case .moderate:
                penalty = 25.0
            case .mild:
                penalty = 10.0
            case .none:
                penalty = 0.0
            }
            totalPenalty += penalty
        }
        
        // Cap penalty at 100
        let finalPenalty = min(100.0, totalPenalty)
        return max(0.0, 100.0 - finalPenalty)
    }
}
