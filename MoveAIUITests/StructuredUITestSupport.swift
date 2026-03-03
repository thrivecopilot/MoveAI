import XCTest

enum StructuredUIScenario: String {
    case workoutSummaryDefault = "WorkoutSummary_default"
    case poseOverlayDetected = "PoseOverlay_detected"
    case poseOverlayNoPose = "PoseOverlay_noPose"
    case dataInputPrefilled = "DataInput_prefilled"
    case videoReviewOverviewMedium = "VideoReview_overview_medium"
}

enum StructuredUITestAppearance: String {
    case light
    case dark
}

enum StructuredUITestTextSize: String {
    case `default` = "default"
    case large = "large"
}

struct VideoReviewLayoutProbe: Decodable {
    let schemaVersion: Int
    let ready: Bool
    let containerWidth: Double
    let containerHeight: Double
    let safeTop: Double
    let safeBottom: Double
    let videoMinX: Double
    let videoMaxX: Double
    let videoMinY: Double
    let videoMaxY: Double
    let sheetMaxY: Double
    let playbackMinY: Double
}

extension XCTestCase {
    func launchScenario(
        _ scenario: StructuredUIScenario,
        appearance: StructuredUITestAppearance = .light,
        textSize: StructuredUITestTextSize = .default
    ) -> XCUIApplication {
        launchScenario(
            scenario.rawValue,
            appearance: appearance,
            textSize: textSize
        )
    }

    func launchScenario(
        _ scenarioName: String,
        appearance: StructuredUITestAppearance = .light,
        textSize: StructuredUITestTextSize = .default
    ) -> XCUIApplication {
        XCUIDevice.shared.orientation = .portrait

        let app = XCUIApplication()
        app.launchArguments = [
            "--uitesting",
            "-uiScenario", scenarioName,
            "-uiAppearance", appearance.rawValue,
            "-uiTextSize", textSize.rawValue,
            "-uiDisableAnimations"
        ]
        app.launch()
        XCTAssertTrue(app.wait(for: .runningForeground, timeout: 10), "App did not reach foreground in time")
        return app
    }

    func element(_ app: XCUIApplication, id: String) -> XCUIElement {
        app.descendants(matching: .any).matching(identifier: id).firstMatch
    }

    @discardableResult
    func expectExists(
        _ element: XCUIElement,
        timeout: TimeInterval = 8,
        message: String,
        file: StaticString = #filePath,
        line: UInt = #line
    ) -> Bool {
        let predicate = NSPredicate(format: "exists == true")
        let expectation = XCTNSPredicateExpectation(predicate: predicate, object: element)
        let result = XCTWaiter.wait(for: [expectation], timeout: timeout)
        let didExist = (result == .completed)
        XCTAssertTrue(didExist, message, file: file, line: line)
        if !didExist {
            attachFallbackScreenshot(named: "failure__\(sanitized(message))")
        }
        return didExist
    }

    func expectLabel(
        _ element: XCUIElement,
        equals expected: String,
        timeout: TimeInterval = 5,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        let predicate = NSPredicate(format: "label == %@", expected)
        let expectation = XCTNSPredicateExpectation(predicate: predicate, object: element)
        let result = XCTWaiter.wait(for: [expectation], timeout: timeout)
        XCTAssertEqual(result, .completed, "Expected label '\(expected)', got '\(element.label)'", file: file, line: line)
    }

    func expectEnabled(
        _ element: XCUIElement,
        equals expected: Bool,
        timeout: TimeInterval = 5,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        let predicate = NSPredicate(format: "isEnabled == %@", NSNumber(value: expected))
        let expectation = XCTNSPredicateExpectation(predicate: predicate, object: element)
        let result = XCTWaiter.wait(for: [expectation], timeout: timeout)
        XCTAssertEqual(result, .completed, "Expected isEnabled=\(expected)", file: file, line: line)
    }

    @discardableResult
    func waitForVideoReviewLayoutProbe(
        _ element: XCUIElement,
        timeout: TimeInterval = 8,
        file: StaticString = #filePath,
        line: UInt = #line
    ) -> VideoReviewLayoutProbe? {
        guard expectExists(
            element,
            timeout: timeout,
            message: "Video review layout probe should exist",
            file: file,
            line: line
        ) else {
            return nil
        }

        let readyPredicate = NSPredicate(format: "value CONTAINS %@", "\"ready\":true")
        let readyExpectation = XCTNSPredicateExpectation(predicate: readyPredicate, object: element)
        let readyResult = XCTWaiter.wait(for: [readyExpectation], timeout: timeout)
        XCTAssertEqual(
            readyResult,
            .completed,
            "Video review layout probe did not become ready. Current value: \(String(describing: element.value))",
            file: file,
            line: line
        )

        guard readyResult == .completed else {
            attachFallbackScreenshot(named: "failure__video_review_layout_probe_not_ready")
            return nil
        }

        let rawValue = String(describing: element.value ?? "")
        guard let data = rawValue.data(using: .utf8) else {
            XCTFail("Video review layout probe value is not valid UTF-8: \(rawValue)", file: file, line: line)
            return nil
        }

        do {
            let decoder = JSONDecoder()
            return try decoder.decode(VideoReviewLayoutProbe.self, from: data)
        } catch {
            XCTFail(
                "Failed to decode video review layout probe: \(error.localizedDescription). Raw: \(rawValue)",
                file: file,
                line: line
            )
            return nil
        }
    }

    func assertApproximatelyEqual(
        _ actual: Double,
        _ expected: Double,
        tolerance: Double = 2.0,
        message: String,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        let difference = abs(actual - expected)
        XCTAssertLessThanOrEqual(
            difference,
            tolerance,
            "\(message) (expected \(expected) ±\(tolerance), got \(actual))",
            file: file,
            line: line
        )
    }

    func runAccessibilityAuditIfAvailable(
        app: XCUIApplication,
        auditTypes: XCUIAccessibilityAuditType = .all,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        guard #available(iOS 17.0, *) else { return }
        XCTAssertNoThrow(
            try app.performAccessibilityAudit(for: auditTypes),
            "Accessibility audit reported issues",
            file: file,
            line: line
        )
    }

    func attachFallbackScreenshot(named name: String) {
        let attachment = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    private func sanitized(_ input: String) -> String {
        let allowed = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "-_"))
        let scalarView = input.unicodeScalars.map { allowed.contains($0) ? Character($0) : "_" }
        return String(scalarView)
    }
}
