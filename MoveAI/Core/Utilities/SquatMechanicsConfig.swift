//
//  SquatMechanicsConfig.swift
//  MoveAI
//
//  Created by Dave Mathew on 1/19/25.
//

import Foundation

/// Configuration parameters for squat mechanics solver and analysis
struct SquatMechanicsConfig {
    // Midfoot estimation
    static let midfootOffsetK: Double = 0.14  // midfoot = ankle.x + k*shin_len
    
    // Angle ranges for solver
    static let torsoAngleRange: ClosedRange<Double> = 10...70  // degrees from vertical
    static let shinAngleRange: ClosedRange<Double> = 0...45   // degrees from vertical
    
    // Optimization weights
    static let balanceWeight: Double = 1.0
    static let romWeight: Double = 0.5
    static let smoothnessWeight: Double = 0.3
    static let depthConstraintWeight: Double = 1000.0  // Strong penalty for missing target depth (dramatically increased to force angle variation)
    static let biomechanicalWeight: Double = 50.0  // Weight for biomechanical validity penalties (unrealistic angles) - increased to strongly penalize invalid solutions
    static let torsoDecreasePenaltyWeight: Double = 10.0  // Weight per degree for torso angle decreases
    static let shinAngleDeficitPenaltyWeight: Double = 50.0  // Weight per degree for shin angles below minimum
    static let torsoUprightPenaltyWeight: Double = 15.0  // Weight per degree for torso angles below anthropometry-based minimum
    
    // Hip shoot detection
    static let hipShootVelocityRatio: Double = 1.25
    static let hipShootDuration: TimeInterval = 0.2  // 200ms
    static let hipShootTorsoAngleIncrease: Double = 10.0  // degrees
    
    // Balance drift threshold
    static let balanceDriftThreshold: Double = 0.12   // shin lengths
    
    // Confidence thresholds
    static let lowConfidenceThreshold: Float = 0.5
    
    // Solver parameters
    static let depthStepSize: Double = 0.05  // 5% depth increments
    static let angleStepSize: Double = 2.0   // 2 degree steps for grid search
    
    // Biomechanical constraints
    static let minimumShinAngleAtDepth: Double = 5.0  // Minimum shin angle (degrees) at depth > 0 (prevents unrealistic vertical shin)
    static let hardConstraintTolerance: Double = 0.1   // Hard constraint tolerance for depth error (stricter value to encourage fallback heuristic usage)
    
    // COM proxy weights
    static let comHipWeight: Double = 0.55
    static let comShoulderWeight: Double = 0.45
}
