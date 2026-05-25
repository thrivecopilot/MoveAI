import XCTest
import CoreGraphics
@testable import MoveAI

final class RunningAnalysisTests: XCTestCase {
    func testAnalyzeRunningProducesLowCadenceIssueWithStructuredMetric() async throws {
        let service = PoseBasedAnalysisService()
        let poses = makeRunningPoses(frameCount: 90)
        let recording = MovementRecording(
            movementType: .running,
            videoURL: URL(fileURLWithPath: "/tmp/running.mov"),
            duration: 3.0,
            poseData: poses
        )

        let result = try await service.analyzeMovement(recording)

        XCTAssertFalse(result.feedback.isEmpty)
        let lowCadence = result.feedback.first { $0.issueKind == .runningLowCadence }
        XCTAssertNotNil(lowCadence)
        XCTAssertEqual(lowCadence?.metrics?.first?.kind, .runningCadenceSpm)
        XCTAssertEqual(lowCadence?.metrics?.first?.unit, .count)
    }

    func testAnalyzeRunningFallsBackToCaptureQualityIssueWhenPoseCoverageIsLow() async throws {
        let service = PoseBasedAnalysisService()
        let poses = (0..<20).map { frame in
            PoseDetectionResult(
                keypoints: [],
                frameIndex: frame,
                timestamp: Date(timeIntervalSince1970: Double(frame) / 30.0)
            )
        }

        let recording = MovementRecording(
            movementType: .running,
            videoURL: URL(fileURLWithPath: "/tmp/running-low-coverage.mov"),
            duration: 1.0,
            poseData: poses
        )

        let result = try await service.analyzeMovement(recording)
        XCTAssertTrue(result.feedback.contains { $0.issueKind == .runningCaptureQualityLimited })
    }

    private func makeRunningPoses(frameCount: Int) -> [PoseDetectionResult] {
        (0..<frameCount).map { frame in
            let t = Double(frame)
            let phase = (2.0 * Double.pi * t) / 60.0
            let swing = 0.05 * sin(phase)
            let leftAnkleX = 0.45 + swing
            let rightAnkleX = 0.55 - swing

            let timestamp = Date(timeIntervalSince1970: t / 30.0)
            let keypoints: [PoseKeypoint] = [
                kp(.nose, x: 0.50, y: 0.86, timestamp: timestamp),
                kp(.leftShoulder, x: 0.46, y: 0.74, timestamp: timestamp),
                kp(.rightShoulder, x: 0.54, y: 0.74, timestamp: timestamp),
                kp(.leftHip, x: 0.47, y: 0.54, timestamp: timestamp),
                kp(.rightHip, x: 0.53, y: 0.54, timestamp: timestamp),
                kp(.leftKnee, x: 0.47, y: 0.38, timestamp: timestamp),
                kp(.rightKnee, x: 0.53, y: 0.38, timestamp: timestamp),
                kp(.leftAnkle, x: leftAnkleX, y: 0.23, timestamp: timestamp),
                kp(.rightAnkle, x: rightAnkleX, y: 0.23, timestamp: timestamp),
                kp(.root, x: 0.50, y: 0.52, timestamp: timestamp),
            ]

            return PoseDetectionResult(keypoints: keypoints, frameIndex: frame, timestamp: timestamp)
        }
    }

    private func kp(_ joint: BodyJoint, x: Double, y: Double, timestamp: Date) -> PoseKeypoint {
        PoseKeypoint(
            name: joint.rawValue,
            position: CGPoint(x: x, y: y),
            confidence: 1.0,
            timestamp: timestamp
        )
    }
}
