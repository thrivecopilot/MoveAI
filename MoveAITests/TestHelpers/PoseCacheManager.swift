//
//  PoseCacheManager.swift
//  MoveAITests
//
//  Created by Dave Mathew on 1/28/25.
//

import Foundation
import CoreGraphics
@testable import MoveAI

// MARK: - CGPoint Codable Extension
extension CGPoint: Codable {
    enum CodingKeys: String, CodingKey {
        case x, y
    }
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let x = try container.decode(CGFloat.self, forKey: .x)
        let y = try container.decode(CGFloat.self, forKey: .y)
        self.init(x: x, y: y)
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(x, forKey: .x)
        try container.encode(y, forKey: .y)
    }
}

/// Manages caching of pose detection results to avoid re-extraction
class PoseCacheManager {
    
    /// Get the cache directory URL for test videos
    static func cacheDirectory(for testVideosDirectory: URL) -> URL {
        return testVideosDirectory.appendingPathComponent(".cache", isDirectory: true)
    }
    
    /// Get the cache file path for a test case
    static func cachePath(for testCaseName: String, testVideosDirectory: URL) -> URL {
        let cacheDir = cacheDirectory(for: testVideosDirectory)
        return cacheDir.appendingPathComponent("\(testCaseName)_poses.json")
    }
    
    /// Ensure cache directory exists
    static func ensureCacheDirectoryExists(for testVideosDirectory: URL) throws {
        let cacheDir = cacheDirectory(for: testVideosDirectory)
        if !FileManager.default.fileExists(atPath: cacheDir.path) {
            try FileManager.default.createDirectory(at: cacheDir, withIntermediateDirectories: true)
        }
    }
    
    /// Save pose data to cache
    static func savePoseData(_ poses: [PoseDetectionResult], for testCaseName: String, testVideosDirectory: URL) throws {
        try ensureCacheDirectoryExists(for: testVideosDirectory)
        
        let cacheURL = cachePath(for: testCaseName, testVideosDirectory: testVideosDirectory)
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        
        let data = try encoder.encode(poses)
        try data.write(to: cacheURL)
        
        print("💾 Cached \(poses.count) pose results to \(cacheURL.path)")
    }
    
    /// Load pose data from cache
    static func loadPoseData(for testCaseName: String, testVideosDirectory: URL) throws -> [PoseDetectionResult]? {
        let cacheURL = cachePath(for: testCaseName, testVideosDirectory: testVideosDirectory)
        
        guard FileManager.default.fileExists(atPath: cacheURL.path) else {
            return nil
        }
        
        let data = try Data(contentsOf: cacheURL)
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        
        let poses = try decoder.decode([PoseDetectionResult].self, from: data)
        print("📂 Loaded \(poses.count) pose results from cache")
        
        return poses
    }
    
    /// Check if cache exists for a test case
    static func hasCache(for testCaseName: String, testVideosDirectory: URL) -> Bool {
        let cacheURL = cachePath(for: testCaseName, testVideosDirectory: testVideosDirectory)
        return FileManager.default.fileExists(atPath: cacheURL.path)
    }
    
    /// Clear cache for a test case
    static func clearCache(for testCaseName: String, testVideosDirectory: URL) throws {
        let cacheURL = cachePath(for: testCaseName, testVideosDirectory: testVideosDirectory)
        
        if FileManager.default.fileExists(atPath: cacheURL.path) {
            try FileManager.default.removeItem(at: cacheURL)
            print("🗑️ Cleared cache for \(testCaseName)")
        }
    }
    
    /// Clear all caches
    static func clearAllCaches(testVideosDirectory: URL) throws {
        let cacheDir = cacheDirectory(for: testVideosDirectory)
        
        if FileManager.default.fileExists(atPath: cacheDir.path) {
            try FileManager.default.removeItem(at: cacheDir)
            print("🗑️ Cleared all caches")
        }
    }
}
