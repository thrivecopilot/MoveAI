import XCTest
@testable import MoveAI

final class PoseOverlayHighlightingTests: XCTestCase {
    func testActiveHighlightedJoints_includesWithinTolerance() {
        let feedback: [FormFeedback] = [
            FormFeedback(category: .safety, message: "warn", severity: .warning, timestamp: 10.0, affectedBodyJoints: [.leftKnee]),
            FormFeedback(category: .safety, message: "crit", severity: .critical, timestamp: 10.2, affectedBodyJoints: [.rightHip])
        ]

        let result = PoseOverlayHighlighting.activeHighlightedJoints(feedback: feedback, at: 10.0, tolerance: 0.2)

        XCTAssertEqual(result[.leftKnee], .warning)
        XCTAssertEqual(result[.rightHip], .critical)
    }

    func testActiveHighlightedJoints_excludesOutsideTolerance() {
        let feedback: [FormFeedback] = [
            FormFeedback(category: .safety, message: "warn", severity: .warning, timestamp: 10.2001, affectedBodyJoints: [.leftKnee]),
            FormFeedback(category: .safety, message: "crit", severity: .critical, timestamp: 9.7999, affectedBodyJoints: [.rightHip])
        ]

        let result = PoseOverlayHighlighting.activeHighlightedJoints(feedback: feedback, at: 10.0, tolerance: 0.2)

        XCTAssertTrue(result.isEmpty)
    }

    func testActiveHighlightedJoints_ignoresNonWarningAndCritical() {
        let feedback: [FormFeedback] = [
            FormFeedback(category: .posture, message: "good", severity: .good, timestamp: 10.0, affectedBodyJoints: [.leftKnee]),
            FormFeedback(category: .posture, message: "excellent", severity: .excellent, timestamp: 10.0, affectedBodyJoints: [.rightHip])
        ]

        let result = PoseOverlayHighlighting.activeHighlightedJoints(feedback: feedback, at: 10.0)

        XCTAssertTrue(result.isEmpty)
    }

    func testActiveHighlightedJoints_ignoresNilAffectedJoints() {
        let feedback: [FormFeedback] = [
            FormFeedback(category: .safety, message: "warn", severity: .warning, timestamp: 10.0, affectedBodyJoints: nil)
        ]

        let result = PoseOverlayHighlighting.activeHighlightedJoints(feedback: feedback, at: 10.0)

        XCTAssertTrue(result.isEmpty)
    }

    func testActiveHighlightedJoints_precedenceCriticalOverWarningForSameJoint() {
        let feedback: [FormFeedback] = [
            FormFeedback(category: .safety, message: "warn", severity: .warning, timestamp: 10.0, affectedBodyJoints: [.leftKnee]),
            FormFeedback(category: .safety, message: "crit", severity: .critical, timestamp: 10.0, affectedBodyJoints: [.leftKnee]),
            // Ensure we never downgrade critical to warning if order flips.
            FormFeedback(category: .safety, message: "warn2", severity: .warning, timestamp: 10.0, affectedBodyJoints: [.leftKnee])
        ]

        let result = PoseOverlayHighlighting.activeHighlightedJoints(feedback: feedback, at: 10.0)

        XCTAssertEqual(result[.leftKnee], .critical)
    }

    func testActiveHighlightedJoints_includesExactlyAtToleranceBoundary() {
        let feedback: [FormFeedback] = [
            FormFeedback(category: .safety, message: "warn", severity: .warning, timestamp: 9.8, affectedBodyJoints: [.leftKnee]),
            FormFeedback(category: .safety, message: "crit", severity: .critical, timestamp: 10.2, affectedBodyJoints: [.rightHip])
        ]

        let result = PoseOverlayHighlighting.activeHighlightedJoints(feedback: feedback, at: 10.0, tolerance: 0.2)

        XCTAssertEqual(result[.leftKnee], .warning)
        XCTAssertEqual(result[.rightHip], .critical)
    }
}
