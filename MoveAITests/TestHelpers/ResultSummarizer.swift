//
//  ResultSummarizer.swift
//  MoveAITests
//
//  Created by Dave Mathew on 1/28/25.
//

import Foundation
@testable import MoveAI

/// Formats and summarizes analysis results in readable format
class ResultSummarizer {
    
    /// Generate a detailed summary of analysis results
    static func summarize(_ result: SquatAnalysisResult) -> String {
        var summary = String()
        
        // Header
        summary += "═══════════════════════════════════════════════════════\n"
        summary += "           SQUAT ANALYSIS RESULTS SUMMARY\n"
        summary += "═══════════════════════════════════════════════════════\n\n"
        
        // Overall Score
        summary += "📊 OVERALL SCORE: \(String(format: "%.1f", result.overallScore))/100\n\n"
        
        // Rep Summary
        summary += "🏋️ REPS DETECTED: \(result.reps.count)\n"
        if !result.reps.isEmpty {
            let fullReps = result.reps.filter { $0.isFullRep }.count
            let reachedDepth = result.reps.filter { $0.reachedDepth }.count
            summary += "   • Full reps: \(fullReps)/\(result.reps.count)\n"
            summary += "   • Reached depth: \(reachedDepth)/\(result.reps.count)\n"
            summary += "   • Returned to start: \(result.reps.filter { $0.returnedToStart }.count)/\(result.reps.count)\n\n"
            
            // Rep Details
            summary += "📋 REP DETAILS:\n"
            for rep in result.reps {
                summary += "   Rep \(rep.repNumber):\n"
                summary += "     • Frames: \(rep.startFrame) → \(rep.bottomFrame) → \(rep.endFrame)\n"
                summary += "     • Duration: \(String(format: "%.2f", rep.endTime - rep.startTime))s\n"
                summary += "     • Full rep: \(rep.isFullRep ? "✅" : "❌")\n"
                summary += "     • Reached depth: \(rep.reachedDepth ? "✅" : "❌")\n"
                summary += "     • Returned to start: \(rep.returnedToStart ? "✅" : "❌")\n"
            }
            summary += "\n"
        }
        
        // Depth Analysis
        if !result.depthMetrics.isEmpty {
            summary += "📏 DEPTH ANALYSIS:\n"
            let depthByRep = Dictionary(grouping: result.depthMetrics, by: { $0.repNumber ?? 0 })
            
            for repNum in result.reps.map({ $0.repNumber }).sorted() {
                if let repDepths = depthByRep[repNum], !repDepths.isEmpty {
                    let deepest = repDepths.max(by: { $0.depthPercentage < $1.depthPercentage })!
                    summary += "   Rep \(repNum):\n"
                    summary += "     • Max depth: \(String(format: "%.1f", deepest.depthPercentage))%\n"
                    summary += "     • At proper depth: \(deepest.isAtDepth ? "✅" : "❌")\n"
                }
            }
            
            if let worst = result.worstDepth {
                summary += "\n   ⚠️ Worst depth: Rep \(worst.repNumber ?? 0) - \(String(format: "%.1f", worst.depthPercentage))%"
                if !worst.isAtDepth {
                    summary += " (SHALLOW)\n"
                } else {
                    summary += "\n"
                }
            }
            summary += "\n"
        }
        
        // Knee Analysis
        if !result.kneeMetrics.isEmpty {
            summary += "🦵 KNEE ANALYSIS:\n"
            let kneeByRep = Dictionary(grouping: result.kneeMetrics, by: { $0.repNumber ?? 0 })
            let repsWithValgus = Set(result.kneeMetrics.filter { $0.hasValgus }.compactMap { $0.repNumber })
            
            if !repsWithValgus.isEmpty {
                summary += "   ⚠️ Knee valgus detected in reps: \(repsWithValgus.sorted().map { String($0) }.joined(separator: ", "))\n"
            } else {
                summary += "   ✅ No knee valgus detected\n"
            }
            
            if let worst = result.worstKneeAngle {
                summary += "   ⚠️ Worst knee angle: Rep \(worst.repNumber ?? 0) - valgus: \(String(format: "%.2f", worst.kneeValgus))\n"
            }
            summary += "\n"
        }
        
        // Feedback Summary
        if !result.feedback.isEmpty {
            summary += "💬 FEEDBACK (\(result.feedback.count) items):\n"
            
            let bySeverity = Dictionary(grouping: result.feedback, by: { $0.severity })
            
            if let critical = bySeverity[.critical], !critical.isEmpty {
                summary += "   🔴 CRITICAL (\(critical.count)):\n"
                for item in critical.prefix(5) {
                    summary += "     • \(item.message)\n"
                    if let repNum = item.repNumber {
                        summary += "       (Rep \(repNum))\n"
                    }
                }
                if critical.count > 5 {
                    summary += "     ... and \(critical.count - 5) more\n"
                }
                summary += "\n"
            }
            
            if let warnings = bySeverity[.warning], !warnings.isEmpty {
                summary += "   🟠 WARNINGS (\(warnings.count)):\n"
                for item in warnings.prefix(5) {
                    summary += "     • \(item.message)\n"
                    if let repNum = item.repNumber {
                        summary += "       (Rep \(repNum))\n"
                    }
                }
                if warnings.count > 5 {
                    summary += "     ... and \(warnings.count - 5) more\n"
                }
                summary += "\n"
            }
            
            if let good = bySeverity[.good], !good.isEmpty {
                summary += "   🟢 GOOD (\(good.count)):\n"
                for item in good.prefix(3) {
                    summary += "     • \(item.message)\n"
                }
                if good.count > 3 {
                    summary += "     ... and \(good.count - 3) more\n"
                }
                summary += "\n"
            }
        }
        
        // Phases Summary
        if !result.phases.isEmpty {
            summary += "🔄 MOVEMENT PHASES: \(result.phases.count) detected\n"
            let phaseTypes = Dictionary(grouping: result.phases, by: { $0.type })
            for (type, phases) in phaseTypes.sorted(by: { $0.key.rawValue < $1.key.rawValue }) {
                summary += "   • \(type.rawValue.capitalized): \(phases.count)\n"
            }
            summary += "\n"
        }
        
        summary += "═══════════════════════════════════════════════════════\n"
        
        return summary
    }
    
    /// Generate a brief summary (one-liner style)
    static func summarizeBrief(_ result: SquatAnalysisResult) -> String {
        var brief = String()
        brief += "Score: \(String(format: "%.1f", result.overallScore))/100 | "
        brief += "Reps: \(result.reps.count) ("
        brief += "\(result.reps.filter { $0.isFullRep }.count) full, "
        brief += "\(result.reps.filter { $0.reachedDepth }.count) at depth) | "
        brief += "Feedback: \(result.feedback.count) items"
        
        let criticalCount = result.feedback.filter { $0.severity == .critical }.count
        let warningCount = result.feedback.filter { $0.severity == .warning }.count
        if criticalCount > 0 {
            brief += " (\(criticalCount) critical, \(warningCount) warnings)"
        }
        
        return brief
    }
    
    /// Save summary to file
    static func saveSummary(_ result: SquatAnalysisResult, to url: URL) throws {
        let summary = summarize(result)
        try summary.write(to: url, atomically: true, encoding: .utf8)
    }
    
    /// Save results as JSON
    static func saveJSON(_ result: SquatAnalysisResult, to url: URL) throws {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        
        let data = try encoder.encode(result)
        try data.write(to: url)
    }
}
