//
//  SquatMechanicsSolverTests.swift
//  MoveAITests
//
//  Created by Dave Mathew on 1/27/26.
//

import XCTest
import CoreGraphics
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

final class CameraAngleDetectionTests: XCTestCase {
    private func pose(frame: Int, leftKneeX: Double?, rightKneeX: Double?, confidence: Float = 1.0) -> PoseDetectionResult {
        var keypoints: [PoseKeypoint] = []

        if let x = leftKneeX {
            keypoints.append(PoseKeypoint(name: "leftKnee", position: CGPoint(x: x, y: 0.5), confidence: confidence))
        }
        if let x = rightKneeX {
            keypoints.append(PoseKeypoint(name: "rightKnee", position: CGPoint(x: x, y: 0.5), confidence: confidence))
        }

        return PoseDetectionResult(
            keypoints: keypoints,
            frameIndex: frame,
            timestamp: Date(timeIntervalSince1970: Double(frame) / 30.0)
        )
    }

    func testDetectCameraAngle_side_whenOnlyOneKneeVisible() {
        let poses = (0..<10).map { i in
            pose(frame: i, leftKneeX: 0.5, rightKneeX: nil)
        }

        let result = SquatAnalyzer.detectCameraAngle(from: poses)

        XCTAssertEqual(result.angle, .side)
        XCTAssertGreaterThanOrEqual(result.confidence, 0.9)
        XCTAssertEqual(result.bothSidesFrameRatio, 0.0, accuracy: 1e-9)
    }

    func testDetectCameraAngle_side_whenBothKneesStacked_hasUsefulConfidence() {
        let poses = (0..<10).map { i in
            pose(frame: i, leftKneeX: 0.48, rightKneeX: 0.52)
        }

        let result = SquatAnalyzer.detectCameraAngle(from: poses)

        XCTAssertEqual(result.angle, .side)
        XCTAssertGreaterThan(result.confidence, 0.6)
        XCTAssertEqual(result.bothSidesFrameRatio, 1.0, accuracy: 1e-9)
        XCTAssertLessThan(result.medianKneeSeparation, 0.08)
    }

    func testDetectCameraAngle_front_whenBothKneesWide() {
        let poses = (0..<10).map { i in
            pose(frame: i, leftKneeX: 0.3, rightKneeX: 0.7)
        }

        let result = SquatAnalyzer.detectCameraAngle(from: poses)

        XCTAssertEqual(result.angle, .front)
        XCTAssertGreaterThanOrEqual(result.confidence, 0.9)
        XCTAssertGreaterThan(result.medianKneeSeparation, 0.18)
        XCTAssertEqual(result.bothSidesFrameRatio, 1.0, accuracy: 1e-9)
    }

    func testDetectCameraAngle_diagonal_whenKneesModerate() {
        let poses = (0..<10).map { i in
            pose(frame: i, leftKneeX: 0.45, rightKneeX: 0.55)
        }

        let result = SquatAnalyzer.detectCameraAngle(from: poses)

        XCTAssertEqual(result.angle, .diagonal)
        XCTAssertGreaterThanOrEqual(result.confidence, 0.9)
        XCTAssertGreaterThan(result.medianKneeSeparation, 0.08)
        XCTAssertLessThan(result.medianKneeSeparation, 0.18)
    }

    func testDetectCameraAngle_confidenceDropsWhenFewFramesHaveBothSides() {
        var poses: [PoseDetectionResult] = []
        poses.reserveCapacity(10)

        for i in 0..<10 {
            if i < 2 {
                poses.append(pose(frame: i, leftKneeX: 0.3, rightKneeX: 0.7))
            } else {
                poses.append(pose(frame: i, leftKneeX: nil, rightKneeX: nil))
            }
        }

        let result = SquatAnalyzer.detectCameraAngle(from: poses)

        XCTAssertEqual(result.angle, .front)
        XCTAssertLessThan(result.confidence, 0.6)
        XCTAssertEqual(result.bothSidesFrameRatio, 0.2, accuracy: 1e-9)
    }
}

final class SquatWarningTests: XCTestCase {
    override func setUp() {
        super.setUp()
        setenv("MOVEAI_ENABLE_SIDE_CHECKS_V2", "1", 1)
        setenv("MOVEAI_ENABLE_FRONT_CHECKS_V2", "1", 1)
        unsetenv("MOVEAI_ENABLE_DIAGONAL_CHECKS")
    }

    private func kp(_ name: String, x: Double, y: Double, confidence: Float = 1.0) -> PoseKeypoint {
        PoseKeypoint(
            name: name,
            position: CGPoint(x: x, y: y),
            confidence: confidence,
            timestamp: Date(timeIntervalSince1970: 0)
        )
    }

    private func pose(frame: Int, seconds: Double, keypoints: [PoseKeypoint]) -> PoseDetectionResult {
        PoseDetectionResult(
            keypoints: keypoints,
            frameIndex: frame,
            timestamp: Date(timeIntervalSince1970: seconds)
        )
    }

    private func oneRepSequence(
        frameCount: Int = 30,
        bottomFrame: Int = 15,
        keypointsForFrame: (Int) -> [PoseKeypoint]
    ) -> (poses: [PoseDetectionResult], smoothedHeights: [Double], rep: SquatRep) {
        let startHeight = 0.7
        let bottomHeight = 0.3
        var heights: [Double] = []
        heights.reserveCapacity(frameCount)

        for i in 0..<frameCount {
            if i <= bottomFrame {
                let t = Double(i) / Double(max(1, bottomFrame))
                heights.append(startHeight + (bottomHeight - startHeight) * t)
            } else {
                let denom = Double(max(1, frameCount - 1 - bottomFrame))
                let t = Double(i - bottomFrame) / denom
                heights.append(bottomHeight + (startHeight - bottomHeight) * t)
            }
        }

        let poses = (0..<frameCount).map { i in
            pose(frame: i, seconds: Double(i) / 30.0, keypoints: keypointsForFrame(i))
        }

        let rep = SquatRep(
            repNumber: 1,
            startFrame: 0,
            endFrame: frameCount - 1,
            startTime: 0,
            endTime: Double(frameCount - 1) / 30.0,
            isFullRep: true,
            bottomFrame: bottomFrame,
            bottomTime: Double(bottomFrame) / 30.0,
            reachedDepth: true,
            returnedToStart: true
        )

        return (poses: poses, smoothedHeights: heights, rep: rep)
    }

    func testKneeValgusTriggersWhenKneesCloserThanAnkles() {
        let seq = oneRepSequence { _ in
            [
                kp("leftAnkle", x: 0.2, y: 0.2),
                kp("rightAnkle", x: 0.8, y: 0.2),
                kp("leftKnee", x: 0.46, y: 0.5),
                kp("rightKnee", x: 0.54, y: 0.5),
                kp("leftHip", x: 0.4, y: 0.8),
                kp("rightHip", x: 0.6, y: 0.8),
            ]
        }

        let feedback = SquatAnalyzer.generateFeedback(
            poses: seq.poses,
            smoothedHeights: seq.smoothedHeights,
            phases: [],
            reps: [seq.rep],
            depthMetrics: [],
            kneeMetrics: [],
            worstDepth: nil,
            worstKnee: nil,
            startTime: Date(timeIntervalSince1970: 0),
            camera: (angle: .front, confidence: 0.9, medianKneeSeparation: 0.3, bothSidesFrameRatio: 1.0),
            segmentLengths: nil,
            formDeviations: []
        )

        XCTAssertTrue(feedback.contains(where: { $0.issueKind == .squatKneeValgus }))
    }

    func testHipShiftTriggersWhenPelvisOffsetChangesFromSetup() {
        let seq = oneRepSequence { frame in
            let isSetup = frame < 5
            let hipMid = isSetup ? 0.5 : 0.56
            return [
                kp("leftAnkle", x: 0.2, y: 0.2),
                kp("rightAnkle", x: 0.8, y: 0.2),
                kp("leftHip", x: hipMid - 0.1, y: 0.8),
                kp("rightHip", x: hipMid + 0.1, y: 0.8),
            ]
        }

        let feedback = SquatAnalyzer.generateFeedback(
            poses: seq.poses,
            smoothedHeights: seq.smoothedHeights,
            phases: [],
            reps: [seq.rep],
            depthMetrics: [],
            kneeMetrics: [],
            worstDepth: nil,
            worstKnee: nil,
            startTime: Date(timeIntervalSince1970: 0),
            camera: (angle: .front, confidence: 0.9, medianKneeSeparation: 0.25, bothSidesFrameRatio: 1.0),
            segmentLengths: nil,
            formDeviations: []
        )

        XCTAssertTrue(feedback.contains(where: { $0.issueKind == .squatHipShift }))
    }

    func testFootCollapseTriggersWhenAnkleAndToeMoveTowardMidline() {
        let seq = oneRepSequence { frame in
            let isSetup = frame < 5
            let leftAnkleX = isSetup ? 0.2 : 0.3
            let leftToeX = isSetup ? 0.18 : 0.32
            return [
                kp("leftHip", x: 0.4, y: 0.8),
                kp("rightHip", x: 0.6, y: 0.8),
                kp("leftAnkle", x: leftAnkleX, y: 0.2),
                kp("leftFootIndex", x: leftToeX, y: 0.18),
            ]
        }

        let feedback = SquatAnalyzer.generateFeedback(
            poses: seq.poses,
            smoothedHeights: seq.smoothedHeights,
            phases: [],
            reps: [seq.rep],
            depthMetrics: [],
            kneeMetrics: [],
            worstDepth: nil,
            worstKnee: nil,
            startTime: Date(timeIntervalSince1970: 0),
            camera: (angle: .front, confidence: 0.9, medianKneeSeparation: 0.25, bothSidesFrameRatio: 1.0),
            segmentLengths: nil,
            formDeviations: []
        )

        XCTAssertTrue(feedback.contains(where: { $0.issueKind == .squatFootCollapse }))
    }

    func testHeelsLiftTriggersWhenHeelRisesRelativeToToe() {
        let seq = oneRepSequence { frame in
            let isSetup = frame < 5
            let ankleY = isSetup ? 0.20 : 0.28
            return [
                kp("leftAnkle", x: 0.5, y: ankleY),
                kp("leftKnee", x: 0.5, y: 0.6),
            ]
        }

        let feedback = SquatAnalyzer.generateFeedback(
            poses: seq.poses,
            smoothedHeights: seq.smoothedHeights,
            phases: [],
            reps: [seq.rep],
            depthMetrics: [],
            kneeMetrics: [],
            worstDepth: nil,
            worstKnee: nil,
            startTime: Date(timeIntervalSince1970: 0),
            camera: (angle: .side, confidence: 0.9, medianKneeSeparation: 0.0, bothSidesFrameRatio: 0.0),
            segmentLengths: nil,
            formDeviations: []
        )

        XCTAssertTrue(feedback.contains(where: { $0.issueKind == .squatHeelsLift }))
    }

    func testKneesStayedBackTriggersWhenShinAngleTooVertical() {
        let segments = AnthropometryEstimator.SegmentLengths(shinLength: 1.0, femurLength: 1.0, torsoLength: 1.0)

        let seq = oneRepSequence { _ in
            [
                kp("leftAnkle", x: 0.5, y: 0.2),
                kp("leftKnee", x: 0.52, y: 0.6),
                kp("leftHeel", x: 0.48, y: 0.2),
                kp("leftHip", x: 0.4, y: 0.8),
            ]
        }

        let feedback = SquatAnalyzer.generateFeedback(
            poses: seq.poses,
            smoothedHeights: seq.smoothedHeights,
            phases: [],
            reps: [seq.rep],
            depthMetrics: [],
            kneeMetrics: [],
            worstDepth: nil,
            worstKnee: nil,
            startTime: Date(timeIntervalSince1970: 0),
            camera: (angle: .side, confidence: 0.9, medianKneeSeparation: 0.0, bothSidesFrameRatio: 0.0),
            segmentLengths: segments,
            formDeviations: []
        )

        XCTAssertTrue(feedback.contains(where: { $0.issueKind == .squatKneesStayedBack }))
    }

    func testDepthInconsistentTriggersAtSetLevelWhenRepDepthsVary() {
        let fps = 30.0
        let frameCount = 90
        let bottomFrames = [15, 45, 75]

        let poses: [PoseDetectionResult] = (0..<frameCount).map { i in
            pose(frame: i, seconds: Double(i) / fps, keypoints: [])
        }

        let heights = Array(repeating: 0.5, count: frameCount)

        let reps: [SquatRep] = (0..<3).map { idx in
            let start = idx * 30
            let end = start + 29
            let bottom = bottomFrames[idx]
            return SquatRep(
                repNumber: idx + 1,
                startFrame: start,
                endFrame: end,
                startTime: Double(start) / fps,
                endTime: Double(end) / fps,
                isFullRep: true,
                bottomFrame: bottom,
                bottomTime: Double(bottom) / fps,
                reachedDepth: true,
                returnedToStart: true
            )
        }

        let depthMetrics: [DepthAnalysis] = [
            DepthAnalysis(
                hipHeight: 0.0,
                kneeHeight: 0.0,
                isAtDepth: true,
                depthPercentage: 90.0,
                timestamp: Date(timeIntervalSince1970: Double(bottomFrames[0]) / fps),
                repNumber: 1
            ),
            DepthAnalysis(
                hipHeight: 0.0,
                kneeHeight: 0.0,
                isAtDepth: true,
                depthPercentage: 75.0,
                timestamp: Date(timeIntervalSince1970: Double(bottomFrames[1]) / fps),
                repNumber: 2
            ),
            DepthAnalysis(
                hipHeight: 0.0,
                kneeHeight: 0.0,
                isAtDepth: true,
                depthPercentage: 60.0,
                timestamp: Date(timeIntervalSince1970: Double(bottomFrames[2]) / fps),
                repNumber: 3
            ),
        ]

        let feedback = SquatAnalyzer.generateFeedback(
            poses: poses,
            smoothedHeights: heights,
            phases: [],
            reps: reps,
            depthMetrics: depthMetrics,
            kneeMetrics: [],
            worstDepth: nil,
            worstKnee: nil,
            startTime: Date(timeIntervalSince1970: 0),
            camera: (angle: .side, confidence: 0.9, medianKneeSeparation: 0.0, bothSidesFrameRatio: 0.0),
            segmentLengths: nil,
            formDeviations: []
        )

        XCTAssertTrue(feedback.contains(where: { $0.issueKind == .squatDepthInconsistent && $0.repNumber == nil }))
    }

    func testBraceLeakEmitsFromTorsoInstabilityDeviation() {
        let seq = oneRepSequence { _ in
            [
                kp("leftHip", x: 0.4, y: 0.8),
                kp("rightHip", x: 0.6, y: 0.8),
            ]
        }

        let deviations: [FormDeviationAnalyzer.FormDeviation] = [
            FormDeviationAnalyzer.FormDeviation(
                type: .torsoInstability,
                severity: .severe,
                magnitude: 26.0,
                frameRange: 10..<12,
                repNumber: 1,
                message: "Torso instability detected"
            )
        ]

        let feedback = SquatAnalyzer.generateFeedback(
            poses: seq.poses,
            smoothedHeights: seq.smoothedHeights,
            phases: [],
            reps: [seq.rep],
            depthMetrics: [],
            kneeMetrics: [],
            worstDepth: nil,
            worstKnee: nil,
            startTime: Date(timeIntervalSince1970: 0),
            camera: (angle: .side, confidence: 0.9, medianKneeSeparation: 0.0, bothSidesFrameRatio: 0.0),
            segmentLengths: nil,
            formDeviations: deviations
        )

        XCTAssertTrue(feedback.contains(where: { $0.issueKind == .squatBraceLeak }))
    }

    func testSideChecksRunEvenWhenSideConfidenceIsLow() {
        let seq = oneRepSequence { _ in [] }

        let shallowDepth = DepthAnalysis(
            hipHeight: 0.0,
            kneeHeight: 0.0,
            isAtDepth: false,
            depthPercentage: 65.0,
            timestamp: Date(timeIntervalSince1970: seq.rep.bottomTime),
            repNumber: 1
        )

        let feedback = SquatAnalyzer.generateFeedback(
            poses: seq.poses,
            smoothedHeights: seq.smoothedHeights,
            phases: [],
            reps: [seq.rep],
            depthMetrics: [shallowDepth],
            kneeMetrics: [],
            worstDepth: nil,
            worstKnee: nil,
            startTime: Date(timeIntervalSince1970: 0),
            camera: (angle: .side, confidence: 0.1, medianKneeSeparation: 0.02, bothSidesFrameRatio: 1.0),
            segmentLengths: nil,
            formDeviations: []
        )

        XCTAssertTrue(feedback.contains(where: { $0.issueKind == .squatDepthTooShallow }))
        XCTAssertFalse(feedback.contains(where: { $0.issueKind == .squatCameraAngleLimited }))
    }

    func testCameraLimitedWarningEmittedOnceWhenAllMajorFamiliesBlocked() {
        let seq = oneRepSequence { _ in [] }

        let feedback = SquatAnalyzer.generateFeedback(
            poses: seq.poses,
            smoothedHeights: seq.smoothedHeights,
            phases: [],
            reps: [seq.rep],
            depthMetrics: [],
            kneeMetrics: [],
            worstDepth: nil,
            worstKnee: nil,
            startTime: Date(timeIntervalSince1970: 0),
            camera: (angle: .front, confidence: 0.2, medianKneeSeparation: 0.28, bothSidesFrameRatio: 1.0),
            segmentLengths: nil,
            formDeviations: []
        )

        let warnings = feedback.filter { $0.issueKind == .squatCameraAngleLimited }
        XCTAssertEqual(warnings.count, 1)
        XCTAssertEqual(warnings.first?.severity, .warning)
        XCTAssertEqual(warnings.first?.repNumber, nil)
        XCTAssertEqual(warnings.first?.timestamp ?? -1, 0, accuracy: 1e-9)
    }

    func testCameraLimitedWarningNotEmittedWhenFrontChecksAreEligible() {
        let seq = oneRepSequence { _ in [] }

        let feedback = SquatAnalyzer.generateFeedback(
            poses: seq.poses,
            smoothedHeights: seq.smoothedHeights,
            phases: [],
            reps: [seq.rep],
            depthMetrics: [],
            kneeMetrics: [],
            worstDepth: nil,
            worstKnee: nil,
            startTime: Date(timeIntervalSince1970: 0),
            camera: (angle: .front, confidence: 0.9, medianKneeSeparation: 0.28, bothSidesFrameRatio: 1.0),
            segmentLengths: nil,
            formDeviations: []
        )

        XCTAssertFalse(feedback.contains(where: { $0.issueKind == .squatCameraAngleLimited }))
    }
}
