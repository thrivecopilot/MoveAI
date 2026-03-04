import CoreVideo
import Foundation
import ImageIO
import Vision

/// Reusable Vision pose extractor for processing multiple frames efficiently.
///
/// - Note: This type is not thread-safe. Use from a single task/queue.
final class PoseExtractor {
    private let request: VNDetectHumanBodyPoseRequest

    private let jointNames: [VNHumanBodyPoseObservation.JointName] = [
        .nose, .leftEye, .rightEye, .leftEar, .rightEar,
        .neck, .leftShoulder, .rightShoulder, .leftElbow, .rightElbow,
        .leftWrist, .rightWrist, .leftHip, .rightHip, .root,
        .leftKnee, .rightKnee, .leftAnkle, .rightAnkle
    ]

    init() {
        let request = VNDetectHumanBodyPoseRequest()

        // Prefer the newest supported revision for best accuracy.
        if let maxRevision = type(of: request).supportedRevisions.max() {
            request.revision = maxRevision
        }

        self.request = request
    }

    func extract(
        pixelBuffer: CVPixelBuffer,
        orientation: CGImagePropertyOrientation,
        frameIndex: Int,
        timestampSeconds: Double
    ) -> PoseDetectionResult {
        var keypoints: [PoseKeypoint] = []

        let handler = VNImageRequestHandler(
            cvPixelBuffer: pixelBuffer,
            orientation: orientation,
            options: [:]
        )

        do {
            try handler.perform([request])

            if let observation = request.results?.first {
                for jointName in jointNames {
                    guard let point = try? observation.recognizedPoint(jointName) else { continue }
                    guard point.confidence > 0.1 else { continue }

                    let keypointName = PoseAnalysisHelpers.jointNameToString(jointName)
                    keypoints.append(
                        PoseKeypoint(
                            name: keypointName,
                            position: CGPoint(x: point.location.x, y: point.location.y),
                            confidence: point.confidence
                        )
                    )
                }
            }
        } catch {
            // Return empty keypoints on failure; downstream expects a uniform, indexable array.
        }

        let ts = Date(timeIntervalSince1970: timestampSeconds)
        return PoseDetectionResult(keypoints: keypoints, frameIndex: frameIndex, timestamp: ts)
    }
}
