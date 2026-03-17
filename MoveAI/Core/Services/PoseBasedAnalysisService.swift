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
            let summary = AnalysisSummaryBuilder.build(
                movementType: recording.movementType,
                feedback: feedback,
                reps: reps,
                depthMetrics: depthMetrics
            )

            return AnalysisResult(
                score: score,
                feedback: feedback,
                reps: reps,
                depthMetrics: depthMetrics,
                analysisSummary: summary
            )

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

        MuayThaiDebug.log("PoseBasedAnalysisService.analyzeMuayThai: poses=\(poseData.count) selectedTechnique=\(recording.technique?.rawValue ?? "nil") selectedStance=\(recording.fightStance?.rawValue ?? "nil") comboEnabled=\(ProcessInfo.processInfo.environment["MOVEAI_ENABLE_MUAY_THAI_COMBO_ANALYZER"] != "0")")

        if let technique = recording.technique {
            MuayThaiDebug.log("PoseBasedAnalysisService: using explicit technique=\(technique.rawValue)")
            return MuayThaiAnalyzer.analyze(
                poses: poseData,
                technique: technique,
                fightStance: recording.fightStance
            )
        }

        let comboAnalyzerEnabled = ProcessInfo.processInfo.environment["MOVEAI_ENABLE_MUAY_THAI_COMBO_ANALYZER"] != "0"
        if comboAnalyzerEnabled,
           let comboDetection = MuayThaiComboDetector.detect(poses: poseData, preferredStance: recording.fightStance),
           !comboDetection.attempts.isEmpty {
            let summary = comboDetection.attempts.map { attempt in "\(attempt.technique.rawValue):\(MuayThaiDebug.format(attempt.confidence))" }.joined(separator: ",")
            MuayThaiDebug.log("PoseBasedAnalysisService: combo auto-detect attempts=\(comboDetection.attempts.count) [\(summary)]")
            return MuayThaiAnalyzer.analyzeCombo(
                poses: poseData,
                comboDetection: comboDetection
            )
        }

        if let detection = MuayThaiTechniqueDetector.detect(poses: poseData, preferredStance: recording.fightStance) {
            MuayThaiDebug.log("PoseBasedAnalysisService: single-technique auto-detect=\(detection.technique.rawValue) confidence=\(MuayThaiDebug.format(detection.confidence)) attempts=\(detection.attemptsCount) inferredStance=\(detection.stanceResolution.stance.rawValue) stanceConfidence=\(MuayThaiDebug.format(detection.stanceResolution.confidence))")
            return MuayThaiAnalyzer.analyze(
                poses: poseData,
                technique: detection.technique,
                fightStance: recording.fightStance,
                detectedTechnique: detection.technique,
                detectionConfidence: detection.confidence
            )
        }

        MuayThaiDebug.log("PoseBasedAnalysisService: auto-detect failed (no confident technique)")
        throw AnalysisError.muayThaiTechniqueAutoDetectionFailed(confidence: nil)
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
