import XCTest
@testable import MoveAI

final class FormFeedbackCodableTests: XCTestCase {
    func testDecodeLegacyJSON() throws {
        let json = """
        {
          "id": "2FD19126-BE9D-45A9-9019-65B3B8E2D5A5",
          "category": "safety",
          "message": "Knees caving inward - push knees out to align with toes",
          "severity": "critical",
          "timestamp": 12.5,
          "repNumber": 2
        }
        """

        let decoded = try JSONDecoder().decode(FormFeedback.self, from: Data(json.utf8))

        XCTAssertEqual(decoded.category, .safety)
        XCTAssertEqual(decoded.severity, .critical)
        XCTAssertEqual(decoded.repNumber, 2)
        XCTAssertNil(decoded.issueKind)
        XCTAssertNil(decoded.affectedBodyJoints)
    }

    func testRoundTripWithJoints() throws {
        let original = FormFeedback(
            category: .safety,
            message: "Knees caving inward - push knees out to align with toes",
            severity: .critical,
            timestamp: 3.2,
            repNumber: 1,
            issueKind: .squatKneeValgus,
            affectedBodyJoints: [.leftKnee, .rightKnee]
        )

        let encoded = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(FormFeedback.self, from: encoded)

        XCTAssertEqual(decoded.id, original.id)
        XCTAssertEqual(decoded.category, original.category)
        XCTAssertEqual(decoded.message, original.message)
        XCTAssertEqual(decoded.severity, original.severity)
        XCTAssertEqual(decoded.timestamp, original.timestamp)
        XCTAssertEqual(decoded.repNumber, original.repNumber)
        XCTAssertEqual(decoded.issueKind, .squatKneeValgus)
        XCTAssertEqual(decoded.affectedBodyJoints, [.leftKnee, .rightKnee])
    }

    func testIssueSummaryBuilderPropagatesJoints() {
        let feedbackItems = [
            FormFeedback(
                category: .safety,
                message: "Knees caving inward - push knees out to align with toes",
                severity: .critical,
                timestamp: 2.0,
                repNumber: 1,
                affectedBodyJoints: [.leftKnee, .rightKnee]
            ),
            FormFeedback(
                category: .safety,
                message: "Knees caving inward - push knees out to align with toes",
                severity: .critical,
                timestamp: 4.0,
                repNumber: 2,
                affectedBodyJoints: [.leftKnee]
            )
        ]

        let summaries = IssueSummaryBuilder.from(feedbackItems)

        XCTAssertEqual(summaries.count, 1)
        XCTAssertEqual(summaries[0].occurrences.count, 2)
        XCTAssertEqual(summaries[0].occurrences[0].affectedBodyJoints, [.leftKnee, .rightKnee])
        XCTAssertEqual(summaries[0].occurrences[1].affectedBodyJoints, [.leftKnee])
    }

    func testIssueSummaryBuilderHandlesNilJoints() {
        let feedbackItems = [
            FormFeedback(
                category: .rangeOfMotion,
                message: "Need to go deeper - aim to get hip crease below knee level",
                severity: .warning,
                timestamp: 1.5,
                repNumber: 1
            )
        ]

        let summaries = IssueSummaryBuilder.from(feedbackItems)

        XCTAssertEqual(summaries.count, 1)
        XCTAssertEqual(summaries[0].occurrences.count, 1)
        XCTAssertEqual(summaries[0].occurrences[0].affectedBodyJoints, [])
    }

    func testRoundTripWithIssueKindAndMetrics() throws {
        let original = FormFeedback(
            category: .posture,
            message: "Torso leaning too far forward at bottom (bias: 11.3°)",
            severity: .warning,
            timestamp: 12.5,
            repNumber: 2,
            issueKind: .squatForwardLean,
            metrics: [
                FeedbackMetric(kind: .squatTorsoBiasDegrees, value: 11.3, unit: .degrees, phase: .bottom)
            ]
        )

        let encoded = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(FormFeedback.self, from: encoded)

        XCTAssertEqual(decoded.issueKind, .squatForwardLean)
        XCTAssertEqual(decoded.metrics?.count, 1)
        XCTAssertEqual(decoded.metrics?.first?.kind, .squatTorsoBiasDegrees)
        XCTAssertEqual(decoded.metrics?.first?.unit, .degrees)
        XCTAssertEqual(decoded.metrics?.first?.phase, .bottom)
        let value = try XCTUnwrap(decoded.metrics?.first?.value)
        XCTAssertEqual(value, 11.3, accuracy: 0.0001)
    }

    func testDecodeWithUnknownMetricKindDoesNotFail() throws {
        let json = """
        {
          "id": "2FD19126-BE9D-45A9-9019-65B3B8E2D5A5",
          "category": "posture",
          "message": "Torso leaning too far forward at bottom (bias: 11.3°)",
          "issueKind": "squat.forward_lean",
          "metrics": [
            {
              "kind": "squat.some_future_metric",
              "value": 12.34,
              "unit": "degrees",
              "phase": "bottom"
            }
          ],
          "severity": "warning",
          "timestamp": 12.5,
          "repNumber": 2
        }
        """

        let decoded = try JSONDecoder().decode(FormFeedback.self, from: Data(json.utf8))

        XCTAssertEqual(decoded.issueKind, .squatForwardLean)
        XCTAssertEqual(decoded.metrics?.count, 1)
        XCTAssertEqual(decoded.metrics?.first?.kind.rawValue, "squat.some_future_metric")
        XCTAssertEqual(decoded.metrics?.first?.unit, .degrees)
    }

    func testMovementIssueResolverPrefersExplicitIssueKind() {
        let feedback = FormFeedback(
            category: .posture,
            message: "Some unknown message",
            severity: .warning,
            timestamp: 1.0,
            repNumber: 1,
            issueKind: .squatHeelsLift
        )

        XCTAssertEqual(MovementIssueResolver.resolve(for: feedback), .squatHeelsLift)
    }

    func testMovementIssueResolverMatchesTorsoLeanPrefix() {
        let feedback = FormFeedback(
            category: .posture,
            message: "Torso leaning too far forward at bottom (bias: 7.1°)",
            severity: .warning,
            timestamp: 1.0,
            repNumber: 1
        )

        XCTAssertEqual(MovementIssueResolver.resolve(for: feedback), .squatForwardLean)
    }

    func testMovementIssueResolverMatchesExactKneeValgusMessage() {
        let feedback = FormFeedback(
            category: .safety,
            message: "Knees caving inward - push knees out to align with toes",
            severity: .critical,
            timestamp: 1.0,
            repNumber: 1
        )

        XCTAssertEqual(MovementIssueResolver.resolve(for: feedback), .squatKneeValgus)
    }

    func testIssueSummaryBuilderGroupsByResolvedKindAndUsesCatalogText() {
        let feedbackItems = [
            FormFeedback(
                category: .posture,
                message: "Torso leaning too far forward at bottom (bias: 11.3°)",
                severity: .warning,
                timestamp: 2.0,
                repNumber: 1,
                metrics: [FeedbackMetric(kind: .squatTorsoBiasDegrees, value: 11.3, unit: .degrees, phase: .bottom)]
            ),
            FormFeedback(
                category: .posture,
                message: "Torso leaning too far forward at bottom (bias: 7.1°)",
                severity: .critical,
                timestamp: 4.0,
                repNumber: 2,
                metrics: [FeedbackMetric(kind: .squatTorsoBiasDegrees, value: 7.1, unit: .degrees, phase: .bottom)]
            )
        ]

        let summaries = IssueSummaryBuilder.from(feedbackItems)

        XCTAssertEqual(summaries.count, 1)
        XCTAssertEqual(summaries[0].title, "Torso tipped forward")
        XCTAssertEqual(summaries[0].severity, .critical)
        XCTAssertFalse(summaries[0].cues.isEmpty)
        XCTAssertEqual(summaries[0].cues.first?.shortText, "Next rep: brace harder + keep chest from collapsing out of the hole.")
        XCTAssertEqual(summaries[0].worstOccurrence.metrics.count, 1)
        XCTAssertEqual(summaries[0].worstOccurrence.metrics.first?.kind, .squatTorsoBiasDegrees)
    }

    func testSquatCueLibraryHasEntriesForAllSquatKinds() {
        for kind in MovementIssueKind.squatCases {
            let entry = SquatCueLibrary.entry(for: kind)
            XCTAssertNotNil(entry, "Missing squat catalog entry for \(kind.rawValue)")
            XCTAssertFalse(entry?.name.isEmpty ?? true)
            XCTAssertFalse(entry?.headline.isEmpty ?? true)
            XCTAssertFalse(entry?.quickFix.isEmpty ?? true)
            XCTAssertFalse(entry?.oneLineDescription.isEmpty ?? true)
        }
    }

    func testMuayThaiCueLibraryHasEntriesForAllMuayThaiKinds() {
        for kind in MovementIssueKind.muayThaiCases where kind != .muayThaiAnalysisCoverageLimited {
            let entry = MuayThaiCueLibrary.entry(for: kind)
            XCTAssertNotNil(entry, "Missing Muay Thai catalog entry for \(kind.rawValue)")
            XCTAssertFalse(entry?.headline.isEmpty ?? true)
            XCTAssertFalse(entry?.quickFix.isEmpty ?? true)
            XCTAssertFalse(entry?.oneLineDescription.isEmpty ?? true)
        }
    }

    func testMovementCueCatalogResolvesAllDefinedKinds() {
        for kind in MovementIssueKind.allCases where kind != .muayThaiAnalysisCoverageLimited {
            let entry = MovementCueCatalog.entry(for: kind)
            XCTAssertNotNil(entry, "Missing movement cue catalog entry for \(kind.rawValue)")
            XCTAssertFalse(entry?.headline.isEmpty ?? true)
            XCTAssertFalse(entry?.quickFix.isEmpty ?? true)
        }
    }
}
