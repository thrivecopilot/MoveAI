//
//  ScreenshotTests.swift
//  MoveAIUITests
//
//  UI screenshot matrix for deterministic scenario capture.
//

import XCTest

final class ScreenshotTests: XCTestCase {
    private enum Appearance: String {
        case light
        case dark
    }

    private enum TextSize: String {
        case `default` = "default"
        case large = "large"
    }

    private struct Scenario {
        let name: String
    }

    private let sessionHistoryScenarios: [Scenario] = [
        Scenario(name: "SessionHistory_loaded"),
        Scenario(name: "SessionHistory_empty"),
        Scenario(name: "SessionHistory_error"),
        Scenario(name: "SessionHistory_longText")
    ]

    private let videoReviewScenarios: [Scenario] = [
        Scenario(name: "VideoReview_overview_collapsed"),
        Scenario(name: "VideoReview_overview_medium"),
        Scenario(name: "VideoReview_overview_expanded")
    ]

    override func setUpWithError() throws {
        continueAfterFailure = true
    }

    func testSessionHistoryScreenshots() throws {
        for scenario in sessionHistoryScenarios {
            captureMatrix(for: scenario)
        }
    }

    func testVideoReviewScreenshots() throws {
        for scenario in videoReviewScenarios {
            captureMatrix(for: scenario)
        }
    }

    private func captureMatrix(for scenario: Scenario) {
        // Default text size: light + dark
        captureScenario(scenario, appearance: .light, textSize: .default)
        captureScenario(scenario, appearance: .dark, textSize: .default)

        // Larger text size: light only to keep the matrix manageable
        captureScenario(scenario, appearance: .light, textSize: .large)
    }

    private func captureScenario(_ scenario: Scenario, appearance: Appearance, textSize: TextSize) {
        let app = launch(scenario: scenario.name, appearance: appearance, textSize: textSize)
        waitForScreen(app, id: "ScenarioRoot_\(scenario.name)")
        takeShot(app, name: shotName(scenario: scenario.name, appearance: appearance, textSize: textSize))
        app.terminate()
    }

    private func launch(scenario: String, appearance: Appearance, textSize: TextSize) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = [
            "--uitesting",
            "-uiScenario", scenario,
            "-uiAppearance", appearance.rawValue,
            "-uiTextSize", textSize.rawValue,
            "-uiDisableAnimations"
        ]
        app.launch()
        _ = app.wait(for: .runningForeground, timeout: 10)
        return app
    }

    private func waitForScreen(_ app: XCUIApplication, id: String) {
        let element = app.otherElements[id]
        XCTAssertTrue(element.waitForExistence(timeout: 8), "Expected screen element not found: \(id)")
    }

    private func takeShot(_ app: XCUIApplication, name: String) {
        let attachment = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        attachment.name = "screenshot__\(name)"
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    private func shotName(scenario: String, appearance: Appearance, textSize: TextSize) -> String {
        return [scenario, appearance.rawValue, textSize.rawValue].joined(separator: "__")
    }
}
