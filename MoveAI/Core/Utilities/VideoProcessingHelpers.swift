//
//  VideoProcessingHelpers.swift
//  MoveAI
//
//  Created by Dave Mathew on 10/11/25.
//

import Foundation
import AVFoundation
import CoreVideo
import CoreImage
import ImageIO

/// Helper functions for video processing and frame extraction
public enum VideoProcessingHelpers {
    private static let sharedCIContext = CIContext()

    
    // MARK: - Debug Logging Helper
    
    public static func writeDebugLog(_ message: String, data: [String: Any], location: String) {
#if !DEBUG
        return
#else
        guard ProcessInfo.processInfo.environment["MOVEAI_POSE_DEBUG"] == "1" else { return }
#endif
        let logPath = "/Users/davemathew/Developer/MoveAI/.cursor/debug.log"
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
    public static func validateVideo(at url: URL) throws {
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
    public static func getVideoDuration(_ asset: AVAsset) async throws -> TimeInterval {
        let duration = try await asset.load(.duration)
        return CMTimeGetSeconds(duration)
    }
    
    /// Get video frame rate
    public static func getVideoFrameRate(_ asset: AVAsset) async throws -> Double {
        guard let videoTrack = try await asset.loadTracks(withMediaType: .video).first else {
            throw VideoProcessingError.noVideoTrack
        }
        
        let frameRate = try await videoTrack.load(.nominalFrameRate)
        return Double(frameRate)
    }
    
    // MARK: - Orientation

    public static func visionOrientation(forPreferredTransform transform: CGAffineTransform) -> CGImagePropertyOrientation {
        // Ignore translation; infer orientation from the 2x2 rotation/mirror matrix.
        func normalizedComponent(_ value: CGFloat) -> Int {
            if abs(value) < 0.001 { return 0 }
            return value > 0 ? 1 : -1
        }

        let a = normalizedComponent(transform.a)
        let b = normalizedComponent(transform.b)
        let c = normalizedComponent(transform.c)
        let d = normalizedComponent(transform.d)

        switch (a, b, c, d) {
        case (1, 0, 0, 1):
            return .up
        case (-1, 0, 0, -1):
            return .down
        case (0, 1, -1, 0):
            return .right
        case (0, -1, 1, 0):
            return .left
        case (-1, 0, 0, 1):
            return .upMirrored
        case (1, 0, 0, -1):
            return .downMirrored
        case (0, 1, 1, 0):
            return .rightMirrored
        case (0, -1, -1, 0):
            return .leftMirrored
        default:
            return .up
        }
    }

    // MARK: - Frame Extraction
    
    /// Extract frames from video at specified intervals
    /// - Parameters:
    ///   - asset: AVAsset to extract frames from
    ///   - targetFPS: Target frames per second to extract (e.g., 30)
    ///   - frameHandler: Optional async closure to process each frame as it's extracted (for streaming)
    ///   - progressHandler: Optional progress callback (0.0 to 1.0)
    /// - Returns: Array of CVPixelBuffers representing video frames (only if frameHandler is nil)
    public static func extractFrames(
        from asset: AVAsset,
        targetFPS: Double = 30.0,
        frameHandler: ((CVPixelBuffer, Int) async throws -> Void)? = nil,
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
        var frameCount = 0
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
                // Extract frame - CGImage will be released after this scope
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
                guard let pixelBuffer = cgImageToPixelBuffer(cgImage) else {
                    continue
                }
                
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
                
                // If frameHandler is provided, use streaming mode
                if let handler = frameHandler {
                    try await handler(pixelBuffer, i)
                    // Frame will be released after handler completes
                    frameCount += 1
                } else {
                    // Legacy mode: accumulate frames
                    frames.append(pixelBuffer)
                    frameCount += 1
                }
                
                // Update progress
                let progress = Double(i + 1) / Double(totalFrames)
                progressHandler?(progress)
                
            } catch {
                print("⚠️ VideoProcessingHelpers: Failed to extract frame at time \(CMTimeGetSeconds(time)): \(error.localizedDescription)")
                // Continue with next frame instead of failing completely
            }
        }
        
        guard frameCount > 0 else {
            throw VideoProcessingError.noFramesExtracted
        }
        
        // Return frames array only if not using streaming mode
        return frames
    }
    
    // MARK: - Frame Downscaling
    
    /// Downscale a pixel buffer to a maximum resolution for memory efficiency
    /// - Parameters:
    ///   - pixelBuffer: Source pixel buffer
    ///   - maxWidth: Maximum width (default 640)
    ///   - maxHeight: Maximum height (default 480)
    /// - Returns: Downscaled pixel buffer, or nil if scaling fails
    public static func downscalePixelBuffer(
        _ pixelBuffer: CVPixelBuffer,
        maxWidth: Int = 640,
        maxHeight: Int = 480
    ) -> CVPixelBuffer? {
        let width = CVPixelBufferGetWidth(pixelBuffer)
        let height = CVPixelBufferGetHeight(pixelBuffer)
        
        // If already smaller than max dimensions, return original
        if width <= maxWidth && height <= maxHeight {
            return pixelBuffer
        }
        
        // Calculate scale factor to fit within max dimensions while maintaining aspect ratio
        let widthScale = Double(maxWidth) / Double(width)
        let heightScale = Double(maxHeight) / Double(height)
        let scale = min(widthScale, heightScale)
        
        let newWidth = Int(Double(width) * scale)
        let newHeight = Int(Double(height) * scale)
        
        // Create new pixel buffer for downscaled image
        var downscaledBuffer: CVPixelBuffer?
        let status = CVPixelBufferCreate(
            kCFAllocatorDefault,
            newWidth,
            newHeight,
            kCVPixelFormatType_32BGRA,
            [
                kCVPixelBufferCGImageCompatibilityKey: kCFBooleanTrue!,
                kCVPixelBufferCGBitmapContextCompatibilityKey: kCFBooleanTrue!
            ] as CFDictionary,
            &downscaledBuffer
        )
        
        guard status == kCVReturnSuccess, let outputBuffer = downscaledBuffer else {
            return nil
        }
        // Use Core Image for high-quality scaling
        let ciImage = CIImage(cvPixelBuffer: pixelBuffer)
        
        // Create transform for scaling
        let transform = CGAffineTransform(scaleX: scale, y: scale)
        let scaledImage = ciImage.transformed(by: transform)
        
        // Render scaled image to output buffer
        sharedCIContext.render(scaledImage, to: outputBuffer)
        
        return outputBuffer
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
    public static func isVideoFormatSupported(_ url: URL) -> Bool {
        let supportedFormats = ["mp4", "mov", "m4v", "avi"]
        let fileExtension = url.pathExtension.lowercased()
        return supportedFormats.contains(fileExtension)
    }
    
    /// Get video file size in MB
    public static func getVideoFileSize(_ url: URL) -> Double? {
        guard let attributes = try? FileManager.default.attributesOfItem(atPath: url.path),
              let fileSize = attributes[.size] as? Int64 else {
            return nil
        }
        return Double(fileSize) / (1024 * 1024) // Convert to MB
    }
}

// MARK: - Video Processing Errors

public enum VideoProcessingError: LocalizedError {
    case videoNotFound
    case videoNotReadable
    case noVideoTrack
    case noFramesExtracted
    case unsupportedFormat
    case processingFailed(String)
    
    public var errorDescription: String? {
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

