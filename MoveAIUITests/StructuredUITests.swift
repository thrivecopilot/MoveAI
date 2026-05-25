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

    func testRunningVideoReviewCollapsed_CueOverlayIsSummaryOnly() throws {
        let scenario: StructuredUIScenario = .videoReviewRunningCollapsed
        let app = launchScenario(scenario)
        defer { app.terminate() }

        expectExists(
            element(app, id: "ScenarioRoot_\(scenario.rawValue)"),
            message: "Running collapsed scenario root should exist"
        )
        expectExists(
            element(app, id: AID.CueOverlay.root),
            message: "Running collapsed scenario should show cue overlay"
        )
        expectExists(
            element(app, id: AID.CueOverlay.title),
            message: "Cue overlay title should be visible"
        )
        expectExists(
            element(app, id: AID.CueOverlay.quickFix),
            message: "Cue overlay quick-fix text should be visible"
        )

        XCTAssertFalse(
            app.staticTexts.matching(NSPredicate(format: "label CONTAINS[c] %@", "rationale")).firstMatch.exists,
            "Collapsed cue overlay should stay summary-only and not render rationale copy"
        )
    }

    func testRunningVideoReviewIssuesCard_ShowsMetricMiniCard() throws {
        let scenario: StructuredUIScenario = .videoReviewRunningMedium
        let app = launchScenario(scenario)
        defer { app.terminate() }

        expectExists(
            element(app, id: "ScenarioRoot_\(scenario.rawValue)"),
            message: "Running medium scenario root should exist"
        )

        let issuesTab = element(app, id: AID.Tabs.issues)
        expectExists(issuesTab, message: "Issues tab should exist in running medium scenario")
        issuesTab.tap()

        expectExists(
            element(app, id: AID.Issues.root),
            message: "Issues tab root should exist after selecting Issues"
        )
        expectExists(
            element(app, id: "IssueMetricCard"),
            message: "Running issues should render metric mini-card"
        )
    }
}
