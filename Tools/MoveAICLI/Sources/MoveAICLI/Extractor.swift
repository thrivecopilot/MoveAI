//
//  Extractor.swift
//  MoveAICLI
//
//  Video -> poses JSON extraction using Vision framework.
//

import Foundation
import AVFoundation
import CoreVideo
import Vision
import MoveAICore

enum Extractor {
    
    /// Extract poses from video and write to JSON file
    static func extract(videoPath: String, outputPath: String) async throws {
        let videoURL = URL(fileURLWithPath: videoPath)
        let outputURL = URL(fileURLWithPath: outputPath)
        
        print("🎬 Extracting poses from \(videoPath)...")
        print("  Output: \(outputURL.path)")
        
        try VideoProcessingHelpers.validateVideo(at: videoURL)
        guard VideoProcessingHelpers.isVideoFormatSupported(videoURL) else {
            throw VideoProcessingError.unsupportedFormat
        }
        
        let asset = AVAsset(url: videoURL)
        let duration = try await VideoProcessingHelpers.getVideoDuration(asset)
        let totalFrames = Int(duration * 30.0)
        
        var poseResults: [PoseDetectionResult] = []
        let checkpointInterval = 30  // Write to cache every 30 frames (~1 second)
        
        try await VideoProcessingHelpers.extractFrames(
            from: asset,
            targetFPS: 30.0,
            frameHandler: { pixelBuffer, frameIndex in
                guard let downscaledBuffer = VideoProcessingHelpers.downscalePixelBuffer(
                    pixelBuffer,
                    maxWidth: 640,
                    maxHeight: 480
                ) else {
                    let result = try await processSingleFrame(pixelBuffer, index: frameIndex)
                    poseResults.append(result)
                    return
                }
                let result = try await processSingleFrame(downscaledBuffer, index: frameIndex)
                poseResults.append(result)
                // Write to cache every N frames so data persists during extraction
                if (frameIndex + 1) % checkpointInterval == 0 {
                    try? writeCheckpoint(poseResults, duration: duration, to: outputURL)
                }
            },
            progressHandler: { progress in
                let pct = Int(progress * 100)
                if pct % 10 == 0 || pct == 100 {
                    print("  Progress: \(pct)%")
                }
            }
        )
        
        guard !poseResults.isEmpty else {
            throw VideoProcessingError.noFramesExtracted
        }
        
        let posesWithTimestamps = poseResults.map { pose in
            let videoTime = min(Double(pose.frameIndex) / 30.0, duration)
            let timestamp = Date(timeIntervalSince1970: videoTime)
            return PoseDetectionResult(
                keypoints: pose.keypoints,
                frameIndex: pose.frameIndex,
                timestamp: timestamp
            )
        }
        
        try savePoses(posesWithTimestamps, to: outputURL)
        print("✅ Extracted \(posesWithTimestamps.count) poses to \(outputPath)")
    }
    
    private static func processSingleFrame(_ pixelBuffer: CVPixelBuffer, index: Int) async throws -> PoseDetectionResult {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<PoseDetectionResult, Error>) in
            let request = VNDetectHumanBodyPoseRequest { request, error in
                var keypoints: [PoseKeypoint] = []
                
                if let error = error {
                    continuation.resume(throwing: error)
                    return
                }
                
                if let observations = request.results as? [VNHumanBodyPoseObservation],
                   let observation = observations.first {
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
                                let keypointName = PoseAnalysisHelpers.jointNameToString(jointName)
                                let keypoint = PoseKeypoint(
                                    name: keypointName,
                                    position: CGPoint(x: point.location.x, y: point.location.y),
                                    confidence: point.confidence
                                )
                                keypoints.append(keypoint)
                            }
                        } catch {
                            continue
                        }
                    }
                }
                
                let result = PoseDetectionResult(keypoints: keypoints, frameIndex: index)
                continuation.resume(returning: result)
            }
            
            let handler = VNImageRequestHandler(cvPixelBuffer: pixelBuffer, orientation: .up)
            do {
                try handler.perform([request])
            } catch {
                let emptyResult = PoseDetectionResult(keypoints: [], frameIndex: index)
                continuation.resume(returning: emptyResult)
            }
        }
    }
    
    /// Write checkpoint to cache during extraction (partial results)
    private static func writeCheckpoint(_ poses: [PoseDetectionResult], duration: TimeInterval, to url: URL) throws {
        guard !poses.isEmpty else { return }
        let withTimestamps = poses.map { pose in
            let videoTime = min(Double(pose.frameIndex) / 30.0, duration)
            let timestamp = Date(timeIntervalSince1970: videoTime)
            return PoseDetectionResult(
                keypoints: pose.keypoints,
                frameIndex: pose.frameIndex,
                timestamp: timestamp
            )
        }
        try savePoses(withTimestamps, to: url)
    }
    
    private static func savePoses(_ poses: [PoseDetectionResult], to url: URL) throws {
        let parent = url.deletingLastPathComponent()
        if !FileManager.default.fileExists(atPath: parent.path) {
            try FileManager.default.createDirectory(at: parent, withIntermediateDirectories: true)
        }
        
        let tempURL = parent.appendingPathComponent(".\(url.lastPathComponent).tmp")
        
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        
        let data = try encoder.encode(poses)
        try data.write(to: tempURL)
        
        if FileManager.default.fileExists(atPath: url.path) {
            try FileManager.default.removeItem(at: url)
        }
        try FileManager.default.moveItem(at: tempURL, to: url)
        
        guard FileManager.default.fileExists(atPath: url.path) else {
            throw VideoProcessingError.processingFailed("Cache file was not created at \(url.path)")
        }
        let attrs = try FileManager.default.attributesOfItem(atPath: url.path)
        let size = attrs[.size] as? Int ?? 0
        guard size > 0 else {
            throw VideoProcessingError.processingFailed("Cache file is empty after write")
        }
        print("  Wrote \(size) bytes to \(url.path)")
    }
}
