import Foundation
@testable import MoveAI

@MainActor
enum MuayThaiLabeledFixtureRunner {
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
    }

    enum RunnerError: LocalizedError {
        case fixtureManifestMissing
        case fixtureVideoMissing(String)
        case poseExtractionFailed(String)
        case explicitTechniqueMissing(String)

        var errorDescription: String? {
            switch self {
            case .fixtureManifestMissing:
                return "Muay Thai fixture manifest not found"
            case .fixtureVideoMissing(let file):
                return "Fixture video not found: \(file)"
            case .poseExtractionFailed(let id):
                return "Pose extraction produced empty poseData for fixture \(id)"
            case .explicitTechniqueMissing(let id):
                return "Fixture \(id) is explicit_technique but selectedTechnique is nil"
            }
        }
    }

    static func loadFixtures() throws -> [Fixture] {
        let manifestURL = try fixtureManifestURL()
        let data = try Data(contentsOf: manifestURL)
        let manifest = try JSONDecoder().decode(Manifest.self, from: data)
        return manifest.fixtures
    }

    static func testVideosDirectory() -> URL {
        repositoryRootURL
            .appendingPathComponent("MoveAITests", isDirectory: true)
            .appendingPathComponent("TestVideos", isDirectory: true)
    }

    static func cacheURL(for fixture: Fixture) -> URL {
        PoseCacheManager.cachePath(for: fixture.id, testVideosDirectory: testVideosDirectory())
    }

    static func cacheExists(for fixture: Fixture) -> Bool {
        PoseCacheManager.hasCache(for: fixture.id, testVideosDirectory: testVideosDirectory())
    }

    static func loadOrExtractPoseData(for fixture: Fixture) async throws -> [PoseDetectionResult] {
        let testVideosDir = testVideosDirectory()
        let videoURL = try videoURL(for: fixture)
        let cacheURL = PoseCacheManager.cachePath(for: fixture.id, testVideosDirectory: testVideosDir)

        if let cached = try PoseCacheManager.loadPoseData(for: fixture.id, testVideosDirectory: testVideosDir),
           !cached.isEmpty,
           cacheIsFresh(cacheURL: cacheURL, videoURL: videoURL) {
            return cached
        }

        let recording = try await VideoProcessor().processVideo(videoURL, movementType: .muayThai)
        guard let poseData = recording.poseData, !poseData.isEmpty else {
            throw RunnerError.poseExtractionFailed(fixture.id)
        }

        try PoseCacheManager.savePoseData(poseData, for: fixture.id, testVideosDirectory: testVideosDir)
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
        let url = testVideosDirectory().appendingPathComponent(fixture.videoFile)
        guard FileManager.default.fileExists(atPath: url.path) else {
            throw RunnerError.fixtureVideoMissing(fixture.videoFile)
        }
        return url
    }

    private static func fixtureManifestURL() throws -> URL {
        let direct = testVideosDirectory().appendingPathComponent("muay_thai_labeled_fixtures.json")
        if FileManager.default.fileExists(atPath: direct.path) {
            return direct
        }

        let bundle = Bundle(for: BundleToken.self)
        if let bundled = bundle.url(forResource: "muay_thai_labeled_fixtures", withExtension: "json") {
            return bundled
        }

        throw RunnerError.fixtureManifestMissing
    }

    private static func cacheIsFresh(cacheURL: URL, videoURL: URL) -> Bool {
        guard
            let cacheDate = modificationDate(for: cacheURL),
            let videoDate = modificationDate(for: videoURL)
        else {
            return false
        }

        return cacheDate >= videoDate
    }

    private static func modificationDate(for url: URL) -> Date? {
        guard let attrs = try? FileManager.default.attributesOfItem(atPath: url.path) else {
            return nil
        }
        return attrs[.modificationDate] as? Date
    }

    private static var repositoryRootURL: URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent() // TestHelpers
            .deletingLastPathComponent() // MoveAITests
            .deletingLastPathComponent() // repo root
    }

    private final class BundleToken {}
}
