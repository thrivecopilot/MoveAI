import XCTest
@testable import MoveAI

final class MuayThaiAnalyzerTests: XCTestCase {
    override func tearDown() {
        unsetenv("MOVEAI_ENABLE_MUAY_THAI_ANALYZER")
        super.tearDown()
    }

    func testMuayThaiCatalogContainsAllRequestedIssues() {
        let actual = Set(MuayThaiIssueCatalog.entries.map(\.issueKind))
        let expected: Set<MovementIssueKind> = [
            .muayThaiJabRearHandDropping,
            .muayThaiJabLeaningForward,
            .muayThaiJabNoShoulderProtection,
            .muayThaiCrossNoHipRotation,
            .muayThaiCrossRearHeelNotPivoting,
            .muayThaiCrossOverreaching,
            .muayThaiLeadHookArmOnly,
            .muayThaiLeadHookTooWide,
            .muayThaiRoundhouseNoSupportFootPivot,
            .muayThaiRoundhouseNoHipTurnover,
            .muayThaiRoundhouseKickingWithFoot,
            .muayThaiRoundhouseNoArmCounterbalance,
            .muayThaiTeepNoKneeChamber,
            .muayThaiTeepFallingForward,
            .muayThaiStraightKneeTravelVertical,
            .muayThaiStraightKneeNoHipThrust,
            .muayThaiHorizontalElbowTooWide,
            .muayThaiHorizontalElbowNoBodyRotation,
            .muayThaiMovementCrossingFeet,
            .muayThaiMovementFlatFooted,
        ]

        XCTAssertEqual(actual, expected)
    }

    func testMuayThaiCatalogSeverityMapping() {
        let highKinds: Set<MovementIssueKind> = [
            .muayThaiJabRearHandDropping,
            .muayThaiCrossNoHipRotation,
            .muayThaiCrossRearHeelNotPivoting,
            .muayThaiRoundhouseNoSupportFootPivot,
            .muayThaiRoundhouseNoHipTurnover,
            .muayThaiStraightKneeNoHipThrust,
            .muayThaiMovementCrossingFeet,
        ]

        for entry in MuayThaiIssueCatalog.entries {
            if highKinds.contains(entry.issueKind) {
                XCTAssertEqual(entry.severity, .critical, "Expected critical severity for \(entry.issueKind.rawValue)")
            } else {
                XCTAssertEqual(entry.severity, .warning, "Expected warning severity for \(entry.issueKind.rawValue)")
            }
        }
    }

    func testMuayThaiCatalogBlockedIssuesExactlyMatchSpec() {
        let blocked = Set(
            MuayThaiIssueCatalog.entries
                .filter { $0.detectionSupport == .blocked }
                .map(\.issueKind)
        )

        XCTAssertEqual(blocked, [
            .muayThaiCrossRearHeelNotPivoting,
            .muayThaiRoundhouseNoSupportFootPivot,
            .muayThaiRoundhouseKickingWithFoot,
            .muayThaiMovementFlatFooted,
        ])
    }

    func testMovementCrossingFeetDetectorTriggersWhenAnklesCross() {
        let poses = crossingMovementPoses(frameCount: 20)
        let attempts = MuayThaiEventDetector.detectAttempts(poses: poses, technique: .movement, stance: .orthodox)

        let outcome = MuayThaiIssueDetectors.evaluate(
            poses: poses,
            attempts: attempts,
            technique: .movement,
            stance: .orthodox
        )

        XCTAssertTrue(outcome.feedback.contains { $0.issueKind == .muayThaiMovementCrossingFeet })
    }

    func testMovementCrossingFeetDetectorDoesNotTriggerWhenStanceWidthStable() {
        let poses = stableMovementPoses(frameCount: 20)
        let attempts = MuayThaiEventDetector.detectAttempts(poses: poses, technique: .movement, stance: .orthodox)

        let outcome = MuayThaiIssueDetectors.evaluate(
            poses: poses,
            attempts: attempts,
            technique: .movement,
            stance: .orthodox
        )

        XCTAssertFalse(outcome.feedback.contains { $0.issueKind == .muayThaiMovementCrossingFeet })
    }

    func testPoseBasedAnalysisServiceMuayThaiRequiresTechnique() async {
        setenv("MOVEAI_ENABLE_MUAY_THAI_ANALYZER", "1", 1)
        let service = PoseBasedAnalysisService()
        let recording = MovementRecording(
            movementType: .muayThai,
            videoURL: URL(fileURLWithPath: "/tmp/test.mov"),
            duration: 2.0,
            poseData: stableMovementPoses(frameCount: 12)
        )

        do {
            _ = try await service.analyzeMovement(recording)
            XCTFail("Expected missing-technique error")
        } catch let error as AnalysisError {
            if case .analysisFailed(let reason) = error {
                XCTAssertTrue(reason.localizedCaseInsensitiveContains("select a muay thai technique"))
            } else {
                XCTFail("Unexpected AnalysisError case: \(error)")
            }
        } catch {
            XCTFail("Unexpected error type: \(error)")
        }
    }

    func testPoseBasedAnalysisServiceMuayThaiCoverageWarningAndNoScorePenalty() async throws {
        setenv("MOVEAI_ENABLE_MUAY_THAI_ANALYZER", "1", 1)

        let service = PoseBasedAnalysisService()
        let recording = MovementRecording(
            movementType: .muayThai,
            technique: .movement,
            fightStance: .orthodox,
            videoURL: URL(fileURLWithPath: "/tmp/test.mov"),
            duration: 2.0,
            poseData: stableMovementPoses(frameCount: 24)
        )

        let result = try await service.analyzeMovement(recording)

        let coverage = result.feedback.filter { $0.issueKind == .muayThaiAnalysisCoverageLimited }
        XCTAssertEqual(coverage.count, 1)
        XCTAssertEqual(result.score, 100, accuracy: 0.0001)
    }

    private func stableMovementPoses(frameCount: Int) -> [PoseDetectionResult] {
        (0..<frameCount).map { frame in
            makePose(
                frame: frame,
                leftAnkleX: 0.42,
                rightAnkleX: 0.58,
                leftKneeX: 0.44,
                rightKneeX: 0.56,
                leftWristX: 0.42,
                rightWristX: 0.58
            )
        }
    }

    private func crossingMovementPoses(frameCount: Int) -> [PoseDetectionResult] {
        (0..<frameCount).map { frame in
            let progress = Double(frame) / Double(max(frameCount - 1, 1))
            let leftAnkle = 0.40 + (0.24 * progress)
            let rightAnkle = 0.60 - (0.24 * progress)
            let leftKnee = 0.43 + (0.19 * progress)
            let rightKnee = 0.57 - (0.19 * progress)

            return makePose(
                frame: frame,
                leftAnkleX: leftAnkle,
                rightAnkleX: rightAnkle,
                leftKneeX: leftKnee,
                rightKneeX: rightKnee,
                leftWristX: 0.42,
                rightWristX: 0.58
            )
        }
    }

    private func makePose(
        frame: Int,
        leftAnkleX: Double,
        rightAnkleX: Double,
        leftKneeX: Double,
        rightKneeX: Double,
        leftWristX: Double,
        rightWristX: Double
    ) -> PoseDetectionResult {
        let timestamp = Date(timeIntervalSince1970: Double(frame) / 30.0)

        let keypoints: [PoseKeypoint] = [
            kp("nose", x: 0.50, y: 0.85, frame: frame),
            kp("neck", x: 0.50, y: 0.76, frame: frame),
            kp("leftShoulder", x: 0.45, y: 0.74, frame: frame),
            kp("rightShoulder", x: 0.55, y: 0.74, frame: frame),
            kp("leftElbow", x: 0.44, y: 0.66, frame: frame),
            kp("rightElbow", x: 0.56, y: 0.66, frame: frame),
            kp("leftWrist", x: leftWristX, y: 0.58, frame: frame),
            kp("rightWrist", x: rightWristX, y: 0.58, frame: frame),
            kp("leftHip", x: 0.46, y: 0.52, frame: frame),
            kp("rightHip", x: 0.54, y: 0.52, frame: frame),
            kp("root", x: 0.50, y: 0.50, frame: frame),
            kp("leftKnee", x: leftKneeX, y: 0.38, frame: frame),
            kp("rightKnee", x: rightKneeX, y: 0.38, frame: frame),
            kp("leftAnkle", x: leftAnkleX, y: 0.24, frame: frame),
            kp("rightAnkle", x: rightAnkleX, y: 0.24, frame: frame),
        ]

        return PoseDetectionResult(keypoints: keypoints, frameIndex: frame, timestamp: timestamp)
    }

    private func kp(_ name: String, x: Double, y: Double, frame: Int) -> PoseKeypoint {
        PoseKeypoint(
            name: name,
            position: CGPoint(x: x, y: y),
            confidence: 1.0,
            timestamp: Date(timeIntervalSince1970: Double(frame) / 30.0)
        )
    }
}
