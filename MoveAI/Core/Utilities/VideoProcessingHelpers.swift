//
//  VideoProcessingHelpers.swift
//  MoveAI
//
//  Created by Dave Mathew on 10/11/25.
//

import Foundation
import AVFoundation
import CoreVideo

/// Helper functions for video processing and frame extraction
enum VideoProcessingHelpers {
    
    // MARK: - Debug Logging Helper
    
    static func writeDebugLog(_ message: String, data: [String: Any], location: String) {
        let logPath = "/Users/davemathew/Documents/MoveAI/.cursor/debug.log"
        let logEntry: [String: Any] = [
            "location": location,
            "message": message,
            "data": data,
            "timestamp": Int(Date().timeIntervalSince1970 * 1000),
            "sessionId": "debug-session",
            "runId": "run1"
        ]
        if let jsonData = try? JSONSerialization.data(withJSONObject: logEntry),
           let jsonString = String(data: jsonData, encoding: .utf8) {
            let logLine = jsonString + "\n"
            if let fileHandle = FileHandle(forWritingAtPath: logPath) {
                defer { fileHandle.closeFile() }
                fileHandle.seekToEndOfFile()
                if let logBytes = logLine.data(using: .utf8) {
                    fileHandle.write(logBytes)
                }
            } else {
                try? logLine.write(toFile: logPath, atomically: true, encoding: .utf8)
            }
        }
    }
    
    // MARK: - Video Validation
    
    /// Validate that a video file exists and is readable
    static func validateVideo(at url: URL) throws {
        guard FileManager.default.fileExists(atPath: url.path) else {
            throw VideoProcessingError.videoNotFound
        }
        
        let asset = AVAsset(url: url)
        
        // Check if asset is readable
        guard asset.isReadable else {
            throw VideoProcessingError.videoNotReadable
        }
        
        // Check if asset has video tracks
        let videoTracks = asset.tracks(withMediaType: .video)
        guard !videoTracks.isEmpty else {
            throw VideoProcessingError.noVideoTrack
        }
    }
    
    /// Get video duration
    static func getVideoDuration(_ asset: AVAsset) async throws -> TimeInterval {
        let duration = try await asset.load(.duration)
        return CMTimeGetSeconds(duration)
    }
    
    /// Get video frame rate
    static func getVideoFrameRate(_ asset: AVAsset) async throws -> Double {
        guard let videoTrack = try await asset.loadTracks(withMediaType: .video).first else {
            throw VideoProcessingError.noVideoTrack
        }
        
        let frameRate = try await videoTrack.load(.nominalFrameRate)
        return Double(frameRate)
    }
    
    // MARK: - Frame Extraction
    
    /// Extract frames from video at specified intervals
    /// - Parameters:
    ///   - asset: AVAsset to extract frames from
    ///   - targetFPS: Target frames per second to extract (e.g., 30)
    ///   - progressHandler: Optional progress callback (0.0 to 1.0)
    /// - Returns: Array of CVPixelBuffers representing video frames
    static func extractFrames(
        from asset: AVAsset,
        targetFPS: Double = 30.0,
        progressHandler: ((Double) -> Void)? = nil
    ) async throws -> [CVPixelBuffer] {
        guard let videoTrack = try await asset.loadTracks(withMediaType: .video).first else {
            throw VideoProcessingError.noVideoTrack
        }
        
        let duration = try await asset.load(.duration)
        let videoDuration = CMTimeGetSeconds(duration)
        
        // Calculate frame interval
        let frameInterval = 1.0 / targetFPS
        let totalFrames = Int(videoDuration * targetFPS)
        
        var frames: [CVPixelBuffer] = []
        let imageGenerator = AVAssetImageGenerator(asset: asset)
        imageGenerator.requestedTimeToleranceBefore = .zero
        imageGenerator.requestedTimeToleranceAfter = .zero
        imageGenerator.appliesPreferredTrackTransform = true
        
        // #region agent log
        if let videoTrack = try? await asset.loadTracks(withMediaType: .video).first {
            let preferredTransform = try? await videoTrack.load(.preferredTransform)
            let naturalSize = try? await videoTrack.load(.naturalSize)
            let logData: [String: Any] = [
                "hypothesisId": "H2",
                "preferredTransform": preferredTransform != nil ? "\(preferredTransform!)" : "nil",
                "naturalSize": naturalSize != nil ? "\(naturalSize!)" : "nil",
                "appliesPreferredTrackTransform": true
            ]
            writeDebugLog("Video track transform info", data: logData, location: "VideoProcessingHelpers.swift:81")
        }
        // #endregion
        
        // Extract frames
        for i in 0..<totalFrames {
            let time = CMTime(seconds: Double(i) * frameInterval, preferredTimescale: 600)
            
            do {
                let cgImage = try await imageGenerator.image(at: time).image
                
                // #region agent log
                if i == 0 {
                    let logData: [String: Any] = [
                        "hypothesisId": "H1,H3",
                        "cgImageWidth": cgImage.width,
                        "cgImageHeight": cgImage.height
                    ]
                    writeDebugLog("First frame CGImage dimensions", data: logData, location: "VideoProcessingHelpers.swift:95")
                }
                // #endregion
                
                // Convert CGImage to CVPixelBuffer
                if let pixelBuffer = cgImageToPixelBuffer(cgImage) {
                    // #region agent log
                    if i == 0 {
                        let width = CVPixelBufferGetWidth(pixelBuffer)
                        let height = CVPixelBufferGetHeight(pixelBuffer)
                        let logData: [String: Any] = [
                            "hypothesisId": "H1,H3",
                            "pixelBufferWidth": width,
                            "pixelBufferHeight": height
                        ]
                        writeDebugLog("First frame pixel buffer dimensions", data: logData, location: "VideoProcessingHelpers.swift:102")
                    }
                    // #endregion
                    frames.append(pixelBuffer)
                }
                
                // Update progress
                let progress = Double(i + 1) / Double(totalFrames)
                progressHandler?(progress)
                
            } catch {
                print("⚠️ VideoProcessingHelpers: Failed to extract frame at time \(CMTimeGetSeconds(time)): \(error.localizedDescription)")
                // Continue with next frame instead of failing completely
            }
        }
        
        guard !frames.isEmpty else {
            throw VideoProcessingError.noFramesExtracted
        }
        
        return frames
    }
    
    // MARK: - Pixel Buffer Conversion
    
    /// Convert CGImage to CVPixelBuffer
    private static func cgImageToPixelBuffer(_ cgImage: CGImage) -> CVPixelBuffer? {
        let width = cgImage.width
        let height = cgImage.height
        
        var pixelBuffer: CVPixelBuffer?
        let status = CVPixelBufferCreate(
            kCFAllocatorDefault,
            width,
            height,
            kCVPixelFormatType_32BGRA,
            [
                kCVPixelBufferCGImageCompatibilityKey: kCFBooleanTrue!,
                kCVPixelBufferCGBitmapContextCompatibilityKey: kCFBooleanTrue!
            ] as CFDictionary,
            &pixelBuffer
        )
        
        guard status == kCVReturnSuccess, let buffer = pixelBuffer else {
            return nil
        }
        
        CVPixelBufferLockBaseAddress(buffer, [])
        defer { CVPixelBufferUnlockBaseAddress(buffer, []) }
        
        let context = CGContext(
            data: CVPixelBufferGetBaseAddress(buffer),
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: CVPixelBufferGetBytesPerRow(buffer),
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.noneSkipFirst.rawValue
        )
        
        context?.draw(cgImage, in: CGRect(x: 0, y: 0, width: width, height: height))
        
        return buffer
    }
    
    // MARK: - Video Format Support
    
    /// Check if video format is supported
    static func isVideoFormatSupported(_ url: URL) -> Bool {
        let supportedFormats = ["mp4", "mov", "m4v", "avi"]
        let fileExtension = url.pathExtension.lowercased()
        return supportedFormats.contains(fileExtension)
    }
    
    /// Get video file size in MB
    static func getVideoFileSize(_ url: URL) -> Double? {
        guard let attributes = try? FileManager.default.attributesOfItem(atPath: url.path),
              let fileSize = attributes[.size] as? Int64 else {
            return nil
        }
        return Double(fileSize) / (1024 * 1024) // Convert to MB
    }
}

// MARK: - Video Processing Errors

enum VideoProcessingError: LocalizedError {
    case videoNotFound
    case videoNotReadable
    case noVideoTrack
    case noFramesExtracted
    case unsupportedFormat
    case processingFailed(String)
    
    var errorDescription: String? {
        switch self {
        case .videoNotFound:
            return "Video file not found"
        case .videoNotReadable:
            return "Video file cannot be read"
        case .noVideoTrack:
            return "Video file does not contain a video track"
        case .noFramesExtracted:
            return "No frames could be extracted from the video"
        case .unsupportedFormat:
            return "Video format is not supported. Please use MP4 or MOV format."
        case .processingFailed(let reason):
            return "Video processing failed: \(reason)"
        }
    }
}

