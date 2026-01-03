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
        
        // Step 3: Extract frames
        currentStep = .extractingFrames
        progress = 0.2
        progressHandler?(0.2)
        
        var frameProgress: Double = 0.2
        let frames = try await VideoProcessingHelpers.extractFrames(
            from: asset,
            targetFPS: 30.0
        ) { frameProgressValue in
            // Map frame extraction progress (0.0-1.0) to overall progress (0.2-0.6)
            frameProgress = 0.2 + (frameProgressValue * 0.4)
            Task { @MainActor in
                self.progress = frameProgress
                progressHandler?(frameProgress)
            }
        }
        
        guard !frames.isEmpty else {
            throw VideoProcessingError.noFramesExtracted
        }
        
        // Step 4: Process frames for pose detection
        currentStep = .analyzingPoses
        progress = 0.6
        progressHandler?(0.6)
        
        let poseResults = try await processFramesForPose(frames) { poseProgressValue in
            // Map pose analysis progress (0.0-1.0) to overall progress (0.6-0.95)
            let poseProgress = 0.6 + (poseProgressValue * 0.35)
            Task { @MainActor in
                self.progress = poseProgress
                progressHandler?(poseProgress)
            }
        }
        
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
    
    /// Process frames through pose detection
    private func processFramesForPose(
        _ frames: [CVPixelBuffer],
        progressHandler: ((Double) -> Void)? = nil
    ) async throws -> [PoseDetectionResult] {
        // Reset pose analysis service
        poseAnalysisService.reset()
        
        var poseResults: [PoseDetectionResult] = []
        let totalFrames = frames.count
        
        // Process frames in batches to avoid memory issues
        let batchSize = 10
        var frameIndex = 0
        
        for batchStart in stride(from: 0, to: frames.count, by: batchSize) {
            let batchEnd = min(batchStart + batchSize, frames.count)
            let batch = Array(frames[batchStart..<batchEnd])
            
            // Process batch
            for frame in batch {
                let result = await processSingleFrame(frame, index: frameIndex)
                poseResults.append(result)
                frameIndex += 1
                
                // Update progress
                let progress = Double(frameIndex) / Double(totalFrames)
                progressHandler?(progress)
            }
        }
        
        return poseResults
    }
    
    /// Process a single frame and wait for pose detection result
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
    
    // MARK: - Cancellation
    
    func cancel() {
        isProcessing = false
        currentStep = .idle
        progress = 0.0
        poseAnalysisService.reset()
    }
}

