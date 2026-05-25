#!/usr/bin/swift

import AVFoundation
import CoreGraphics
import Foundation
import Vision

struct PoseKeypoint: Codable {
    let id: UUID
    let name: String
    let position: CGPoint
    let confidence: Float
    let timestamp: Date
}

struct PoseDetectionResult: Codable {
    let keypoints: [PoseKeypoint]
    let timestamp: Date
    let frameIndex: Int
}

private enum JointNameMapper {
    static func toString(_ joint: VNHumanBodyPoseObservation.JointName) -> String {
        switch joint {
        case .nose: return "nose"
        case .leftEye: return "leftEye"
        case .rightEye: return "rightEye"
        case .leftEar: return "leftEar"
        case .rightEar: return "rightEar"
        case .neck: return "neck"
        case .leftShoulder: return "leftShoulder"
        case .rightShoulder: return "rightShoulder"
        case .leftElbow: return "leftElbow"
        case .rightElbow: return "rightElbow"
        case .leftWrist: return "leftWrist"
        case .rightWrist: return "rightWrist"
        case .leftHip: return "leftHip"
        case .rightHip: return "rightHip"
        case .root: return "root"
        case .leftKnee: return "leftKnee"
        case .rightKnee: return "rightKnee"
        case .leftAnkle: return "leftAnkle"
        case .rightAnkle: return "rightAnkle"
        default: return String(describing: joint)
        }
    }
}

private let trackedJoints: [VNHumanBodyPoseObservation.JointName] = [
    .nose, .leftEye, .rightEye, .leftEar, .rightEar,
    .neck, .leftShoulder, .rightShoulder, .leftElbow, .rightElbow,
    .leftWrist, .rightWrist, .leftHip, .rightHip, .root,
    .leftKnee, .rightKnee, .leftAnkle, .rightAnkle,
]

private struct Args {
    let input: URL
    let output: URL
    let fps: Double
}

private enum CLIError: LocalizedError {
    case invalidArguments
    case missingValue(String)
    case unreadableVideo(URL)
    case noDuration
    case noImageForAllSamples

    var errorDescription: String? {
        switch self {
        case .invalidArguments:
            return "Usage: extract_muaythai_pose_cache.swift --input <video.mov> --output <cache.json> [--fps 30]"
        case .missingValue(let flag):
            return "Missing value for \(flag)"
        case .unreadableVideo(let url):
            return "Video not found: \(url.path)"
        case .noDuration:
            return "Video duration is not available"
        case .noImageForAllSamples:
            return "Could not decode any frame from input video"
        }
    }
}

private func parseArgs() throws -> Args {
    let argv = Array(CommandLine.arguments.dropFirst())
    guard !argv.isEmpty else { throw CLIError.invalidArguments }

    var inputPath: String?
    var outputPath: String?
    var fps: Double = 30.0

    var idx = 0
    while idx < argv.count {
        let token = argv[idx]
        switch token {
        case "--input":
            idx += 1
            guard idx < argv.count else { throw CLIError.missingValue("--input") }
            inputPath = argv[idx]
        case "--output":
            idx += 1
            guard idx < argv.count else { throw CLIError.missingValue("--output") }
            outputPath = argv[idx]
        case "--fps":
            idx += 1
            guard idx < argv.count else { throw CLIError.missingValue("--fps") }
            fps = Double(argv[idx]) ?? 30.0
        default:
            throw CLIError.invalidArguments
        }
        idx += 1
    }

    guard let inputPath, let outputPath else { throw CLIError.invalidArguments }
    let input = URL(fileURLWithPath: inputPath)
    let output = URL(fileURLWithPath: outputPath)
    return Args(input: input, output: output, fps: max(1.0, fps))
}

private func extractPoses(input: URL, fps: Double) throws -> [PoseDetectionResult] {
    guard FileManager.default.fileExists(atPath: input.path) else {
        throw CLIError.unreadableVideo(input)
    }

    let asset = AVAsset(url: input)
    let duration = CMTimeGetSeconds(asset.duration)
    guard duration.isFinite, duration > 0 else {
        throw CLIError.noDuration
    }

    let totalSamples = max(1, Int(duration * fps))
    let generator = AVAssetImageGenerator(asset: asset)
    generator.appliesPreferredTrackTransform = true
    let sampleTolerance = CMTime(seconds: 1.0 / fps, preferredTimescale: 600)
    generator.requestedTimeToleranceBefore = sampleTolerance
    generator.requestedTimeToleranceAfter = sampleTolerance

    let request = VNDetectHumanBodyPoseRequest()
    if let maxRevision = type(of: request).supportedRevisions.max() {
        request.revision = maxRevision
    }

    var results: [PoseDetectionResult] = []
    var previousImage: CGImage?
    var decodedAtLeastOne = false

    for i in 0..<totalSamples {
        let sampleTime = CMTime(seconds: Double(i) / fps, preferredTimescale: 600)

        let cgImage: CGImage
        do {
            cgImage = try generator.copyCGImage(at: sampleTime, actualTime: nil)
            previousImage = cgImage
            decodedAtLeastOne = true
        } catch {
            guard let fallback = previousImage else {
                results.append(
                    PoseDetectionResult(
                        keypoints: [],
                        timestamp: Date(timeIntervalSince1970: Double(i) / fps),
                        frameIndex: i
                    )
                )
                continue
            }
            cgImage = fallback
        }

        let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
        var keypoints: [PoseKeypoint] = []

        do {
            try handler.perform([request])
            if let observation = request.results?.first {
                for joint in trackedJoints {
                    guard let point = try? observation.recognizedPoint(joint), point.confidence > 0.1 else {
                        continue
                    }
                    keypoints.append(
                        PoseKeypoint(
                            id: UUID(),
                            name: JointNameMapper.toString(joint),
                            position: CGPoint(x: point.location.x, y: point.location.y),
                            confidence: point.confidence,
                            timestamp: Date(timeIntervalSince1970: Double(i) / fps)
                        )
                    )
                }
            }
        } catch {
            // Keep an empty frame for failed inference to preserve indexability.
        }

        results.append(
            PoseDetectionResult(
                keypoints: keypoints,
                timestamp: Date(timeIntervalSince1970: Double(i) / fps),
                frameIndex: i
            )
        )
    }

    guard decodedAtLeastOne else {
        throw CLIError.noImageForAllSamples
    }

    return results
}

private func save(_ results: [PoseDetectionResult], to output: URL) throws {
    let parent = output.deletingLastPathComponent()
    try FileManager.default.createDirectory(at: parent, withIntermediateDirectories: true)

    let encoder = JSONEncoder()
    encoder.dateEncodingStrategy = .iso8601
    encoder.outputFormatting = [.prettyPrinted, .sortedKeys]

    let data = try encoder.encode(results)
    try data.write(to: output)
}

do {
    let args = try parseArgs()
    let results = try extractPoses(input: args.input, fps: args.fps)
    try save(results, to: args.output)

    let nonEmpty = results.filter { !$0.keypoints.isEmpty }.count
    print("✅ Wrote \(results.count) frames to \(args.output.path)")
    print("   non-empty frames: \(nonEmpty)")
} catch {
    fputs("❌ \(error.localizedDescription)\n", stderr)
    exit(1)
}
