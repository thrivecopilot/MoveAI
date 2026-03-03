//
//  XCUITestHelpers.swift
//  MoveAIUITests
//
//  Shared helpers for launching the app into deterministic ScenarioRouter states.
//  Mirrors the launch pattern from ScreenshotTests.swift (lines 70-87).
//

import XCTest

/// Launches the app into a deterministic scenario via ScenarioRouter launch arguments.
///
/// Usage:
/// ```swift
/// let app = launchScenario("SessionHistory_loaded")
/// // ... assertions ...
/// app.terminate()
/// ```
///
/// - Parameters:
///   - name: The `UIScenario.rawValue` (e.g. `"SessionHistory_loaded"`, `"VideoReview_overview_medium"`).
///   - appearance: `"light"` or `"dark"`. Defaults to `"light"`.
///   - textSize: `"default"` or `"large"`. Defaults to `"default"`.
///   - timeout: How long to wait for the scenario root element. Defaults to 10 seconds.
///   - file: Caller file for assertion failure reporting.
///   - line: Caller line for assertion failure reporting.
/// - Returns: The launched `XCUIApplication` instance.
@discardableResult
func launchScenario(
    _ name: String,
    appearance: String = "light",
    textSize: String = "default",
    timeout: TimeInterval = 10,
    file: StaticString = #file,
    line: UInt = #line
) -> XCUIApplication {
    XCUIDevice.shared.orientation = .portrait

    let app = XCUIApplication()
    app.launchArguments = [
        "--uitesting",
        "-uiScenario", name,
        "-uiAppearance", appearance,
        "-uiTextSize", textSize,
        "-uiDisableAnimations"
    ]
    app.launch()
    _ = app.wait(for: .runningForeground, timeout: timeout)

    // Use descendants(matching: .any) because SwiftUI may expose the
    // ScenarioRoot identifier on various element types (group, other, etc.)
    let scenarioRoot = app.descendants(matching: .any)[AID.scenarioRoot(name)]
    XCTAssertTrue(
        scenarioRoot.waitForExistence(timeout: 8),
        "ScenarioRoot_\(name) not found within timeout",
        file: file,
        line: line
    )
    return app
}

// MARK: - Convenience Extensions

extension XCUIApplication {
    /// Waits for an element with the given accessibility identifier to exist.
    func waitForElement(
        _ identifier: String,
        timeout: TimeInterval = 5,
        file: StaticString = #file,
        line: UInt = #line
    ) -> XCUIElement {
        // Try common element types in priority order
        let queries: [XCUIElementQuery] = [
            otherElements,
            buttons,
            staticTexts,
            scrollViews,
            textFields,
            images
        ]
        for query in queries {
            let element = query[identifier]
            if element.waitForExistence(timeout: 0.5) {
                return element
            }
        }
        // Fallback: use otherElements and assert
        let element = otherElements[identifier]
        XCTAssertTrue(
            element.waitForExistence(timeout: timeout),
            "Element '\(identifier)' not found within \(timeout)s",
            file: file,
            line: line
        )
        return element
    }
}
