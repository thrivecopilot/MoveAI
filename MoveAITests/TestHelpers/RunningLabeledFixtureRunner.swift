import Foundation
@testable import MoveAI

@MainActor
enum RunningLabeledFixtureRunner {
    struct Manifest: Codable {
        let fixtures: [Fixture]
    }

    struct Fixture: Codable {
        let id: String
        let cacheId: String?
        let videoFile: String?
        let requiredIssueKinds: [String]
        let forbiddenIssueKinds: [String]
        let expectedIssueCounts: [String: Int]?
        let requiredMetricKinds: [String]?
    }

    enum RunnerError: LocalizedError {
        case fixtureManifestMissing
        case fixtureVideoMissing(String)
        case extractionRequiresVideoFile(String)
        case cacheUnavailable(String)
        case poseExtractionFailed(String)

        var errorDescription: String? {
            switch self {
            case .fixtureManifestMissing:
                return "Running fixture manifest not found"
            case .fixtureVideoMissing(let file):
                return "Fixture video not found: \(file)"
            case .extractionRequiresVideoFile(let id):
                return "Fixture \(id) has no videoFile configured for extraction"
            case .cacheUnavailable(let id):
                return "Pose cache unavailable for fixture \(id)"
            case .poseExtractionFailed(let id):
                return "Pose extraction produced empty poseData for fixture \(id)"
            }
        }
    }

    private static let testVideosDirectoryEnvKey = "MOVEAI_TEST_VIDEOS_DIR"
    private static let liveExtractionEnvKey = "MOVEAI_ENABLE_LIVE_POSE_EXTRACTION_TESTS"
    private static let allowSimulatorExtractionEnvKey = "MOVEAI_ALLOW_SIMULATOR_EXTRACTION"

    static func loadFixtures() throws -> [Fixture] {
        let manifestURL = try fixtureManifestURL()
        let data = try Data(contentsOf: manifestURL)
        let manifest = try JSONDecoder().decode(Manifest.self, from: data)

        guard let filter = fixtureFilterIDs(), !filter.isEmpty else {
            return manifest.fixtures
        }

        let filtered = manifest.fixtures.filter { filter.contains($0.id) }
        print("🎯 Running fixture filter active (\(filtered.count)/\(manifest.fixtures.count)): \(filtered.map(\.id).joined(separator: ","))")
        return filtered
    }

    static func testVideosDirectory() -> URL {
        if let overrideDirectory = environmentTestVideosDirectory() {
            return overrideDirectory
        }

        let repositoryDirectory = repositoryTestVideosDirectory
        if isReadableDirectory(repositoryDirectory) {
            return repositoryDirectory
        }

        if let bundledDirectory = bundledTestVideosDirectories().first(where: { isReadableDirectory($0) }) {
            return bundledDirectory
        }

        return repositoryDirectory
    }

    static func cacheKey(for fixture: Fixture) -> String {
        if let cacheId = fixture.cacheId?.trimmingCharacters(in: .whitespacesAndNewlines), !cacheId.isEmpty {
            return cacheId
        }
        return fixture.id
    }

    static func cacheExists(for fixture: Fixture) -> Bool {
        PoseCacheManager.hasCache(for: cacheKey(for: fixture), testVideosDirectory: testVideosDirectory())
    }

    static func loadPoseDataFromCache(for fixture: Fixture) throws -> [PoseDetectionResult] {
        let key = cacheKey(for: fixture)
        guard let cached = try PoseCacheManager.loadPoseData(for: key, testVideosDirectory: testVideosDirectory()), !cached.isEmpty else {
            throw RunnerError.cacheUnavailable(fixture.id)
        }
        return cached
    }

    static func loadOrExtractPoseData(for fixture: Fixture, forceReextract: Bool = false) async throws -> [PoseDetectionResult] {
        let key = cacheKey(for: fixture)
        let videosDirectory = testVideosDirectory()

        if !forceReextract,
           let cached = try PoseCacheManager.loadPoseData(for: key, testVideosDirectory: videosDirectory),
           !cached.isEmpty {
            return cached
        }

        guard isLiveExtractionEnabledForCurrentRuntime() else {
            throw RunnerError.cacheUnavailable(fixture.id)
        }

        let videoURL = try videoURL(for: fixture)
        let recording = try await VideoProcessor().processVideo(videoURL, movementType: .running)

        guard let poseData = recording.poseData, !poseData.isEmpty else {
            throw RunnerError.poseExtractionFailed(fixture.id)
        }

        try PoseCacheManager.savePoseData(poseData, for: key, testVideosDirectory: videosDirectory)

        // Best-effort provenance writing for extraction workflows.
        if let videoFile = fixture.videoFile {
            do {
                let videoSHA256 = try PoseCacheManager.fileSHA256(at: videoURL)
                let cacheURL = PoseCacheManager.cachePath(for: key, testVideosDirectory: videosDirectory)
                let cacheSHA256 = try PoseCacheManager.fileSHA256(at: cacheURL)
                try PoseCacheManager.saveCacheProvenance(
                    fixtureId: key,
                    videoFile: videoFile,
                    videoSHA256: videoSHA256,
                    cacheSHA256: cacheSHA256,
                    generator: "video_processor_running",
                    testVideosDirectory: videosDirectory
                )
            } catch {
                print("⚠️ Running fixture provenance skipped for \(fixture.id): \(error.localizedDescription)")
            }
        }

        return poseData
    }

    static func analyzeFixture(_ fixture: Fixture, poseData: [PoseDetectionResult]) async throws -> AnalysisResult {
        let recording = MovementRecording(
            movementType: .running,
            videoURL: URL(fileURLWithPath: "/tmp/\(fixture.id).mov"),
            duration: max(Double(poseData.count) / 30.0, 0.1),
            poseData: poseData
        )

        return try await PoseBasedAnalysisService().analyzeMovement(recording)
    }

    static func issueKindSet(from result: AnalysisResult) -> Set<String> {
        Set(result.feedback.compactMap { $0.issueKind?.rawValue })
    }

    static func issueCounts(from result: AnalysisResult) -> [String: Int] {
        Dictionary(
            result.feedback.compactMap { $0.issueKind?.rawValue }.map { ($0, 1) },
            uniquingKeysWith: +
        )
    }

    static func metricKindSet(from result: AnalysisResult) -> Set<String> {
        let kinds = result.feedback
            .compactMap { $0.metrics }
            .flatMap { $0 }
            .map { $0.kind.rawValue }
        return Set(kinds)
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

    private static func fixtureManifestURL() throws -> URL {
        for directory in resourceSearchDirectories() {
            let candidate = directory.appendingPathComponent("running_labeled_fixtures.json")
            if isReadableFile(candidate) {
                return candidate
            }
        }

        let bundle = Bundle(for: BundleToken.self)
        if let bundled = bundle.url(forResource: "running_labeled_fixtures", withExtension: "json"),
           isReadableFile(bundled) {
            return bundled
        }

        throw RunnerError.fixtureManifestMissing
    }

    private static func videoURL(for fixture: Fixture) throws -> URL {
        guard let file = fixture.videoFile?.trimmingCharacters(in: .whitespacesAndNewlines), !file.isEmpty else {
            throw RunnerError.extractionRequiresVideoFile(fixture.id)
        }

        for directory in resourceSearchDirectories() {
            let candidate = directory.appendingPathComponent(file)
            if isReadableFile(candidate) {
                return candidate
            }
        }

        let bundle = Bundle(for: BundleToken.self)
        let fileName = file as NSString
        let stem = fileName.deletingPathExtension
        let ext = fileName.pathExtension
        if let bundledURL = bundle.url(
            forResource: stem,
            withExtension: ext.isEmpty ? nil : ext
        ) ?? bundle.url(forResource: file, withExtension: nil),
           isReadableFile(bundledURL) {
            return bundledURL
        }

        throw RunnerError.fixtureVideoMissing(file)
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
        guard let raw = ProcessInfo.processInfo.environment[testVideosDirectoryEnvKey], !raw.isEmpty else {
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

    private final class BundleToken {}
}
