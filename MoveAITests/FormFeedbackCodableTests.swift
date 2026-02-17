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
        XCTAssertNil(decoded.affectedBodyJoints)
    }

    func testRoundTripWithJoints() throws {
        let original = FormFeedback(
            category: .safety,
            message: "Knees caving inward - push knees out to align with toes",
            severity: .critical,
            timestamp: 3.2,
            repNumber: 1,
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
}
