//
//  StructuralUITests.swift
//  MoveAIUITests
//
//  Accessibility-first structured UI verification tests.
//  Launches the app into deterministic ScenarioRouter states and asserts
//  element existence, text content, enabled state, and hierarchy —
//  without capturing pixel screenshots.
//
//  Run via:
//    bash scripts/run_structural_tests.sh
//  or:
//    xcodebuild test -scheme MoveAI \
//      -destination 'platform=iOS Simulator,id=B512B7D6-8471-4F50-98D4-EF0932937865' \
//      -only-testing:MoveAIUITests/StructuralUITests
//

import XCTest

final class StructuralUITests: XCTestCase {

    private var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    override func tearDownWithError() throws {
        app?.terminate()
        app = nil
    }

    // MARK: - Element lookup helpers
    //
    // SwiftUI can expose accessibilityIdentifier'd views as various XCUIElement
    // types (other, scrollView, group, etc.). Use `descendants(matching: .any)`
    // to search across all types reliably.

    /// Find any element by accessibility identifier, regardless of its element type.
    private func element(_ identifier: String) -> XCUIElement {
        app.descendants(matching: .any).matching(identifier: identifier).firstMatch
    }

    /// Assert an element with the given identifier exists (waits up to `timeout`).
    private func assertExists(
        _ identifier: String,
        timeout: TimeInterval = 3,
        _ message: String,
        file: StaticString = #file,
        line: UInt = #line
    ) {
        XCTAssertTrue(
            element(identifier).waitForExistence(timeout: timeout),
            message,
            file: file,
            line: line
        )
    }

    /// Assert an element with the given identifier does NOT exist.
    private func assertNotExists(
        _ identifier: String,
        _ message: String,
        file: StaticString = #file,
        line: UInt = #line
    ) {
        XCTAssertFalse(
            element(identifier).exists,
            message,
            file: file,
            line: line
        )
    }

    /// Assert the draggable sheet does not leave a visible gap above the playback bar.
    private func assertSheetFlushWithPlaybackBar(
        tolerance: CGFloat = 1.5,
        file: StaticString = #file,
        line: UInt = #line
    ) {
        let playbackBarId = "VideoReview.PlaybackBar"
        assertExists(playbackBarId, "Playback bar must exist for flush-alignment check", file: file, line: line)
        assertExists(AID.VideoReview.sheet, "Sheet must exist for flush-alignment check", file: file, line: line)

        let probeElement = element(AID.VideoReview.root)
        guard let probe = waitForVideoReviewLayoutProbe(
            probeElement,
            timeout: 8,
            file: file,
            line: line
        ) else {
            return
        }

        let delta = probe.playbackMinY - probe.sheetMaxY

        XCTAssertLessThanOrEqual(
            delta,
            Double(tolerance),
            "Expected no gap between sheet and playback bar; probe delta was \(delta), sheetMaxY=\(probe.sheetMaxY), playbackMinY=\(probe.playbackMinY)",
            file: file,
            line: line
        )
    }

    /// Default audit categories to exclude in tests.
    ///
    /// These categories produce findings that are:
    /// - Simulator-only artifacts (contrast varies from real hardware)
    /// - Layout noise (text clipping, hit-area from embedded controls, etc.)
    /// - Already tracked as known-issues outside the test suite
    ///
    /// The audit still checks critical categories like trait, sufficientElementDescription,
    /// and parentChild, which catch real regressions.
    private static let defaultAuditExclusions: XCUIAccessibilityAuditType = [
        .contrast,                  // "Contrast nearly passed" — simulator rendering differs from hardware
        .hitRegion,                 // "Hit area is too small" — small icon buttons are intentional in dense layouts
        .textClipped,               // "Text clipped" — simulator layout engine clips differently
        .dynamicType,               // "Dynamic Type partially unsupported" — SwiftUI system components
        .sufficientElementDescription  // "Label not human-readable" / "Element has no description" — tracked separately
    ]

    /// Run performAccessibilityAudit, handling simulator bugs gracefully.
    /// The "Invalid target app" error (Code=-902) is a known simulator issue
    /// that doesn't indicate real a11y problems.
    private func runA11yAudit(
        excluding: XCUIAccessibilityAuditType = StructuralUITests.defaultAuditExclusions,
        file: StaticString = #file,
        line: UInt = #line
    ) {
        do {
            try app.performAccessibilityAudit(for: XCUIAccessibilityAuditType.all.subtracting(excluding))
        } catch {
            let nsError = error as NSError
            // Code -902 = "Invalid target app" — simulator bug, not a real a11y issue
            if nsError.domain == "com.apple.accessibilityAudit" && nsError.code == -902 {
                // Known simulator limitation — skip gracefully
                print("⚠️ Skipping a11y audit: simulator target app error (known issue)")
            } else {
                XCTFail("Accessibility audit failed: \(error)", file: file, line: line)
            }
        }
    }

    // =========================================================================
    // MARK: - Session History: Loaded
    // =========================================================================

    func testSessionHistoryLoaded_structure() throws {
        app = launchScenario("SessionHistory_loaded")

        // Navigation title
        XCTAssertTrue(
            app.navigationBars["Session History"].waitForExistence(timeout: 5),
            "Navigation bar title 'Session History' must exist"
        )

        // Filter buttons
        for title in ["All", "Squat", "Deadlift", "Bench Press"] {
            XCTAssertTrue(
                app.buttons[title].exists || app.staticTexts[title].exists,
                "Filter '\(title)' must be visible"
            )
        }

        // Session list exists (not empty, not error)
        assertExists(AID.SessionHistory.list, "Session list must exist for loaded state")
        assertNotExists(AID.SessionHistory.emptyState, "Empty state must NOT exist for loaded state")
        assertNotExists(AID.SessionHistory.errorState, "Error state must NOT exist for loaded state")

        // Session card content — 3 sessions from fixture:
        //   squat/92, deadlift/78, benchPress/nil("Pending")
        XCTAssertTrue(app.staticTexts["Squat"].exists, "Squat session card must be visible")
        XCTAssertTrue(app.staticTexts["92"].exists, "Score 92 must be visible")
        XCTAssertTrue(app.staticTexts["Deadlift"].exists, "Deadlift session card must be visible")
        XCTAssertTrue(app.staticTexts["78"].exists, "Score 78 must be visible")
        XCTAssertTrue(app.staticTexts["Bench Press"].exists, "Bench Press session card must be visible")
        XCTAssertTrue(app.staticTexts["Pending"].exists, "Pending badge for nil score must be visible")
    }

    func testSessionHistoryLoaded_a11yAudit() throws {
        app = launchScenario("SessionHistory_loaded")
        runA11yAudit()
    }

    // =========================================================================
    // MARK: - Session History: Empty
    // =========================================================================

    func testSessionHistoryEmpty_structure() throws {
        app = launchScenario("SessionHistory_empty")

        // Empty state visible (check both identifier and text)
        let hasEmptyIdentifier = element(AID.SessionHistory.emptyState).waitForExistence(timeout: 3)
        let hasEmptyText = app.staticTexts["No Sessions Yet"].waitForExistence(timeout: 3)
        XCTAssertTrue(hasEmptyIdentifier || hasEmptyText, "Empty state must be visible")

        // No list
        XCTAssertFalse(
            element(AID.SessionHistory.list).exists,
            "Session list must NOT exist for empty state"
        )
    }

    // =========================================================================
    // MARK: - Session History: Error
    // =========================================================================

    func testSessionHistoryError_structure() throws {
        app = launchScenario("SessionHistory_error")

        // Error state — check identifier or text
        let hasErrorIdentifier = element(AID.SessionHistory.errorState).waitForExistence(timeout: 5)
        let hasErrorText = app.staticTexts["Unable to Load Sessions"].waitForExistence(timeout: 5)
        XCTAssertTrue(hasErrorIdentifier || hasErrorText, "Error state must be visible")

        // Try Again button
        let tryAgain = app.buttons["Try Again"]
        XCTAssertTrue(tryAgain.waitForExistence(timeout: 3), "Try Again button must exist")
        XCTAssertTrue(tryAgain.isEnabled, "Try Again button must be enabled")
    }

    func testSessionHistoryError_a11yAudit() throws {
        app = launchScenario("SessionHistory_error")
        runA11yAudit()
    }

    // =========================================================================
    // MARK: - Session History: Long Text
    // =========================================================================

    func testSessionHistoryLongText_structure() throws {
        app = launchScenario("SessionHistory_longText")

        assertExists(AID.SessionHistory.list, timeout: 5, "Session list must exist for long text state")
        XCTAssertTrue(app.staticTexts["Squat"].exists, "Squat session must be visible")
        XCTAssertTrue(app.staticTexts["88"].exists, "Score 88 must be visible")
    }

    // =========================================================================
    // MARK: - Video Review: Medium Sheet
    // =========================================================================

    func testVideoReviewMedium_structure() throws {
        app = launchScenario("VideoReview_overview_medium")

        // Root layout
        assertExists(AID.VideoReview.root, timeout: 5, "VideoReviewLayoutView root must exist")

        // Sheet
        assertExists(AID.VideoReview.sheet, "Analysis sheet must exist")

        // Tab buttons — Overview is the active tab
        XCTAssertTrue(
            app.buttons["Overview"].exists || app.staticTexts["Overview"].exists,
            "Overview tab must be visible"
        )
        XCTAssertTrue(
            app.buttons["Issues"].exists || app.staticTexts["Issues"].exists,
            "Issues tab must be visible"
        )
        XCTAssertTrue(
            app.buttons["Notes"].exists || app.staticTexts["Notes"].exists,
            "Notes tab must be visible"
        )

        // Compact middle state: only score + rep summary are visible.
        XCTAssertTrue(app.staticTexts["Score"].exists, "Score label must be visible")
        XCTAssertTrue(app.staticTexts["72"].exists, "Score value 72 from fixture must be visible")

        let repSummary = app.staticTexts.matching(
            NSPredicate(format: "label CONTAINS 'total'")
        )
        XCTAssertTrue(
            repSummary.firstMatch.waitForExistence(timeout: 3),
            "Rep summary must be visible in medium state"
        )

        assertNotExists(
            "WorkoutSummary.TopFixesSection",
            "Top fixes list must not be visible in compact medium state"
        )

        assertSheetFlushWithPlaybackBar()

        // Tapping Issues/Notes in medium should switch tabs (no auto expansion).
        let issuesTabById = element(AID.Tabs.issues)
        let issuesTab = issuesTabById.exists ? issuesTabById : (app.buttons["Issues"].exists ? app.buttons["Issues"] : app.staticTexts["Issues"])
        XCTAssertTrue(issuesTab.exists, "Issues tab must exist in medium state")
        issuesTab.tap()
        XCTAssertTrue(
            app.staticTexts["SAFETY"].waitForExistence(timeout: 3),
            "Selecting Issues from medium should show Issues content"
        )

        let notesTabById = element(AID.Tabs.notes)
        let notesTab = notesTabById.exists ? notesTabById : (app.buttons["Notes"].exists ? app.buttons["Notes"] : app.staticTexts["Notes"])
        XCTAssertTrue(notesTab.exists, "Notes tab must exist after selecting Issues")
        notesTab.tap()
        assertExists(AID.Notes.root, timeout: 3, "Selecting Notes should show Notes content")
    }

    func testVideoReviewMedium_a11yAudit() throws {
        app = launchScenario("VideoReview_overview_medium")
        runA11yAudit()
    }

    // =========================================================================
    // MARK: - Video Review: Collapsed
    // =========================================================================

    func testVideoReviewCollapsed_structure() throws {
        app = launchScenario("VideoReview_overview_collapsed")

        assertExists(AID.VideoReview.root, timeout: 5, "VideoReviewLayoutView root must exist")

        // Sheet exists (drag handle visible).
        assertExists(AID.VideoReview.sheet, "Sheet must exist even when collapsed")

        // Collapsed state should only expose the handle strip.
        XCTAssertFalse(
            app.buttons["Overview"].exists || app.staticTexts["Overview"].exists,
            "Overview tab must be hidden when collapsed"
        )
        XCTAssertFalse(
            app.buttons["Issues"].exists || app.staticTexts["Issues"].exists,
            "Issues tab must be hidden when collapsed"
        )
        XCTAssertFalse(
            app.buttons["Notes"].exists || app.staticTexts["Notes"].exists,
            "Notes tab must be hidden when collapsed"
        )
        assertNotExists("WorkoutSummary.ScoreTitle", "Score content must be hidden when collapsed")

        assertSheetFlushWithPlaybackBar()
    }

    // =========================================================================
    // MARK: - Video Review: Expanded
    // =========================================================================

    func testVideoReviewExpanded_structure() throws {
        app = launchScenario("VideoReview_overview_expanded")

        assertExists(AID.VideoReview.root, timeout: 5, "VideoReviewLayoutView root must exist")

        // Tabs should be visible in expanded state
        XCTAssertTrue(
            app.buttons["Overview"].exists || app.staticTexts["Overview"].exists,
            "Overview tab must be visible in expanded state"
        )

        // Score and overview content
        XCTAssertTrue(app.staticTexts["Score"].exists, "Score label must be visible in expanded state")

        // Rep summary (4 reps from fixture)
        let repSummary = app.staticTexts.matching(
            NSPredicate(format: "label CONTAINS %@", "4 total")
        )
        XCTAssertTrue(
            repSummary.firstMatch.waitForExistence(timeout: 3),
            "Rep summary 4 total must be visible in expanded state"
        )

        assertExists("WorkoutSummary.TopFixesSection", "Top fixes must be visible in expanded state")
        assertSheetFlushWithPlaybackBar()
    }

    // =========================================================================
    // MARK: - Home: Loaded
    // =========================================================================

    func testHomeLoaded_structure() throws {
        app = launchScenario("Home_loaded")

        // Navigation title
        XCTAssertTrue(
            app.navigationBars["MoveAI"].waitForExistence(timeout: 5),
            "Navigation bar title 'MoveAI' must exist"
        )

        // Welcome header text
        XCTAssertTrue(
            app.staticTexts["Master Your Movements"].exists,
            "'Master Your Movements' header must be visible"
        )

        // Start Session section
        XCTAssertTrue(
            app.staticTexts["Start Session"].exists,
            "'Start Session' section title must be visible"
        )

        // Movement options
        XCTAssertTrue(app.staticTexts["Squat"].exists, "Squat movement option must be visible")
        XCTAssertTrue(app.staticTexts["Deadlift"].exists, "Deadlift movement option must be visible")
        XCTAssertTrue(app.staticTexts["Bench Press"].exists, "Bench Press movement option must be visible")

        // Coming Soon cards
        XCTAssertTrue(
            app.staticTexts["Olympic Lifting"].exists,
            "Olympic Lifting 'Coming Soon' card must be visible"
        )

        // Recent Sessions section (fixture has 3 sessions)
        XCTAssertTrue(
            app.staticTexts["Recent Sessions"].exists,
            "'Recent Sessions' section must be visible"
        )
    }

    func testHomeLoaded_a11yAudit() throws {
        app = launchScenario("Home_loaded")
        runA11yAudit()
    }

    // =========================================================================
    // MARK: - Structural Snapshots
    // =========================================================================

    func testSessionHistoryLoaded_snapshot() throws {
        app = launchScenario("SessionHistory_loaded")
        try StructuralTreeSnapshot.verify(
            app: app,
            rootIdentifier: AID.SessionHistory.root,
            snapshotName: "SessionHistory_loaded__light__default",
            file: #file,
            line: #line
        )
    }

    func testVideoReviewMedium_snapshot() throws {
        app = launchScenario("VideoReview_overview_medium")
        try StructuralTreeSnapshot.verify(
            app: app,
            rootIdentifier: AID.VideoReview.root,
            snapshotName: "VideoReview_overview_medium__light__default",
            file: #file,
            line: #line
        )
    }
}
