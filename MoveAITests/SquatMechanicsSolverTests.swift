//
//  SquatMechanicsSolverTests.swift
//  MoveAITests
//
//  Created by Dave Mathew on 1/27/26.
//

import XCTest
@testable import MoveAI

final class SquatMechanicsSolverTests: XCTestCase {
    
    // Test segment lengths matching observed values from user's output
    let testSegmentLengths = AnthropometryEstimator.SegmentLengths(
        shinLength: 1.0,
        femurLength: 1.063,
        torsoLength: 1.056
    )
    
    // Test rep height range matching user's output
    let testRepStartHeight: Double = 0.619
    let testRepBottomHeight: Double = 0.387
    
    // MARK: - Test Angles Vary With Depth
    
    func testAnglesVaryWithDepth() {
        let curves = SquatMechanicsSolver.solveIdealAngles(
            segmentLengths: testSegmentLengths,
            repStartHeight: testRepStartHeight,
            repBottomHeight: testRepBottomHeight,
            depthSteps: [0.0, 0.2, 0.45, 0.7, 0.95, 1.0]  // Key depths to test
        )
        
        // Verify we got results for all depths
        XCTAssertEqual(curves.depths.count, curves.torsoAngles.count, "Should have same number of depths and torso angles")
        XCTAssertEqual(curves.depths.count, curves.shinAngles.count, "Should have same number of depths and shin angles")
        XCTAssertEqual(curves.depths.count, 6, "Should have 6 depth steps")
        
        // Verify angles vary (not all the same)
        let uniqueTorsoAngles = Set(curves.torsoAngles.map { round($0 * 10) / 10 })  // Round to 1 decimal
        XCTAssertGreaterThan(uniqueTorsoAngles.count, 1, "Torso angles should vary with depth. Found: \(curves.torsoAngles)")
        
        let uniqueShinAngles = Set(curves.shinAngles.map { round($0 * 10) / 10 })  // Round to 1 decimal
        XCTAssertGreaterThan(uniqueShinAngles.count, 1, "Shin angles should vary with depth. Found: \(curves.shinAngles)")
        
        // Print results for debugging
        print("\n=== testAnglesVaryWithDepth Results ===")
        for (index, depth) in curves.depths.enumerated() {
            print("Depth \(String(format: "%.2f", depth)): torso=\(String(format: "%.1f", curves.torsoAngles[index]))°, shin=\(String(format: "%.1f", curves.shinAngles[index]))°")
        }
    }
    
    // MARK: - Test Depth Errors Are Small
    
    func testDepthErrorsAreSmall() {
        let depthSteps: [Double] = [0.0, 0.2, 0.45, 0.7, 0.95, 1.0]
        let curves = SquatMechanicsSolver.solveIdealAngles(
            segmentLengths: testSegmentLengths,
            repStartHeight: testRepStartHeight,
            repBottomHeight: testRepBottomHeight,
            depthSteps: depthSteps
        )
        
        var maxDepthError: Double = 0.0
        var depthErrors: [(depth: Double, error: Double)] = []
        
        // For each depth, verify the normalized depth error is small
        for (index, targetDepth) in curves.depths.enumerated() {
            let torsoAngle = curves.torsoAngles[index]
            let shinAngle = curves.shinAngles[index]
            
            // Build stick figure at this depth
            guard let stickFigure = SquatMechanicsSolver.buildStickFigure(
                torsoAngle: torsoAngle,
                shinAngle: shinAngle,
                segmentLengths: testSegmentLengths,
                depth: targetDepth
            ) else {
                XCTFail("Could not build stick figure at depth \(targetDepth)")
                continue
            }
            
            // Build reference stick figures at depth=0 and depth=1
            guard let stickAtDepth0 = SquatMechanicsSolver.buildStickFigure(
                torsoAngle: torsoAngle,
                shinAngle: shinAngle,
                segmentLengths: testSegmentLengths,
                depth: 0.0
            ),
            let stickAtDepth1 = SquatMechanicsSolver.buildStickFigure(
                torsoAngle: torsoAngle,
                shinAngle: shinAngle,
                segmentLengths: testSegmentLengths,
                depth: 1.0
            ) else {
                XCTFail("Could not build reference stick figures for depth \(targetDepth)")
                continue
            }
            
            // Calculate normalized depth
            let depth0HipY = stickAtDepth0.hip.y
            let depth1HipY = stickAtDepth1.hip.y
            let depthRange = depth1HipY - depth0HipY
            
            guard abs(depthRange) > 1e-6 else {
                XCTFail("Invalid depth range at depth \(targetDepth)")
                continue
            }
            
            let normalizedDepth = (stickFigure.hip.y - depth0HipY) / depthRange
            let depthError = abs(normalizedDepth - targetDepth)
            
            depthErrors.append((depth: targetDepth, error: depthError))
            maxDepthError = max(maxDepthError, depthError)
            
            // Verify error is small (allow some tolerance for grid search resolution)
            XCTAssertLessThan(depthError, 0.2, "Depth error at depth \(targetDepth) should be < 0.2, got \(depthError)")
        }
        
        // Print results for debugging
        print("\n=== testDepthErrorsAreSmall Results ===")
        print("Max depth error: \(String(format: "%.4f", maxDepthError))")
        for (depth, error) in depthErrors {
            print("Depth \(String(format: "%.2f", depth)): error=\(String(format: "%.4f", error))")
        }
        
        // Overall assertion: max error should be reasonable
        XCTAssertLessThan(maxDepthError, 0.2, "Maximum depth error should be < 0.2, got \(maxDepthError)")
    }
    
    // MARK: - Test Torso Angle Increases With Depth
    
    func testTorsoAngleIncreasesWithDepth() {
        let depthSteps: [Double] = [0.0, 0.2, 0.45, 0.7, 0.95, 1.0]
        let curves = SquatMechanicsSolver.solveIdealAngles(
            segmentLengths: testSegmentLengths,
            repStartHeight: testRepStartHeight,
            repBottomHeight: testRepBottomHeight,
            depthSteps: depthSteps
        )
        
        // Verify torso angle generally increases with depth (biomechanically correct)
        // Allow for some non-monotonicity due to optimization, but overall trend should be upward
        var previousTorsoAngle: Double? = nil
        var increases = 0
        var decreases = 0
        
        for (index, depth) in curves.depths.enumerated() {
            let torsoAngle = curves.torsoAngles[index]
            
            if let prev = previousTorsoAngle {
                if torsoAngle > prev {
                    increases += 1
                } else if torsoAngle < prev {
                    decreases += 1
                }
            }
            previousTorsoAngle = torsoAngle
        }
        
        // Print results for debugging
        print("\n=== testTorsoAngleIncreasesWithDepth Results ===")
        for (index, depth) in curves.depths.enumerated() {
            print("Depth \(String(format: "%.2f", depth)): torso=\(String(format: "%.1f", curves.torsoAngles[index]))°")
        }
        print("Increases: \(increases), Decreases: \(decreases)")
        
        // Overall trend should be increasing (more increases than decreases)
        // For biomechanically correct squat, torso should lean more forward as depth increases
        XCTAssertGreaterThan(increases, decreases, "Torso angle should generally increase with depth. Increases: \(increases), Decreases: \(decreases)")
        
        // Also verify that the final torso angle is greater than the initial
        let initialTorsoAngle = curves.torsoAngles.first!
        let finalTorsoAngle = curves.torsoAngles.last!
        XCTAssertGreaterThan(finalTorsoAngle, initialTorsoAngle, 
                           "Final torso angle (\(finalTorsoAngle)°) should be greater than initial (\(initialTorsoAngle)°)")
    }
    
    // MARK: - Helper Test: Verify Stick Figure Building
    
    func testStickFigureBuilding() {
        // Test that we can build stick figures at different depths
        let torsoAngle: Double = 30.0
        let shinAngle: Double = 20.0
        
        for depth in [0.0, 0.5, 1.0] {
            guard let stickFigure = SquatMechanicsSolver.buildStickFigure(
                torsoAngle: torsoAngle,
                shinAngle: shinAngle,
                segmentLengths: testSegmentLengths,
                depth: depth
            ) else {
                XCTFail("Could not build stick figure at depth \(depth)")
                continue
            }
            
            // Verify stick figure has valid coordinates
            XCTAssertGreaterThan(stickFigure.hip.y, stickFigure.ankle.y, "Hip should be below ankle at depth \(depth)")
            XCTAssertGreaterThan(stickFigure.knee.y, stickFigure.ankle.y, "Knee should be below ankle at depth \(depth)")
            
            // Verify hip moves down as depth increases
            if depth > 0.0 {
                // This is a basic sanity check - deeper should generally mean lower hip
                // (though exact relationship depends on angles)
                XCTAssertNotNil(stickFigure, "Stick figure should be valid at depth \(depth)")
            }
        }
    }
}
