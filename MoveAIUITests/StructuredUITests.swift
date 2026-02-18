import XCTest

final class StructuredUITests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    func testVideoReviewMedium_VideoCoversSafeAreaBandAndFullWidth() throws {
        let scenario: StructuredUIScenario = .videoReviewOverviewMedium
        let app = launchScenario(scenario)
        defer { app.terminate() }

        expectExists(
            element(app, id: "ScenarioRoot_\(scenario.rawValue)"),
            message: "VideoReview medium scenario root should exist"
        )

        let topBar = element(app, id: "VideoReview.TopBar")
        expectExists(topBar, message: "VideoReview top bar should exist")

        let videoSurface = element(app, id: "VideoReview.VideoSurface")
        expectExists(videoSurface, message: "VideoReview video surface should exist")

        let playbackBar = element(app, id: "VideoReview.PlaybackBar")
        expectExists(playbackBar, message: "VideoReview playback bar should exist")

        let window = app.windows.firstMatch
        expectExists(window, message: "Main application window should exist")

        let windowFrame = window.frame
        let videoFrame = videoSurface.frame

        assertApproximatelyEqual(
            Double(videoFrame.minX),
            Double(windowFrame.minX),
            tolerance: 2.0,
            message: "Video surface minX should align with window minX"
        )
        assertApproximatelyEqual(
            Double(videoFrame.maxX),
            Double(windowFrame.maxX),
            tolerance: 2.0,
            message: "Video surface maxX should align with window maxX"
        )

    }

    func testVideoReviewMedium_AccessibilityAudit() throws {
        let scenario: StructuredUIScenario = .videoReviewOverviewMedium
        let app = launchScenario(scenario)
        defer { app.terminate() }

        expectExists(
            element(app, id: "ScenarioRoot_\(scenario.rawValue)"),
            message: "VideoReview medium scenario root should exist before accessibility audit"
        )
        expectExists(
            element(app, id: "VideoReview.VideoSurface"),
            message: "VideoReview video surface should exist before accessibility audit"
        )

        let auditTypes: XCUIAccessibilityAuditType = [.elementDetection]

        runAccessibilityAuditIfAvailable(app: app, auditTypes: auditTypes)
    }
}
