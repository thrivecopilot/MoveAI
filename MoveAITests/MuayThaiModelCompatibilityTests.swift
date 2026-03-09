import XCTest
@testable import MoveAI

final class MuayThaiModelCompatibilityTests: XCTestCase {
    func testMovementRecordingRoundTripWithTechniqueAndStance() throws {
        let recording = MovementRecording(
            movementType: .muayThai,
            technique: .cross,
            fightStance: .southpaw,
            videoURL: URL(fileURLWithPath: "/tmp/test.mov"),
            duration: 4.2,
            poseData: []
        )

        let data = try JSONEncoder().encode(recording)
        let decoded = try JSONDecoder().decode(MovementRecording.self, from: data)

        XCTAssertEqual(decoded.movementType, .muayThai)
        XCTAssertEqual(decoded.technique, .cross)
        XCTAssertEqual(decoded.fightStance, .southpaw)
    }

    func testSessionRoundTripWithTechniqueAndStance() throws {
        let session = Session(
            movementType: .muayThai,
            technique: .jab,
            fightStance: .orthodox,
            videoURL: URL(fileURLWithPath: "/tmp/test.mov"),
            timestamp: Date(timeIntervalSince1970: 1234),
            analysisResult: nil,
            poseData: [],
            notes: "test",
            isRecordedLive: false
        )

        let data = try JSONEncoder().encode(session)
        let decoded = try JSONDecoder().decode(Session.self, from: data)

        XCTAssertEqual(decoded.movementType, .muayThai)
        XCTAssertEqual(decoded.technique, .jab)
        XCTAssertEqual(decoded.fightStance, .orthodox)
    }

    func testMovementRecordingBackwardDecodeWithoutTechniqueFields() throws {
        let json = """
        {
          "id": "2FD19126-BE9D-45A9-9019-65B3B8E2D5A5",
          "movementType": "squat",
          "videoURL": "file:///tmp/test.mov",
          "timestamp": 0,
          "duration": 3.5,
          "poseData": null,
          "analysisResult": null
        }
        """

        let decoded = try JSONDecoder().decode(MovementRecording.self, from: Data(json.utf8))
        XCTAssertEqual(decoded.movementType, .squat)
        XCTAssertNil(decoded.technique)
        XCTAssertNil(decoded.fightStance)
    }

    func testSessionBackwardDecodeWithoutTechniqueFields() throws {
        let json = """
        {
          "id": "2FD19126-BE9D-45A9-9019-65B3B8E2D5A5",
          "movementType": "squat",
          "videoURL": "file:///tmp/test.mov",
          "timestamp": 0,
          "analysisResult": null,
          "poseData": null,
          "notes": null,
          "isRecordedLive": false
        }
        """

        let decoded = try JSONDecoder().decode(Session.self, from: Data(json.utf8))
        XCTAssertEqual(decoded.movementType, .squat)
        XCTAssertNil(decoded.technique)
        XCTAssertNil(decoded.fightStance)
    }
}
