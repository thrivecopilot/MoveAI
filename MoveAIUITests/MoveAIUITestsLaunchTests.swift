//
//  MoveAIUITestsLaunchTests.swift
//  MoveAIUITests
//
//  Created by Dave Mathew on 10/11/25.
//

import XCTest

final class MoveAIUITestsLaunchTests: XCTestCase {

    override class var runsForEachTargetApplicationUIConfiguration: Bool {
        // Running for each configuration (appearance/orientation/etc.) can be flaky on CI
        // and isn't needed for our deterministic UI regression tests.
        false
    }

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    @MainActor
    func testLaunch() throws {
        XCUIDevice.shared.orientation = .portrait

        let app = XCUIApplication()
        // Ensure a deterministic launch path (bypass onboarding/permissions).
        app.launchArguments = [
            "--uitesting",
            "-uiDisableAnimations"
        ]
        app.launch()

        // Insert steps here to perform after app launch but before taking a screenshot,
        // such as logging into a test account or navigating somewhere in the app

        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = "Launch Screen"
        // Keep screenshots only on failure to reduce memory pressure during UI test runs.
        attachment.lifetime = .deleteOnSuccess
        add(attachment)
    }
}
