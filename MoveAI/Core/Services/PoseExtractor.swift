import CoreVideo
import Foundation
import ImageIO
import Vision

/// Reusable Vision pose extractor for processing multiple frames efficiently.
///
/// - Note: This type is not thread-safe. Use from a single task/queue.
final class PoseExtractor {
    private let request: VNDetectHumanBodyPoseRequest
    private let fallbackRequest: VNDetectHumanBodyPoseRequest
    private var shouldUseFallbackRequest = false

    private let jointNames: [VNHumanBodyPoseObservation.JointName] = [
        .nose, .leftEye, .rightEye, .leftEar, .rightEar,
        .neck, .leftShoulder, .rightShoulder, .leftElbow, .rightElbow,
        .leftWrist, .rightWrist, .leftHip, .rightHip, .root,
        .leftKnee, .rightKnee, .leftAnkle, .rightAnkle
    ]

    init() {
        let primary = VNDetectHumanBodyPoseRequest()
        let fallback = VNDetectHumanBodyPoseRequest()

        let supportedRevisions = type(of: primary).supportedRevisions.sorted()
        if let maxRevision = supportedRevisions.last {
            // Prefer the latest revision for parity with production analysis quality.
            primary.revision = maxRevision
        }
        if let minRevision = supportedRevisions.first, minRevision != primary.revision {
            // Keep a lower-revision fallback for runtimes where the latest model fails to load.
            fallback.revision = minRevision
        }

        self.request = primary
        self.fallbackRequest = fallback
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

        if !runPoseRequest(shouldUseFallbackRequest ? fallbackRequest : request, with: handler, into: &keypoints) {
            // If the primary revision fails due model-loading/runtime issues, permanently
            // fall back to the default revision for this extractor instance.
            if !shouldUseFallbackRequest {
                shouldUseFallbackRequest = true
                _ = runPoseRequest(fallbackRequest, with: handler, into: &keypoints)
            }
        }

        let ts = Date(timeIntervalSince1970: timestampSeconds)
        return PoseDetectionResult(keypoints: keypoints, frameIndex: frameIndex, timestamp: ts)
    }

    @discardableResult
    private func runPoseRequest(
        _ poseRequest: VNDetectHumanBodyPoseRequest,
        with handler: VNImageRequestHandler,
        into keypoints: inout [PoseKeypoint]
    ) -> Bool {
        do {
            try handler.perform([poseRequest])

            if let observation = poseRequest.results?.first {
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

            return true
        } catch {
            return false
        }
    }
}
