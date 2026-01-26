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
        let totalFrames = Int(duration * 30.0) // Estimate based on 30fps
        
        // Step 3 & 4: Extract and process frames in streaming mode (memory efficient)
        currentStep = .extractingFrames
        progress = 0.2
        progressHandler?(0.2)
        
        // Reset pose analysis service
        poseAnalysisService.reset()
        
        var poseResults: [PoseDetectionResult] = []
        var processedFrameCount = 0
        
        // Stream frames: extract, downscale, process, release
        try await VideoProcessingHelpers.extractFrames(
            from: asset,
            targetFPS: 30.0,
            frameHandler: { [weak self] pixelBuffer, frameIndex in
                guard let self = self else { return }
                
                // Downscale frame for memory efficiency (pose detection doesn't need full resolution)
                guard let downscaledBuffer = VideoProcessingHelpers.downscalePixelBuffer(
                    pixelBuffer,
                    maxWidth: 640,
                    maxHeight: 480
                ) else {
                    // If downscaling fails, use original (shouldn't happen, but handle gracefully)
                    print("⚠️ VideoProcessor: Failed to downscale frame \(frameIndex), using original")
                    let result = await self.processSingleFrame(pixelBuffer, index: frameIndex)
                    await MainActor.run {
                        poseResults.append(result)
                        processedFrameCount += 1
                    }
                    return
                }
                
                // Process downscaled frame for pose detection
                let result = await self.processSingleFrame(downscaledBuffer, index: frameIndex)
                
                // Store result (small data structure)
                await MainActor.run {
                    poseResults.append(result)
                    processedFrameCount += 1
                    
                    // Update progress: combine extraction and processing (0.2-0.95)
                    let extractionProgress = Double(frameIndex + 1) / Double(totalFrames)
                    let overallProgress = 0.2 + (extractionProgress * 0.75)
                    self.progress = overallProgress
                    progressHandler?(overallProgress)
                }
                
                // Frame buffers will be released automatically after this scope
            },
            progressHandler: nil // Progress handled in frameHandler
        )
        
        guard !poseResults.isEmpty else {
            throw VideoProcessingError.noFramesExtracted
        }
        
        // Update to analyzing step for final processing
        currentStep = .analyzingPoses
        
        // Step 5: Create MovementRecording
        currentStep = .complete
        progress = 1.0
        progressHandler?(1.0)
        
        let recording = MovementRecording(
            movementType: movementType,
            videoURL: url,
            duration: duration,
            poseData: poseResults
        )
        
        return recording
    }
    
    // MARK: - Pose Detection Processing
    
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

