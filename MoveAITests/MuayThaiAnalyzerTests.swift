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
            .muayThaiPostureForwardOverBase,
            .muayThaiJabPoorRetraction,
            .muayThaiCrossNoHipRotation,
            .muayThaiCrossRearHeelNotPivoting,
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

    func testMuayThaiTechniqueDetectorDetectsJabFromLeadWristPattern() {
        let poses = jabLikePoses(frameCount: 20)
        let detection = MuayThaiTechniqueDetector.detect(poses: poses, preferredStance: .orthodox)

        XCTAssertEqual(detection?.technique, .jab)
        XCTAssertNotNil(detection)
    }

    func testMuayThaiTechniqueDetectorDetectsRightHandJabWhenStanceUnknown() {
        let poses = rightHandJabPoses(frameCount: 24, leftGuardDropped: false)
        let detection = MuayThaiTechniqueDetector.detect(poses: poses, preferredStance: nil)
        XCTAssertNotNil(detection)
        XCTAssertEqual(detection?.technique, .jab)
    }

    func testMuayThaiTechniqueDetectorPrefersJabForRepeatedRightHandJabsWhenStanceUnknown() {
        let poses = repeatedRightHandJabPoses(
            frameCount: 72,
            strikeCenters: [8, 18, 28, 38, 48, 58],
            leftGuardDropped: false,
            hipRotationScale: 0.01
        )
        let detection = MuayThaiTechniqueDetector.detect(poses: poses, preferredStance: nil)

        XCTAssertNotNil(detection)
        XCTAssertEqual(detection?.technique, .jab)
    }

    func testJabRearHandDropDoesNotTriggerWhenWrongStanceButGuardIsStable() {
        let poses = repeatedRightHandJabPoses(
            frameCount: 72,
            strikeCenters: [8, 18, 28, 38, 48, 58],
            leftGuardDropped: false,
            hipRotationScale: 0.01
        )
        let attempts = MuayThaiEventDetector.detectAttempts(poses: poses, technique: .jab, stance: .orthodox)

        let outcome = MuayThaiIssueDetectors.evaluate(
            poses: poses,
            attempts: attempts,
            technique: .jab,
            stance: .orthodox,
            stanceSource: .userSelected
        )

        XCTAssertFalse(outcome.feedback.contains { $0.issueKind == .muayThaiJabRearHandDropping })
    }

    func testJabRearHandDropStillTriggersWhenGuardActuallyDrops() {
        let poses = repeatedRightHandJabPoses(
            frameCount: 72,
            strikeCenters: [8, 18, 28, 38, 48, 58],
            leftGuardDropped: true,
            hipRotationScale: 0.01
        )
        let attempts = MuayThaiEventDetector.detectAttempts(poses: poses, technique: .jab, stance: .southpaw)

        let outcome = MuayThaiIssueDetectors.evaluate(
            poses: poses,
            attempts: attempts,
            technique: .jab,
            stance: .southpaw,
            stanceSource: .userSelected
        )

        let issueKinds = outcome.feedback.map(\.issueKind)
        XCTAssertTrue(
            outcome.feedback.contains { $0.issueKind == .muayThaiJabRearHandDropping },
            "Expected rear-hand dropping feedback, got: \(issueKinds)"
        )
    }

    func testMuayThaiTechniqueDetectorDetectsMovementFromFootworkPattern() {
        let poses = footworkMovementPoses(frameCount: 20)
        let detection = MuayThaiTechniqueDetector.detect(poses: poses, preferredStance: .orthodox)

        XCTAssertEqual(detection?.technique, .movement)
        XCTAssertNotNil(detection)
    }

    func testMuayThaiComboDetectorDetectsMultipleTechniquesInSingleClip() {
        let poses = jabCrossComboPoses(frameCount: 36)
        let detection = MuayThaiComboDetector.detect(poses: poses, preferredStance: .orthodox)

        XCTAssertNotNil(detection)
        let techniques = Set(detection?.attempts.map(\.technique) ?? [])
        XCTAssertTrue(techniques.contains(.jab))
        XCTAssertTrue(techniques.contains(.cross))
        XCTAssertGreaterThanOrEqual(detection?.attempts.count ?? 0, 2)
    }

    func testMuayThaiComboDetectorDoesNotForceAutoInferredStanceForClassification() {
        let poses = repeatedRightHandJabPoses(
            frameCount: 72,
            strikeCenters: [8, 18, 28, 38, 48, 58],
            leftGuardDropped: false,
            hipRotationScale: 0.01
        )

        let detection = MuayThaiComboDetector.detect(poses: poses, preferredStance: nil)
        XCTAssertNotNil(detection)

        let techniques = detection?.attempts.map(\.technique) ?? []
        XCTAssertFalse(techniques.isEmpty)

        let grouped = Dictionary(grouping: techniques, by: { $0 }).mapValues(\.count)
        XCTAssertGreaterThan(grouped[.jab] ?? 0, grouped[.cross] ?? 0, "Expected jab to dominate repeated jab-only clip")
    }

    func testMuayThaiIssueDetectorsAggregateBlockedCoverageForMixedAttempts() {
        let poses = stableMovementPoses(frameCount: 20)
        let attempts = [
            MuayThaiClassifiedAttempt(
                attempt: TechniqueAttempt(startFrame: 0, endFrame: 10, peakFrame: 5, peakTimestamp: poses[5].timestamp.timeIntervalSince1970),
                technique: .cross,
                confidence: 0.7
            ),
            MuayThaiClassifiedAttempt(
                attempt: TechniqueAttempt(startFrame: 9, endFrame: 19, peakFrame: 14, peakTimestamp: poses[14].timestamp.timeIntervalSince1970),
                technique: .movement,
                confidence: 0.7
            ),
        ]

        let outcome = MuayThaiIssueDetectors.evaluate(
            poses: poses,
            classifiedAttempts: attempts,
            stance: .orthodox
        )

        let blockedKinds = Set(outcome.blockedEntries.map(\.issueKind))
        XCTAssertTrue(blockedKinds.contains(.muayThaiCrossRearHeelNotPivoting))
        XCTAssertTrue(blockedKinds.contains(.muayThaiMovementFlatFooted))
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

    func testRearHandDroppingIgnoresStrikingHandWhenStanceMapIsWrong() {
        let poses = rightHandJabPoses(frameCount: 21, leftGuardDropped: false)
        let peakFrame = poses.count / 2
        let attempts = [
            TechniqueAttempt(
                startFrame: 0,
                endFrame: poses.count - 1,
                peakFrame: peakFrame,
                peakTimestamp: poses[peakFrame].timestamp.timeIntervalSince1970
            )
        ]

        let outcome = MuayThaiIssueDetectors.evaluate(
            poses: poses,
            attempts: attempts,
            technique: .jab,
            stance: .orthodox,
            stanceSource: .userSelected
        )

        XCTAssertFalse(outcome.feedback.contains { $0.issueKind == .muayThaiJabRearHandDropping })
    }

    func testRearHandDroppingTargetsGuardHandForRightHandJab() {
        let poses = repeatedRightHandJabPoses(
            frameCount: 72,
            strikeCenters: [8, 18, 28, 38, 48, 58],
            leftGuardDropped: true,
            hipRotationScale: 0.01
        )
        let attempts = MuayThaiEventDetector.detectAttempts(poses: poses, technique: .jab, stance: .orthodox)

        let outcome = MuayThaiIssueDetectors.evaluate(
            poses: poses,
            attempts: attempts,
            technique: .jab,
            stance: .orthodox,
            stanceSource: .userSelected
        )

        guard let rearHandDrop = outcome.feedback.first(where: { $0.issueKind == .muayThaiJabRearHandDropping }) else {
            let issueKinds = outcome.feedback.map(\.issueKind)
            XCTFail("Expected rear-hand dropping feedback, got: \(issueKinds)")
            return
        }

        let joints = rearHandDrop.affectedBodyJoints ?? []
        XCTAssertTrue(joints.contains(.leftWrist), "Expected leftWrist in affected joints, got: \(joints)")
        XCTAssertFalse(joints.contains(.rightWrist), "Expected rightWrist to be excluded, got: \(joints)")
    }

    func testPoseBasedAnalysisServiceMuayThaiAutoDetectsTechniqueWhenMissing() async throws {
        setenv("MOVEAI_ENABLE_MUAY_THAI_ANALYZER", "1", 1)

        let service = PoseBasedAnalysisService()
        let recording = MovementRecording(
            movementType: .muayThai,
            videoURL: URL(fileURLWithPath: "/tmp/test.mov"),
            duration: 2.0,
            poseData: jabLikePoses(frameCount: 24)
        )

        let result = try await service.analyzeMovement(recording)

        XCTAssertEqual(result.detectedTechnique, .jab)
        XCTAssertEqual(result.analysisSummary?.unitKind, .strike)
    }

    func testPoseBasedAnalysisServiceMuayThaiAutoDetectFailsForLowMotionClip() async {
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
            XCTFail("Expected auto-detection failure")
        } catch let error as AnalysisError {
            if case .muayThaiTechniqueAutoDetectionFailed = error {
                // expected
            } else {
                XCTFail("Unexpected AnalysisError case: \(error)")
            }
        } catch {
            XCTFail("Unexpected error type: \(error)")
        }
    }

    func testPoseBasedAnalysisServiceMuayThaiRespectsExplicitDisableFlag() async {
        setenv("MOVEAI_ENABLE_MUAY_THAI_ANALYZER", "0", 1)
        let service = PoseBasedAnalysisService()
        let recording = MovementRecording(
            movementType: .muayThai,
            technique: .jab,
            videoURL: URL(fileURLWithPath: "/tmp/test.mov"),
            duration: 2.0,
            poseData: stableMovementPoses(frameCount: 12)
        )

        do {
            _ = try await service.analyzeMovement(recording)
            XCTFail("Expected Muay Thai disabled error")
        } catch let error as AnalysisError {
            if case .muayThaiAnalysisDisabled = error {
                // expected
            } else {
                XCTFail("Unexpected AnalysisError case: \(error)")
            }
        } catch {
            XCTFail("Unexpected error type: \(error)")
        }
    }

    func testPoseBasedAnalysisServiceMuayThaiQualityLimitAndCoverageWarningHaveNoScorePenalty() async throws {
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

        let quality = result.feedback.filter { $0.issueKind == .muayThaiCaptureQualityLimited }
        let coverage = result.feedback.filter { $0.issueKind == .muayThaiAnalysisCoverageLimited }
        XCTAssertEqual(quality.count, 1)
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
                rightWristX: 0.58,
                leftElbowX: 0.44,
                rightElbowX: 0.56,
                leftShoulderX: 0.45,
                rightShoulderX: 0.55
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
                rightWristX: 0.58,
                leftElbowX: 0.44,
                rightElbowX: 0.56,
                leftShoulderX: 0.45,
                rightShoulderX: 0.55
            )
        }
    }

    private func footworkMovementPoses(frameCount: Int) -> [PoseDetectionResult] {
        (0..<frameCount).map { frame in
            let progress = Double(frame) / Double(max(frameCount - 1, 1))
            let lateralShift = 0.12 * progress

            return makePose(
                frame: frame,
                leftAnkleX: 0.42 + lateralShift,
                rightAnkleX: 0.58 + lateralShift,
                leftKneeX: 0.44 + lateralShift,
                rightKneeX: 0.56 + lateralShift,
                leftWristX: 0.42,
                rightWristX: 0.58,
                leftElbowX: 0.44,
                rightElbowX: 0.56,
                leftShoulderX: 0.45 + (lateralShift * 0.5),
                rightShoulderX: 0.55 + (lateralShift * 0.5)
            )
        }
    }

    private func rightHandJabPoses(frameCount: Int, leftGuardDropped: Bool) -> [PoseDetectionResult] {
        let center = max(1, frameCount / 2)
        let halfWidth = max(3, frameCount / 4)

        return (0..<frameCount).map { frame in
            let pulse = triangularPulse(frame: frame, center: center, halfWidth: halfWidth)

            let strikingWristX = 0.58 + (0.30 * pulse)
            let strikingElbowX = 0.56 + (0.10 * pulse)
            let strikingShoulderX = 0.55 + (0.03 * pulse)

            let guardDropPulse = leftGuardDropped ? pulse : 0
            let guardWristX = 0.50 - (0.05 * guardDropPulse)
            let guardWristY = 0.84 - (0.16 * guardDropPulse)

            return makePose(
                frame: frame,
                leftAnkleX: 0.42,
                rightAnkleX: 0.58,
                leftKneeX: 0.44,
                rightKneeX: 0.56,
                leftWristX: guardWristX,
                rightWristX: strikingWristX,
                leftElbowX: 0.44,
                rightElbowX: strikingElbowX,
                leftShoulderX: 0.45,
                rightShoulderX: strikingShoulderX,
                leftWristY: guardWristY,
                rightWristY: 0.58
            )
        }
    }

    private func repeatedRightHandJabPoses(
        frameCount: Int,
        strikeCenters: [Int],
        leftGuardDropped: Bool,
        hipRotationScale: Double
    ) -> [PoseDetectionResult] {
        let halfWidth = 3

        return (0..<frameCount).map { frame in
            let pulse = strikeCenters.reduce(0.0) { partial, center in
                max(partial, triangularPulse(frame: frame, center: center, halfWidth: halfWidth))
            }

            let strikingWristX = 0.58 + (0.28 * pulse)
            let strikingElbowX = 0.56 + (0.10 * pulse)
            let leftShoulderX = 0.45 + (hipRotationScale * 0.35 * pulse)
            let rightShoulderX = 0.55 + (hipRotationScale * pulse)

            let guardDropPulse = leftGuardDropped ? pulse : 0
            let guardWristX = 0.50 - (0.05 * guardDropPulse)
            let guardWristY = 0.84 - (0.16 * guardDropPulse)

            return makePose(
                frame: frame,
                leftAnkleX: 0.42,
                rightAnkleX: 0.58,
                leftKneeX: 0.44,
                rightKneeX: 0.56,
                leftWristX: guardWristX,
                rightWristX: strikingWristX,
                leftElbowX: 0.44,
                rightElbowX: strikingElbowX,
                leftShoulderX: leftShoulderX,
                rightShoulderX: rightShoulderX,
                leftWristY: guardWristY,
                rightWristY: 0.58
            )
        }
    }

    private func jabLikePoses(frameCount: Int) -> [PoseDetectionResult] {
        (0..<frameCount).map { frame in
            let progress = Double(frame) / Double(max(frameCount - 1, 1))
            let pulse = progress <= 0.5 ? (progress * 2.0) : ((1.0 - progress) * 2.0)

            let leadWristX = 0.42 + (0.30 * pulse)
            let rearWristX = 0.58 + (0.03 * pulse)
            let leadElbowX = 0.44 + (0.10 * pulse)
            let leadShoulderX = 0.45 + (0.03 * pulse)

            return makePose(
                frame: frame,
                leftAnkleX: 0.42,
                rightAnkleX: 0.58,
                leftKneeX: 0.44,
                rightKneeX: 0.56,
                leftWristX: leadWristX,
                rightWristX: rearWristX,
                leftElbowX: leadElbowX,
                rightElbowX: 0.56,
                leftShoulderX: leadShoulderX,
                rightShoulderX: 0.55
            )
        }
    }

    private func jabCrossComboPoses(frameCount: Int) -> [PoseDetectionResult] {
        (0..<frameCount).map { frame in
            let jabPulse = triangularPulse(frame: frame, center: 9, halfWidth: 5)
            let crossPulse = triangularPulse(frame: frame, center: 25, halfWidth: 5)

            let leadWristX = 0.42 + (0.28 * jabPulse) + (0.03 * crossPulse)
            let rearWristX = 0.58 + (0.03 * jabPulse) + (0.30 * crossPulse)
            let leftElbowX = 0.44 + (0.09 * jabPulse)
            let rightElbowX = 0.56 + (0.09 * crossPulse)
            let leftShoulderX = 0.45 + (0.02 * jabPulse) + (0.03 * crossPulse)
            let rightShoulderX = 0.55 + (0.01 * jabPulse) + (0.02 * crossPulse)

            return makePose(
                frame: frame,
                leftAnkleX: 0.42,
                rightAnkleX: 0.58,
                leftKneeX: 0.44,
                rightKneeX: 0.56,
                leftWristX: leadWristX,
                rightWristX: rearWristX,
                leftElbowX: leftElbowX,
                rightElbowX: rightElbowX,
                leftShoulderX: leftShoulderX,
                rightShoulderX: rightShoulderX
            )
        }
    }

    private func triangularPulse(frame: Int, center: Int, halfWidth: Int) -> Double {
        let distance = abs(frame - center)
        guard distance <= halfWidth else { return 0 }
        return 1.0 - (Double(distance) / Double(max(halfWidth, 1)))
    }

    private func makePose(
        frame: Int,
        leftAnkleX: Double,
        rightAnkleX: Double,
        leftKneeX: Double,
        rightKneeX: Double,
        leftWristX: Double,
        rightWristX: Double,
        leftElbowX: Double,
        rightElbowX: Double,
        leftShoulderX: Double,
        rightShoulderX: Double,
        leftWristY: Double = 0.58,
        rightWristY: Double = 0.58
    ) -> PoseDetectionResult {
        let timestamp = Date(timeIntervalSince1970: Double(frame) / 30.0)

        let keypoints: [PoseKeypoint] = [
            kp("nose", x: 0.50, y: 0.85, frame: frame),
            kp("neck", x: 0.50, y: 0.76, frame: frame),
            kp("leftShoulder", x: leftShoulderX, y: 0.74, frame: frame),
            kp("rightShoulder", x: rightShoulderX, y: 0.74, frame: frame),
            kp("leftElbow", x: leftElbowX, y: 0.66, frame: frame),
            kp("rightElbow", x: rightElbowX, y: 0.66, frame: frame),
            kp("leftWrist", x: leftWristX, y: leftWristY, frame: frame),
            kp("rightWrist", x: rightWristX, y: rightWristY, frame: frame),
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
