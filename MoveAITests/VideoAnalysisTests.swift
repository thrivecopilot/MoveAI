//
//  VideoAnalysisTests.swift
//  MoveAITests
//
//  Created by Dave Mathew on 10/11/25.
//

import XCTest
@testable import MoveAI

/// Tests for video analysis using test videos and expected results
@MainActor
final class VideoAnalysisTests: XCTestCase {
    
    /// Test directory containing test videos and markdown files
    /// Files are added directly to bundle resources, not in a subdirectory
    var testVideosDirectory: URL {
        let testBundle = Bundle(for: type(of: self))
        // Look for files directly in the test bundle's resources
        if let resourcePath = testBundle.resourcePath {
            return URL(fileURLWithPath: resourcePath)
        }
        // Fallback: try to find it via bundle URL
        return testBundle.bundleURL
    }
    
    /// Load a test case from directory
    /// Supports multiple video formats: .mp4, .MOV, .mov, etc.
    func loadTestCase(name: String) throws -> VideoTestCase {
        let csvURL = testVideosDirectory.appendingPathComponent("\(name)_expected.csv")
        
        guard FileManager.default.fileExists(atPath: csvURL.path) else {
            throw TestError.csvNotFound(name)
        }
        
        // Try to find video file with common extensions
        let videoExtensions = ["mp4", "MOV", "mov", "MP4", "m4v", "M4V"]
        var videoURL: URL?
        
        for ext in videoExtensions {
            let candidateURL = testVideosDirectory.appendingPathComponent("\(name).\(ext)")
            if FileManager.default.fileExists(atPath: candidateURL.path) {
                videoURL = candidateURL
                break
            }
        }
        
        guard let foundVideoURL = videoURL else {
            throw TestError.videoNotFound(name)
        }
        
        let csvContent = try String(contentsOf: csvURL, encoding: .utf8)
        let expectedResults = try VideoTestParser.parseExpectedResults(from: csvContent)
        
        return VideoTestCase(
            name: name,
            videoURL: foundVideoURL,
            expectedResults: expectedResults
        )
    }
    
    /// Run a single test case
    func runTestCase(_ testCase: VideoTestCase) async throws {
        let result = try await VideoTestRunner.runTest(testCase)
        
        if !result.passed {
            var failureMessage = "Test '\(testCase.name)' failed:\n"
            for failure in result.failures {
                failureMessage += "  - \(failure.metric): \(failure.message)\n"
                failureMessage += "    Expected: \(failure.expected)\n"
                failureMessage += "    Actual: \(failure.actual)\n"
            }
            XCTFail(failureMessage)
        } else {
            print("✅ Test '\(testCase.name)' passed!")
        }
    }
    
    // MARK: - Test Cases
    
    /// Test with the existing test video
    /// Add your test video as "test_case_1.mp4" (or .MOV) and "test_case_1_expected.csv" in TestVideos directory
    func testExistingVideo() async throws {
        // Skip if test files don't exist
        let testCaseName = "test_case_1"
        let csvURL = testVideosDirectory.appendingPathComponent("\(testCaseName)_expected.csv")
        
        guard FileManager.default.fileExists(atPath: csvURL.path) else {
            throw XCTSkip("Test CSV not found at \(csvURL.path). Please add test_case_1_expected.csv to TestVideos directory.")
        }
        
        let testCase = try loadTestCase(name: testCaseName)
        try await runTestCase(testCase)
    }
    
    // Add more test methods for additional test cases as needed
    // func testCase2() async throws { ... }
    // func testCase3() async throws { ... }
}

enum TestError: Error {
    case videoNotFound(String)
    case csvNotFound(String)
}
