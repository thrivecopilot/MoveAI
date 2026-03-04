import XCTest
import CoreGraphics
import ImageIO
@testable import MoveAI

final class VideoOrientationMappingTests: XCTestCase {
    func testVisionOrientationMapping_matchesCommonPreferredTransforms() {
        let cases: [(CGAffineTransform, CGImagePropertyOrientation)] = [
            (.identity, .up),
            (CGAffineTransform(a: -1, b: 0, c: 0, d: -1, tx: 0, ty: 0), .down),
            (CGAffineTransform(a: 0, b: 1, c: -1, d: 0, tx: 0, ty: 0), .right),
            (CGAffineTransform(a: 0, b: -1, c: 1, d: 0, tx: 0, ty: 0), .left),
            (CGAffineTransform(a: -1, b: 0, c: 0, d: 1, tx: 0, ty: 0), .upMirrored),
            (CGAffineTransform(a: 1, b: 0, c: 0, d: -1, tx: 0, ty: 0), .downMirrored),
            (CGAffineTransform(a: 0, b: 1, c: 1, d: 0, tx: 0, ty: 0), .rightMirrored),
            (CGAffineTransform(a: 0, b: -1, c: -1, d: 0, tx: 0, ty: 0), .leftMirrored)
        ]

        for (transform, expected) in cases {
            XCTAssertEqual(
                VideoProcessingHelpers.visionOrientation(forPreferredTransform: transform),
                expected,
                "Unexpected orientation for preferredTransform=\(transform)"
            )
        }
    }

    func testVisionOrientationMapping_ignoresTranslation() {
        let translated = CGAffineTransform(a: 0, b: 1, c: -1, d: 0, tx: 123, ty: 456)
        XCTAssertEqual(VideoProcessingHelpers.visionOrientation(forPreferredTransform: translated), .right)
    }
}
