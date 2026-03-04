import AVFoundation
import CoreVideo
import Foundation

enum VideoFrameReaderError: Error {
    case cannotAddOutput
    case cannotStartReading(underlying: Error?)
}

/// Reads video frames sequentially via AVAssetReader (fast) and allows uniform sampling.
final class VideoFrameReader {
    private struct Sample {
        let pixelBuffer: CVPixelBuffer
        let presentationTime: CMTime

        var presentationSeconds: Double {
            CMTimeGetSeconds(presentationTime)
        }
    }

    private let reader: AVAssetReader
    private let output: AVAssetReaderTrackOutput

    init(asset: AVAsset, videoTrack: AVAssetTrack, outputSettings: [String: Any]? = nil) throws {
        let reader = try AVAssetReader(asset: asset)

        let settings = outputSettings
            ?? [kCVPixelBufferPixelFormatTypeKey as String: Int(kCVPixelFormatType_32BGRA)]

        let output = AVAssetReaderTrackOutput(track: videoTrack, outputSettings: settings)
        output.alwaysCopiesSampleData = false

        guard reader.canAdd(output) else {
            throw VideoFrameReaderError.cannotAddOutput
        }

        reader.add(output)

        self.reader = reader
        self.output = output
    }

    private func startReading() throws {
        guard reader.startReading() else {
            throw VideoFrameReaderError.cannotStartReading(underlying: reader.error)
        }
    }

    private func nextSample() -> Sample? {
        guard let sampleBuffer = output.copyNextSampleBuffer() else { return nil }
        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return nil }
        let presentationTime = CMSampleBufferGetPresentationTimeStamp(sampleBuffer)
        return Sample(pixelBuffer: pixelBuffer, presentationTime: presentationTime)
    }

    /// Iterate over a uniform time grid and deliver the nearest decoded frame for each sample time.
    ///
    /// - Important: This guarantees `handler` is called exactly `Int(durationSeconds * targetFPS)` times.
    func forEachUniformSample(
        durationSeconds: TimeInterval,
        targetFPS: Double,
        handler: (_ sampleIndex: Int, _ pixelBuffer: CVPixelBuffer?) async throws -> Void
    ) async throws {
        try startReading()

        let totalSamples = max(0, Int(durationSeconds * targetFPS))
        var previous: Sample? = nil
        var current: Sample? = nextSample()

        for i in 0..<totalSamples {
            let targetSeconds = Double(i) / targetFPS

            while let c = current, c.presentationSeconds < targetSeconds {
                previous = c
                current = nextSample()
            }

            let chosen: Sample?
            if let prev = previous, let curr = current {
                let prevDist = abs(prev.presentationSeconds - targetSeconds)
                let currDist = abs(curr.presentationSeconds - targetSeconds)
                chosen = (currDist <= prevDist) ? curr : prev
            } else {
                chosen = current ?? previous
            }

            try await handler(i, chosen?.pixelBuffer)
        }
    }
}
