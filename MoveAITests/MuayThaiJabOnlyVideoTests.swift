import XCTest
@testable import MoveAI

@MainActor
final class MuayThaiJabOnlyVideoTests: XCTestCase {
    override func tearDown() {
        unsetenv("MOVEAI_ENABLE_MUAY_THAI_ANALYZER")
        unsetenv("MOVEAI_ENABLE_MUAY_THAI_COMBO_ANALYZER")
        unsetenv("MOVEAI_MUAY_THAI_DEBUG")
        super.tearDown()
    }

    func testJabOnlyCacheExtraction() async throws {
        let testVideosDir = testVideosDirectory
        let videoURL = try jabOnlyVideoURL()
        let recording = try await VideoProcessor().processVideo(videoURL, movementType: .muayThai)

        guard let poseData = recording.poseData,
              !poseData.isEmpty,
              hasUsableKeypoints(in: poseData) else {
            throw XCTSkip("Pose extraction unavailable or produced empty keypoints on this simulator/runtime")
        }

        try PoseCacheManager.savePoseData(poseData, for: "jab_only", testVideosDirectory: testVideosDir)
        XCTAssertGreaterThan(poseData.count, 0)
    }

    func testJabOnlyAutoDetectUsesJabFromCachedPoses() async throws {
        setenv("MOVEAI_ENABLE_MUAY_THAI_ANALYZER", "1", 1)
        setenv("MOVEAI_ENABLE_MUAY_THAI_COMBO_ANALYZER", "1", 1)
        setenv("MOVEAI_MUAY_THAI_DEBUG", "1", 1)

        let poseData = try await loadOrExtractCachedJabOnlyPoses()
        let recording = MovementRecording(
            movementType: .muayThai,
            videoURL: try jabOnlyVideoURL(),
            duration: max(Double(poseData.count) / 30.0, 0.1),
            poseData: poseData
        )

        let result = try await PoseBasedAnalysisService().analyzeMovement(recording)

        print("[JabOnlyTest] detectedTechnique=\(result.detectedTechnique?.rawValue ?? "nil") confidence=\(result.detectionConfidence ?? -1) score=\(result.score)")
        let issueKinds = result.feedback.compactMap { $0.issueKind?.rawValue }
        print("[JabOnlyTest] issueKinds=\(issueKinds)")

        XCTAssertEqual(result.detectedTechnique, .jab)
    }

    func testJabOnlyExplicitJabDoesNotMislabelRearHandDrop() async throws {
        setenv("MOVEAI_ENABLE_MUAY_THAI_ANALYZER", "1", 1)
        setenv("MOVEAI_MUAY_THAI_DEBUG", "1", 1)

        let poseData = try await loadOrExtractCachedJabOnlyPoses()
        let recording = MovementRecording(
            movementType: .muayThai,
            technique: .jab,
            fightStance: .orthodox,
            videoURL: try jabOnlyVideoURL(),
            duration: max(Double(poseData.count) / 30.0, 0.1),
            poseData: poseData
        )

        let result = try await PoseBasedAnalysisService().analyzeMovement(recording)
        let kinds = Set(result.feedback.compactMap(\.issueKind))
        print("[JabOnlyTest] explicit-jab issueKinds=\(kinds.map(\.rawValue).sorted())")

        XCTAssertFalse(
            kinds.contains(.muayThaiJabRearHandDropping),
            "Expected clean jab reference clip to avoid rear-hand-drop labeling"
        )
    }

    private var testVideosDirectory: URL {
        MuayThaiLabeledFixtureRunner.testVideosDirectory()
    }

    private func jabOnlyVideoURL() throws -> URL {
        let candidates = [
            "jab_only.mov",
            "jab_only.MOV",
            "jab_only.mp4",
            "jab_only.MP4",
        ]

        for fileName in candidates {
            let candidateURL = testVideosDirectory.appendingPathComponent(fileName)
            if FileManager.default.fileExists(atPath: candidateURL.path) {
                return candidateURL
            }
        }

        throw XCTSkip("jab_only video not found in test resources")
    }

    private func loadOrExtractCachedJabOnlyPoses() async throws -> [PoseDetectionResult] {
        let testVideosDir = testVideosDirectory

        if let cached = try PoseCacheManager.loadPoseData(for: "jab_only", testVideosDirectory: testVideosDir),
           !cached.isEmpty,
           hasUsableKeypoints(in: cached) {
            return cached
        }

        let videoURL = try jabOnlyVideoURL()
        let recording = try await VideoProcessor().processVideo(videoURL, movementType: .muayThai)
        guard let poseData = recording.poseData,
              !poseData.isEmpty,
              hasUsableKeypoints(in: poseData) else {
            throw XCTSkip("Pose extraction unavailable or produced empty keypoints on this simulator/runtime")
        }

        try PoseCacheManager.savePoseData(poseData, for: "jab_only", testVideosDirectory: testVideosDir)
        return poseData
    }

    private func hasUsableKeypoints(in poses: [PoseDetectionResult]) -> Bool {
        poses.contains { !$0.keypoints.isEmpty }
    }
}
