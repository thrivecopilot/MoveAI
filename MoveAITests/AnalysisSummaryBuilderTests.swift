import XCTest
@testable import MoveAI

final class AnalysisSummaryBuilderTests: XCTestCase {
    func testBuildRepSummaryUsesRepsAndDepthMetrics() {
        let reps = [
            SquatRep(
                repNumber: 1,
                startFrame: 0,
                endFrame: 30,
                startTime: 0.0,
                endTime: 1.0,
                isFullRep: true,
                bottomFrame: 15,
                bottomTime: 0.5,
                reachedDepth: true,
                returnedToStart: true
            ),
            SquatRep(
                repNumber: 2,
                startFrame: 31,
                endFrame: 60,
                startTime: 1.05,
                endTime: 2.0,
                isFullRep: true,
                bottomFrame: 46,
                bottomTime: 1.5,
                reachedDepth: false,
                returnedToStart: true
            ),
            SquatRep(
                repNumber: 3,
                startFrame: 61,
                endFrame: 90,
                startTime: 2.05,
                endTime: 3.0,
                isFullRep: false,
                bottomFrame: 76,
                bottomTime: 2.5,
                reachedDepth: true,
                returnedToStart: false
            ),
        ]

        let depthMetrics = [
            DepthAnalysis(
                hipHeight: 0.42,
                kneeHeight: 0.50,
                isAtDepth: true,
                depthPercentage: 86,
                timestamp: Date(timeIntervalSince1970: 0.5),
                repNumber: 1
            ),
            DepthAnalysis(
                hipHeight: 0.45,
                kneeHeight: 0.48,
                isAtDepth: false,
                depthPercentage: 92,
                timestamp: Date(timeIntervalSince1970: 1.5),
                repNumber: 2
            ),
        ]

        let feedback = [
            FormFeedback(
                category: .posture,
                message: "Torso tipped forward",
                severity: .warning,
                timestamp: 1.5,
                repNumber: 2,
                issueKind: .squatForwardLean
            ),
            FormFeedback(
                category: .safety,
                message: "Camera angle/visibility limited analysis.",
                severity: .warning,
                timestamp: 0,
                repNumber: nil,
                issueKind: .squatCameraAngleLimited
            ),
        ]

        let summary = AnalysisSummaryBuilder.build(
            movementType: .squat,
            feedback: feedback,
            reps: reps,
            depthMetrics: depthMetrics
        )

        XCTAssertEqual(summary?.unitKind, .rep)
        XCTAssertEqual(summary?.totalUnits, 3)
        XCTAssertEqual(summary?.goodUnits, 1)
        XCTAssertEqual(summary?.unitsNeedingAttention, 2)
        XCTAssertEqual(summary?.warningEvents, 1)
    }

    func testBuildStrikeSummaryInfersAttemptsFromWarningTimestamps() {
        let feedback = [
            FormFeedback(
                category: .posture,
                message: "Turn your hip through the punch",
                severity: .critical,
                timestamp: 1.0,
                repNumber: nil,
                issueKind: .muayThaiCrossNoHipRotation
            ),
            FormFeedback(
                category: .safety,
                message: "Keep your rear hand on your cheek",
                severity: .warning,
                timestamp: 1.0,
                repNumber: nil,
                issueKind: .muayThaiJabRearHandDropping
            ),
            FormFeedback(
                category: .stability,
                message: "Avoid leaning forward on the teep",
                severity: .warning,
                timestamp: 2.0,
                repNumber: nil,
                issueKind: .muayThaiTeepFallingForward
            ),
            FormFeedback(
                category: .safety,
                message: "Analysis coverage limited",
                severity: .warning,
                timestamp: 0,
                repNumber: nil,
                issueKind: .muayThaiAnalysisCoverageLimited
            ),
        ]

        let summary = AnalysisSummaryBuilder.build(
            movementType: .muayThai,
            feedback: feedback,
            reps: nil,
            depthMetrics: nil,
            attemptsCount: 4,
            attemptsNeedingAttention: nil
        )

        XCTAssertEqual(summary?.unitKind, .strike)
        XCTAssertEqual(summary?.totalUnits, 4)
        XCTAssertEqual(summary?.unitsNeedingAttention, 2)
        XCTAssertEqual(summary?.goodUnits, 2)
        XCTAssertEqual(summary?.warningEvents, 3)
    }

    func testBuildStrikeSummaryUsesExplicitAttemptsNeedingAttention() {
        let feedback = [
            FormFeedback(
                category: .posture,
                message: "Turn your hip through the punch",
                severity: .warning,
                timestamp: 0.8,
                repNumber: nil,
                issueKind: .muayThaiCrossNoHipRotation
            ),
        ]

        let summary = AnalysisSummaryBuilder.build(
            movementType: .muayThai,
            feedback: feedback,
            reps: nil,
            depthMetrics: nil,
            attemptsCount: 5,
            attemptsNeedingAttention: 3
        )

        XCTAssertEqual(summary?.unitKind, .strike)
        XCTAssertEqual(summary?.totalUnits, 5)
        XCTAssertEqual(summary?.unitsNeedingAttention, 3)
        XCTAssertEqual(summary?.goodUnits, 2)
        XCTAssertEqual(summary?.warningEvents, 1)
    }

    func testBuildStrikeSummaryWithNoWarningsStillCountsStrikes() {
        let summary = AnalysisSummaryBuilder.build(
            movementType: .muayThai,
            feedback: [],
            reps: nil,
            depthMetrics: nil,
            attemptsCount: 3,
            attemptsNeedingAttention: 0
        )

        XCTAssertEqual(summary?.unitKind, .strike)
        XCTAssertEqual(summary?.totalUnits, 3)
        XCTAssertEqual(summary?.goodUnits, 3)
        XCTAssertEqual(summary?.unitsNeedingAttention, 0)
        XCTAssertEqual(summary?.warningEvents, 0)
    }

    func testAnalysisResultRoundTripWithoutSummaryDecodesNilSummary() throws {
        let original = AnalysisResult(
            score: 88,
            feedback: [
                FormFeedback(
                    category: .posture,
                    message: "Good posture",
                    severity: .good,
                    timestamp: 0.3
                )
            ]
        )

        let encoded = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(AnalysisResult.self, from: encoded)

        XCTAssertNil(decoded.analysisSummary)
        XCTAssertNil(decoded.detectedTechnique)
        XCTAssertNil(decoded.detectionConfidence)
    }

    func testAnalysisResultBackwardDecodeWithoutDetectionFields() throws {
        let json = """
        {
          "score": 92.0,
          "feedback": [],
          "timestamp": 0
        }
        """

        let decoded = try JSONDecoder().decode(AnalysisResult.self, from: Data(json.utf8))

        XCTAssertEqual(decoded.score, 92.0, accuracy: 0.0001)
        XCTAssertNil(decoded.detectedTechnique)
        XCTAssertNil(decoded.detectionConfidence)
    }
}
