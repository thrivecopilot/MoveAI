import XCTest
@testable import MoveAI

final class SheetDetentTests: XCTestCase {
    func testCollapsedHeightUsesAbsoluteHandleMinimum() {
        let height = SheetDetentLayoutCalculator.sheetHeight(
            for: .collapsed,
            availableHeight: 800,
            minCollapsedHeight: 36
        )

        XCTAssertEqual(height, 36, accuracy: 1)
    }

    func testMediumHeightUsesFractionWhenAboveMinimum() {
        let height = SheetDetentLayoutCalculator.sheetHeight(
            for: .medium,
            availableHeight: 800,
            minCollapsedHeight: 36
        )

        XCTAssertEqual(height, 304, accuracy: 1)
    }

    func testMediumHeightFloorsAtMinimumHeight() {
        let height = SheetDetentLayoutCalculator.sheetHeight(
            for: .medium,
            availableHeight: 600,
            minCollapsedHeight: 36
        )

        XCTAssertEqual(height, 300, accuracy: 1)
    }

    func testExpandedHeightUsesDetentFraction() {
        let height = SheetDetentLayoutCalculator.sheetHeight(
            for: .expanded,
            availableHeight: 800,
            minCollapsedHeight: 36
        )

        XCTAssertEqual(height, 704, accuracy: 1)
    }
}
