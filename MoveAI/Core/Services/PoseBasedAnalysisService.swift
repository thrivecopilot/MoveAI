//
//  PoseBasedAnalysisService.swift
//  MoveAI
//
//  Created by Dave Mathew on 10/11/25.
//

import Foundation

/// Analysis service that uses pose detection data to analyze movements
class PoseBasedAnalysisService: AnalysisServiceProtocol {

    func analyzeMovement(_ recording: MovementRecording) async throws -> AnalysisResult {
        // Check if we have pose data
        guard let poseData = recording.poseData, !poseData.isEmpty else {
            throw AnalysisError.noPoseData
        }

        // Route to appropriate analyzer based on movement type
        switch recording.movementType {
        case .squat:
            return try analyzeSquat(recording: recording, poseData: poseData)
        case .deadlift:
            // TODO: Implement deadlift analysis
            throw AnalysisError.notImplemented
        case .benchPress:
            // TODO: Implement bench press analysis
            throw AnalysisError.notImplemented
        case .muayThai:
            return try analyzeMuayThai(recording: recording, poseData: poseData)
        }
    }

    // MARK: - Squat Analysis

    private func analyzeSquat(recording: MovementRecording, poseData: [PoseDetectionResult]) throws -> AnalysisResult {
        // Use SquatAnalyzer to analyze the full sequence
        let result = SquatAnalyzer.analyzeFullSequence(poseData)

        switch result {
        case .success(let analysisResult):
            // Convert SquatAnalysisResult to AnalysisResult
            let feedback = analysisResult.feedback
            let score = analysisResult.overallScore
            let reps = analysisResult.reps
            let depthMetrics = analysisResult.depthMetrics

            return AnalysisResult(score: score, feedback: feedback, reps: reps, depthMetrics: depthMetrics)

        case .failure(let error):
            // Convert SquatAnalysisError to AnalysisError
            throw convertSquatError(error)
        }
    }

    // MARK: - Muay Thai Analysis

    private func analyzeMuayThai(recording: MovementRecording, poseData: [PoseDetectionResult]) throws -> AnalysisResult {
        if ProcessInfo.processInfo.environment["MOVEAI_ENABLE_MUAY_THAI_ANALYZER"] == "0" {
            throw AnalysisError.muayThaiAnalysisDisabled
        }

        guard let technique = recording.technique else {
            throw AnalysisError.muayThaiTechniqueRequired
        }

        return MuayThaiAnalyzer.analyze(
            poses: poseData,
            technique: technique,
            fightStance: recording.fightStance
        )
    }

    // MARK: - Error Conversion

    private func convertSquatError(_ error: SquatAnalysisError) -> AnalysisError {
        switch error {
        case .noPoseData:
            return .noPoseData
        case .insufficientValidFrames(let count, let required):
            return .insufficientFrames(actual: count, required: required)
        case .missingRequiredKeypoints(let missing):
            return .missingKeypoints(missing: missing)
        case .lowPoseConfidence(let avg, let threshold):
            return .lowConfidence(averageConfidence: avg, threshold: threshold)
        case .noMovementPhasesDetected:
            return .noMovementDetected
        case .invalidPoseSequence(let reason):
            return .analysisFailed(reason: reason)
        }
    }
}
