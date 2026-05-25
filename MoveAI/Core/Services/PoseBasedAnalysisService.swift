//
//  PoseBasedAnalysisService.swift
//  MoveAI
//
//  Created by Dave Mathew on 10/11/25.
//

import Foundation
import CoreGraphics

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
        case .running:
            return try analyzeRunning(recording: recording, poseData: poseData)
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

        if let fallback = MuayThaiTechniqueDetector.detectBestEffort(
            poses: poseData,
            preferredStance: recording.fightStance
        ) {
            MuayThaiDebug.log(
                "PoseBasedAnalysisService: best-effort auto-detect=\(fallback.technique.rawValue) confidence=\(MuayThaiDebug.format(fallback.confidence)) attempts=\(fallback.attemptsCount) inferredStance=\(fallback.stanceResolution.stance.rawValue) stanceConfidence=\(MuayThaiDebug.format(fallback.stanceResolution.confidence))"
            )
            return MuayThaiAnalyzer.analyze(
                poses: poseData,
                technique: fallback.technique,
                fightStance: recording.fightStance,
                detectedTechnique: fallback.technique,
                detectionConfidence: fallback.confidence
            )
        }

        MuayThaiDebug.log("PoseBasedAnalysisService: auto-detect failed (no confident technique)")
        throw AnalysisError.muayThaiTechniqueAutoDetectionFailed(confidence: nil)
    }

    // MARK: - Running Analysis (v1 heuristic)

    private func analyzeRunning(recording: MovementRecording, poseData: [PoseDetectionResult]) throws -> AnalysisResult {
        let validFrames = poseData.filter { !$0.keypoints.isEmpty }
        let totalFrames = poseData.count
        let nonEmptyRatio = totalFrames > 0 ? Double(validFrames.count) / Double(totalFrames) : 0

        var feedback: [FormFeedback] = []

        if validFrames.count < 45 || nonEmptyRatio < 0.6 {
            feedback.append(
                FormFeedback(
                    category: .safety,
                    message: "Running capture quality limited: full-body visibility was not consistent enough for confident gait checks.",
                    severity: .warning,
                    timestamp: 0,
                    issueKind: .runningCaptureQualityLimited
                )
            )

            let score = 62.0
            let summary = AnalysisSummaryBuilder.build(
                movementType: recording.movementType,
                feedback: feedback,
                reps: nil,
                depthMetrics: nil
            )
            return AnalysisResult(score: score, feedback: feedback, analysisSummary: summary)
        }

        let cadence = estimateCadenceSpm(validFrames)
        if let cadence, cadence < 158 {
            feedback.append(
                FormFeedback(
                    category: .tempo,
                    message: "Running cadence is low for this clip; step turnover can be quicker.",
                    severity: .warning,
                    timestamp: averageTimestamp(validFrames),
                    issueKind: .runningLowCadence,
                    metrics: [FeedbackMetric(kind: .runningCadenceSpm, value: cadence, unit: .count)]
                )
            )
        }

        if let torsoLean = averageTorsoLeanDegrees(validFrames), torsoLean > 20 {
            feedback.append(
                FormFeedback(
                    category: .posture,
                    message: "Forward lean is elevated during running.",
                    severity: .warning,
                    timestamp: averageTimestamp(validFrames),
                    issueKind: .runningExcessiveForwardLean,
                    metrics: [FeedbackMetric(kind: .runningTorsoLeanDegrees, value: torsoLean, unit: .degrees)]
                )
            )
        }

        if let verticalOsc = verticalOscillationRatio(validFrames), verticalOsc > 0.075 {
            feedback.append(
                FormFeedback(
                    category: .stability,
                    message: "Vertical oscillation is high (too much bounce).",
                    severity: .warning,
                    timestamp: averageTimestamp(validFrames),
                    issueKind: .runningExcessiveVerticalOscillation,
                    metrics: [FeedbackMetric(kind: .runningVerticalOscillationRatio, value: verticalOsc, unit: .ratio)]
                )
            )
        }

        if let strideSymmetry = strideSymmetryRatio(validFrames), strideSymmetry < 0.86 {
            feedback.append(
                FormFeedback(
                    category: .stability,
                    message: "Stride asymmetry detected between left and right sides.",
                    severity: .warning,
                    timestamp: averageTimestamp(validFrames),
                    issueKind: .runningAsymmetricStride,
                    metrics: [FeedbackMetric(kind: .runningStrideSymmetryRatio, value: strideSymmetry, unit: .ratio)]
                )
            )
        }

        if let overstride = overstrideRatio(validFrames), overstride > 1.45 {
            feedback.append(
                FormFeedback(
                    category: .rangeOfMotion,
                    message: "Overstriding detected: foot strike is landing too far ahead.",
                    severity: .warning,
                    timestamp: averageTimestamp(validFrames),
                    issueKind: .runningOverstriding,
                    metrics: [FeedbackMetric(kind: .runningOverstrideRatio, value: overstride, unit: .ratio)]
                )
            )
        }

        if feedback.isEmpty {
            feedback.append(
                FormFeedback(
                    category: .posture,
                    message: "Running form looked stable in this clip.",
                    severity: .good,
                    timestamp: averageTimestamp(validFrames)
                )
            )
        }

        let warningCount = feedback.filter { $0.severity == .warning || $0.severity == .critical }.count
        let score = max(55.0, 100.0 - Double(warningCount * 12))
        let summary = AnalysisSummaryBuilder.build(
            movementType: recording.movementType,
            feedback: feedback,
            reps: nil,
            depthMetrics: nil
        )

        return AnalysisResult(score: score, feedback: feedback, analysisSummary: summary)
    }

    private func averageTimestamp(_ poses: [PoseDetectionResult]) -> TimeInterval {
        guard !poses.isEmpty else { return 0 }
        let total = poses.reduce(0.0) { partial, pose in
            partial + pose.timestamp.timeIntervalSince1970
        }
        return total / Double(poses.count)
    }

    private func estimateCadenceSpm(_ poses: [PoseDetectionResult]) -> Double? {
        var deltas: [Double] = []
        for pose in poses {
            guard
                let left = keypoint(.leftAnkle, in: pose),
                let right = keypoint(.rightAnkle, in: pose)
            else { continue }
            deltas.append(Double(left.position.x - right.position.x))
        }

        guard deltas.count >= 8 else { return nil }

        var signChanges = 0
        var lastSign = deltas.first.map { $0 >= 0 ? 1 : -1 } ?? 1
        var framesSinceChange = 0

        for delta in deltas.dropFirst() {
            let sign = delta >= 0 ? 1 : -1
            framesSinceChange += 1
            if sign != lastSign && framesSinceChange >= 4 {
                signChanges += 1
                lastSign = sign
                framesSinceChange = 0
            }
        }

        guard signChanges > 0 else { return nil }

        let start = poses.first?.timestamp.timeIntervalSince1970 ?? 0
        let end = poses.last?.timestamp.timeIntervalSince1970 ?? start
        let duration = max(0.5, end - start)
        return (Double(signChanges) * 60.0) / duration
    }

    private func averageTorsoLeanDegrees(_ poses: [PoseDetectionResult]) -> Double? {
        let angles = poses.compactMap { pose -> Double? in
            guard
                let leftShoulder = keypoint(.leftShoulder, in: pose),
                let rightShoulder = keypoint(.rightShoulder, in: pose),
                let leftHip = keypoint(.leftHip, in: pose),
                let rightHip = keypoint(.rightHip, in: pose)
            else { return nil }

            let shoulderMid = midpoint(leftShoulder.position, rightShoulder.position)
            let hipMid = midpoint(leftHip.position, rightHip.position)
            let dx = Double(shoulderMid.x - hipMid.x)
            let dy = Double(shoulderMid.y - hipMid.y)
            guard abs(dy) > 0.0001 else { return nil }
            return abs(atan2(dx, dy)) * 180.0 / .pi
        }

        return mean(angles)
    }

    private func verticalOscillationRatio(_ poses: [PoseDetectionResult]) -> Double? {
        let hipMidY: [Double] = poses.compactMap { pose in
            guard
                let leftHip = keypoint(.leftHip, in: pose),
                let rightHip = keypoint(.rightHip, in: pose)
            else { return nil }
            return Double((leftHip.position.y + rightHip.position.y) / 2.0)
        }

        let referenceLegLengths = poses.compactMap { pose -> Double? in
            guard
                let leftHip = keypoint(.leftHip, in: pose),
                let leftKnee = keypoint(.leftKnee, in: pose),
                let leftAnkle = keypoint(.leftAnkle, in: pose),
                let rightHip = keypoint(.rightHip, in: pose),
                let rightKnee = keypoint(.rightKnee, in: pose),
                let rightAnkle = keypoint(.rightAnkle, in: pose)
            else { return nil }

            let leftLeg = distance(leftHip.position, leftKnee.position) + distance(leftKnee.position, leftAnkle.position)
            let rightLeg = distance(rightHip.position, rightKnee.position) + distance(rightKnee.position, rightAnkle.position)
            return Double((leftLeg + rightLeg) / 2.0)
        }

        guard let stdev = standardDeviation(hipMidY), let legLength = mean(referenceLegLengths), legLength > 0 else {
            return nil
        }
        return stdev / legLength
    }

    private func strideSymmetryRatio(_ poses: [PoseDetectionResult]) -> Double? {
        let leftX = poses.compactMap { pose in keypoint(.leftAnkle, in: pose).map { Double($0.position.x) } }
        let rightX = poses.compactMap { pose in keypoint(.rightAnkle, in: pose).map { Double($0.position.x) } }
        guard leftX.count > 6, rightX.count > 6 else { return nil }

        let leftAmp = (leftX.max() ?? 0) - (leftX.min() ?? 0)
        let rightAmp = (rightX.max() ?? 0) - (rightX.min() ?? 0)
        let larger = max(leftAmp, rightAmp)
        guard larger > 0 else { return nil }
        return min(leftAmp, rightAmp) / larger
    }

    private func overstrideRatio(_ poses: [PoseDetectionResult]) -> Double? {
        let ratios = poses.compactMap { pose -> Double? in
            guard
                let leftAnkle = keypoint(.leftAnkle, in: pose),
                let rightAnkle = keypoint(.rightAnkle, in: pose),
                let leftHip = keypoint(.leftHip, in: pose),
                let rightHip = keypoint(.rightHip, in: pose),
                let leftKnee = keypoint(.leftKnee, in: pose),
                let rightKnee = keypoint(.rightKnee, in: pose)
            else { return nil }

            let strideSpan = Double(abs(leftAnkle.position.x - rightAnkle.position.x))
            let hipWidth = Double(abs(leftHip.position.x - rightHip.position.x))
            let legScale = Double(distance(leftHip.position, leftKnee.position) + distance(rightHip.position, rightKnee.position)) / 2.0
            let normalizer = max(0.0001, max(hipWidth, legScale))
            return strideSpan / normalizer
        }

        return mean(ratios)
    }

    private func keypoint(_ joint: BodyJoint, in pose: PoseDetectionResult) -> PoseKeypoint? {
        pose.keypoints.first(where: { $0.name == joint.rawValue })
    }

    private func midpoint(_ a: CGPoint, _ b: CGPoint) -> CGPoint {
        CGPoint(x: (a.x + b.x) / 2.0, y: (a.y + b.y) / 2.0)
    }

    private func distance(_ a: CGPoint, _ b: CGPoint) -> CGFloat {
        let dx = a.x - b.x
        let dy = a.y - b.y
        return sqrt(dx * dx + dy * dy)
    }

    private func mean(_ values: [Double]) -> Double? {
        guard !values.isEmpty else { return nil }
        return values.reduce(0, +) / Double(values.count)
    }

    private func standardDeviation(_ values: [Double]) -> Double? {
        guard values.count > 1, let avg = mean(values) else { return nil }
        let variance = values.reduce(0.0) { partial, value in
            let delta = value - avg
            return partial + (delta * delta)
        } / Double(values.count)
        return sqrt(variance)
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
