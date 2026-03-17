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
        case .muayThai:
            return [
                FormFeedback(
                    category: .posture,
                    message: "Rear hand stayed active in guard on most attempts",
                    severity: .good,
                    timestamp: 0.9
                ),
                FormFeedback(
                    category: .safety,
                    message: "Turn your hip through the punch for more power",
                    severity: .warning,
                    timestamp: 1.7
                ),
                FormFeedback(
                    category: .stability,
                    message: "Keep your stance width stable during movement",
                    severity: .warning,
                    timestamp: 2.4
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

// MARK: - Detailed Error Protocol

protocol DetailedError: LocalizedError {
    var primaryMessage: String { get }
    var diagnosticInfo: String? { get }
    var userTips: [String] { get }
    var recoverySuggestion: String? { get }
}

extension DetailedError {
    var errorDescription: String? {
        return primaryMessage
    }
}

// MARK: - Analysis Error

enum AnalysisError: DetailedError {
    case notImplemented
    case muayThaiAnalysisDisabled
    case muayThaiTechniqueRequired
    case muayThaiTechniqueAutoDetectionFailed(confidence: Double?)
    case noPoseData
    case insufficientFrames(actual: Int, required: Int)
    case missingKeypoints(missing: [String])
    case lowConfidence(averageConfidence: Double, threshold: Double)
    case noMovementDetected
    case cameraAngleIssue
    case analysisFailed(reason: String)
    case invalidVideo
    case videoProcessingFailed(String)
    case unsupportedVideoFormat
    case videoCorrupted
    case processingTimeout
    
    var primaryMessage: String {
        switch self {
        case .notImplemented:
            return "Analysis not yet implemented for this movement type"
        case .muayThaiAnalysisDisabled:
            return "Muay Thai analysis is currently unavailable in this build"
        case .muayThaiTechniqueRequired:
            return "Select a Muay Thai movement (jab, cross, etc.) before analysis"
        case .muayThaiTechniqueAutoDetectionFailed(let confidence):
            if let confidence {
                let pct = Int((confidence * 100.0).rounded())
                return "Couldn't confidently detect the Muay Thai movement from this clip (confidence: \(pct)%)"
            }
            return "Couldn't confidently detect the Muay Thai movement from this clip"
        case .noPoseData:
            return "No pose detection data available"
        case .insufficientFrames(let actual, let required):
            return "Not enough valid frames detected (\(actual) of \(required) required)"
        case .missingKeypoints(let missing):
            let joints = missing.joined(separator: ", ")
            return "Required body joints not detected: \(joints)"
        case .lowConfidence(let avg, let threshold):
            return "Pose detection confidence too low (average: \(String(format: "%.1f", avg * 100))%, need: \(String(format: "%.1f", threshold * 100))%)"
        case .noMovementDetected:
            return "No movement pattern detected in the recording"
        case .cameraAngleIssue:
            return "Camera angle not suitable for analysis"
        case .analysisFailed(let reason):
            return "Analysis failed: \(reason)"
        case .invalidVideo:
            return "Invalid video file for analysis"
        case .videoProcessingFailed(let reason):
            return "Video processing failed: \(reason)"
        case .unsupportedVideoFormat:
            return "Video format is not supported. Please use MP4 or MOV format."
        case .videoCorrupted:
            return "Video file appears to be corrupted or unreadable"
        case .processingTimeout:
            return "Video processing took too long. Please try a shorter video."
        }
    }
    
    var diagnosticInfo: String? {
        switch self {
        case .insufficientFrames(let actual, let required):
            return "Detected \(actual) valid frames, but need at least \(required) frames for analysis"
        case .missingKeypoints(let missing):
            return "Missing keypoints: \(missing.joined(separator: ", "))"
        case .lowConfidence(let avg, let threshold):
            return "Average confidence: \(String(format: "%.2f", avg)), threshold: \(String(format: "%.2f", threshold))"
        case .analysisFailed(let reason):
            return reason
        default:
            return nil
        }
    }
    
    var userTips: [String] {
        switch self {
        case .noPoseData:
            return VideoCaptureTips.tipsForNoPoseData
        case .insufficientFrames:
            return VideoCaptureTips.tipsForInsufficientFrames
        case .missingKeypoints:
            return VideoCaptureTips.tipsForMissingKeypoints
        case .lowConfidence:
            return VideoCaptureTips.tipsForLowConfidence
        case .noMovementDetected:
            return VideoCaptureTips.tipsForNoMovement
        case .cameraAngleIssue:
            return VideoCaptureTips.tipsForCameraAngle
        case .muayThaiAnalysisDisabled:
            return ["Muay Thai analysis is temporarily disabled in this build.", "Try again in a build with Muay Thai analysis enabled."]
        case .muayThaiTechniqueRequired:
            return ["Select a specific Muay Thai movement before running analysis.", "Then record or upload your set again for technique-specific feedback."]
        case .muayThaiTechniqueAutoDetectionFailed:
            return ["Auto-detection could not confidently identify the movement in this clip.", "Choose the movement manually, or upload a clip with clearer full-body visibility and a distinct strike pattern."]
        case .videoProcessingFailed, .unsupportedVideoFormat, .videoCorrupted, .processingTimeout:
            return VideoCaptureTips.tipsForVideoProcessing
        default:
            return VideoCaptureTips.generalTips
        }
    }
    
    var recoverySuggestion: String? {
        switch self {
        case .insufficientFrames:
            return "Try recording for at least 3-5 seconds with continuous movement"
        case .missingKeypoints:
            return "Reposition yourself so your full body is visible in the frame"
        case .lowConfidence:
            return "Improve lighting and ensure clear background contrast"
        case .cameraAngleIssue:
            return "Position camera at a 45-90 degree angle to your side"
        case .muayThaiAnalysisDisabled:
            return "Use a build with Muay Thai analysis enabled"
        case .muayThaiTechniqueRequired:
            return "Choose jab, cross, hook, kick, knee, elbow, or movement before analysis"
        case .muayThaiTechniqueAutoDetectionFailed:
            return "Select the movement manually or upload a clearer clip with one primary strike pattern"
        case .unsupportedVideoFormat:
            return "Convert your video to MP4 or MOV format and try again"
        case .videoCorrupted:
            return "Try selecting a different video file"
        case .processingTimeout:
            return "Try with a shorter video (under 30 seconds)"
        default:
            return "Try recording again with better positioning and lighting"
        }
    }
}

