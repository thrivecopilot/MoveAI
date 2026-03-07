import XCTest
@testable import MoveAI

final class TrendsInsightsEngineTests: XCTestCase {
    private let baseDate = Date(timeIntervalSince1970: 1_735_689_600)

    func testBuildSnapshot_usesOnlyLastFiveAnalyzedSquatSessions() {
        let sessions: [Session] = [
            makeSession(daysAgo: 1, score: 91, feedback: [feedback(.squatHeelsLift)]),
            makeSession(daysAgo: 2, score: 88, feedback: [feedback(.squatHeelsLift)]),
            makeSession(daysAgo: 3, score: 85, feedback: [feedback(.squatHeelsLift)]),
            makeSession(daysAgo: 4, score: 82, feedback: [feedback(.squatHeelsLift)]),
            makeSession(daysAgo: 5, score: 79, feedback: [feedback(.squatHeelsLift)]),
            makeSession(daysAgo: 6, score: 76, feedback: [feedback(.squatHeelsLift)]),
            makeSession(daysAgo: 0, movement: .deadlift, score: 99, feedback: [feedback(.squatHeelsLift)]),
            makeSession(daysAgo: 7, score: 70, feedback: nil)
        ]

        let snapshot = TrendsInsightsEngine.buildSnapshot(sessions: sessions)

        XCTAssertEqual(snapshot.analyzedSessionCount, 6)
        XCTAssertEqual(snapshot.scoreTrend.count, 5)
        XCTAssertEqual(snapshot.scoreTrend.first?.score ?? -1, 79, accuracy: 0.001)
        XCTAssertEqual(snapshot.scoreTrend.last?.score ?? -1, 91, accuracy: 0.001)
    }

    func testBuildSnapshot_primaryFixUsesHighestWeightedIssue() {
        let sessions: [Session] = [
            makeSession(daysAgo: 1, score: 70, feedback: [feedback(.squatHeelsLift, severity: .critical)]),
            makeSession(daysAgo: 2, score: 71, feedback: [feedback(.squatHeelsLift)]),
            makeSession(daysAgo: 3, score: 72, feedback: [feedback(.squatKneeValgus)]),
            makeSession(daysAgo: 4, score: 73, feedback: [feedback(.squatKneeValgus)]),
            makeSession(daysAgo: 5, score: 74, feedback: [])
        ]

        let snapshot = TrendsInsightsEngine.buildSnapshot(sessions: sessions)

        XCTAssertEqual(snapshot.primaryFix?.issueKind, .squatHeelsLift)
        XCTAssertEqual(snapshot.troubleAreas.first?.issueKind, .squatHeelsLift)
    }

    func testBuildSnapshot_qualitySummaryPenalizesMappedDimensions() {
        let sessions: [Session] = [
            makeSession(daysAgo: 1, score: 66, feedback: [
                feedback(.squatDepthTooShallow, severity: .critical),
                feedback(.squatHeelsLift),
            ]),
            makeSession(daysAgo: 2, score: 68, feedback: [
                feedback(.squatDepthTooShallow),
                feedback(.squatIncompleteROM),
            ]),
            makeSession(daysAgo: 3, score: 70, feedback: [feedback(.squatForwardLean)]),
            makeSession(daysAgo: 4, score: 71, feedback: []),
            makeSession(daysAgo: 5, score: 72, feedback: [])
        ]

        let snapshot = TrendsInsightsEngine.buildSnapshot(sessions: sessions)

        let depthScore = snapshot.qualitySummary.first(where: { $0.dimension == .depth })
        let torsoScore = snapshot.qualitySummary.first(where: { $0.dimension == .torsoControl })

        XCTAssertNotNil(depthScore)
        XCTAssertNotNil(torsoScore)
        XCTAssertLessThan(depthScore?.score ?? 100, torsoScore?.score ?? 100)
        XCTAssertTrue(snapshot.qualitySummary.allSatisfy { (40...100).contains($0.score) })
    }

    func testBuildSnapshot_troubleAreaOrderingDeterministicOnTie() {
        let sessions: [Session] = [
            makeSession(daysAgo: 1, score: 70, feedback: [feedback(.squatHeelsLift), feedback(.squatKneeValgus)]),
            makeSession(daysAgo: 2, score: 71, feedback: []),
            makeSession(daysAgo: 3, score: 72, feedback: []),
            makeSession(daysAgo: 4, score: 73, feedback: []),
            makeSession(daysAgo: 5, score: 74, feedback: [])
        ]

        let snapshot = TrendsInsightsEngine.buildSnapshot(sessions: sessions)
        let orderedKinds = snapshot.troubleAreas.map(\.issueKind.rawValue)

        XCTAssertEqual(orderedKinds, [
            MovementIssueKind.squatHeelsLift.rawValue,
            MovementIssueKind.squatKneeValgus.rawValue,
        ])
    }

    func testBuildSnapshot_quickRoutineUsesTopIssueDrills() {
        let sessions: [Session] = [
            makeSession(daysAgo: 1, score: 62, feedback: [feedback(.squatHeelsLift, severity: .critical)]),
            makeSession(daysAgo: 2, score: 64, feedback: [feedback(.squatHeelsLift)]),
            makeSession(daysAgo: 3, score: 66, feedback: [feedback(.squatDepthTooShallow)]),
            makeSession(daysAgo: 4, score: 69, feedback: []),
            makeSession(daysAgo: 5, score: 71, feedback: [])
        ]

        let snapshot = TrendsInsightsEngine.buildSnapshot(sessions: sessions)

        XCTAssertNotNil(snapshot.quickRoutine)
        XCTAssertLessThanOrEqual(snapshot.quickRoutine?.drills.count ?? 0, 3)
        XCTAssertTrue(snapshot.quickRoutine?.drills.contains(where: { $0.localizedCaseInsensitiveContains("dorsiflexion") }) ?? false)
        XCTAssertTrue(snapshot.quickRoutine?.frequencyRecommendation.localizedCaseInsensitiveContains("week") ?? false)
    }

    func testBuildSnapshot_expertDiscoveryFiltersToPrimaryIssue() {
        let sessions: [Session] = [
            makeSession(daysAgo: 1, score: 61, feedback: [feedback(.squatBraceLeak, severity: .critical)]),
            makeSession(daysAgo: 2, score: 63, feedback: [feedback(.squatForwardLean)]),
            makeSession(daysAgo: 3, score: 65, feedback: [feedback(.squatBraceLeak)]),
            makeSession(daysAgo: 4, score: 67, feedback: []),
            makeSession(daysAgo: 5, score: 69, feedback: [])
        ]

        let snapshot = TrendsInsightsEngine.buildSnapshot(sessions: sessions)

        XCTAssertFalse(snapshot.expertDiscovery.isEmpty)
        XCTAssertTrue(
            snapshot.expertDiscovery.contains(where: {
                $0.issueAssociation.localizedCaseInsensitiveContains("torso") ||
                $0.creator.localizedCaseInsensitiveContains("Torokhtiy")
            })
        )
    }

    func testBuildSnapshot_smallWinsFallbackAvoidsDiscouragingCopy() {
        let sessions: [Session] = [
            makeSession(daysAgo: 1, score: 60, feedback: [feedback(.squatKneeValgus, severity: .critical), feedback(.squatHeelsLift)]),
            makeSession(daysAgo: 2, score: 61, feedback: [feedback(.squatKneeValgus, severity: .critical), feedback(.squatHeelsLift)]),
            makeSession(daysAgo: 3, score: 62, feedback: [feedback(.squatKneeValgus), feedback(.squatHeelsLift)]),
            makeSession(daysAgo: 4, score: 63, feedback: [feedback(.squatKneeValgus)]),
            makeSession(daysAgo: 5, score: 64, feedback: [feedback(.squatHeelsLift)])
        ]

        let snapshot = TrendsInsightsEngine.buildSnapshot(sessions: sessions)

        XCTAssertFalse(snapshot.smallWins.isEmpty)
        XCTAssertFalse(snapshot.smallWins.contains(where: { $0.text.localizedCaseInsensitiveContains("No clear improvements yet") }))
    }

    func testBuildSnapshot_lowAndFullDataStateExposeCoachModels() {
        let lowDataSessions: [Session] = [
            makeSession(daysAgo: 1, score: 70, feedback: [feedback(.squatHeelsLift)]),
            makeSession(daysAgo: 2, score: 71, feedback: [feedback(.squatKneeValgus)]),
        ]
        let lowSnapshot = TrendsInsightsEngine.buildSnapshot(sessions: lowDataSessions)

        XCTAssertNotNil(lowSnapshot.lowDataHint)
        XCTAssertNotNil(lowSnapshot.primaryFix)

        let fullDataSessions: [Session] = [
            makeSession(daysAgo: 1, score: 65, feedback: [feedback(.squatHeelsLift)]),
            makeSession(daysAgo: 2, score: 66, feedback: [feedback(.squatDepthTooShallow)]),
            makeSession(daysAgo: 3, score: 67, feedback: [feedback(.squatHeelsLift)]),
            makeSession(daysAgo: 4, score: 68, feedback: [feedback(.squatKneeValgus)]),
            makeSession(daysAgo: 5, score: 69, feedback: [feedback(.squatHeelsLift)]),
        ]
        let fullSnapshot = TrendsInsightsEngine.buildSnapshot(sessions: fullDataSessions)

        XCTAssertNil(fullSnapshot.lowDataHint)
        XCTAssertNotNil(fullSnapshot.primaryFix)
        XCTAssertNotNil(fullSnapshot.todayCue)
        XCTAssertNotNil(fullSnapshot.quickRoutine)
    }

    private func feedback(_ kind: MovementIssueKind, severity: FeedbackSeverity = .warning) -> FormFeedback {
        FormFeedback(
            category: .safety,
            message: kind.rawValue,
            severity: severity,
            timestamp: 1.0,
            issueKind: kind
        )
    }

    private func makeSession(
        daysAgo: Int,
        movement: MovementType = .squat,
        score: Double,
        feedback: [FormFeedback]?
    ) -> Session {
        Session(
            movementType: movement,
            videoURL: URL(fileURLWithPath: "/dev/null"),
            timestamp: Calendar(identifier: .gregorian).date(byAdding: .day, value: -daysAgo, to: baseDate) ?? baseDate,
            analysisResult: feedback.map { AnalysisResult(score: score, feedback: $0) },
            notes: nil,
            isRecordedLive: false
        )
    }
}
