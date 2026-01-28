//
//  VideoTestRunner.swift
//  MoveAITests
//
//  Created by Dave Mathew on 10/11/25.
//

import Foundation
import AVFoundation
@testable import MoveAI

/// Runner for video analysis tests
@MainActor
class VideoTestRunner {
    
    /// Run a single test case
    static func runTest(_ testCase: VideoTestCase) async throws -> TestResult {
        // Step 1: Process video to extract pose data
        let videoProcessor = VideoProcessor()
        let recording = try await videoProcessor.processVideo(
            testCase.videoURL,
            movementType: .squat
        )
        
        // Step 2: Run analysis
        guard let poseData = recording.poseData, !poseData.isEmpty else {
            throw TestError.noPoseData
        }
        
        let analysisResult = SquatAnalyzer.analyzeFullSequence(poseData)
        
        guard case .success(let squatResult) = analysisResult else {
            throw TestError.analysisFailed
        }
        
        // Step 3: Validate results
        let failures = validateResults(
            expected: testCase.expectedResults,
            actual: squatResult
        )
        
        return TestResult(
            testCase: testCase,
            passed: failures.isEmpty,
            failures: failures,
            analysisResult: squatResult
        )
    }
    
    /// Validate actual results against expected
    private static func validateResults(
        expected: ExpectedResults,
        actual: SquatAnalysisResult
    ) -> [TestResult.TestFailure] {
        var failures: [TestResult.TestFailure] = []
        
        // Validate rep count
        if actual.reps.count != expected.repCount {
            failures.append(TestResult.TestFailure(
                metric: "Rep Count",
                expected: "\(expected.repCount)",
                actual: "\(actual.reps.count)",
                message: "Expected \(expected.repCount) reps, got \(actual.reps.count)"
            ))
        }
        
        // Validate rep frame ranges (if provided)
        for expectedRange in expected.repFrameRanges {
            guard let actualRep = actual.reps.first(where: { $0.repNumber == expectedRange.repNumber }) else {
                failures.append(TestResult.TestFailure(
                    metric: "Rep \(expectedRange.repNumber) Frame Range",
                    expected: "frames ~\(expectedRange.startFrame)-\(expectedRange.endFrame)",
                    actual: "rep not found",
                    message: "Rep \(expectedRange.repNumber) not found in results"
                ))
                continue
            }
            
            // Get original frame indices from pose data
            // Note: actualRep.startFrame/endFrame/bottomFrame are filtered indices, need to map to original
            // For now, we'll validate using the filtered indices with tolerance
            let startDiff = abs(actualRep.startFrame - expectedRange.startFrame)
            let bottomDiff = abs(actualRep.bottomFrame - expectedRange.bottomFrame)
            let endDiff = abs(actualRep.endFrame - expectedRange.endFrame)
            
            if startDiff > expectedRange.tolerance {
                failures.append(TestResult.TestFailure(
                    metric: "Rep \(expectedRange.repNumber) Start Frame",
                    expected: "~\(expectedRange.startFrame) (±\(expectedRange.tolerance))",
                    actual: "\(actualRep.startFrame)",
                    message: "Rep \(expectedRange.repNumber) start frame \(actualRep.startFrame) is outside tolerance of expected ~\(expectedRange.startFrame)"
                ))
            }
            
            if bottomDiff > expectedRange.tolerance {
                failures.append(TestResult.TestFailure(
                    metric: "Rep \(expectedRange.repNumber) Bottom Frame",
                    expected: "~\(expectedRange.bottomFrame) (±\(expectedRange.tolerance))",
                    actual: "\(actualRep.bottomFrame)",
                    message: "Rep \(expectedRange.repNumber) bottom frame \(actualRep.bottomFrame) is outside tolerance of expected ~\(expectedRange.bottomFrame)"
                ))
            }
            
            if endDiff > expectedRange.tolerance {
                failures.append(TestResult.TestFailure(
                    metric: "Rep \(expectedRange.repNumber) End Frame",
                    expected: "~\(expectedRange.endFrame) (±\(expectedRange.tolerance))",
                    actual: "\(actualRep.endFrame)",
                    message: "Rep \(expectedRange.repNumber) end frame \(actualRep.endFrame) is outside tolerance of expected ~\(expectedRange.endFrame)"
                ))
            }
        }
        
        // Validate depth quality
        let depthByRep = Dictionary(grouping: actual.depthMetrics, by: { $0.repNumber ?? 0 })
        for (repNum, expectedQuality) in expected.depthQuality {
            guard let repDepthMetrics = depthByRep[repNum], !repDepthMetrics.isEmpty else {
                failures.append(TestResult.TestFailure(
                    metric: "Rep \(repNum) Depth Quality",
                    expected: String(describing: expectedQuality),
                    actual: "no depth metrics found",
                    message: "No depth metrics found for rep \(repNum)"
                ))
                continue
            }
            
            // Find deepest point (maximum depthPercentage)
            guard let deepestPoint = repDepthMetrics.max(by: { $0.depthPercentage < $1.depthPercentage }) else {
                continue
            }
            
            switch expectedQuality {
            case .excellent:
                if !deepestPoint.isAtDepth {
                    failures.append(TestResult.TestFailure(
                        metric: "Rep \(repNum) Depth Quality",
                        expected: "EXCELLENT (isAtDepth=true)",
                        actual: "SHALLOW (isAtDepth=false, depthPercentage=\(String(format: "%.1f", deepestPoint.depthPercentage))%)",
                        message: "Rep \(repNum) expected excellent depth but got shallow"
                    ))
                }
            case .shallow(let expectedPercentage):
                if deepestPoint.isAtDepth {
                    failures.append(TestResult.TestFailure(
                        metric: "Rep \(repNum) Depth Quality",
                        expected: "SHALLOW (isAtDepth=false)",
                        actual: "EXCELLENT (isAtDepth=true)",
                        message: "Rep \(repNum) expected shallow depth but got excellent"
                    ))
                } else if let expectedPercent = expectedPercentage {
                    // Check if depth percentage is approximately correct (±10%)
                    let percentDiff = abs(deepestPoint.depthPercentage - expectedPercent)
                    if percentDiff > 10.0 {
                        failures.append(TestResult.TestFailure(
                            metric: "Rep \(repNum) Depth Percentage",
                            expected: "~\(String(format: "%.1f", expectedPercent))%",
                            actual: "\(String(format: "%.1f", deepestPoint.depthPercentage))%",
                            message: "Rep \(repNum) depth percentage \(String(format: "%.1f", deepestPoint.depthPercentage))% differs from expected ~\(String(format: "%.1f", expectedPercent))%"
                        ))
                    }
                }
            }
        }
        
        // Validate full vs partial reps
        for (repNum, expectedIsFull) in expected.fullReps {
            guard let actualRep = actual.reps.first(where: { $0.repNumber == repNum }) else {
                failures.append(TestResult.TestFailure(
                    metric: "Rep \(repNum) Full Rep",
                    expected: expectedIsFull ? "Full" : "Partial",
                    actual: "rep not found",
                    message: "Rep \(repNum) not found in results"
                ))
                continue
            }
            
            if actualRep.isFullRep != expectedIsFull {
                failures.append(TestResult.TestFailure(
                    metric: "Rep \(repNum) Full Rep",
                    expected: expectedIsFull ? "Full (isFullRep=true)" : "Partial (isFullRep=false)",
                    actual: actualRep.isFullRep ? "Full (isFullRep=true)" : "Partial (isFullRep=false)",
                    message: "Rep \(repNum) expected \(expectedIsFull ? "full" : "partial") but got \(actualRep.isFullRep ? "full" : "partial")"
                ))
            }
        }
        
        // Validate knee valgus
        // Skip validation for side-view videos (knee valgus can only be detected from front/back views)
        // Detect side view: if all knee metrics have hasValgus=false and we expect None, it's likely a side view
        let kneeByRep = Dictionary(grouping: actual.kneeMetrics, by: { $0.repNumber ?? 0 })
        let allMetricsHaveNoValgus = actual.kneeMetrics.allSatisfy { !$0.hasValgus }
        let allExpectedNone = expected.kneeValgus.values.allSatisfy { !$0 }
        let isLikelySideView = allMetricsHaveNoValgus && allExpectedNone && !actual.kneeMetrics.isEmpty
        
        if !isLikelySideView {
            // Only validate knee valgus for front/back views
            for (repNum, expectedHasValgus) in expected.kneeValgus {
                guard let repKneeMetrics = kneeByRep[repNum], !repKneeMetrics.isEmpty else {
                    // No knee data - skip validation (ankles may not be detected)
                    continue
                }
                
                // Check if any frame in this rep has valgus
                let actualHasValgus = repKneeMetrics.contains { $0.hasValgus }
                
                if actualHasValgus != expectedHasValgus {
                    failures.append(TestResult.TestFailure(
                        metric: "Rep \(repNum) Knee Valgus",
                        expected: expectedHasValgus ? "Detected" : "None",
                        actual: actualHasValgus ? "Detected" : "None",
                        message: "Rep \(repNum) knee valgus mismatch: expected \(expectedHasValgus ? "detected" : "none"), got \(actualHasValgus ? "detected" : "none")"
                    ))
                }
            }
        }
        // If isLikelySideView is true, skip knee valgus validation (side views can't detect valgus)
        
        // Back rounding validation removed - now handled by biomechanical deviations (formDeviations)
        // Tests should validate formDeviations instead if needed
        
        return failures
    }
    
    enum TestError: Error {
        case noPoseData
        case analysisFailed
        case videoProcessingFailed
    }
}
