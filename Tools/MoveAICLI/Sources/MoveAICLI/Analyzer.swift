//
//  Analyzer.swift
//  MoveAICLI
//
//  Cached poses -> analysis results using MoveAICore.CLIAnalyzer.
//

import Foundation
import MoveAICore

enum Analyzer {
    
    /// Load cached poses, run analysis, write results
    static func analyze(testCaseName: String, cacheDir: String, resultsDir: String) throws {
        let cacheURL = URL(fileURLWithPath: cacheDir).appendingPathComponent("\(testCaseName)_poses.json")
        
        print("📊 Analyzing cached poses for \(testCaseName)...")
        
        guard FileManager.default.fileExists(atPath: cacheURL.path) else {
            fputs("Error: Cache file not found: \(cacheURL.path)\n", stderr)
            fputs("Run 'extract' first to generate pose cache.\n", stderr)
            exit(1)
        }
        
        let poses = try loadPoses(from: cacheURL)
        print("  Loaded \(poses.count) poses from cache")
        
        do {
            try CLIAnalyzer.analyzeAndWrite(
                poses: poses,
                testCaseName: testCaseName,
                resultsDir: resultsDir
            )
        } catch {
            fputs("❌ Analysis failed: \(error.localizedDescription)\n", stderr)
            exit(1)
        }
    }
    
    private static func loadPoses(from url: URL) throws -> [PoseDetectionResult] {
        let data = try Data(contentsOf: url)
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try decoder.decode([PoseDetectionResult].self, from: data)
    }
}
