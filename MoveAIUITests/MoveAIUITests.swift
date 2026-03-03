//
//  MoveAIUITests.swift
//  MoveAIUITests
//
//  High-level smoke tests for the production navigation shell.
//  Prefer ScenarioRouter-based tests for deterministic layout verification.
//

import XCTest

final class MoveAIUITests: XCTestCase {

    private var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        XCUIDevice.shared.orientation = .portrait

        app = XCUIApplication()
        app.launchArguments = ["--uitesting"]
        app.launch()
        _ = app.wait(for: .runningForeground, timeout: 10)
    }

    override func tearDownWithError() throws {
        app?.terminate()
        app = nil
    }

    private func element(_ identifier: String) -> XCUIElement {
        app.descendants(matching: .any).matching(identifier: identifier).firstMatch
    }

    func testLaunchesIntoMainTabView() throws {
        XCTAssertTrue(
            element(AID.MainTabBar.root).waitForExistence(timeout: 5),
            "Main tab bar should exist"
        )

        XCTAssertTrue(
            element(AID.Home.root).waitForExistence(timeout: 5),
            "Home view should exist"
        )

        XCTAssertTrue(
            app.navigationBars["MoveAI"].exists,
            "Home navigation bar title should be visible"
        )
    }

    func testMainTabNavigation() throws {
        XCTAssertTrue(
            element(AID.MainTabBar.root).waitForExistence(timeout: 5),
            "Main tab bar should exist"
        )

        // SwiftUI often doesn\x27t surface custom tab buttons as stable XCUIElements.
        // Tap by normalized screen coordinates near the bottom bar.
        let homeTap = app.coordinate(withNormalizedOffset: CGVector(dx: 0.17, dy: 0.95))
        let profileTap = app.coordinate(withNormalizedOffset: CGVector(dx: 0.50, dy: 0.95))
        let trendsTap = app.coordinate(withNormalizedOffset: CGVector(dx: 0.83, dy: 0.95))

        trendsTap.tap()
        XCTAssertTrue(
            app.navigationBars["Trends"].waitForExistence(timeout: 5),
            "Should switch to Trends"
        )

        profileTap.tap()
        XCTAssertTrue(
            app.navigationBars["Profile"].waitForExistence(timeout: 5),
            "Should switch to Profile"
        )

        homeTap.tap()
        XCTAssertTrue(
            app.navigationBars["MoveAI"].waitForExistence(timeout: 5),
            "Should switch back to Home"
        )
    }
}
