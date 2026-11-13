import XCTest
import CoreGraphics
@testable import MoveAI

/// Runs the squat analyzer with camera normalization on (as the app does) over
/// pose data from real handheld clips. Before normalization these clips were
/// scored with the wrong rep count, view or depth; see `PoseNormalizer`.
final class SquatCameraNormalizationTests: XCTestCase {

    private struct Fixture: Decodable {
        struct Frame: Decodable {
            let t: Double
            let k: [String: [Double]]
        }
        let width: Double
        let height: Double
        let frames: [Frame]
    }

    /// Vision reports these joints only (no heels or toes).
    private static let visionJoints: Set<String> = [
        "nose", "leftEye", "rightEye", "leftEar", "rightEar", "neck",
        "leftShoulder", "rightShoulder", "leftElbow", "rightElbow", "leftWrist", "rightWrist",
        "leftHip", "rightHip", "root", "leftKnee", "rightKnee", "leftAnkle", "rightAnkle"
    ]

    private func load(_ name: String) throws -> (poses: [PoseDetectionResult], aspect: Double) {
        let url = MuayThaiLabeledFixtureRunner.testVideosDirectory()
            .appendingPathComponent("web_pose_fixtures")
            .appendingPathComponent("\(name).json")
        guard FileManager.default.fileExists(atPath: url.path) else {
            throw XCTSkip("Missing fixture \(url.path)")
        }
        let fixture = try JSONDecoder().decode(Fixture.self, from: Data(contentsOf: url))
        let poses: [PoseDetectionResult] = fixture.frames.map { frame in
            let timestamp = Date(timeIntervalSince1970: frame.t / 1000)
            let keypoints = frame.k.compactMap { jointName, values -> PoseKeypoint? in
                guard Self.visionJoints.contains(jointName), values.count == 3, values[2] > 0.1 else { return nil }
                return PoseKeypoint(
                    name: jointName,
                    position: CGPoint(x: values[0], y: values[1]),
                    confidence: Float(values[2]),
                    timestamp: timestamp
                )
            }
            // The app extracts at 30 fps; spread frame indices to match.
            let frameIndex = Int((frame.t / 1000 * 30).rounded())
            return PoseDetectionResult(keypoints: keypoints, frameIndex: frameIndex, timestamp: timestamp)
        }
        return (poses, fixture.width / fixture.height)
    }

    private func analyze(_ name: String) throws -> Result<SquatAnalysisResult, SquatAnalysisError> {
        let fixture = try load(name)
        return SquatAnalyzer.analyzeFullSequence(fixture.poses, videoAspect: fixture.aspect)
    }

    private func assertSquats(_ name: String, reps: Int, view: CameraAngle, file: StaticString = #filePath, line: UInt = #line) throws {
        switch try analyze(name) {
        case .failure(let error):
            XCTFail("\(name): analysis failed: \(error.primaryMessage)", file: file, line: line)
        case .success(let result):
            XCTAssertEqual(result.reps.count, reps, "\(name): rep count", file: file, line: line)
            XCTAssertEqual(result.reps.filter { $0.isFullRep }.count, reps, "\(name): complete reps", file: file, line: line)
            XCTAssertEqual(result.cameraAngle, view, "\(name): view", file: file, line: line)
            XCTAssertTrue((0...100).contains(result.overallScore), "\(name): score in range", file: file, line: line)
        }
    }

    // Barbell front squats, handheld iPhone, 3 reps each.

    func testSideViewFindsThreeCompleteReps() throws {
        try assertSquats("front_squat_side", reps: 3, view: .side)
    }

    func testFrontViewFindsThreeRepsAndIgnoresTheReRack() throws {
        try assertSquats("front_squat_front", reps: 3, view: .front)
    }

    func testFrontViewDoesNotFlagDepth() throws {
        guard case .success(let result) = try analyze("front_squat_front") else {
            return XCTFail("front_squat_front: analysis failed")
        }
        XCTAssertFalse(result.feedback.contains { $0.issueKind == .squatDepthTooShallow }, "Depth is not judged from the front")
        XCTAssertEqual(result.overallScore, 100, accuracy: 0.001, "No depth penalty from the front")
    }

    func testDiagonalViewIgnoresTheWalkOutAndCameraMovement() throws {
        try assertSquats("front_squat_diagonal", reps: 3, view: .diagonal)
    }

    // Muay Thai clips: nothing here is a squat.

    func testKickIsNotCountedAsASquat() throws {
        if case .success(let result) = try analyze("not_a_squat_kick") {
            XCTFail("Kick clip produced \(result.reps.count) squat reps")
        }
    }

    func testJabIsNotCountedAsASquat() throws {
        if case .success(let result) = try analyze("not_a_squat_jab") {
            XCTFail("Jab clip produced \(result.reps.count) squat reps")
        }
    }

    // Without a video shape the analyzer must behave exactly as before.

    func testWithoutVideoAspectNothingIsNormalized() throws {
        let fixture = try load("front_squat_front")
        guard case .success(let result) = SquatAnalyzer.analyzeFullSequence(fixture.poses) else {
            return XCTFail("front_squat_front: analysis failed without videoAspect")
        }
        // The un-normalized path counts the re-rack as a fourth rep.
        XCTAssertEqual(result.reps.count, 4)
    }

    // MARK: - Normalizer

    func testNormalizerMakesAnglesTrueOnPortraitVideo() {
        // A lifter leaning 45° in a 9:16 picture: the shoulder is as far forward
        // of the hip as it is above it, in true distance.
        let aspect = 9.0 / 16.0
        func keypoint(_ name: String, _ x: Double, _ y: Double) -> PoseKeypoint {
            // x is given in true units (fractions of the picture's height) and
            // stored as Vision would report it (fractions of its width).
            PoseKeypoint(name: name, position: CGPoint(x: x / aspect, y: y), confidence: 0.9)
        }
        let pose = PoseDetectionResult(keypoints: [
            keypoint("leftAnkle", 0.20, 0.10), keypoint("rightAnkle", 0.20, 0.10),
            keypoint("leftKnee", 0.20, 0.30), keypoint("rightKnee", 0.20, 0.30),
            keypoint("leftHip", 0.20, 0.50), keypoint("rightHip", 0.20, 0.50),
            keypoint("leftShoulder", 0.40, 0.70), keypoint("rightShoulder", 0.40, 0.70)
        ], frameIndex: 0)

        let normalized = PoseNormalizer.normalize([pose], aspect: aspect)
        XCTAssertEqual(normalized.count, 1)
        func position(_ name: String) -> CGPoint? { normalized[0].keypoints.first { $0.name == name }?.position }
        guard let hip = position("leftHip"), let shoulder = position("leftShoulder"),
              let knee = position("leftKnee"), let ankle = position("leftAnkle") else {
            return XCTFail("Normalized pose is missing joints")
        }
        XCTAssertEqual(Double(shoulder.x - hip.x), Double(shoulder.y - hip.y), accuracy: 1e-6, "45° lean stays 45°")
        XCTAssertEqual(Double(hypot(knee.x - ankle.x, knee.y - ankle.y)), PoseNormalizer.shinRef, accuracy: 1e-6, "Shin is the unit of length")
        XCTAssertEqual(Double(ankle.y), PoseNormalizer.anchorY, accuracy: 1e-6, "Feet sit at the anchor")
    }

    func testDisplayAspectRatioAccountsForRotation() {
        let landscape = CGSize(width: 1920, height: 1080)
        XCTAssertEqual(VideoProcessingHelpers.displayAspectRatio(naturalSize: landscape, preferredTransform: .identity) ?? 0, 16.0 / 9.0, accuracy: 1e-9)
        let quarterTurn = CGAffineTransform(a: 0, b: 1, c: -1, d: 0, tx: 1080, ty: 0)
        XCTAssertEqual(VideoProcessingHelpers.displayAspectRatio(naturalSize: landscape, preferredTransform: quarterTurn) ?? 0, 9.0 / 16.0, accuracy: 1e-9)
        XCTAssertNil(VideoProcessingHelpers.displayAspectRatio(naturalSize: .zero, preferredTransform: .identity))
    }
}
