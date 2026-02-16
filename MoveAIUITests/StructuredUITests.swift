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

        let probeElement = element(app, id: "VideoReview.LayoutProbe")
        guard let probe = waitForVideoReviewLayoutProbe(probeElement) else {
            return
        }

        XCTAssertEqual(probe.schemaVersion, 1, "Unexpected layout probe schema version")
        XCTAssertTrue(probe.ready, "Layout probe should report ready=true")

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

        assertApproximatelyEqual(
            probe.videoMinX,
            0,
            tolerance: 2.0,
            message: "Probe videoMinX should be flush with the container left edge"
        )
        assertApproximatelyEqual(
            probe.videoMaxX,
            probe.containerWidth,
            tolerance: 2.0,
            message: "Probe videoMaxX should be flush with the container right edge"
        )

        XCTAssertLessThanOrEqual(
            probe.videoMinY,
            probe.safeTop + 2.0,
            "Video should start at or above the safe-area top boundary"
        )
        XCTAssertGreaterThanOrEqual(
            probe.videoMaxY,
            probe.containerHeight - probe.safeBottom - 2.0,
            "Video should extend to the safe-area bottom boundary"
        )

        StructuralSnapshotTesting.assertSnapshot(
            app: app,
            scenario: scenario,
            identifiers: [
                "VideoReviewLayoutView",
                "VideoReviewSheet",
                "VideoReview.TopBar",
                "VideoReview.VideoSurface",
                "VideoReview.PlaybackBar"
            ],
            testCase: self
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
