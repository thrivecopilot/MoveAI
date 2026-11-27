//
//  CLIAnalyzer.swift
//  MoveAICore
//
//  Public API for CLI: load poses, analyze, write results.
//

import Foundation

public enum CLIAnalyzer {
    
    /// Load poses from cache, run analysis, write summary and JSON to results directory
    public static func analyzeAndWrite(
        poses: [PoseDetectionResult],
        testCaseName: String,
        resultsDir: String
    ) throws {
        let resultsBaseURL = URL(fileURLWithPath: resultsDir)
        
        let result = SquatAnalyzer.analyzeFullSequence(poses)
        
        switch result {
        case .success(let analysisResult):
            let summaryURL = resultsBaseURL.appendingPathComponent("\(testCaseName)_summary.txt")
            let jsonURL = resultsBaseURL.appendingPathComponent("\(testCaseName)_results.json")
            
            try FileManager.default.createDirectory(at: resultsBaseURL, withIntermediateDirectories: true)
            
            let summary = summarize(analysisResult)
            try summary.write(to: summaryURL, atomically: true, encoding: .utf8)
            
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            let jsonData = try encoder.encode(analysisResult)
            try jsonData.write(to: jsonURL)
            
            print(summary)
            print("✅ Results saved to:")
            print("   \(summaryURL.path)")
            print("   \(jsonURL.path)")
            
        case .failure(let error):
            throw error
        }
    }
    
    private static func summarize(_ result: SquatAnalysisResult) -> String {
        var s = ""
        s += "═══════════════════════════════════════════════════════\n"
        s += "           SQUAT ANALYSIS RESULTS SUMMARY\n"
        s += "═══════════════════════════════════════════════════════\n\n"
        s += "📊 OVERALL SCORE: \(String(format: "%.1f", result.overallScore))/100\n\n"
        s += "🏋️ REPS DETECTED: \(result.reps.count)\n"
        if !result.reps.isEmpty {
            s += "   • Full reps: \(result.reps.filter { $0.isFullRep }.count)/\(result.reps.count)\n"
            s += "   • Reached depth: \(result.reps.filter { $0.reachedDepth }.count)/\(result.reps.count)\n\n"
            s += "📋 REP DETAILS:\n"
            for rep in result.reps {
                s += "   Rep \(rep.repNumber): Frames \(rep.startFrame) → \(rep.bottomFrame) → \(rep.endFrame)\n"
                s += "     Full: \(rep.isFullRep ? "✅" : "❌"), Depth: \(rep.reachedDepth ? "✅" : "❌")\n"
            }
        }
        s += "\n💬 FEEDBACK: \(result.feedback.count) items\n"
        s += "═══════════════════════════════════════════════════════\n"
        return s
    }
}
