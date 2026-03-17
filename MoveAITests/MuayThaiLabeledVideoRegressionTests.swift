import XCTest
@testable import MoveAI

@MainActor
final class MuayThaiLabeledVideoRegressionTests: XCTestCase {
    override func tearDown() {
        unsetenv("MOVEAI_ENABLE_MUAY_THAI_ANALYZER")
        unsetenv("MOVEAI_ENABLE_MUAY_THAI_COMBO_ANALYZER")
        unsetenv("MOVEAI_MUAY_THAI_DEBUG")
        super.tearDown()
    }

    func testExtractAllLabeledVideosToCache() async throws {
        let fixtures = try MuayThaiLabeledFixtureRunner.loadFixtures()
        XCTAssertFalse(fixtures.isEmpty, "Expected at least one labeled fixture")

        for fixture in fixtures {
            let poseData = try await MuayThaiLabeledFixtureRunner.loadOrExtractPoseData(for: fixture)
            XCTAssertFalse(poseData.isEmpty, "Expected non-empty poseData for fixture \(fixture.id)")
            XCTAssertTrue(
                MuayThaiLabeledFixtureRunner.cacheExists(for: fixture),
                "Expected cache file for fixture \(fixture.id)"
            )
        }
    }

    func testAutoDetectMatchesFixtureExpectationFromCache() async throws {
        enableMuayThaiAnalyzer(debug: false)

        let fixtures = try MuayThaiLabeledFixtureRunner.loadFixtures().filter {
            $0.analysisMode == .autoDetect && $0.expectedDetectedTechnique != nil
        }

        XCTAssertFalse(fixtures.isEmpty, "Expected auto-detect fixtures in manifest")

        var mismatches: [String] = []
        for fixture in fixtures {
            let poseData = try await MuayThaiLabeledFixtureRunner.loadOrExtractPoseData(for: fixture)
            let result = try await MuayThaiLabeledFixtureRunner.analyzeFixture(fixture, poseData: poseData)
            let expected = fixture.expectedDetectedTechnique
            let actual = result.detectedTechnique

            if expected != actual {
                mismatches.append(
                    "\(fixture.id): expected \(expected?.rawValue ?? "nil"), got \(actual?.rawValue ?? "nil") (confidence=\(result.detectionConfidence.map { String(format: "%.3f", $0) } ?? "nil"))"
                )
            }
        }

        XCTAssertTrue(mismatches.isEmpty, mismatches.joined(separator: "\n"))
    }

    func testIssueExpectationsMatchFromCache() async throws {
        enableMuayThaiAnalyzer(debug: false)

        let fixtures = try MuayThaiLabeledFixtureRunner.loadFixtures().filter {
            !$0.requiredIssueKinds.isEmpty || !$0.forbiddenIssueKinds.isEmpty
        }

        XCTAssertFalse(fixtures.isEmpty, "Expected fixtures with issue expectations in manifest")

        var failures: [String] = []
        for fixture in fixtures {
            let poseData = try await MuayThaiLabeledFixtureRunner.loadOrExtractPoseData(for: fixture)
            let result = try await MuayThaiLabeledFixtureRunner.analyzeFixture(fixture, poseData: poseData)
            let issueKinds = MuayThaiLabeledFixtureRunner.issueKindSet(from: result)

            for required in fixture.requiredIssueKinds where !issueKinds.contains(required) {
                failures.append(
                    "\(fixture.id): missing required issue \(required). actual=[\(issueKinds.sorted().joined(separator: ","))]"
                )
            }

            for forbidden in fixture.forbiddenIssueKinds where issueKinds.contains(forbidden) {
                failures.append(
                    "\(fixture.id): found forbidden issue \(forbidden). actual=[\(issueKinds.sorted().joined(separator: ","))]"
                )
            }
        }

        XCTAssertTrue(failures.isEmpty, failures.joined(separator: "\n"))
    }

    func testJabLeadHandErrorFixtureDoesNotReportRearHandDrop() async throws {
        enableMuayThaiAnalyzer(debug: false)

        let fixture = try MuayThaiLabeledFixtureRunner.loadFixtures().first { $0.id == "jab_dropping_lead_hand" }
        XCTAssertNotNil(fixture, "Fixture jab_dropping_lead_hand missing from manifest")

        guard let fixture else { return }

        let poseData = try await MuayThaiLabeledFixtureRunner.loadOrExtractPoseData(for: fixture)
        let result = try await MuayThaiLabeledFixtureRunner.analyzeFixture(fixture, poseData: poseData)
        let issueKinds = MuayThaiLabeledFixtureRunner.issueKindSet(from: result)

        XCTAssertFalse(issueKinds.contains(MovementIssueKind.muayThaiJabRearHandDropping.rawValue))
    }

    private func enableMuayThaiAnalyzer(debug: Bool) {
        setenv("MOVEAI_ENABLE_MUAY_THAI_ANALYZER", "1", 1)
        setenv("MOVEAI_ENABLE_MUAY_THAI_COMBO_ANALYZER", "1", 1)

        if debug || ProcessInfo.processInfo.environment["MOVEAI_MUAY_THAI_DEBUG"] == "1" {
            setenv("MOVEAI_MUAY_THAI_DEBUG", "1", 1)
        } else {
            unsetenv("MOVEAI_MUAY_THAI_DEBUG")
        }
    }
}
