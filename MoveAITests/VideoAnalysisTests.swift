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
    
    // MARK: - Cached Testing Methods
    
    /// Test pose extraction only (slow, run once to cache)
    func testPoseExtraction() async throws {
        let testCaseName = "test_case_1"
        let csvURL = testVideosDirectory.appendingPathComponent("\(testCaseName)_expected.csv")
        
        guard FileManager.default.fileExists(atPath: csvURL.path) else {
            throw XCTSkip("Test CSV not found. Please add test_case_1_expected.csv to TestVideos directory.")
        }
        
        let testCase = try loadTestCase(name: testCaseName)
        let recording = try await VideoTestRunner.extractPosesOnly(testCase, testVideosDirectory: testVideosDirectory)
        
        XCTAssertNotNil(recording.poseData)
        XCTAssertFalse(recording.poseData?.isEmpty ?? true)
        print("✅ Extracted \(recording.poseData?.count ?? 0) poses")
    }
    
    /// Test analysis with cached poses (fast, for iteration)
    func testAnalysisWithCache() async throws {
        let testCaseName = "test_case_1"
        
        // Check if cache exists
        guard PoseCacheManager.hasCache(for: testCaseName, testVideosDirectory: testVideosDirectory) else {
            throw XCTSkip("No cached poses found. Run testPoseExtraction() first to create cache.")
        }
        
        let testCase = try loadTestCase(name: testCaseName)
        let result = try await VideoTestRunner.analyzeWithCachedPoses(testCase, testVideosDirectory: testVideosDirectory)
        
        // Print key solver metrics for quick sanity checking
        let separator = String(repeating: "=", count: 60)
        print("\n" + separator)
        print("🔍 KEY SOLVER METRICS")
        print(separator)
        print("📊 Overall Score: \(String(format: "%.1f", result.overallScore))/100")
        print("🏋️ Reps Detected: \(result.reps.count)")
        
        if !result.reps.isEmpty {
            print("\n📐 Ideal Angle Ranges (per rep):")
            for rep in result.reps {
                // Note: Ideal angles are computed during analysis and logged there
                // We can't easily access them here without modifying the analyzer
                // But we can show rep info
                print("   Rep \(rep.repNumber): frames \(rep.startFrame)-\(rep.endFrame), depth: \(rep.reachedDepth ? "✅" : "❌")")
            }
        }
        
        // Show deviations summary if available (from feedback)
        let criticalIssues = result.feedback.filter { $0.severity == .critical }
        let warnings = result.feedback.filter { $0.severity == .warning }
        
        if !criticalIssues.isEmpty || !warnings.isEmpty {
            print("\n⚠️ Issues Detected:")
            if !criticalIssues.isEmpty {
                print("   🔴 Critical: \(criticalIssues.count)")
                for issue in criticalIssues.prefix(3) {
                    print("      - \(issue.message)")
                }
            }
            if !warnings.isEmpty {
                print("   🟠 Warnings: \(warnings.count)")
                for issue in warnings.prefix(3) {
                    print("      - \(issue.message)")
                }
            }
        } else {
            print("\n✅ No critical issues detected")
        }
        
        // Depth analysis summary
        if !result.depthMetrics.isEmpty {
            let depthByRep = Dictionary(grouping: result.depthMetrics, by: { $0.repNumber ?? 0 })
            print("\n📏 Depth Analysis:")
            for repNum in result.reps.map({ $0.repNumber }).sorted() {
                if let repDepths = depthByRep[repNum], !repDepths.isEmpty {
                    let deepest = repDepths.max(by: { $0.depthPercentage < $1.depthPercentage })!
                    print("   Rep \(repNum): \(String(format: "%.1f", deepest.depthPercentage))% depth (\(deepest.isAtDepth ? "✅ at depth" : "❌ shallow"))")
                }
            }
        }
        
        print(separator + "\n")
        
        // Print full summary
        let summary = ResultSummarizer.summarize(result)
        print(summary)
        
        // Save results
        let resultsDir = testVideosDirectory.appendingPathComponent(".results", isDirectory: true)
        try? FileManager.default.createDirectory(at: resultsDir, withIntermediateDirectories: true)
        
        let summaryURL = resultsDir.appendingPathComponent("\(testCaseName)_summary.txt")
        let jsonURL = resultsDir.appendingPathComponent("\(testCaseName)_results.json")
        
        try ResultSummarizer.saveSummary(result, to: summaryURL)
        try ResultSummarizer.saveJSON(result, to: jsonURL)
        
        print("💾 Results saved to:")
        print("   Summary: \(summaryURL.path)")
        print("   JSON: \(jsonURL.path)")
        
        XCTAssertFalse(result.reps.isEmpty, "Should detect at least one rep")
    }
    
    /// Test full pipeline with caching (extract if needed, then analyze)
    func testFullPipelineWithCache() async throws {
        let testCaseName = "test_case_1"
        let csvURL = testVideosDirectory.appendingPathComponent("\(testCaseName)_expected.csv")
        
        guard FileManager.default.fileExists(atPath: csvURL.path) else {
            throw XCTSkip("Test CSV not found. Please add test_case_1_expected.csv to TestVideos directory.")
        }
        
        let testCase = try loadTestCase(name: testCaseName)
        let result = try await VideoTestRunner.runTestWithCache(testCase, testVideosDirectory: testVideosDirectory, useCache: true)
        
        // Print brief summary
        if let analysisResult = result.analysisResult {
            let brief = ResultSummarizer.summarizeBrief(analysisResult)
            print("📊 \(brief)")
        }
        
        if !result.passed {
            var failureMessage = "Test '\(testCase.name)' failed:\n"
            for failure in result.failures {
                failureMessage += "  - \(failure.metric): \(failure.message)\n"
            }
            XCTFail(failureMessage)
        } else {
            print("✅ Test '\(testCase.name)' passed!")
        }
    }
    
    // Add more test methods for additional test cases as needed
    // func testCase2() async throws { ... }
    // func testCase3() async throws { ... }
}

enum TestError: Error {
    case videoNotFound(String)
    case csvNotFound(String)
}
