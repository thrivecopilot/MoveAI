//
//  PoseExtractionTests.swift
//  MoveAICLITests
//
//  Verifies pose extraction stores results in cache without app/simulator.
//

import XCTest
import Foundation
import MoveAICore

final class PoseExtractionTests: XCTestCase {

    /// Resolve path to TestVideos relative to package (Tools/MoveAICLI/Tests/MoveAICLITests -> project root)
    private var testVideosURL: URL {
        let packageDir = URL(fileURLWithPath: #file)
            .deletingLastPathComponent()  // PoseExtractionTests.swift
            .deletingLastPathComponent() // MoveAICLITests
            .deletingLastPathComponent() // Tests
            .deletingLastPathComponent() // MoveAICLI
        return packageDir
            .deletingLastPathComponent() // Tools
            .deletingLastPathComponent() // project root
            .appendingPathComponent("MoveAITests/TestVideos", isDirectory: true)
    }

    private func videoURL(for name: String) -> URL {
        let mov = testVideosURL.appendingPathComponent("\(name).MOV")
        let mp4 = testVideosURL.appendingPathComponent("\(name).mp4")
        let movLower = testVideosURL.appendingPathComponent("\(name).mov")
        if FileManager.default.fileExists(atPath: mov.path) { return mov }
        if FileManager.default.fileExists(atPath: mp4.path) { return mp4 }
        if FileManager.default.fileExists(atPath: movLower.path) { return movLower }
        return mov
    }

    private func cacheURL(for name: String) -> URL {
        testVideosURL
            .appendingPathComponent(".cache", isDirectory: true)
            .appendingPathComponent("\(name)_poses.json")
    }

    /// Test that running extract produces a readable cache file
    func testCacheFileIsReadableAfterExtract() async throws {
        let testCase = "test_case_1"
        let videoURL = videoURL(for: testCase)
        let cacheURL = cacheURL(for: testCase)

        guard FileManager.default.fileExists(atPath: videoURL.path) else {
            throw XCTSkip("Add \(testCase).MOV to MoveAITests/TestVideos to run this test")
        }

        let cliPackageDir = URL(fileURLWithPath: #file)
            .deletingLastPathComponent()  // PoseExtractionTests.swift
            .deletingLastPathComponent()  // MoveAICLITests
            .deletingLastPathComponent()  // Tests
            .deletingLastPathComponent()  // MoveAICLI (package root)

        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/env")
        process.arguments = ["swift", "run", "MoveAICLI", "extract", videoURL.path, "--output", cacheURL.path]
        process.currentDirectoryURL = cliPackageDir

        try process.run()
        process.waitUntilExit()

        XCTAssertEqual(process.terminationStatus, 0, "Extract command should succeed")

        guard FileManager.default.fileExists(atPath: cacheURL.path) else {
            XCTFail("Cache file should exist at \(cacheURL.path)")
            return
        }

        let data = try Data(contentsOf: cacheURL)
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let poses = try decoder.decode([PoseDetectionResult].self, from: data)

        XCTAssertGreaterThan(poses.count, 0, "Cache should contain at least one pose")

        let posesWithKeypoints = poses.filter { !$0.keypoints.isEmpty }
        XCTAssertGreaterThan(posesWithKeypoints.count, 0, "At least one pose should have keypoints")
    }

    /// Test that existing cache file has expected structure
    func testCacheFormatMatchesExpectedStructure() throws {
        let testCase = "test_case_1"
        let cacheURL = cacheURL(for: testCase)

        guard FileManager.default.fileExists(atPath: cacheURL.path) else {
            throw XCTSkip("Run extract first: ./scripts/run-test.sh extract \(testCase)")
        }

        let data = try Data(contentsOf: cacheURL)
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let poses = try decoder.decode([PoseDetectionResult].self, from: data)

        XCTAssertGreaterThan(poses.count, 0)

        for pose in poses.prefix(5) {
            _ = pose.frameIndex
            _ = pose.timestamp
            for keypoint in pose.keypoints.prefix(3) {
                XCTAssertFalse(keypoint.name.isEmpty)
                XCTAssertGreaterThanOrEqual(keypoint.confidence, 0)
                XCTAssertLessThanOrEqual(keypoint.confidence, 1)
            }
        }
    }
}
