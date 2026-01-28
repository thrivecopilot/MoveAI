//
//  SquatMechanicsSolver.swift
//  MoveAI
//
//  Created by Dave Mathew on 1/19/25.
//

import Foundation
import CoreGraphics

/// Geometric solver for predicting ideal squat mechanics based on anthropometry
/// Uses balance constraints and biomechanical principles to predict optimal angles
struct SquatMechanicsSolver {
    
    /// Ideal angle curves across depth
    struct IdealAngleCurves {
        let torsoAngles: [Double]  // alpha(d) for each depth step
        let shinAngles: [Double]   // beta(d) for each depth step
        let depths: [Double]       // Corresponding depth values [0,1]
    }
    
    /// 2D stick figure representation
    struct StickFigure {
        let ankle: CGPoint
        let knee: CGPoint
        let hip: CGPoint
        let shoulder: CGPoint
        let comProxy: CGPoint
        let midfootEst: CGPoint
    }
    
    /// Solve ideal angles for a rep given segment lengths and depth range
    /// Uses rep boundaries to determine depth range
    static func solveIdealAngles(
        segmentLengths: AnthropometryEstimator.SegmentLengths,
        repStartHeight: Double,
        repBottomHeight: Double,
        depthSteps: [Double]? = nil
    ) -> IdealAngleCurves {
        // Generate depth steps if not provided
        let steps = depthSteps ?? generateDepthSteps()
        
        print("    🎯 Solving for \(steps.count) depth steps (range: \(String(format: "%.2f", steps.first ?? 0)) to \(String(format: "%.2f", steps.last ?? 1)))")
        print("    📐 Rep height range: start=\(String(format: "%.4f", repStartHeight)), bottom=\(String(format: "%.4f", repBottomHeight))")
        print("    📐 Height difference: \(String(format: "%.4f", repBottomHeight - repStartHeight))")
        
        var torsoAngles: [Double] = []
        var shinAngles: [Double] = []
        
        var previousTorsoAngle: Double? = nil
        var previousShinAngle: Double? = nil
        
        var solvedCount = 0
        for depth in steps {
            // Grid search for optimal angles (now works in normalized depth [0,1] space)
            let (bestTorso, bestShin) = gridSearchOptimalAngles(
                depth: depth,
                segmentLengths: segmentLengths,
                previousTorso: previousTorsoAngle,
                previousShin: previousShinAngle
            )
            
            torsoAngles.append(bestTorso)
            shinAngles.append(bestShin)
            
            previousTorsoAngle = bestTorso
            previousShinAngle = bestShin
            
            // Debug: Verify depth constraint and show how angles vary
            if let testStick = buildStickFigure(
                torsoAngle: bestTorso,
                shinAngle: bestShin,
                segmentLengths: segmentLengths,
                depth: depth
            ),
            let stickAtDepth0 = buildStickFigure(
                torsoAngle: bestTorso,
                shinAngle: bestShin,
                segmentLengths: segmentLengths,
                depth: 0.0
            ),
            let stickAtDepth1 = buildStickFigure(
                torsoAngle: bestTorso,
                shinAngle: bestShin,
                segmentLengths: segmentLengths,
                depth: 1.0
            ) {
                let actualHipY = testStick.hip.y
                let depth0HipY = stickAtDepth0.hip.y
                let depth1HipY = stickAtDepth1.hip.y
                let depthRange = depth1HipY - depth0HipY
                
                // Calculate normalized depth error
                let normalizedDepth = abs(depthRange) > 1e-6 ? (actualHipY - depth0HipY) / depthRange : 0.0
                let depthError = abs(normalizedDepth - depth)
                let balanceErr = calculateBalanceError(testStick)
                
                solvedCount += 1
                if solvedCount % 5 == 0 || depth == steps.first || depth == steps.last {
                    print("      ✓ Solved depth \(String(format: "%.2f", depth)): torso=\(String(format: "%.1f", bestTorso))°, shin=\(String(format: "%.1f", bestShin))°")
                    print("         normalized_depth: target=\(String(format: "%.4f", depth)), actual=\(String(format: "%.4f", normalizedDepth)), error=\(String(format: "%.4f", depthError))")
                    print("         hip.y: actual=\(String(format: "%.4f", actualHipY)), range=[\(String(format: "%.4f", depth0HipY)), \(String(format: "%.4f", depth1HipY))]")
                    print("         knee.y=\(String(format: "%.4f", testStick.knee.y)), balance_error=\(String(format: "%.4f", balanceErr))")
                }
            } else {
                solvedCount += 1
                if solvedCount % 5 == 0 || depth == steps.first || depth == steps.last {
                    print("      ⚠️ Solved depth \(String(format: "%.2f", depth)): torso=\(String(format: "%.1f", bestTorso))°, shin=\(String(format: "%.1f", bestShin))° (could not build stick figure)")
                }
            }
        }
        
        return IdealAngleCurves(
            torsoAngles: torsoAngles,
            shinAngles: shinAngles,
            depths: steps
        )
    }
    
    /// Build 2D stick figure from angles and segment lengths
    /// Now determines femur angle from depth instead of forcing hip Y to target
    static func buildStickFigure(
        torsoAngle: Double,
        shinAngle: Double,
        segmentLengths: AnthropometryEstimator.SegmentLengths,
        depth: Double  // Normalized depth [0,1] - used to determine femur angle
    ) -> StickFigure? {
        // Ankle at origin (0, 0) - reference point
        // IMPORTANT: We're using Vision coordinate system where Y increases downward
        // So ankle at (0, 0) means ankle is at the top of the coordinate space
        // As we go down, Y increases
        let ankle = CGPoint(x: 0, y: 0)
        
        // Convert angles from degrees to radians
        // Angles are measured from vertical (0° = vertical, positive = forward lean)
        let shinAngleRad = shinAngle * .pi / 180.0
        let torsoAngleRad = torsoAngle * .pi / 180.0
        
        // Calculate knee position from shin angle and length
        // In normalized coordinates, shin length = 1.0
        // Shin angle: 0° = vertical (straight down), positive = forward (knee moves forward and down)
        // In Vision coordinates (Y increases downward):
        //   kneeX = sin(angle) * length (forward = positive X)
        //   kneeY = cos(angle) * length (downward = positive Y)
        let kneeX = sin(shinAngleRad) * segmentLengths.shinLength
        let kneeY = cos(shinAngleRad) * segmentLengths.shinLength  // Positive Y = downward
        let knee = CGPoint(x: kneeX, y: kneeY)
        
        // Calculate femur angle from depth
        // At depth=0 (standing): femur nearly vertical (~5° backward from vertical)
        // At depth=1 (bottom): femur more horizontal (~45° backward from vertical)
        // Interpolate: femurAngle = 5° + depth * 40° (backward from vertical)
        // Note: Negative angle means backward (hip behind knee)
        let femurAngleDegrees = 5.0 + depth * 40.0
        let femurAngleRad = -femurAngleDegrees * .pi / 180.0  // Negative = backward
        
        // Calculate hip position from knee using femur angle and length
        let femurLength = segmentLengths.femurLength
        // Femur extends backward from knee (negative X direction in typical squat)
        // In Vision coordinates (Y increases downward):
        //   hipX = kneeX + sin(femurAngle) * femurLength
        //   hipY = kneeY + cos(femurAngle) * femurLength
        // Since femurAngle is negative (backward), sin is negative, so hipX < kneeX
        let hipX = kneeX + sin(femurAngleRad) * femurLength
        let hipY = kneeY + cos(femurAngleRad) * femurLength
        let hip = CGPoint(x: hipX, y: hipY)
        
        // Calculate shoulder position from hip using torso angle
        let shoulderX = hipX + sin(torsoAngleRad) * segmentLengths.torsoLength
        let shoulderY = hipY - cos(torsoAngleRad) * segmentLengths.torsoLength  // Torso goes up (negative Y)
        let shoulder = CGPoint(x: shoulderX, y: shoulderY)
        
        // Calculate COM proxy
        let comX = SquatMechanicsConfig.comHipWeight * hipX + SquatMechanicsConfig.comShoulderWeight * shoulderX
        let comY = SquatMechanicsConfig.comHipWeight * hipY + SquatMechanicsConfig.comShoulderWeight * shoulderY
        let comProxy = CGPoint(x: comX, y: comY)
        
        // Estimate midfoot position
        let midfootX = ankle.x + SquatMechanicsConfig.midfootOffsetK * segmentLengths.shinLength
        let midfootEst = CGPoint(x: midfootX, y: ankle.y)
        
        return StickFigure(
            ankle: ankle,
            knee: knee,
            hip: hip,
            shoulder: shoulder,
            comProxy: comProxy,
            midfootEst: midfootEst
        )
    }
    
    /// Calculate balance error (distance from COM to midfoot)
    static func calculateBalanceError(_ stickFigure: StickFigure) -> Double {
        let errorX = stickFigure.comProxy.x - stickFigure.midfootEst.x
        return abs(errorX)
    }
    
    /// Calculate minimum shin angle based on depth and anthropometry
    /// Depth-dependent: more depth requires more knee travel (higher shin angle)
    /// Anthropometry-aware: longer femurs require more shin angle to maintain balance
    private static func calculateMinimumShinAngle(
        depth: Double,
        segmentLengths: AnthropometryEstimator.SegmentLengths
    ) -> Double {
        // Base minimum scales with depth: 5° at top, 20° at bottom (relaxed from 25°)
        var minShinAngle = 5.0 + depth * 15.0
        
        // Adjust based on femur/shin ratio
        // Long femurs (ratio > 1.1): require more shin angle to maintain balance
        // Short femurs (ratio < 0.9): can tolerate less shin angle
        let adjustmentFactor = 1.0 + 0.2 * (segmentLengths.femurShinRatio - 1.0)
        minShinAngle *= adjustmentFactor
        
        // At depth 0, allow 0-5° (standing can be vertical)
        if depth <= 0.01 {
            return 0.0
        }
        
        return minShinAngle
    }
    
    /// Calculate minimum torso angle based on anthropometry
    /// Shorter torso relative to femur requires more forward lean (higher torso angle) to maintain balance
    private static func calculateMinimumTorsoAngle(
        depth: Double,
        segmentLengths: AnthropometryEstimator.SegmentLengths
    ) -> Double {
        // Base minimum: 12° for proportional torso/femur ratio (1.0) - relaxed from 15°
        // Formula: expectedMinTorsoAngle = 12.0 + (1.0 - torsofemurRatio) * 15.0
        // - If torsofemurRatio = 0.8 (short torso): 12.0 + 0.2 * 15.0 = 15.0°
        // - If torsofemurRatio = 1.0 (proportional): 12.0°
        // - If torsofemurRatio = 1.2 (long torso): 12.0 - 0.2 * 15.0 = 9.0°
        let baseMinTorso = 12.0 + (1.0 - segmentLengths.torsofemurRatio) * 15.0
        
        // At depth 0 (standing), allow more upright (reduce minimum by 5°)
        // At depth 1 (bottom), require the full minimum
        let depthAdjustment = (1.0 - depth) * 5.0
        
        return baseMinTorso - depthAdjustment
    }
    
    /// Grid search for optimal angles at a given depth
    /// Now works in normalized depth [0,1] space instead of absolute Y coordinates
    private static func gridSearchOptimalAngles(
        depth: Double,  // Normalized depth [0,1] - target depth we're solving for
        segmentLengths: AnthropometryEstimator.SegmentLengths,
        previousTorso: Double?,
        previousShin: Double?
    ) -> (torso: Double, shin: Double) {
        let stepSize = SquatMechanicsConfig.angleStepSize
        let torsoRange = SquatMechanicsConfig.torsoAngleRange
        let shinRange = SquatMechanicsConfig.shinAngleRange
        
        // Calculate anthropometry-based minimums
        let minShinAngle = calculateMinimumShinAngle(depth: depth, segmentLengths: segmentLengths)
        let minTorsoAngle = calculateMinimumTorsoAngle(depth: depth, segmentLengths: segmentLengths)
        
        var bestCost = Double.infinity
        var bestTorso: Double = torsoRange.lowerBound
        var bestShin: Double = shinRange.lowerBound
        var foundValidSolution = false
        
        // Grid search
        var torso = torsoRange.lowerBound
        while torso <= torsoRange.upperBound {
            var shin = shinRange.lowerBound
            while shin <= shinRange.upperBound {
                // EARLY REJECTION: Check minimum shin angle BEFORE building stick figures
                // This prevents wasting computation on invalid solutions
                if depth > 0.01 && shin < minShinAngle {
                    shin += stepSize
                    continue
                }
                
                // Build stick figure at current depth using these angles
                guard let stickFigure = buildStickFigure(
                    torsoAngle: torso,
                    shinAngle: shin,
                    segmentLengths: segmentLengths,
                    depth: depth
                ) else {
                    shin += stepSize
                    continue
                }
                
                // Calculate reference stick figures at depth=0 and depth=1 using the same angles
                // This establishes the depth range for this angle configuration
                guard let stickAtDepth0 = buildStickFigure(
                    torsoAngle: torso,
                    shinAngle: shin,
                    segmentLengths: segmentLengths,
                    depth: 0.0
                ),
                let stickAtDepth1 = buildStickFigure(
                    torsoAngle: torso,
                    shinAngle: shin,
                    segmentLengths: segmentLengths,
                    depth: 1.0
                ) else {
                    shin += stepSize
                    continue
                }
                
                // Calculate normalized depth from stick figure's hip.y
                // Normalize relative to the depth range (depth=0 to depth=1) for these angles
                let depth0HipY = stickAtDepth0.hip.y
                let depth1HipY = stickAtDepth1.hip.y
                let depthRange = depth1HipY - depth0HipY
                
                guard abs(depthRange) > 1e-6 else {
                    // Invalid depth range (shouldn't happen, but guard against division by zero)
                    shin += stepSize
                    continue
                }
                
                // Normalize current hip.y to [0,1] depth space
                let normalizedDepth = (stickFigure.hip.y - depth0HipY) / depthRange
                
                // CRITICAL: Depth constraint penalty - compare normalized depths
                // This works in [0,1] space and is independent of coordinate system
                let depthError = abs(normalizedDepth - depth)
                
                // Hard constraint: skip solutions with large depth errors
                // This ensures we only consider angle combinations that can achieve the target depth
                if depthError > SquatMechanicsConfig.hardConstraintTolerance {
                    shin += stepSize
                    continue
                }
                
                // Mark that we found at least one valid solution
                foundValidSolution = true
                
                // Calculate cost
                let balanceError = calculateBalanceError(stickFigure)
                let balanceCost = SquatMechanicsConfig.balanceWeight * balanceError * balanceError
                
                // Use linear penalty instead of squared for more proportional cost
                let depthCost = SquatMechanicsConfig.depthConstraintWeight * depthError
                
                // ROM penalty (penalize extreme angles)
                let romPenalty = calculateROMPenalty(torso: torso, shin: shin)
                let romCost = SquatMechanicsConfig.romWeight * romPenalty
                
                // Biomechanical penalty: penalize unrealistic angles
                var biomechanicalPenalty = 0.0
                
                // Penalize shin angles below depth-appropriate minimum
                if depth > 0.01 && shin < minShinAngle {
                    let shinDeficit = minShinAngle - shin
                    biomechanicalPenalty += shinDeficit * SquatMechanicsConfig.shinAngleDeficitPenaltyWeight
                }
                
                // Penalize torso angles below anthropometry-based minimum
                if torso < minTorsoAngle {
                    let torsoDeficit = minTorsoAngle - torso
                    biomechanicalPenalty += torsoDeficit * SquatMechanicsConfig.torsoUprightPenaltyWeight
                }
                
                // Penalize torso angles that decrease significantly with depth (should generally increase)
                if let prevTorso = previousTorso, depth > 0.1 {
                    let torsoDecrease = max(0.0, prevTorso - torso)  // Only penalize decreases
                    if torsoDecrease > 5.0 {
                        // Penalize significant torso angle decreases (>5°)
                        biomechanicalPenalty += torsoDecrease * SquatMechanicsConfig.torsoDecreasePenaltyWeight
                    }
                }
                
                let biomechanicalCost = SquatMechanicsConfig.biomechanicalWeight * biomechanicalPenalty
                
                // Smoothness penalty (if we have previous angles)
                var smoothnessCost = 0.0
                if let prevTorso = previousTorso, let prevShin = previousShin {
                    let torsoDiff = torso - prevTorso
                    let shinDiff = shin - prevShin
                    smoothnessCost = SquatMechanicsConfig.smoothnessWeight * (torsoDiff * torsoDiff + shinDiff * shinDiff)
                }
                
                let totalCost = balanceCost + depthCost + romCost + biomechanicalCost + smoothnessCost
                
                if totalCost < bestCost {
                    bestCost = totalCost
                    bestTorso = torso
                    bestShin = shin
                }
                
                shin += stepSize
            }
            torso += stepSize
        }
        
        // Fallback: If no valid solutions found, use anthropometry-based heuristics
        if !foundValidSolution {
            print("      ⚠️ No valid solutions found for depth \(String(format: "%.2f", depth)), using fallback heuristics")
            
            // Fallback heuristic based on anthropometry
            // Longer femurs → more torso lean and shin angle needed
            // Shorter torso relative to femur → more torso lean needed
            let femurShinRatio = segmentLengths.femurShinRatio
            let torsofemurRatio = segmentLengths.torsofemurRatio
            
            // Estimate reasonable angles based on anthropometry
            // Base angles that scale with depth
            let baseTorso = 15.0 + depth * 30.0  // 15° at top, 45° at bottom
            let baseShin = 5.0 + depth * 25.0   // 5° at top, 30° at bottom
            
            // Adjust for anthropometry
            let torsoAdjustment = (1.0 - torsofemurRatio) * 15.0  // Shorter torso → more lean
            let shinAdjustment = (femurShinRatio - 1.0) * 10.0      // Longer femurs → more shin angle
            
            let fallbackTorso = max(torsoRange.lowerBound, min(torsoRange.upperBound, baseTorso + torsoAdjustment))
            let fallbackShin = max(shinRange.lowerBound, min(shinRange.upperBound, baseShin + shinAdjustment))
            
            return (fallbackTorso, fallbackShin)
        }
        
        return (bestTorso, bestShin)
    }
    
    /// Calculate ROM penalty for extreme angles
    private static func calculateROMPenalty(torso: Double, shin: Double) -> Double {
        var penalty = 0.0
        
        // Penalize torso angles near extremes
        let torsoRange = SquatMechanicsConfig.torsoAngleRange
        let torsoMid = (torsoRange.lowerBound + torsoRange.upperBound) / 2.0
        let torsoDeviation = abs(torso - torsoMid) / (torsoRange.upperBound - torsoRange.lowerBound) * 2.0
        if torsoDeviation > 0.8 {
            penalty += (torsoDeviation - 0.8) * 10.0
        }
        
        // Penalize shin angles near extremes
        let shinRange = SquatMechanicsConfig.shinAngleRange
        let shinMid = (shinRange.lowerBound + shinRange.upperBound) / 2.0
        let shinDeviation = abs(shin - shinMid) / (shinRange.upperBound - shinRange.lowerBound) * 2.0
        if shinDeviation > 0.8 {
            penalty += (shinDeviation - 0.8) * 10.0
        }
        
        return penalty
    }
    
    /// Generate depth steps from 0 to 1
    private static func generateDepthSteps() -> [Double] {
        let stepSize = SquatMechanicsConfig.depthStepSize
        var steps: [Double] = []
        var depth = 0.0
        while depth <= 1.0 {
            steps.append(depth)
            depth += stepSize
        }
        // Ensure we end at exactly 1.0
        if steps.last != 1.0 {
            steps.append(1.0)
        }
        return steps
    }
    
    /// Predict angle bands with tolerance based on confidence and camera angle
    static func predictAngleBands(
        idealCurves: IdealAngleCurves,
        confidence: Double,
        isSideView: Bool = true
    ) -> (torsoBand: Double, shinBand: Double) {
        // Base tolerance
        var torsoBand = 5.0  // ±5 degrees
        var shinBand = 3.0   // ±3 degrees
        
        // Widen bands if confidence is low
        if confidence < Double(SquatMechanicsConfig.lowConfidenceThreshold) {
            torsoBand *= 1.5
            shinBand *= 1.5
        }
        
        // Widen bands if camera isn't side-on (less reliable measurements)
        if !isSideView {
            torsoBand *= 1.2
            shinBand *= 1.2
        }
        
        return (torsoBand, shinBand)
    }
    
    // MARK: - Synthetic Data Generator (for testing)
    
    /// Generate synthetic squat pose data with known angles and noise
    /// Useful for validating the solver and testing deviation detection
    static func generateSyntheticSquat(
        segmentLengths: AnthropometryEstimator.SegmentLengths,
        idealCurves: IdealAngleCurves,
        repStartHeight: Double,
        repBottomHeight: Double,
        frameCount: Int = 100,
        noiseLevel: Double = 0.02
    ) -> [PoseDetectionResult] {
        var poses: [PoseDetectionResult] = []
        
        // Generate frames from start to bottom
        for i in 0..<frameCount {
            let progress = Double(i) / Double(frameCount - 1)  // 0.0 to 1.0
            let depth = progress  // Linear depth progression
            
            // Interpolate ideal angles for this depth
            let (torsoAngle, shinAngle) = interpolateAngles(at: depth, from: idealCurves)
            
            // Add noise
            let noisyTorso = torsoAngle + (Double.random(in: -1...1) * noiseLevel * 180.0)
            let noisyShin = shinAngle + (Double.random(in: -1...1) * noiseLevel * 180.0)
            
            // Build stick figure using depth to determine femur angle
            guard let stickFigure = buildStickFigure(
                torsoAngle: noisyTorso,
                shinAngle: noisyShin,
                segmentLengths: segmentLengths,
                depth: depth
            ) else {
                continue
            }
            
            // Create keypoints from stick figure
            var keypoints: [PoseKeypoint] = []
            
            // Ankle
            keypoints.append(PoseKeypoint(
                name: "leftAnkle",
                position: stickFigure.ankle,
                confidence: 0.9
            ))
            
            // Knee
            keypoints.append(PoseKeypoint(
                name: "leftKnee",
                position: stickFigure.knee,
                confidence: 0.9
            ))
            
            // Hip
            keypoints.append(PoseKeypoint(
                name: "leftHip",
                position: stickFigure.hip,
                confidence: 0.9
            ))
            
            // Shoulder
            keypoints.append(PoseKeypoint(
                name: "leftShoulder",
                position: stickFigure.shoulder,
                confidence: 0.9
            ))
            
            // Create pose result
            let pose = PoseDetectionResult(
                keypoints: keypoints,
                frameIndex: i
            )
            poses.append(pose)
        }
        
        return poses
    }
    
    /// Interpolate angles from ideal curves at a given depth
    private static func interpolateAngles(
        at depth: Double,
        from curves: IdealAngleCurves
    ) -> (torso: Double, shin: Double) {
        let depths = curves.depths
        let torsoAngles = curves.torsoAngles
        let shinAngles = curves.shinAngles
        
        guard !depths.isEmpty, depths.count == torsoAngles.count, depths.count == shinAngles.count else {
            return (30.0, 20.0)  // Default angles
        }
        
        // Find surrounding depth indices
        if depth <= depths.first! {
            return (torsoAngles.first!, shinAngles.first!)
        }
        if depth >= depths.last! {
            return (torsoAngles.last!, shinAngles.last!)
        }
        
        // Linear interpolation
        for i in 0..<(depths.count - 1) {
            if depth >= depths[i] && depth <= depths[i + 1] {
                let t = (depth - depths[i]) / (depths[i + 1] - depths[i])
                let torso = torsoAngles[i] + t * (torsoAngles[i + 1] - torsoAngles[i])
                let shin = shinAngles[i] + t * (shinAngles[i + 1] - shinAngles[i])
                return (torso, shin)
            }
        }
        
        return (torsoAngles.last!, shinAngles.last!)
    }
}
