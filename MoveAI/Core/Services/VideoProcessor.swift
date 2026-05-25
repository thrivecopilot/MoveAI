//
//  VideoProcessor.swift
//  MoveAI
//
//  Created by Dave Mathew on 10/11/25.
//

import Foundation
import AVFoundation
import CoreVideo
import Vision
import UIKit

/// Service for processing uploaded videos to extract pose data
@MainActor
class VideoProcessor: ObservableObject {
    @Published var isProcessing = false
    @Published var progress: Double = 0.0
    @Published var currentStep: ProcessingStep = .idle

    private let poseAnalysisService = PoseAnalysisService()

    enum ProcessingStep {
        case idle
        case validating
        case extractingFrames
        case analyzingPoses
        case complete
    }

    private static let targetFPS: Double = 30.0

    // MARK: - Main Processing Method

    /// Process a video file and extract pose data
    /// - Parameters:
    ///   - url: URL of the video file
    ///   - movementType: Type of movement being analyzed
    ///   - progressHandler: Optional callback for progress updates
    /// - Returns: MovementRecording with pose data
    func processVideo(
        _ url: URL,
        movementType: MovementType,
        technique: MuayThaiTechnique? = nil,
        fightStance: FightStance? = nil,
        progressHandler: ((Double) -> Void)? = nil
    ) async throws -> MovementRecording {
        isProcessing = true
        progress = 0.0
        defer {
            isProcessing = false
            currentStep = .idle
        }

        // Step 1: Validate video
        currentStep = .validating
        progress = 0.1
        progressHandler?(0.1)

        try VideoProcessingHelpers.validateVideo(at: url)

        guard VideoProcessingHelpers.isVideoFormatSupported(url) else {
            throw VideoProcessingError.unsupportedFormat
        }

        // Step 2: Load asset and get duration
        let asset = AVAsset(url: url)
        let duration = try await VideoProcessingHelpers.getVideoDuration(asset)
        let totalFrames = Int(duration * Self.targetFPS)

        // Step 3 & 4: Extract and process frames in streaming mode (memory efficient)
        currentStep = .extractingFrames
        progress = 0.2
        progressHandler?(0.2)

        // Reset pose analysis service
        poseAnalysisService.reset()

        let poseResults: [PoseDetectionResult]
        let forceLegacy = ProcessInfo.processInfo.environment["MOVEAI_USE_LEGACY_FRAME_EXTRACTION"] == "1"

        if forceLegacy {
            poseResults = try await extractPosesLegacy(
                asset: asset,
                duration: duration,
                totalFrames: totalFrames,
                progressHandler: progressHandler
            )
        } else {
            do {
                poseResults = try await extractPosesUsingAssetReader(
                    asset: asset,
                    duration: duration,
                    totalFrames: totalFrames,
                    progressHandler: progressHandler
                )
            } catch {
                // Safety net: preserve behavior on any reader failure.
                poseResults = try await extractPosesLegacy(
                    asset: asset,
                    duration: duration,
                    totalFrames: totalFrames,
                    progressHandler: progressHandler
                )
            }
        }

        guard !poseResults.isEmpty else {
            throw VideoProcessingError.noFramesExtracted
        }

        // Update to analyzing step for final processing
        currentStep = .analyzingPoses

        // Step 5: Create MovementRecording
        currentStep = .complete
        progress = 1.0
        progressHandler?(1.0)

        return MovementRecording(
            movementType: movementType,
            technique: technique,
            fightStance: fightStance,
            videoURL: url,
            duration: duration,
            poseData: poseResults
        )
    }

    // MARK: - Fast Extraction (AVAssetReader)

    private func extractPosesUsingAssetReader(
        asset: AVAsset,
        duration: TimeInterval,
        totalFrames: Int,
        progressHandler: ((Double) -> Void)?
    ) async throws -> [PoseDetectionResult] {
        let videoTrack = try await asset.loadTracks(withMediaType: .video).first
        guard let videoTrack else {
            throw VideoProcessingError.noVideoTrack
        }

        let preferredTransform = try await videoTrack.load(.preferredTransform)
        let orientation = VideoProcessingHelpers.visionOrientation(forPreferredTransform: preferredTransform)

        let progressUpdate: @Sendable (Int) async -> Void = { [weak self] sampleIndex in
            guard let self else { return }

            // Throttle UI updates to reduce MainActor contention.
            if sampleIndex % 2 != 0 && sampleIndex != max(0, totalFrames - 1) {
                return
            }

            let extractionProgress = totalFrames > 0
                ? Double(sampleIndex + 1) / Double(totalFrames)
                : 0
            let overallProgress = 0.2 + (extractionProgress * 0.75)

            await MainActor.run {
                self.progress = overallProgress
                progressHandler?(overallProgress)
            }
        }

        return try await Task.detached(priority: .userInitiated) {
            let reader = try VideoFrameReader(asset: asset, videoTrack: videoTrack)
            let extractor = PoseExtractor()

            var results: [PoseDetectionResult] = []
            results.reserveCapacity(max(0, totalFrames))

            let start = CFAbsoluteTimeGetCurrent()
            var emptyFrameCount = 0

            try await reader.forEachUniformSample(durationSeconds: duration, targetFPS: Self.targetFPS) { sampleIndex, pixelBuffer in
                let timestampSeconds = min(Double(sampleIndex) / Self.targetFPS, duration)

                guard let pixelBuffer else {
                    emptyFrameCount += 1
                    let ts = Date(timeIntervalSince1970: timestampSeconds)
                    results.append(PoseDetectionResult(keypoints: [], frameIndex: sampleIndex, timestamp: ts))
                    await progressUpdate(sampleIndex)
                    return
                }

                let downscaled = VideoProcessingHelpers.downscalePixelBuffer(
                    pixelBuffer,
                    maxWidth: 640,
                    maxHeight: 480
                ) ?? pixelBuffer

                let pose = extractor.extract(
                    pixelBuffer: downscaled,
                    orientation: orientation,
                    frameIndex: sampleIndex,
                    timestampSeconds: timestampSeconds
                )

                if pose.keypoints.isEmpty {
                    emptyFrameCount += 1
                }

                results.append(pose)
                await progressUpdate(sampleIndex)
            }

#if DEBUG
            if ProcessInfo.processInfo.environment["MOVEAI_POSE_DEBUG"] == "1" {
                let elapsed = CFAbsoluteTimeGetCurrent() - start
                let msPerFrame = totalFrames > 0 ? (elapsed * 1000.0) / Double(totalFrames) : 0
                print(
                    "🎬 VideoProcessor: AVAssetReader extraction finished in \(String(format: "%.2f", elapsed))s (\(String(format: "%.1f", msPerFrame))ms/frame), emptyFrames=\(emptyFrameCount)/\(totalFrames)"
                )
            }
#endif

            return results
        }.value
    }

    // MARK: - Legacy Extraction (AVAssetImageGenerator)

    private func extractPosesLegacy(
        asset: AVAsset,
        duration: TimeInterval,
        totalFrames: Int,
        progressHandler: ((Double) -> Void)?
    ) async throws -> [PoseDetectionResult] {
        var poseResults: [PoseDetectionResult] = []

        try await VideoProcessingHelpers.extractFrames(
            from: asset,
            targetFPS: Self.targetFPS,
            frameHandler: { [weak self] pixelBuffer, frameIndex in
                guard let self = self else { return }

                let downscaledBuffer = VideoProcessingHelpers.downscalePixelBuffer(
                    pixelBuffer,
                    maxWidth: 640,
                    maxHeight: 480
                ) ?? pixelBuffer

                let result = await self.processSingleFrame(downscaledBuffer, index: frameIndex)

                await MainActor.run {
                    poseResults.append(result)

                    let extractionProgress = Double(frameIndex + 1) / Double(max(1, totalFrames))
                    let overallProgress = 0.2 + (extractionProgress * 0.75)
                    self.progress = overallProgress
                    progressHandler?(overallProgress)
                }
            },
            progressHandler: nil
        )

        guard !poseResults.isEmpty else {
            return []
        }

        // Reassign pose timestamps to align with video time (extraction uses 30fps)
        // Frame index i = video time i/30 seconds; clamp to duration for edge cases
        return poseResults.map { pose in
            let videoTime = min(Double(pose.frameIndex) / Self.targetFPS, duration)
            let timestamp = Date(timeIntervalSince1970: videoTime)
            return PoseDetectionResult(keypoints: pose.keypoints, frameIndex: pose.frameIndex, timestamp: timestamp)
        }
    }

    // MARK: - Pose Detection Processing (Legacy)

    /// Process a single frame and wait for pose detection result
    /// Uses autoreleasepool to release intermediate objects promptly
    private func processSingleFrame(_ pixelBuffer: CVPixelBuffer, index: Int) async -> PoseDetectionResult {
        return await withCheckedContinuation { continuation in
            let request = VNDetectHumanBodyPoseRequest { request, error in
                var keypoints: [PoseKeypoint] = []

                if let error = error {
                    print("⚠️ VideoProcessor: Pose detection failed for frame \(index) - \(error.localizedDescription)")
                } else if let observations = request.results as? [VNHumanBodyPoseObservation],
                          let observation = observations.first {
                    // Extract keypoints
                    let jointNames: [VNHumanBodyPoseObservation.JointName] = [
                        .nose, .leftEye, .rightEye, .leftEar, .rightEar,
                        .neck, .leftShoulder, .rightShoulder, .leftElbow, .rightElbow,
                        .leftWrist, .rightWrist, .leftHip, .rightHip, .root,
                        .leftKnee, .rightKnee, .leftAnkle, .rightAnkle
                    ]

                    for jointName in jointNames {
                        do {
                            let point = try observation.recognizedPoint(jointName)
                            if point.confidence > 0.1 {
                                // Use consistent keypoint name mapping to ensure reliable matching
                                let keypointName = PoseAnalysisHelpers.jointNameToString(jointName)
                                let keypoint = PoseKeypoint(
                                    name: keypointName,
                                    position: CGPoint(x: point.location.x, y: point.location.y),
                                    confidence: point.confidence
                                )

                                // #region agent log
                                if index == 0 && keypoints.isEmpty && jointName == .nose {
                                    let logData: [String: Any] = [
                                        "hypothesisId": "H1,H3,H4",
                                        "keypointName": keypointName,
                                        "normalizedX": point.location.x,
                                        "normalizedY": point.location.y,
                                        "source": "uploaded_video"
                                    ]
                                    VideoProcessingHelpers.writeDebugLog("First keypoint coordinates from video", data: logData, location: "VideoProcessor.swift:180")
                                }
                                // #endregion

                                keypoints.append(keypoint)
                            }
                        } catch {
                            continue
                        }
                    }
                }

                let poseResult = PoseDetectionResult(keypoints: keypoints, frameIndex: index)
                continuation.resume(returning: poseResult)
            }

            if let maxRevision = type(of: request).supportedRevisions.max() {
                request.revision = maxRevision
            }

            // Process within autoreleasepool to release memory promptly
            autoreleasepool {
                let handler = VNImageRequestHandler(cvPixelBuffer: pixelBuffer, orientation: .up)
                do {
                    // #region agent log
                    if index == 0 {
                        let width = CVPixelBufferGetWidth(pixelBuffer)
                        let height = CVPixelBufferGetHeight(pixelBuffer)
                        let logData: [String: Any] = [
                            "hypothesisId": "H1,H3",
                            "pixelBufferWidth": width,
                            "pixelBufferHeight": height,
                            "visionOrientation": "up"
                        ]
                        VideoProcessingHelpers.writeDebugLog("Pose detection input dimensions", data: logData, location: "VideoProcessor.swift:192")
                    }
                    // #endregion

                    try handler.perform([request])
                } catch {
                    print("❌ VideoProcessor: Failed to perform pose detection: \(error.localizedDescription)")
                    let emptyResult = PoseDetectionResult(keypoints: [], frameIndex: index)
                    continuation.resume(returning: emptyResult)
                }
            }
        }
    }

    // MARK: - Cancellation

    func cancel() {
        isProcessing = false
        currentStep = .idle
        progress = 0.0
        poseAnalysisService.reset()
    }
}
