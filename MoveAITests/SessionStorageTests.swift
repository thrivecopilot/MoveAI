//
//  SessionStorageTests.swift
//  MoveAITests
//
//  Video storage lifecycle: sessions persist portable video file names (not
//  absolute container paths), imported videos move out of tmp, and deleting a
//  session reclaims its video file.
//

import XCTest
@testable import MoveAI

@MainActor
final class SessionStorageTests: XCTestCase {

    private var documents: URL!
    private var sessionsDirectory: URL!
    private var createdFiles: [URL] = []

    override func setUp() async throws {
        documents = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        sessionsDirectory = documents.appendingPathComponent("Sessions", isDirectory: true)
        try? FileManager.default.removeItem(at: sessionsDirectory)
        // Skip the one-time UserDefaults migration inside SessionManager.init.
        UserDefaults.standard.set(true, forKey: "sessions_migrated_to_files")
    }

    override func tearDown() async throws {
        try? FileManager.default.removeItem(at: sessionsDirectory)
        for url in createdFiles {
            try? FileManager.default.removeItem(at: url)
        }
        createdFiles = []
    }

    // MARK: - Helpers

    private func makeVideoFile(named name: String, in directory: URL? = nil) throws -> URL {
        let url = (directory ?? documents).appendingPathComponent(name)
        try Data("fake video".utf8).write(to: url)
        createdFiles.append(url)
        return url
    }

    private func makeSession(videoURL: URL) -> Session {
        Session(movementType: .squat, videoURL: videoURL)
    }

    private func encodeToJSON(_ session: Session) throws -> String {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        return String(data: try encoder.encode(session), encoding: .utf8)!
    }

    private func decodeSession(fromJSON json: String) throws -> Session {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try decoder.decode(Session.self, from: Data(json.utf8))
    }

    // MARK: - Codable portability

    func testOwnedVideoEncodesFileNameNotAbsolutePath() throws {
        let videoURL = try makeVideoFile(named: "squat_test_encode.mov")
        let json = try encodeToJSON(makeSession(videoURL: videoURL))

        XCTAssertTrue(json.contains("\"videoFileName\""), "Owned videos must persist as a file name")
        XCTAssertTrue(json.contains("squat_test_encode.mov"))
        XCTAssertFalse(
            json.contains(documents.path),
            "Session JSON must not contain the absolute container path (it changes across app updates)"
        )
    }

    func testFileNameDecodesAgainstCurrentContainer() throws {
        let videoURL = try makeVideoFile(named: "squat_test_decode.mov")
        let json = try encodeToJSON(makeSession(videoURL: videoURL))

        let decoded = try decodeSession(fromJSON: json)
        XCTAssertEqual(decoded.videoURL.standardizedFileURL, videoURL.standardizedFileURL)
    }

    func testLegacyAbsoluteURLFromStaleContainerResolvesToDocuments() throws {
        // Older builds persisted absolute URLs; after an app update the container
        // UUID differs, so the stored path is dead but the file name survives.
        let videoURL = try makeVideoFile(named: "legacy_squat.mov")
        let staleURL = "file:///var/mobile/Containers/Data/Application/DEAD-BEEF/Documents/legacy_squat.mov"
        let json = """
        {"id":"11111111-2222-3333-4444-555555555555","movementType":"squat",\
        "timestamp":"2026-01-01T00:00:00Z","isRecordedLive":true,"videoURL":"\(staleURL)"}
        """

        let decoded = try decodeSession(fromJSON: json)
        XCTAssertEqual(decoded.videoURL.standardizedFileURL, videoURL.standardizedFileURL)
    }

    func testLegacyAbsoluteURLKeptWhenFileStillExists() throws {
        let liveURL = try makeVideoFile(named: "still_alive.mov", in: FileManager.default.temporaryDirectory)
        let json = """
        {"id":"11111111-2222-3333-4444-555555555555","movementType":"squat",\
        "timestamp":"2026-01-01T00:00:00Z","isRecordedLive":false,"videoURL":"\(liveURL.absoluteString)"}
        """

        let decoded = try decodeSession(fromJSON: json)
        XCTAssertEqual(decoded.videoURL.standardizedFileURL, liveURL.standardizedFileURL)
    }

    func testNonOwnedVideoURLRoundTrips() throws {
        // Bundle fixtures / preview URLs are not in Documents and must survive as-is.
        let bundleish = URL(fileURLWithPath: "/dev/null")
        let json = try encodeToJSON(makeSession(videoURL: bundleish))
        XCTAssertTrue(json.contains("\"videoURL\""))

        let decoded = try decodeSession(fromJSON: json)
        XCTAssertEqual(decoded.videoURL.standardizedFileURL, bundleish.standardizedFileURL)
    }

    // MARK: - Import out of tmp

    func testImportMovesVideoOutOfTemporaryDirectory() throws {
        let tempURL = try makeVideoFile(named: "incoming.mov", in: FileManager.default.temporaryDirectory)

        let permanentURL = try VideoStorage.importToPermanentStorage(tempURL)
        createdFiles.append(permanentURL)

        XCTAssertTrue(VideoStorage.isOwned(permanentURL), "Imported video must land in Documents")
        XCTAssertTrue(FileManager.default.fileExists(atPath: permanentURL.path))
        XCTAssertFalse(
            FileManager.default.fileExists(atPath: tempURL.path),
            "Original must be moved (tmp is purgeable)"
        )
        XCTAssertEqual(permanentURL.pathExtension, "mov")
    }

    // MARK: - Deletion reclaims the video

    func testDeleteSessionRemovesOwnedVideo() throws {
        let videoURL = try makeVideoFile(named: "to_delete.mov")
        let manager = SessionManager()
        let session = makeSession(videoURL: videoURL)
        manager.addSession(session)

        manager.deleteSession(session)

        XCTAssertFalse(FileManager.default.fileExists(atPath: videoURL.path))
    }

    func testDeleteSessionKeepsVideoSharedWithAnotherSession() throws {
        let videoURL = try makeVideoFile(named: "shared.mov")
        let manager = SessionManager()
        let first = makeSession(videoURL: videoURL)
        let second = makeSession(videoURL: videoURL)
        manager.addSession(first)
        manager.addSession(second)

        manager.deleteSession(first)

        XCTAssertTrue(
            FileManager.default.fileExists(atPath: videoURL.path),
            "Video still referenced by another session must not be deleted"
        )
    }

    func testDeleteSessionNeverTouchesNonOwnedFiles() throws {
        let outsideURL = try makeVideoFile(named: "outside.mov", in: FileManager.default.temporaryDirectory)
        let manager = SessionManager()
        let session = makeSession(videoURL: outsideURL)
        manager.addSession(session)

        manager.deleteSession(session)

        XCTAssertTrue(
            FileManager.default.fileExists(atPath: outsideURL.path),
            "Files outside the videos directory are not owned and must not be deleted"
        )
    }

    // MARK: - Pose data sidecars

    private func makePoseData(frames: Int = 3) -> [PoseDetectionResult] {
        (0..<frames).map { index in
            PoseDetectionResult(
                keypoints: [
                    PoseKeypoint(name: "leftHip", position: CGPoint(x: 0.4, y: 0.5), confidence: 0.9),
                    PoseKeypoint(name: "rightHip", position: CGPoint(x: 0.6, y: 0.5), confidence: 0.9),
                ],
                frameIndex: index
            )
        }
    }

    private func sessionsDir() -> URL { sessionsDirectory }

    func testPoseDataSavedToSidecarNotSessionFile() throws {
        let videoURL = try makeVideoFile(named: "sidecar.mov")
        let manager = SessionManager()
        let session = Session(movementType: .squat, videoURL: videoURL, poseData: makePoseData())
        manager.addSession(session)

        let sessionFile = sessionsDir().appendingPathComponent("\(session.id.uuidString).json")
        let poseFile = sessionsDir().appendingPathComponent("Poses/\(session.id.uuidString).json")
        let sessionJSON = String(data: try Data(contentsOf: sessionFile), encoding: .utf8)!

        XCTAssertFalse(sessionJSON.contains("poseData"), "Session file must not embed pose data")
        XCTAssertTrue(FileManager.default.fileExists(atPath: poseFile.path), "Pose sidecar must exist")
    }

    func testReloadedSessionHydratesPoseDataOnDemand() throws {
        let videoURL = try makeVideoFile(named: "hydrate.mov")
        let manager = SessionManager()
        let session = Session(movementType: .squat, videoURL: videoURL, poseData: makePoseData(frames: 5))
        manager.addSession(session)

        let reloaded = SessionManager()
        let loaded = try XCTUnwrap(reloaded.sessions.first { $0.id == session.id })
        XCTAssertNil(loaded.poseData, "Sessions must load without pose data at launch")

        let hydrated = reloaded.hydratedSession(loaded)
        XCTAssertEqual(hydrated.poseData?.count, 5, "Hydration must restore the sidecar pose data")
    }

    func testLegacyInlinePoseDataIsSplitOnLoad() throws {
        let videoURL = try makeVideoFile(named: "legacy_inline.mov")
        let session = Session(movementType: .squat, videoURL: videoURL, poseData: makePoseData(frames: 4))

        // Write a legacy-format file: pose data inline in the session JSON.
        try FileManager.default.createDirectory(at: sessionsDir(), withIntermediateDirectories: true)
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        var legacy = try JSONSerialization.jsonObject(
            with: encoder.encode(session), options: []
        ) as! [String: Any]
        let poseJSON = try JSONSerialization.jsonObject(
            with: encoder.encode(session.poseData!), options: []
        )
        legacy["poseData"] = poseJSON
        let legacyData = try JSONSerialization.data(withJSONObject: legacy)
        let sessionFile = sessionsDir().appendingPathComponent("\(session.id.uuidString).json")
        try legacyData.write(to: sessionFile)

        let manager = SessionManager()
        let loaded = try XCTUnwrap(manager.sessions.first { $0.id == session.id })
        XCTAssertNil(loaded.poseData, "Inline pose data must be stripped from memory")

        let poseFile = sessionsDir().appendingPathComponent("Poses/\(session.id.uuidString).json")
        XCTAssertTrue(FileManager.default.fileExists(atPath: poseFile.path), "Migration must write the sidecar")
        let rewritten = String(data: try Data(contentsOf: sessionFile), encoding: .utf8)!
        XCTAssertFalse(rewritten.contains("poseData"), "Migration must rewrite the session file without poses")
        XCTAssertEqual(manager.hydratedSession(loaded).poseData?.count, 4)
    }

    func testUpdateWithoutPoseDataPreservesSidecar() throws {
        let videoURL = try makeVideoFile(named: "preserve.mov")
        let manager = SessionManager()
        let session = Session(movementType: .squat, videoURL: videoURL, poseData: makePoseData(frames: 2))
        manager.addSession(session)

        // Views construct updates from non-hydrated copies (poseData == nil).
        let update = Session(
            id: session.id,
            movementType: session.movementType,
            videoURL: session.videoURL,
            timestamp: session.timestamp,
            poseData: nil,
            notes: "new note"
        )
        manager.updateSession(update)

        let reloaded = SessionManager()
        let loaded = try XCTUnwrap(reloaded.sessions.first { $0.id == session.id })
        XCTAssertEqual(loaded.notes, "new note")
        XCTAssertEqual(
            reloaded.hydratedSession(loaded).poseData?.count, 2,
            "An update without pose data must not destroy the sidecar"
        )
    }

    func testDeleteSessionRemovesPoseSidecar() throws {
        let videoURL = try makeVideoFile(named: "sidecar_delete.mov")
        let manager = SessionManager()
        let session = Session(movementType: .squat, videoURL: videoURL, poseData: makePoseData())
        manager.addSession(session)
        let poseFile = sessionsDir().appendingPathComponent("Poses/\(session.id.uuidString).json")
        XCTAssertTrue(FileManager.default.fileExists(atPath: poseFile.path))

        manager.deleteSession(session)
        XCTAssertFalse(FileManager.default.fileExists(atPath: poseFile.path))
    }

    // MARK: - End-to-end persistence

    func testSessionSurvivesReloadWithResolvedVideoURL() throws {
        let videoURL = try makeVideoFile(named: "round_trip.mov")
        let manager = SessionManager()
        let session = makeSession(videoURL: videoURL)
        manager.addSession(session)

        let reloaded = SessionManager()
        let loaded = reloaded.sessions.first { $0.id == session.id }
        XCTAssertNotNil(loaded)
        XCTAssertEqual(loaded?.videoURL.standardizedFileURL, videoURL.standardizedFileURL)
    }
}
