//
//  VideoTestCase.swift
//  MoveAITests
//
//  Created by Dave Mathew on 10/11/25.
//

import Foundation
import AVFoundation
@testable import MoveAI

/// Represents a single video test case with expected results
struct VideoTestCase {
    let name: String
    let videoURL: URL
    let expectedResults: ExpectedResults
    
    init(name: String, videoURL: URL, expectedResults: ExpectedResults) {
        self.name = name
        self.videoURL = videoURL
        self.expectedResults = expectedResults
    }
}

/// Expected results for a video test case
struct ExpectedResults {
    let repCount: Int
    let repFrameRanges: [RepFrameRange]
    let depthQuality: [Int: DepthQuality]
    let fullReps: [Int: Bool]  // repNumber -> isFullRep
    let kneeValgus: [Int: Bool]  // repNumber -> hasValgus
    let backRounding: [Int: BackRoundingSeverity]  // repNumber -> severity
    
    struct RepFrameRange {
        let repNumber: Int
        let startFrame: Int
        let bottomFrame: Int
        let endFrame: Int
        let tolerance: Int  // ±frames tolerance
    }
    
    enum DepthQuality {
        case excellent  // isAtDepth = true
        case shallow(depthPercentage: Double?)  // isAtDepth = false, optional depth percentage
    }
    
    enum BackRoundingSeverity {
        case none
        case mild
        case moderate
        case severe
    }
}

/// Test result for a single test case
struct TestResult {
    let testCase: VideoTestCase
    let passed: Bool
    let failures: [TestFailure]
    let analysisResult: SquatAnalysisResult?
    
    struct TestFailure {
        let metric: String
        let expected: String
        let actual: String
        let message: String
    }
}
