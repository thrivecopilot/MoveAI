//
//  StructuralSnapshot.swift
//  MoveAIUITests
//
//  Lightweight JSON structural snapshot mechanism for XCUITest.
//  Captures the accessibility tree rooted at a given identifier and compares
//  it deterministically against a reference JSON file.
//
//  Usage:
//  ```swift
//  try StructuralTreeSnapshot.verify(
//      app: app,
//      rootIdentifier: AID.SessionHistory.root,
//      snapshotName: "SessionHistory_loaded__light__default",
//      file: #file, line: #line
//  )
//  ```
//
//  On first run (no reference file), the current tree is recorded and the test
//  fails with "Recorded new snapshot — re-run to verify." Delete the JSON to
//  re-record.
//

import XCTest

enum StructuralTreeSnapshot {

    // MARK: - Element Node Model

    /// A lightweight, Codable representation of one XCUIElement and its children.
    struct ElementNode: Codable, Equatable {
        let identifier: String
        let elementType: String
        let label: String
        let value: String?
        let isEnabled: Bool
        let children: [ElementNode]
    }

    // MARK: - Capture

    /// Walk the accessibility subtree rooted at `rootIdentifier` up to `maxDepth`.
    static func capture(
        app: XCUIApplication,
        rootIdentifier: String,
        maxDepth: Int = 4
    ) -> ElementNode? {
        // Use descendants(matching: .any) to find elements regardless of type —
        // SwiftUI can expose identifiers on various XCUIElement types.
        // Use .firstMatch to avoid "Multiple matching elements found" when
        // SwiftUI propagates identifiers to child elements.
        let root = app.descendants(matching: .any)[rootIdentifier].firstMatch
        guard root.waitForExistence(timeout: 5) else { return nil }
        return captureNode(root, depth: 0, maxDepth: maxDepth)
    }

    private static func captureNode(
        _ element: XCUIElement,
        depth: Int,
        maxDepth: Int
    ) -> ElementNode {
        let children: [ElementNode]
        if depth < maxDepth {
            let childElements = element.children(matching: .any)
                .allElementsBoundByAccessibilityElement
            children = childElements.map { captureNode($0, depth: depth + 1, maxDepth: maxDepth) }
        } else {
            children = []
        }
        return ElementNode(
            identifier: element.identifier,
            elementType: elementTypeName(element.elementType),
            label: element.label,
            value: element.value as? String,
            isEnabled: element.isEnabled,
            children: children
        )
    }

    // MARK: - Verify

    /// Compare the current accessibility tree against a stored reference JSON.
    ///
    /// - If no reference exists, records the current tree and fails (so you can review it).
    /// - If a reference exists, compares field-by-field and reports diffs on mismatch.
    static func verify(
        app: XCUIApplication,
        rootIdentifier: String,
        snapshotName: String,
        maxDepth: Int = 4,
        file: StaticString,
        line: UInt
    ) throws {
        guard let current = capture(app: app, rootIdentifier: rootIdentifier, maxDepth: maxDepth) else {
            XCTFail(
                "Could not find root element '\(rootIdentifier)' for snapshot '\(snapshotName)'",
                file: file,
                line: line
            )
            return
        }

        let snapshotsDir = snapshotsDirectory()
        let refPath = snapshotsDir.appendingPathComponent("\(snapshotName).json")

        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let currentData = try encoder.encode(current)

        if FileManager.default.fileExists(atPath: refPath.path) {
            // Compare against reference
            let refData = try Data(contentsOf: refPath)
            let reference = try JSONDecoder().decode(ElementNode.self, from: refData)

            if current != reference {
                // Write actual tree for debugging
                let actualPath = snapshotsDir.appendingPathComponent("\(snapshotName).actual.json")
                try currentData.write(to: actualPath)

                let diff = diffNodes(expected: reference, actual: current, path: rootIdentifier)
                XCTFail(
                    "Structural snapshot mismatch for '\(snapshotName)':\n\(diff)\n\nActual written to: \(actualPath.path)",
                    file: file,
                    line: line
                )
            }
        } else {
            // Record mode: write reference file
            try FileManager.default.createDirectory(at: snapshotsDir, withIntermediateDirectories: true)
            try currentData.write(to: refPath)
            XCTFail(
                "Recorded new snapshot '\(snapshotName)'. Review at: \(refPath.path)\nRe-run to verify against reference.",
                file: file,
                line: line
            )
        }
    }

    // MARK: - Diff

    private static func diffNodes(
        expected: ElementNode,
        actual: ElementNode,
        path: String
    ) -> String {
        var diffs: [String] = []

        if expected.identifier != actual.identifier {
            diffs.append("  \(path).identifier: '\(expected.identifier)' → '\(actual.identifier)'")
        }
        if expected.elementType != actual.elementType {
            diffs.append("  \(path).elementType: '\(expected.elementType)' → '\(actual.elementType)'")
        }
        if expected.label != actual.label {
            diffs.append("  \(path).label: '\(expected.label)' → '\(actual.label)'")
        }
        if expected.value != actual.value {
            diffs.append("  \(path).value: '\(expected.value ?? "nil")' → '\(actual.value ?? "nil")'")
        }
        if expected.isEnabled != actual.isEnabled {
            diffs.append("  \(path).isEnabled: \(expected.isEnabled) → \(actual.isEnabled)")
        }
        if expected.children.count != actual.children.count {
            diffs.append("  \(path).children.count: \(expected.children.count) → \(actual.children.count)")
        }

        let minCount = min(expected.children.count, actual.children.count)
        for i in 0..<minCount {
            let childId = actual.children[i].identifier.isEmpty
                ? "\(i)"
                : actual.children[i].identifier
            let childPath = "\(path)/\(childId)"
            let childDiff = diffNodes(
                expected: expected.children[i],
                actual: actual.children[i],
                path: childPath
            )
            if !childDiff.isEmpty {
                diffs.append(childDiff)
            }
        }

        return diffs.joined(separator: "\n")
    }

    // MARK: - Storage

    /// Snapshots are stored at a fixed path so they persist across test sessions.
    /// `NSTemporaryDirectory()` is per-app-sandbox, so we use `/tmp/` directly
    /// which is shared across all processes on the simulator host.
    /// To persist for CI, copy from `/tmp/MoveAI_Snapshots/` into the repo.
    private static func snapshotsDirectory() -> URL {
        URL(fileURLWithPath: "/tmp/MoveAI_Snapshots")
    }

    // MARK: - Utilities

    private static func elementTypeName(_ type: XCUIElement.ElementType) -> String {
        switch type {
        case .any:              return "any"
        case .other:            return "other"
        case .application:      return "application"
        case .group:            return "group"
        case .window:           return "window"
        case .sheet:            return "sheet"
        case .drawer:           return "drawer"
        case .alert:            return "alert"
        case .dialog:           return "dialog"
        case .button:           return "button"
        case .radioButton:      return "radioButton"
        case .radioGroup:       return "radioGroup"
        case .checkBox:         return "checkBox"
        case .disclosureTriangle: return "disclosureTriangle"
        case .popUpButton:      return "popUpButton"
        case .comboBox:         return "comboBox"
        case .menuButton:       return "menuButton"
        case .toolbarButton:    return "toolbarButton"
        case .popover:          return "popover"
        case .keyboard:         return "keyboard"
        case .key:              return "key"
        case .navigationBar:    return "navigationBar"
        case .tabBar:           return "tabBar"
        case .tabGroup:         return "tabGroup"
        case .toolbar:          return "toolbar"
        case .statusBar:        return "statusBar"
        case .table:            return "table"
        case .tableRow:         return "tableRow"
        case .tableColumn:      return "tableColumn"
        case .outline:          return "outline"
        case .outlineRow:       return "outlineRow"
        case .browser:          return "browser"
        case .collectionView:   return "collectionView"
        case .slider:           return "slider"
        case .pageIndicator:    return "pageIndicator"
        case .progressIndicator: return "progressIndicator"
        case .activityIndicator: return "activityIndicator"
        case .segmentedControl: return "segmentedControl"
        case .picker:           return "picker"
        case .pickerWheel:      return "pickerWheel"
        case .switch:           return "switch"
        case .toggle:           return "toggle"
        case .link:             return "link"
        case .image:            return "image"
        case .icon:             return "icon"
        case .searchField:      return "searchField"
        case .scrollView:       return "scrollView"
        case .scrollBar:        return "scrollBar"
        case .staticText:       return "staticText"
        case .textField:        return "textField"
        case .secureTextField:  return "secureTextField"
        case .datePicker:       return "datePicker"
        case .textView:         return "textView"
        case .menu:             return "menu"
        case .menuItem:         return "menuItem"
        case .menuBar:          return "menuBar"
        case .menuBarItem:      return "menuBarItem"
        case .map:              return "map"
        case .webView:          return "webView"
        case .incrementArrow:   return "incrementArrow"
        case .decrementArrow:   return "decrementArrow"
        case .timeline:         return "timeline"
        case .ratingIndicator:  return "ratingIndicator"
        case .valueIndicator:   return "valueIndicator"
        case .splitGroup:       return "splitGroup"
        case .splitter:         return "splitter"
        case .relevanceIndicator: return "relevanceIndicator"
        case .colorWell:        return "colorWell"
        case .helpTag:          return "helpTag"
        case .matte:            return "matte"
        case .dockItem:         return "dockItem"
        case .ruler:            return "ruler"
        case .rulerMarker:      return "rulerMarker"
        case .grid:             return "grid"
        case .levelIndicator:   return "levelIndicator"
        case .cell:             return "cell"
        case .layoutArea:       return "layoutArea"
        case .layoutItem:       return "layoutItem"
        case .handle:           return "handle"
        case .stepper:          return "stepper"
        case .tab:              return "tab"
        case .touchBar:         return "touchBar"
        case .statusItem:       return "statusItem"
        @unknown default:       return "unknown(\(type.rawValue))"
        }
    }
}
