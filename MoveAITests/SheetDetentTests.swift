import XCTest
@testable import MoveAI

final class SheetDetentTests: XCTestCase {
    func testCollapsedHeightUsesHandleOnlyMinimum() {
        let height = SheetDetentLayoutCalculator.sheetHeight(
            for: .collapsed,
            availableHeight: 800,
            minCollapsedHeight: 0
        )

        XCTAssertEqual(height, DragHandleMetrics.minCollapsedHeight, accuracy: 1)
    }

    func testMediumHeightCapsAtCompactMaximum() {
        let height = SheetDetentLayoutCalculator.sheetHeight(
            for: .medium,
            availableHeight: 800,
            minCollapsedHeight: DragHandleMetrics.minCollapsedHeight
        )

        XCTAssertEqual(height, 162, accuracy: 1)
    }

    func testMediumHeightFloorsAtCompactMinimum() {
        let height = SheetDetentLayoutCalculator.sheetHeight(
            for: .medium,
            availableHeight: 300,
            minCollapsedHeight: DragHandleMetrics.minCollapsedHeight
        )

        XCTAssertEqual(height, 126, accuracy: 1)
    }

    func testExpandedHeightUsesDetentFraction() {
        let height = SheetDetentLayoutCalculator.sheetHeight(
            for: .expanded,
            availableHeight: 800,
            minCollapsedHeight: DragHandleMetrics.minCollapsedHeight
        )

        XCTAssertEqual(height, 704, accuracy: 1)
    }
}
