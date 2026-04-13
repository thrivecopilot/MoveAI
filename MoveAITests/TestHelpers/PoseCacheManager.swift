//
//  PoseCacheManager.swift
//  MoveAITests
//
//  Created by Dave Mathew on 1/28/25.
//

import Foundation
import CoreGraphics
import CryptoKit
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
    struct CacheProvenance: Codable {
        let schemaVersion: Int
        let fixtureId: String
        let videoFile: String
        let videoSHA256: String
        let cacheSHA256: String
        let generatedAt: Date
        let generator: String
    }

    private static let cacheDirectoryEnvKey = "MOVEAI_POSE_CACHE_DIR"
    private static let cacheSubdirectoryEnvKey = "MOVEAI_POSE_CACHE_SUBDIR"
    private static let defaultCacheSubdirectory = ".cache"
    private static let deviceFallbackCacheSubdirectory = "muaythai_cache"
    
    /// Get the cache directory URL for test videos
    static func cacheDirectory(for testVideosDirectory: URL) -> URL {
        let env = ProcessInfo.processInfo.environment
        if let explicitDir = env[cacheDirectoryEnvKey], !explicitDir.isEmpty {
            let explicitURL = URL(fileURLWithPath: explicitDir, isDirectory: true)
            if explicitURL.path.hasPrefix("/") {
                return explicitURL
            }

            return testVideosDirectory.appendingPathComponent(explicitDir, isDirectory: true)
        }

        // On physical devices, test fixture URLs can resolve to host/source paths
        // that are not writable from the app sandbox. Fall back to sandbox tmp.
        if !FileManager.default.isWritableFile(atPath: testVideosDirectory.path) {
            return FileManager.default.temporaryDirectory
                .appendingPathComponent(deviceFallbackCacheSubdirectory, isDirectory: true)
        }

        let cacheSubdirectory = env[cacheSubdirectoryEnvKey]
            .flatMap { $0.isEmpty ? nil : $0 } ?? defaultCacheSubdirectory
        return testVideosDirectory.appendingPathComponent(cacheSubdirectory, isDirectory: true)
    }
    
    /// Get the cache file path for a test case
    static func cachePath(for testCaseName: String, testVideosDirectory: URL) -> URL {
        let cacheDir = cacheDirectory(for: testVideosDirectory)
        return cacheDir.appendingPathComponent("\(testCaseName)_poses.json")
    }

    static func provenancePath(for testCaseName: String, testVideosDirectory: URL) -> URL {
        let cacheDir = cacheDirectory(for: testVideosDirectory)
        return cacheDir.appendingPathComponent("\(testCaseName)_poses.meta.json")
    }

    static func resolvedCachePath(for testCaseName: String, testVideosDirectory: URL) -> URL? {
        let direct = cachePath(for: testCaseName, testVideosDirectory: testVideosDirectory)
        if FileManager.default.fileExists(atPath: direct.path) {
            return direct
        }

        return bundledResourceURL(stem: "\(testCaseName)_poses", extension: "json")
    }

    static func resolvedProvenancePath(for testCaseName: String, testVideosDirectory: URL) -> URL? {
        let direct = provenancePath(for: testCaseName, testVideosDirectory: testVideosDirectory)
        if FileManager.default.fileExists(atPath: direct.path) {
            return direct
        }

        return bundledResourceURL(stem: "\(testCaseName)_poses.meta", extension: "json")
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

    static func saveCacheProvenance(
        fixtureId: String,
        videoFile: String,
        videoSHA256: String,
        cacheSHA256: String,
        generator: String,
        testVideosDirectory: URL
    ) throws {
        try ensureCacheDirectoryExists(for: testVideosDirectory)

        let provenance = CacheProvenance(
            schemaVersion: 1,
            fixtureId: fixtureId,
            videoFile: videoFile,
            videoSHA256: videoSHA256,
            cacheSHA256: cacheSHA256,
            generatedAt: Date(),
            generator: generator
        )

        let provenanceURL = provenancePath(for: fixtureId, testVideosDirectory: testVideosDirectory)
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try encoder.encode(provenance)
        try data.write(to: provenanceURL)
    }
    
    /// Load pose data from cache
    static func loadPoseData(for testCaseName: String, testVideosDirectory: URL) throws -> [PoseDetectionResult]? {
        guard let cacheURL = resolvedCachePath(for: testCaseName, testVideosDirectory: testVideosDirectory) else {
            return nil
        }

        let data = try Data(contentsOf: cacheURL)
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        
        let poses = try decoder.decode([PoseDetectionResult].self, from: data)
        print("📂 Loaded \(poses.count) pose results from cache")
        
        return poses
    }

    static func loadCacheProvenance(
        for testCaseName: String,
        testVideosDirectory: URL
    ) throws -> CacheProvenance? {
        guard let provenanceURL = resolvedProvenancePath(
            for: testCaseName,
            testVideosDirectory: testVideosDirectory
        ) else {
            return nil
        }

        let data = try Data(contentsOf: provenanceURL)
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try decoder.decode(CacheProvenance.self, from: data)
    }
    
    /// Check if cache exists for a test case
    static func hasCache(for testCaseName: String, testVideosDirectory: URL) -> Bool {
        resolvedCachePath(for: testCaseName, testVideosDirectory: testVideosDirectory) != nil
    }
    
    /// Clear cache for a test case
    static func clearCache(for testCaseName: String, testVideosDirectory: URL) throws {
        let cacheURL = cachePath(for: testCaseName, testVideosDirectory: testVideosDirectory)
        let provenanceURL = provenancePath(for: testCaseName, testVideosDirectory: testVideosDirectory)
        
        if FileManager.default.fileExists(atPath: cacheURL.path) {
            try FileManager.default.removeItem(at: cacheURL)
            print("🗑️ Cleared cache for \(testCaseName)")
        }
        if FileManager.default.fileExists(atPath: provenanceURL.path) {
            try FileManager.default.removeItem(at: provenanceURL)
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

    static func fileSHA256(at url: URL) throws -> String {
        let data = try Data(contentsOf: url)
        let digest = SHA256.hash(data: data)
        return digest.map { String(format: "%02x", $0) }.joined()
    }

    private static func bundledResourceURL(stem: String, extension ext: String) -> URL? {
        let bundles = [Bundle.main] + Bundle.allBundles + Bundle.allFrameworks
        for bundle in bundles {
            if let url = bundle.url(forResource: stem, withExtension: ext) {
                return url
            }
            if let url = bundle.url(forResource: "\(stem).\(ext)", withExtension: nil) {
                return url
            }
        }
        return nil
    }
}
