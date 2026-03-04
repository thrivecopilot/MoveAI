import XCTest
import AVFoundation
@testable import MoveAI

final class UniformSamplerTests: XCTestCase {
    func testVideoFrameReader_uniformSampling_callsHandlerExpectedNumberOfTimes() async throws {
        let bundle = Bundle(for: type(of: self))

        let candidates: [URL?] = [
            bundle.url(forResource: "test_case_1", withExtension: "MOV"),
            bundle.url(forResource: "test_case_1", withExtension: "mov"),
            bundle.url(forResource: "test_case_1", withExtension: "mp4")
        ]

        guard let videoURL = candidates.compactMap({ $0 }).first else {
            throw XCTSkip("Test video not found in test bundle resources (expected test_case_1.MOV)")
        }

        let asset = AVAsset(url: videoURL)
        let tracks = try await asset.loadTracks(withMediaType: .video)
        guard let track = tracks.first else {
            XCTFail("No video track found in test video")
            return
        }

        // Use an exactly representable duration to avoid floating rounding issues in Int(duration * fps).
        let requestedDurationSeconds: TimeInterval = 0.5
        let targetFPS: Double = 30.0
        let expectedSamples = Int(requestedDurationSeconds * targetFPS)

        let reader = try VideoFrameReader(asset: asset, videoTrack: track)

        var indices: [Int] = []
        indices.reserveCapacity(expectedSamples)
        var nonNilPixelBuffers = 0

        try await reader.forEachUniformSample(durationSeconds: requestedDurationSeconds, targetFPS: targetFPS) { i, pixelBuffer in
            indices.append(i)
            if pixelBuffer != nil {
                nonNilPixelBuffers += 1
            }

            // This mirrors the contract used downstream in VideoProcessor.
            let timestampSeconds = Double(i) / targetFPS
            XCTAssertGreaterThanOrEqual(timestampSeconds, 0)
        }

        XCTAssertEqual(indices.count, expectedSamples)
        XCTAssertEqual(indices, Array(0..<expectedSamples))
        XCTAssertGreaterThan(nonNilPixelBuffers, 0)
    }
}
