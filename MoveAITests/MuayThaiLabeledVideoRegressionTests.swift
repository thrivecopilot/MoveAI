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
        guard MuayThaiLabeledFixtureRunner.isLiveExtractionEnabledForCurrentRuntime() else {
            throw XCTSkip("Live extraction is disabled by default. Use external cache refresh or set MOVEAI_ENABLE_LIVE_POSE_EXTRACTION_TESTS=1.")
        }

        let fixtures = try MuayThaiLabeledFixtureRunner.loadFixtures()
        XCTAssertFalse(fixtures.isEmpty, "Expected at least one labeled fixture")

        for fixture in fixtures {
            let poseData = try await MuayThaiLabeledFixtureRunner.loadOrExtractPoseData(
                for: fixture,
                forceReextract: true
            )
            let coverage = MuayThaiLabeledFixtureRunner.poseCoverageMetrics(from: poseData)
            XCTAssertFalse(poseData.isEmpty, "Expected non-empty poseData for fixture \(fixture.id)")
            XCTAssertTrue(
                MuayThaiLabeledFixtureRunner.meetsCoverageGate(coverage),
                "Expected usable pose coverage for fixture \(fixture.id): nonEmpty=\(coverage.nonEmptyFrames)/\(coverage.totalFrames), ratio=\(String(format: "%.3f", coverage.nonEmptyFrameRatio)), avgKeypoints=\(String(format: "%.2f", coverage.averageKeypointsPerNonEmptyFrame))"
            )
            XCTAssertTrue(
                MuayThaiLabeledFixtureRunner.cacheExists(for: fixture),
                "Expected cache file for fixture \(fixture.id)"
            )
            XCTAssertTrue(
                MuayThaiLabeledFixtureRunner.cacheProvenanceExists(for: fixture),
                "Expected cache provenance metadata for fixture \(fixture.id)"
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

    func testStrikeAndIssueCountExpectationsMatchFromCache() async throws {
        enableMuayThaiAnalyzer(debug: false)
        let enforceStrictStrikeCounts = ProcessInfo.processInfo.environment["MOVEAI_STRICT_STRIKE_COUNTS"] == "1"
        let logIssueMetrics = ProcessInfo.processInfo.environment["MOVEAI_LOG_ISSUE_METRICS"] == "1"

        let fixtures = try MuayThaiLabeledFixtureRunner.loadFixtures()
        let fixturesWithExpectations = fixtures.filter {
            $0.expectedStrikeCount != nil || $0.expectedIssueCounts != nil
        }

        guard !fixturesWithExpectations.isEmpty else {
            throw XCTSkip("No fixtures define expectedStrikeCount/expectedIssueCounts yet")
        }

        var failures: [String] = []
        for fixture in fixtures {
            let poseData = try await MuayThaiLabeledFixtureRunner.loadOrExtractPoseData(for: fixture)
            let result = try await MuayThaiLabeledFixtureRunner.analyzeFixture(fixture, poseData: poseData)
            let detectedTechnique = result.detectedTechnique?.rawValue ?? fixture.selectedTechnique?.rawValue ?? "nil"
            let strikeCount = result.analysisSummary?.totalUnits ?? -1
            let allIssueKinds = result.feedback.compactMap { $0.issueKind?.rawValue }
            let allIssueCounts = Dictionary(allIssueKinds.map { ($0, 1) }, uniquingKeysWith: +)

            if logIssueMetrics {
                for feedback in result.feedback {
                    let kind = feedback.issueKind?.rawValue ?? "nil"
                    let metrics = (feedback.metrics ?? [])
                        .map { "\($0.kind.rawValue):\(String(format: "%.3f", $0.value))" }
                        .joined(separator: ",")
                    print(
                        "ISSUE_METRIC|" +
                        "id=\(fixture.id)|" +
                        "issue=\(kind)|" +
                        "ts=\(String(format: "%.3f", feedback.timestamp))|" +
                        "metrics=\(metrics)"
                    )
                }
            }

            print(
                "ANALYZE_FIXTURE|" +
                "id=\(fixture.id)|" +
                "detected=\(detectedTechnique)|" +
                "strikes=\(strikeCount)|" +
                "issues=\(formatIssueCounts(allIssueCounts))"
            )

            guard fixture.expectedStrikeCount != nil || fixture.expectedIssueCounts != nil else {
                continue
            }

            if enforceStrictStrikeCounts, let expectedStrikeCount = fixture.expectedStrikeCount {
                let actualStrikeCount = strikeCount
                if actualStrikeCount != expectedStrikeCount {
                    failures.append(
                        "\(fixture.id): expected strikes=\(expectedStrikeCount), got \(actualStrikeCount)"
                    )
                }
            }

            if let expectedIssueCounts = fixture.expectedIssueCounts {
                let actionableIssueKinds = result.feedback
                    .compactMap { $0.issueKind?.rawValue }
                    .filter {
                        $0 != MovementIssueKind.muayThaiAnalysisCoverageLimited.rawValue &&
                        $0 != MovementIssueKind.muayThaiCaptureQualityLimited.rawValue
                    }
                let actualIssueCounts = Dictionary(actionableIssueKinds.map { ($0, 1) }, uniquingKeysWith: +)

                for (expectedKind, expectedCount) in expectedIssueCounts {
                    let actualCount = actualIssueCounts[expectedKind] ?? 0
                    if actualCount < expectedCount {
                        failures.append(
                            "\(fixture.id): expected at least \(expectedCount)x \(expectedKind), got \(actualCount)x. actual=[\(formatIssueCounts(actualIssueCounts))]"
                        )
                    }
                }
            }
        }

        XCTAssertTrue(failures.isEmpty, failures.joined(separator: "\n"))
    }

    func testJabLeadHandErrorFixtureReportsRearHandDropKey() async throws {
        enableMuayThaiAnalyzer(debug: false)

        let fixture = try MuayThaiLabeledFixtureRunner.loadFixtures().first { $0.id == "jab_dropping_lead_hand" }
        XCTAssertNotNil(fixture, "Fixture jab_dropping_lead_hand missing from manifest")

        guard let fixture else { return }

        let poseData = try await MuayThaiLabeledFixtureRunner.loadOrExtractPoseData(for: fixture)
        let result = try await MuayThaiLabeledFixtureRunner.analyzeFixture(fixture, poseData: poseData)
        let issueKinds = MuayThaiLabeledFixtureRunner.issueKindSet(from: result)

        XCTAssertTrue(issueKinds.contains(MovementIssueKind.muayThaiJabRearHandDropping.rawValue))
    }

    func testDebugJabOnlyAutoDetectUnderParityCache() async throws {
        let fixture = try MuayThaiLabeledFixtureRunner.loadFixtures().first { $0.id == "jab_only" }
        XCTAssertNotNil(fixture, "Fixture jab_only missing from manifest")
        guard let fixture else { return }

        let poseData = try await MuayThaiLabeledFixtureRunner.loadOrExtractPoseData(for: fixture)
        print("JAB_ONLY_DEBUG|pose_count=\(poseData.count)")

        let stanceHypotheses: [(label: String, stance: FightStance?)] = [
            ("fixture", fixture.selectedFightStance),
            ("nil", nil),
            ("orthodox", .orthodox),
            ("southpaw", .southpaw),
        ]

        for hypothesis in stanceHypotheses {
            let stance = FightStanceResolver.resolve(preferred: hypothesis.stance, from: poseData)
            print("JAB_ONLY_DEBUG|hypothesis=\(hypothesis.label)|resolved_stance=\(stance.stance.rawValue)|source=\(String(describing: stance.source))|confidence=\(String(format: "%.3f", stance.confidence))")

            if let combo = MuayThaiComboDetector.detect(poses: poseData, preferredStance: hypothesis.stance) {
                let techniques = combo.attempts.map(\.technique.rawValue).joined(separator: ",")
                print("JAB_ONLY_DEBUG|hypothesis=\(hypothesis.label)|combo_attempts=\(combo.attempts.count)|techniques=\(techniques)|dominant=\(combo.dominantTechnique?.rawValue ?? "nil")|dominant_share=\(combo.dominantTechniqueShare.map { String(format: "%.3f", $0) } ?? "nil")")
            } else {
                print("JAB_ONLY_DEBUG|hypothesis=\(hypothesis.label)|combo=nil")
            }

            if let single = MuayThaiTechniqueDetector.detect(poses: poseData, preferredStance: hypothesis.stance) {
                print("JAB_ONLY_DEBUG|hypothesis=\(hypothesis.label)|single=\(single.technique.rawValue)|confidence=\(String(format: "%.3f", single.confidence))|attempts=\(single.attemptsCount)")
            } else {
                print("JAB_ONLY_DEBUG|hypothesis=\(hypothesis.label)|single=nil")
            }

            if let bestEffort = MuayThaiTechniqueDetector.detectBestEffort(poses: poseData, preferredStance: hypothesis.stance) {
                print("JAB_ONLY_DEBUG|hypothesis=\(hypothesis.label)|best_effort=\(bestEffort.technique.rawValue)|confidence=\(String(format: "%.3f", bestEffort.confidence))|attempts=\(bestEffort.attemptsCount)")
            } else {
                print("JAB_ONLY_DEBUG|hypothesis=\(hypothesis.label)|best_effort=nil")
            }
        }
    }

    func testJabArcherFixtureUsesSpecializedRearHandDropMessage() async throws {
        enableMuayThaiAnalyzer(debug: false)

        let fixture = try MuayThaiLabeledFixtureRunner.loadFixtures().first { $0.id == "jab_archer_error" }
        XCTAssertNotNil(fixture, "Fixture jab_archer_error missing from manifest")
        guard let fixture else { return }

        let poseData = try await MuayThaiLabeledFixtureRunner.loadOrExtractPoseData(for: fixture)
        let result = try await MuayThaiLabeledFixtureRunner.analyzeFixture(fixture, poseData: poseData)
        let rearHandMessages = result.feedback
            .filter { $0.issueKind == .muayThaiJabRearHandDropping }
            .map { $0.message.lowercased() }

        XCTAssertFalse(rearHandMessages.isEmpty, "Expected rear-hand-drop feedback for jab_archer_error")
        XCTAssertTrue(
            rearHandMessages.contains { $0.contains("drawing a bow") },
            "Expected archer-specific rear-hand-drop cue. messages=[\(rearHandMessages.joined(separator: " | "))]"
        )
    }

    func testDumpFixtureAnalysisSummaryFromCache() async throws {
        enableMuayThaiAnalyzer(debug: false)

        let fixtures = try MuayThaiLabeledFixtureRunner.loadFixtures().sorted { $0.id < $1.id }
        XCTAssertFalse(fixtures.isEmpty, "Expected fixtures in manifest")

        for fixture in fixtures {
            let poseData = try await MuayThaiLabeledFixtureRunner.loadOrExtractPoseData(for: fixture)
            let result = try await MuayThaiLabeledFixtureRunner.analyzeFixture(fixture, poseData: poseData)
            let issueKinds = result.feedback.compactMap { $0.issueKind?.rawValue }
            let issueCounts = Dictionary(issueKinds.map { ($0, 1) }, uniquingKeysWith: +)
            let issueSummary = issueCounts
                .keys
                .sorted()
                .map { "\($0):\(issueCounts[$0] ?? 0)" }
                .joined(separator: ",")

            let analysisUnitKind = result.analysisSummary?.unitKind.rawValue ?? "nil"
            let strikeCount = result.analysisSummary?.totalUnits ?? -1
            let warningEvents = result.analysisSummary?.warningEvents ?? -1

            print(
                "FIXTURE_SUMMARY|" +
                "id=\(fixture.id)|" +
                "video=\(fixture.videoFile)|" +
                "mode=\(fixture.analysisMode.rawValue)|" +
                "detected=\(result.detectedTechnique?.rawValue ?? fixture.selectedTechnique?.rawValue ?? "nil")|" +
                "confidence=\(result.detectionConfidence.map { String(format: "%.3f", $0) } ?? "nil")|" +
                "unit=\(analysisUnitKind)|" +
                "strikes=\(strikeCount)|" +
                "warning_events=\(warningEvents)|" +
                "issues=\(issueSummary)|" +
                "expected_strikes=\(fixture.expectedStrikeCount.map(String.init) ?? "nil")|" +
                "expected_issue_counts=\(fixture.expectedIssueCounts.map(formatIssueCounts) ?? "nil")|" +
                "required=\(fixture.requiredIssueKinds.sorted().joined(separator: ","))|" +
                "forbidden=\(fixture.forbiddenIssueKinds.sorted().joined(separator: ","))"
            )
        }
    }

    private func formatIssueCounts(_ counts: [String: Int]) -> String {
        counts.keys
            .sorted()
            .map { "\($0):\(counts[$0] ?? 0)" }
            .joined(separator: ",")
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
