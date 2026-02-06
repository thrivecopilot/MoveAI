//
//  PreviewData.swift
//  MoveAI
//
//  Fake data for SwiftUI previews so layouts can be iterated in the Xcode canvas
//  without running the app. Based on test_case_1 structure (4 reps, mixed quality).
//

#if DEBUG
import Foundation

enum PreviewData {

    /// Placeholder URL for preview; AVPlayer will show black in canvas. Safe for layout iteration.
    static var placeholderVideoURL: URL {
        URL(fileURLWithPath: "/tmp/preview.mov")
    }

    /// Session with full analysis (score, reps, feedback). Use for session-detail and sheet previews.
    static func sessionWithAnalysis() -> Session {
        Session(
            movementType: .squat,
            videoURL: placeholderVideoURL,
            timestamp: Date(),
            analysisResult: analysisResult(),
            poseData: nil,
            notes: "Preview notes for layout iteration.",
            isRecordedLive: false
        )
    }

    /// Session without analysis (e.g. "No analysis yet" state).
    static func sessionWithoutAnalysis() -> Session {
        Session(
            movementType: .squat,
            videoURL: placeholderVideoURL,
            timestamp: Date(),
            analysisResult: nil,
            poseData: nil,
            notes: nil,
            isRecordedLive: false
        )
    }

    /// Analysis result shaped like test_case_1: 4 reps, mix of excellent/shallow/back rounding.
    static func analysisResult() -> AnalysisResult {
        let reps = squatReps()
        let depthMetrics = depthMetricsForReps()
        let feedback: [FormFeedback] = [
            FormFeedback(category: .safety, message: "Back rounding at bottom on rep 3.", severity: .warning, timestamp: 11.67, repNumber: 3),
            FormFeedback(category: .rangeOfMotion, message: "Rep 4 was shallow; aim for hip crease below knee.", severity: .warning, timestamp: 17.23, repNumber: 4),
            FormFeedback(category: .posture, message: "Good bracing and upright torso on reps 1–2.", severity: .good, timestamp: 3.1, repNumber: 1),
            FormFeedback(category: .stability, message: "Knees tracked well over toes.", severity: .excellent, timestamp: 7.83, repNumber: 2),
        ]
        return AnalysisResult(
            score: 72,
            feedback: feedback,
            reps: reps,
            depthMetrics: depthMetrics
        )
    }

    // MARK: - Reps (test_case_1: frames 20→93→157, 157→235→285, 300→350→430, 480→517→540 at 30 fps)
    private static let frameRate = 30.0

    private static func squatReps() -> [SquatRep] {
        [
            SquatRep(repNumber: 1, startFrame: 20, endFrame: 157, startTime: 20 / frameRate, endTime: 157 / frameRate, isFullRep: true, bottomFrame: 93, bottomTime: 93 / frameRate, reachedDepth: true, returnedToStart: true),
            SquatRep(repNumber: 2, startFrame: 157, endFrame: 285, startTime: 157 / frameRate, endTime: 285 / frameRate, isFullRep: true, bottomFrame: 235, bottomTime: 235 / frameRate, reachedDepth: true, returnedToStart: true),
            SquatRep(repNumber: 3, startFrame: 300, endFrame: 430, startTime: 300 / frameRate, endTime: 430 / frameRate, isFullRep: true, bottomFrame: 350, bottomTime: 350 / frameRate, reachedDepth: true, returnedToStart: true),
            SquatRep(repNumber: 4, startFrame: 480, endFrame: 540, startTime: 480 / frameRate, endTime: 540 / frameRate, isFullRep: true, bottomFrame: 517, bottomTime: 517 / frameRate, reachedDepth: false, returnedToStart: true),
        ]
    }

    private static func depthMetricsForReps() -> [DepthAnalysis] {
        let baseDate = Date()
        return [
            DepthAnalysis(hipHeight: 0.72, kneeHeight: 0.68, isAtDepth: true, depthPercentage: 102, timestamp: baseDate, repNumber: 1),
            DepthAnalysis(hipHeight: 0.71, kneeHeight: 0.67, isAtDepth: true, depthPercentage: 100, timestamp: baseDate, repNumber: 2),
            DepthAnalysis(hipHeight: 0.75, kneeHeight: 0.70, isAtDepth: true, depthPercentage: 98, timestamp: baseDate, repNumber: 3),
            DepthAnalysis(hipHeight: 0.82, kneeHeight: 0.78, isAtDepth: false, depthPercentage: 78, timestamp: baseDate, repNumber: 4),
        ]
    }
}
#endif
