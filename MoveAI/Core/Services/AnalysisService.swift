//
//  AnalysisService.swift
//  MoveAI
//
//  Created by Dave Mathew on 10/11/25.
//

import Foundation

protocol AnalysisServiceProtocol {
    func analyzeMovement(_ recording: MovementRecording) async throws -> AnalysisResult
}

class MockAnalysisService: AnalysisServiceProtocol {
    func analyzeMovement(_ recording: MovementRecording) async throws -> AnalysisResult {
        // Simulate analysis delay
        try await Task.sleep(nanoseconds: 2_000_000_000) // 2 seconds
        
        // Generate mock feedback based on movement type
        let feedback = generateMockFeedback(for: recording.movementType)
        let score = calculateMockScore(from: feedback)
        
        return AnalysisResult(score: score, feedback: feedback)
    }
    
    private func generateMockFeedback(for movementType: MovementType) -> [FormFeedback] {
        switch movementType {
        case .squat:
            return [
                FormFeedback(
                    category: .posture,
                    message: "Good chest position throughout the movement",
                    severity: .good,
                    timestamp: 1.2
                ),
                FormFeedback(
                    category: .rangeOfMotion,
                    message: "Hip crease below knee level - excellent depth",
                    severity: .excellent,
                    timestamp: 2.1
                ),
                FormFeedback(
                    category: .stability,
                    message: "Slight forward lean on ascent - engage core more",
                    severity: .warning,
                    timestamp: 3.4
                )
            ]
        case .deadlift:
            return [
                FormFeedback(
                    category: .posture,
                    message: "Excellent neutral spine position",
                    severity: .excellent,
                    timestamp: 0.8
                ),
                FormFeedback(
                    category: .tempo,
                    message: "Good controlled descent",
                    severity: .good,
                    timestamp: 2.3
                ),
                FormFeedback(
                    category: .safety,
                    message: "Keep bar close to body throughout lift",
                    severity: .warning,
                    timestamp: 1.7
                )
            ]
        case .benchPress:
            return [
                FormFeedback(
                    category: .posture,
                    message: "Good shoulder blade retraction",
                    severity: .good,
                    timestamp: 0.5
                ),
                FormFeedback(
                    category: .rangeOfMotion,
                    message: "Full range of motion - bar touches chest",
                    severity: .excellent,
                    timestamp: 1.8
                ),
                FormFeedback(
                    category: .stability,
                    message: "Maintain tight arch throughout movement",
                    severity: .warning,
                    timestamp: 2.9
                )
            ]
        }
    }
    
    private func calculateMockScore(from feedback: [FormFeedback]) -> Double {
        let weights: [FeedbackSeverity: Double] = [
            .excellent: 1.0,
            .good: 0.8,
            .warning: 0.6,
            .critical: 0.3
        ]
        
        let totalWeight = feedback.reduce(0) { sum, item in
            sum + (weights[item.severity] ?? 0.5)
        }
        
        let averageWeight = totalWeight / Double(feedback.count)
        return min(100, max(0, averageWeight * 100))
    }
}

// MARK: - Live Analysis Service (Placeholder)

class LiveAnalysisService: AnalysisServiceProtocol {
    func analyzeMovement(_ recording: MovementRecording) async throws -> AnalysisResult {
        // TODO: Implement actual AI analysis
        // This would integrate with your chosen ML service
        throw AnalysisError.notImplemented
    }
}

enum AnalysisError: LocalizedError {
    case notImplemented
    case invalidVideo
    case analysisFailed
    
    var errorDescription: String? {
        switch self {
        case .notImplemented:
            return "Live analysis not yet implemented"
        case .invalidVideo:
            return "Invalid video file for analysis"
        case .analysisFailed:
            return "Analysis failed - please try again"
        }
    }
}

