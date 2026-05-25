import XCTest
@testable import MoveAI

@MainActor
final class RunningLabeledVideoRegressionTests: XCTestCase {
    func testExtractAllLabeledVideosToCache() async throws {
        guard RunningLabeledFixtureRunner.isLiveExtractionEnabledForCurrentRuntime() else {
            throw XCTSkip("Live extraction is disabled by default. Use external cache refresh or set MOVEAI_ENABLE_LIVE_POSE_EXTRACTION_TESTS=1.")
        }

        let fixtures = try RunningLabeledFixtureRunner.loadFixtures().filter {
            ($0.videoFile?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false)
        }

        guard !fixtures.isEmpty else {
            throw XCTSkip("No running fixtures define videoFile values for extraction yet.")
        }

        for fixture in fixtures {
            let poseData = try await RunningLabeledFixtureRunner.loadOrExtractPoseData(
                for: fixture,
                forceReextract: true
            )
            XCTAssertFalse(poseData.isEmpty, "Expected non-empty poseData for fixture \(fixture.id)")
            XCTAssertTrue(
                RunningLabeledFixtureRunner.cacheExists(for: fixture),
                "Expected cache file for fixture \(fixture.id)"
            )
        }
    }

    func testIssueExpectationsMatchFromCache() async throws {
        let fixtures = try fixturesWithAvailableCache()

        var failures: [String] = []
        for fixture in fixtures {
            let poseData = try RunningLabeledFixtureRunner.loadPoseDataFromCache(for: fixture)
            let result = try await RunningLabeledFixtureRunner.analyzeFixture(fixture, poseData: poseData)
            let issueKinds = RunningLabeledFixtureRunner.issueKindSet(from: result)

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

    func testMetricExpectationsMatchFromCache() async throws {
        let fixtures = try fixturesWithAvailableCache().filter {
            !($0.requiredMetricKinds ?? []).isEmpty
        }

        guard !fixtures.isEmpty else {
            throw XCTSkip("No fixtures define requiredMetricKinds yet")
        }

        var failures: [String] = []
        for fixture in fixtures {
            let poseData = try RunningLabeledFixtureRunner.loadPoseDataFromCache(for: fixture)
            let result = try await RunningLabeledFixtureRunner.analyzeFixture(fixture, poseData: poseData)
            let metricKinds = RunningLabeledFixtureRunner.metricKindSet(from: result)

            for required in fixture.requiredMetricKinds ?? [] where !metricKinds.contains(required) {
                failures.append(
                    "\(fixture.id): missing required metric \(required). actual=[\(metricKinds.sorted().joined(separator: ","))]"
                )
            }
        }

        XCTAssertTrue(failures.isEmpty, failures.joined(separator: "\n"))
    }

    func testIssueCountExpectationsMatchFromCache() async throws {
        let fixtures = try fixturesWithAvailableCache().filter {
            $0.expectedIssueCounts != nil
        }

        guard !fixtures.isEmpty else {
            throw XCTSkip("No fixtures define expectedIssueCounts yet")
        }

        var failures: [String] = []
        for fixture in fixtures {
            let poseData = try RunningLabeledFixtureRunner.loadPoseDataFromCache(for: fixture)
            let result = try await RunningLabeledFixtureRunner.analyzeFixture(fixture, poseData: poseData)
            let actualCounts = RunningLabeledFixtureRunner.issueCounts(from: result)

            for (expectedKind, expectedCount) in fixture.expectedIssueCounts ?? [:] {
                let actual = actualCounts[expectedKind] ?? 0
                if actual < expectedCount {
                    failures.append(
                        "\(fixture.id): expected at least \(expectedCount)x \(expectedKind), got \(actual)x. actual=[\(formatIssueCounts(actualCounts))]"
                    )
                }
            }
        }

        XCTAssertTrue(failures.isEmpty, failures.joined(separator: "\n"))
    }

    func testDumpFixtureAnalysisSummaryFromCache() async throws {
        let fixtures = try fixturesWithAvailableCache().sorted { $0.id < $1.id }

        for fixture in fixtures {
            let poseData = try RunningLabeledFixtureRunner.loadPoseDataFromCache(for: fixture)
            let result = try await RunningLabeledFixtureRunner.analyzeFixture(fixture, poseData: poseData)
            let issueCounts = RunningLabeledFixtureRunner.issueCounts(from: result)
            let metricKinds = RunningLabeledFixtureRunner.metricKindSet(from: result)

            print(
                "RUNNING_FIXTURE_SUMMARY|" +
                "id=\(fixture.id)|" +
                "issues=\(formatIssueCounts(issueCounts))|" +
                "metrics=\(metricKinds.sorted().joined(separator: ","))|" +
                "score=\(String(format: "%.1f", result.score))"
            )
        }
    }

    private func fixturesWithAvailableCache() throws -> [RunningLabeledFixtureRunner.Fixture] {
        let fixtures = try RunningLabeledFixtureRunner.loadFixtures()

        guard !fixtures.isEmpty else {
            throw XCTSkip("No running fixtures found in running_labeled_fixtures.json")
        }

        let available = fixtures.filter { RunningLabeledFixtureRunner.cacheExists(for: $0) }
        guard !available.isEmpty else {
            let missing = fixtures.map(\.id).sorted().joined(separator: ",")
            throw XCTSkip(
                "No running fixture caches found. Refresh caches externally and rerun. missing=\(missing)"
            )
        }

        let missing = fixtures
            .filter { !RunningLabeledFixtureRunner.cacheExists(for: $0) }
            .map(\.id)
            .sorted()

        if !missing.isEmpty {
            print("⚠️ Running fixtures without cache (skipped): \(missing.joined(separator: ","))")
        }

        return available
    }

    private func formatIssueCounts(_ counts: [String: Int]) -> String {
        counts.keys
            .sorted()
            .map { "\($0):\(counts[$0] ?? 0)" }
            .joined(separator: ",")
    }
}
