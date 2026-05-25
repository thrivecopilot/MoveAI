import Foundation
@testable import MoveAI

@MainActor
enum MuayThaiLabeledFixtureRunner {
    struct PoseCoverageMetrics {
        let totalFrames: Int
        let nonEmptyFrames: Int
        let nonEmptyFrameRatio: Double
        let averageKeypointsPerNonEmptyFrame: Double
    }

    struct Manifest: Codable {
        let fixtures: [Fixture]
    }

    enum AnalysisMode: String, Codable {
        case autoDetect = "auto_detect"
        case explicitTechnique = "explicit_technique"
    }

    struct Fixture: Codable {
        let id: String
        let videoFile: String
        let analysisMode: AnalysisMode
        let selectedTechnique: MuayThaiTechnique?
        let selectedFightStance: FightStance?
        let expectedDetectedTechnique: MuayThaiTechnique?
        let requiredIssueKinds: [String]
        let forbiddenIssueKinds: [String]
        let expectedStrikeCount: Int?
        let expectedIssueCounts: [String: Int]?
    }

    enum RunnerError: LocalizedError {
        case fixtureManifestMissing
        case fixtureVideoMissing(String)
        case cacheUnavailable(String, String)
        case poseExtractionFailed(String)
        case poseExtractionLowCoverage(String, PoseCoverageMetrics)
        case explicitTechniqueMissing(String)

        var errorDescription: String? {
            switch self {
            case .fixtureManifestMissing:
                return "Muay Thai fixture manifest not found"
            case .fixtureVideoMissing(let file):
                return "Fixture video not found: \(file)"
            case .cacheUnavailable(let id, let reason):
                return "Pose cache unavailable for fixture \(id): \(reason)"
            case .poseExtractionFailed(let id):
                return "Pose extraction produced empty poseData for fixture \(id)"
            case .poseExtractionLowCoverage(let id, let metrics):
                return "Pose extraction quality too low for fixture \(id): nonEmptyFrames=\(metrics.nonEmptyFrames)/\(metrics.totalFrames), ratio=\(String(format: "%.3f", metrics.nonEmptyFrameRatio)), avgKeypoints=\(String(format: "%.2f", metrics.averageKeypointsPerNonEmptyFrame))"
            case .explicitTechniqueMissing(let id):
                return "Fixture \(id) is explicit_technique but selectedTechnique is nil"
            }
        }
    }

    private static let minimumNonEmptyFrameRatio = 0.10
    private static let minimumAverageKeypointsPerNonEmptyFrame = 6.0
    private static let testVideosDirectoryEnvKey = "MOVEAI_TEST_VIDEOS_DIR"
    private static let liveExtractionEnvKey = "MOVEAI_ENABLE_LIVE_POSE_EXTRACTION_TESTS"
    private static let allowSimulatorExtractionEnvKey = "MOVEAI_ALLOW_SIMULATOR_EXTRACTION"

    static func loadFixtures() throws -> [Fixture] {
        let manifestURL = try fixtureManifestURL()
        let data = try Data(contentsOf: manifestURL)
        let manifest = try JSONDecoder().decode(Manifest.self, from: data)
        let fixtures = manifest.fixtures

        guard let filter = fixtureFilterIDs(), !filter.isEmpty else {
            return fixtures
        }

        let filtered = fixtures.filter { filter.contains($0.id) }
        print("🎯 Fixture filter active (\(filtered.count)/\(fixtures.count)): \(filtered.map(\.id).joined(separator: ","))")
        return filtered
    }

    static func testVideosDirectory() -> URL {
        if let overrideDirectory = environmentTestVideosDirectory() {
            return overrideDirectory
        }

        let repositoryDirectory = repositoryTestVideosDirectory
        if isReadableDirectory(repositoryDirectory) && isWritableDirectory(repositoryDirectory) {
            return repositoryDirectory
        }

        if let bundledDirectory = bundledTestVideosDirectories().first(where: { isReadableDirectory($0) }) {
            return bundledDirectory
        }

        if isReadableDirectory(repositoryDirectory) {
            return repositoryDirectory
        }

        return repositoryDirectory
    }

    static func cacheURL(for fixture: Fixture) -> URL {
        PoseCacheManager.cachePath(for: fixture.id, testVideosDirectory: testVideosDirectory())
    }

    static func cacheProvenanceURL(for fixture: Fixture) -> URL {
        PoseCacheManager.provenancePath(for: fixture.id, testVideosDirectory: testVideosDirectory())
    }

    static func cacheExists(for fixture: Fixture) -> Bool {
        PoseCacheManager.hasCache(for: fixture.id, testVideosDirectory: testVideosDirectory())
    }

    static func cacheProvenanceExists(for fixture: Fixture) -> Bool {
        PoseCacheManager.resolvedProvenancePath(
            for: fixture.id,
            testVideosDirectory: testVideosDirectory()
        ) != nil
    }

    static func loadCacheProvenance(for fixture: Fixture) throws -> PoseCacheManager.CacheProvenance? {
        try PoseCacheManager.loadCacheProvenance(
            for: fixture.id,
            testVideosDirectory: testVideosDirectory()
        )
    }

    static func loadOrExtractPoseData(for fixture: Fixture, forceReextract: Bool = false) async throws -> [PoseDetectionResult] {
        let testVideosDir = testVideosDirectory()
        let extractionEnabled = isLiveExtractionEnabledForCurrentRuntime()

        if !forceReextract,
           let cached = try PoseCacheManager.loadPoseData(for: fixture.id, testVideosDirectory: testVideosDir),
           !cached.isEmpty {
            let coverage = poseCoverageMetrics(from: cached)
            guard meetsCoverageGate(coverage) else {
                guard extractionEnabled else {
                    throw RunnerError.cacheUnavailable(
                        fixture.id,
                        "cache coverage too low (nonEmpty=\(coverage.nonEmptyFrames)/\(coverage.totalFrames), ratio=\(String(format: "%.3f", coverage.nonEmptyFrameRatio))); refresh cache externally"
                    )
                }

                print("⚠️ Cache quality too low for \(fixture.id). Re-extracting. nonEmpty=\(coverage.nonEmptyFrames)/\(coverage.totalFrames) ratio=\(String(format: "%.3f", coverage.nonEmptyFrameRatio))")
                let context = try videoValidationContext(for: fixture)
                return try await extractAndCachePoseData(
                    fixture: fixture,
                    videoURL: context.videoURL,
                    videoSHA256: context.videoSHA256,
                    testVideosDir: testVideosDir
                )
            }

            guard let context = optionalVideoValidationContext(for: fixture) else {
                print("ℹ️ Using cached poses for \(fixture.id) without video provenance validation")
                return cached
            }

            guard let resolvedCacheURL = PoseCacheManager.resolvedCachePath(
                for: fixture.id,
                testVideosDirectory: testVideosDir
            ) else {
                return cached
            }

            guard let freshness = cacheIsFresh(cacheURL: resolvedCacheURL, videoURL: context.videoURL) else {
                print("ℹ️ Cache freshness unavailable for \(fixture.id). Using cached poses without re-extraction.")
                return cached
            }

            if freshness {
                if try cacheProvenanceMatches(
                    fixture: fixture,
                    videoSHA256: context.videoSHA256,
                    cacheURL: resolvedCacheURL,
                    testVideosDir: testVideosDir
                ) {
                    return cached
                }

                if shouldBackfillCacheProvenance() {
                    try backfillCacheProvenance(
                        fixture: fixture,
                        videoSHA256: context.videoSHA256,
                        cacheURL: resolvedCacheURL,
                        testVideosDir: testVideosDir
                    )
                    return cached
                }

                guard extractionEnabled else {
                    throw RunnerError.cacheUnavailable(
                        fixture.id,
                        "cache provenance mismatch; refresh cache externally"
                    )
                }

                print("⚠️ Cache provenance mismatch for \(fixture.id). Re-extracting.")
            } else {
                guard extractionEnabled else {
                    throw RunnerError.cacheUnavailable(
                        fixture.id,
                        "cache is stale relative to video file; refresh cache externally"
                    )
                }

                print("⚠️ Cache stale for \(fixture.id). Re-extracting.")
            }

            return try await extractAndCachePoseData(
                fixture: fixture,
                videoURL: context.videoURL,
                videoSHA256: context.videoSHA256,
                testVideosDir: testVideosDir
            )
        }

        guard extractionEnabled else {
            throw RunnerError.cacheUnavailable(
                fixture.id,
                forceReextract
                    ? "forceReextract requested but live extraction is disabled"
                    : "cache missing; refresh cache externally before running analysis tests"
            )
        }

        let context = try videoValidationContext(for: fixture)
        return try await extractAndCachePoseData(
            fixture: fixture,
            videoURL: context.videoURL,
            videoSHA256: context.videoSHA256,
            testVideosDir: testVideosDir
        )
    }

    static func isLiveExtractionEnabledForCurrentRuntime() -> Bool {
        guard ProcessInfo.processInfo.environment[liveExtractionEnvKey] == "1" else {
            return false
        }

        #if targetEnvironment(simulator)
        return ProcessInfo.processInfo.environment[allowSimulatorExtractionEnvKey] == "1"
        #else
        return true
        #endif
    }

    static func poseCoverageMetrics(from poses: [PoseDetectionResult]) -> PoseCoverageMetrics {
        let totalFrames = poses.count
        let nonEmptyFrames = poses.reduce(into: 0) { partial, pose in
            if !pose.keypoints.isEmpty {
                partial += 1
            }
        }

        let nonEmptyRatio = totalFrames > 0
            ? Double(nonEmptyFrames) / Double(totalFrames)
            : 0
        let keypointsAcrossNonEmptyFrames = poses.reduce(into: 0) { partial, pose in
            if !pose.keypoints.isEmpty {
                partial += pose.keypoints.count
            }
        }
        let averageKeypoints = nonEmptyFrames > 0
            ? Double(keypointsAcrossNonEmptyFrames) / Double(nonEmptyFrames)
            : 0

        return PoseCoverageMetrics(
            totalFrames: totalFrames,
            nonEmptyFrames: nonEmptyFrames,
            nonEmptyFrameRatio: nonEmptyRatio,
            averageKeypointsPerNonEmptyFrame: averageKeypoints
        )
    }

    static func meetsCoverageGate(_ metrics: PoseCoverageMetrics) -> Bool {
        metrics.totalFrames > 0 &&
        metrics.nonEmptyFrameRatio >= minimumNonEmptyFrameRatio &&
        metrics.averageKeypointsPerNonEmptyFrame >= minimumAverageKeypointsPerNonEmptyFrame
    }

    private static func extractAndCachePoseData(
        fixture: Fixture,
        videoURL: URL,
        videoSHA256: String,
        testVideosDir: URL
    ) async throws -> [PoseDetectionResult] {
        let recording = try await VideoProcessor().processVideo(videoURL, movementType: .muayThai)
        guard let poseData = recording.poseData, !poseData.isEmpty else {
            throw RunnerError.poseExtractionFailed(fixture.id)
        }

        let coverage = poseCoverageMetrics(from: poseData)
        guard meetsCoverageGate(coverage) else {
            throw RunnerError.poseExtractionLowCoverage(fixture.id, coverage)
        }

        try PoseCacheManager.savePoseData(poseData, for: fixture.id, testVideosDirectory: testVideosDir)
        let cacheURL = PoseCacheManager.cachePath(for: fixture.id, testVideosDirectory: testVideosDir)
        let cacheSHA256 = try PoseCacheManager.fileSHA256(at: cacheURL)
        try PoseCacheManager.saveCacheProvenance(
            fixtureId: fixture.id,
            videoFile: fixture.videoFile,
            videoSHA256: videoSHA256,
            cacheSHA256: cacheSHA256,
            generator: "video_processor",
            testVideosDirectory: testVideosDir
        )
        return poseData
    }

    static func analyzeFixture(_ fixture: Fixture, poseData: [PoseDetectionResult]) async throws -> AnalysisResult {
        let videoURL = try videoURL(for: fixture)

        let selectedTechnique: MuayThaiTechnique?
        switch fixture.analysisMode {
        case .autoDetect:
            selectedTechnique = nil
        case .explicitTechnique:
            guard let technique = fixture.selectedTechnique else {
                throw RunnerError.explicitTechniqueMissing(fixture.id)
            }
            selectedTechnique = technique
        }

        let recording = MovementRecording(
            movementType: .muayThai,
            technique: selectedTechnique,
            fightStance: fixture.selectedFightStance,
            videoURL: videoURL,
            duration: max(Double(poseData.count) / 30.0, 0.1),
            poseData: poseData
        )

        return try await PoseBasedAnalysisService().analyzeMovement(recording)
    }

    static func issueKindSet(from result: AnalysisResult) -> Set<String> {
        Set(result.feedback.compactMap { $0.issueKind?.rawValue })
    }

    private static func videoURL(for fixture: Fixture) throws -> URL {
        for directory in resourceSearchDirectories() {
            let candidate = directory.appendingPathComponent(fixture.videoFile)
            if isReadableFile(candidate) {
                return candidate
            }
        }

        let bundle = Bundle(for: BundleToken.self)
        let fileName = fixture.videoFile as NSString
        let stem = fileName.deletingPathExtension
        let ext = fileName.pathExtension
        if let bundledURL = bundle.url(
            forResource: stem,
            withExtension: ext.isEmpty ? nil : ext
        ) ?? bundle.url(forResource: fixture.videoFile, withExtension: nil),
           isReadableFile(bundledURL) {
            return bundledURL
        }

        throw RunnerError.fixtureVideoMissing(fixture.videoFile)
    }

    private static func fixtureManifestURL() throws -> URL {
        for directory in resourceSearchDirectories() {
            let candidate = directory.appendingPathComponent("muay_thai_labeled_fixtures.json")
            if isReadableFile(candidate) {
                return candidate
            }
        }

        let bundle = Bundle(for: BundleToken.self)
        if let bundled = bundle.url(forResource: "muay_thai_labeled_fixtures", withExtension: "json"),
           isReadableFile(bundled) {
            return bundled
        }

        throw RunnerError.fixtureManifestMissing
    }

    private static func videoValidationContext(for fixture: Fixture) throws -> VideoValidationContext {
        let videoURL = try videoURL(for: fixture)
        let videoSHA256 = try PoseCacheManager.fileSHA256(at: videoURL)
        return VideoValidationContext(videoURL: videoURL, videoSHA256: videoSHA256)
    }

    private static func optionalVideoValidationContext(for fixture: Fixture) -> VideoValidationContext? {
        do {
            return try videoValidationContext(for: fixture)
        } catch {
            print("ℹ️ Skipping cache provenance checks for \(fixture.id): \(error.localizedDescription)")
            return nil
        }
    }

    private static func shouldBackfillCacheProvenance() -> Bool {
        ProcessInfo.processInfo.environment["MOVEAI_BACKFILL_CACHE_PROVENANCE"] != "0"
    }

    private static func fixtureFilterIDs() -> Set<String>? {
        guard let raw = ProcessInfo.processInfo.environment["MOVEAI_FIXTURE_IDS"] else {
            return nil
        }

        let ids = raw
            .split(separator: ",")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        guard !ids.isEmpty else { return nil }
        return Set(ids)
    }

    private static func cacheProvenanceMatches(
        fixture: Fixture,
        videoSHA256: String,
        cacheURL: URL,
        testVideosDir: URL
    ) throws -> Bool {
        guard let provenance = try PoseCacheManager.loadCacheProvenance(
            for: fixture.id,
            testVideosDirectory: testVideosDir
        ) else {
            return false
        }

        guard provenance.schemaVersion == 1,
              provenance.fixtureId == fixture.id,
              provenance.videoFile == fixture.videoFile,
              provenance.videoSHA256 == videoSHA256 else {
            return false
        }

        let cacheSHA256 = try PoseCacheManager.fileSHA256(at: cacheURL)
        return provenance.cacheSHA256 == cacheSHA256
    }

    private static func backfillCacheProvenance(
        fixture: Fixture,
        videoSHA256: String,
        cacheURL: URL,
        testVideosDir: URL
    ) throws {
        let cacheSHA256 = try PoseCacheManager.fileSHA256(at: cacheURL)
        try PoseCacheManager.saveCacheProvenance(
            fixtureId: fixture.id,
            videoFile: fixture.videoFile,
            videoSHA256: videoSHA256,
            cacheSHA256: cacheSHA256,
            generator: "backfill_existing_cache",
            testVideosDirectory: testVideosDir
        )
        print("🧾 Backfilled cache provenance for \(fixture.id)")
    }

    private static func cacheIsFresh(cacheURL: URL, videoURL: URL) -> Bool? {
        guard
            let cacheDate = modificationDate(for: cacheURL),
            let videoDate = modificationDate(for: videoURL)
        else {
            return nil
        }

        return cacheDate >= videoDate
    }

    private static func modificationDate(for url: URL) -> Date? {
        guard let attrs = try? FileManager.default.attributesOfItem(atPath: url.path) else {
            return nil
        }
        return attrs[.modificationDate] as? Date
    }

    private static func resourceSearchDirectories() -> [URL] {
        var directories: [URL] = []

        if let overrideDirectory = environmentTestVideosDirectory() {
            directories.append(overrideDirectory)
        }

        directories.append(contentsOf: bundledTestVideosDirectories())
        directories.append(repositoryTestVideosDirectory)

        var seen: Set<String> = []
        return directories.filter { url in
            let normalizedPath = url.standardizedFileURL.path
            guard !seen.contains(normalizedPath) else {
                return false
            }
            seen.insert(normalizedPath)
            return true
        }
    }

    private static func bundledTestVideosDirectories() -> [URL] {
        let bundle = Bundle(for: BundleToken.self)
        guard let resourceURL = bundle.resourceURL else {
            return []
        }

        return [
            resourceURL,
            resourceURL.appendingPathComponent("TestVideos", isDirectory: true)
        ]
    }

    private static func environmentTestVideosDirectory() -> URL? {
        guard let raw = ProcessInfo.processInfo.environment[testVideosDirectoryEnvKey],
              !raw.isEmpty else {
            return nil
        }

        let explicitURL = URL(fileURLWithPath: raw, isDirectory: true)
        if explicitURL.path.hasPrefix("/") {
            return explicitURL
        }

        return repositoryRootURL.appendingPathComponent(raw, isDirectory: true)
    }

    private static func isReadableFile(_ url: URL) -> Bool {
        FileManager.default.fileExists(atPath: url.path) &&
        FileManager.default.isReadableFile(atPath: url.path)
    }

    private static func isReadableDirectory(_ url: URL) -> Bool {
        var isDirectory: ObjCBool = false
        let exists = FileManager.default.fileExists(atPath: url.path, isDirectory: &isDirectory)
        return exists && isDirectory.boolValue && FileManager.default.isReadableFile(atPath: url.path)
    }

    private static func isWritableDirectory(_ url: URL) -> Bool {
        FileManager.default.isWritableFile(atPath: url.path)
    }

    private static var repositoryTestVideosDirectory: URL {
        repositoryRootURL
            .appendingPathComponent("MoveAITests", isDirectory: true)
            .appendingPathComponent("TestVideos", isDirectory: true)
    }

    private static var repositoryRootURL: URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent() // TestHelpers
            .deletingLastPathComponent() // MoveAITests
            .deletingLastPathComponent() // repo root
    }

    private struct VideoValidationContext {
        let videoURL: URL
        let videoSHA256: String
    }

    private final class BundleToken {}
}
