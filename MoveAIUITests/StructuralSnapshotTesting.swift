import XCTest

struct StructuralSnapshot: Codable, Equatable {
    let schemaVersion: Int
    let scenario: String
    let elements: [StructuralSnapshotElement]
}

struct StructuralSnapshotElement: Codable, Equatable {
    let id: String
    let exists: Bool
    let label: String
    let value: String?
    let isEnabled: Bool?
}

enum StructuralSnapshotTesting {
    private static let controlElementTypes: Set<XCUIElement.ElementType> = [
        .button,
        .switch,
        .slider,
        .textField,
        .secureTextField,
        .picker,
        .segmentedControl,
        .stepper,
        .tabBar,
        .tab
    ]

    static func assertSnapshot(
        app: XCUIApplication,
        scenario: StructuredUIScenario,
        identifiers: [String],
        testCase: XCTestCase,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        let snapshot = captureSnapshot(app: app, scenario: scenario, identifiers: identifiers)
        attach(snapshot: snapshot, name: "structural_snapshot__\(scenario.rawValue)", to: testCase)

        let baselineURL = baselineFileURL(for: scenario)
        guard let baselineData = try? Data(contentsOf: baselineURL) else {
            XCTFail("Missing structural snapshot baseline at \(baselineURL.path)", file: file, line: line)
            testCase.attachFallbackScreenshot(named: "missing_baseline__\(scenario.rawValue)")
            return
        }

        do {
            let decoder = JSONDecoder()
            let baseline = try decoder.decode(StructuralSnapshot.self, from: baselineData)

            if baseline != snapshot {
                attach(data: baselineData, name: "structural_baseline__\(scenario.rawValue)", to: testCase)
                if let actualData = encodedData(for: snapshot) {
                    attach(data: actualData, name: "structural_actual__\(scenario.rawValue)", to: testCase)
                }
                testCase.attachFallbackScreenshot(named: "snapshot_diff__\(scenario.rawValue)")
                XCTFail("Structural snapshot mismatch for \(scenario.rawValue)", file: file, line: line)
            }
        } catch {
            XCTFail("Failed to decode baseline snapshot: \(error.localizedDescription)", file: file, line: line)
        }
    }

    private static func captureSnapshot(
        app: XCUIApplication,
        scenario: StructuredUIScenario,
        identifiers: [String]
    ) -> StructuralSnapshot {
        let elements = identifiers
            .sorted()
            .map { id in
                let query = app.descendants(matching: .any).matching(identifier: id)
                let element = query.firstMatch
                let exists = element.exists
                let label = exists ? element.label : ""
                let value = exists ? normalizedValue(element.value) : nil

                let enabled: Bool?
                if exists && controlElementTypes.contains(element.elementType) {
                    enabled = element.isEnabled
                } else {
                    enabled = nil
                }

                return StructuralSnapshotElement(
                    id: id,
                    exists: exists,
                    label: label,
                    value: value,
                    isEnabled: enabled
                )
            }

        return StructuralSnapshot(
            schemaVersion: 1,
            scenario: scenario.rawValue,
            elements: elements
        )
    }

    private static func normalizedValue(_ rawValue: Any?) -> String? {
        guard let rawValue else { return nil }
        let valueString = String(describing: rawValue)
        if valueString.isEmpty || valueString == "<null>" || valueString == "nil" {
            return nil
        }
        return valueString
    }

    private static func baselineFileURL(for scenario: StructuredUIScenario) -> URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .appendingPathComponent("StructuralSnapshots/Baselines", isDirectory: true)
            .appendingPathComponent("\(scenario.rawValue).json", isDirectory: false)
    }

    private static func attach(snapshot: StructuralSnapshot, name: String, to testCase: XCTestCase) {
        guard let data = encodedData(for: snapshot) else { return }
        attach(data: data, name: name, to: testCase)
    }

    private static func attach(data: Data, name: String, to testCase: XCTestCase) {
        let attachment = XCTAttachment(data: data, uniformTypeIdentifier: "public.json")
        attachment.name = name
        attachment.lifetime = .keepAlways
        testCase.add(attachment)
    }

    private static func encodedData(for snapshot: StructuralSnapshot) -> Data? {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return try? encoder.encode(snapshot)
    }
}
