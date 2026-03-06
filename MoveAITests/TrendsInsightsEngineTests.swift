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

    func testBuildSnapshot_weightedBurdenRankingOrdersTopIssues() {
        let sessions: [Session] = [
            makeSession(daysAgo: 1, score: 70, feedback: [feedback(.squatHeelsLift, severity: .critical)]),
            makeSession(daysAgo: 2, score: 71, feedback: [feedback(.squatHeelsLift)]),
            makeSession(daysAgo: 3, score: 72, feedback: [feedback(.squatKneeValgus)]),
            makeSession(daysAgo: 4, score: 73, feedback: [feedback(.squatKneeValgus)]),
            makeSession(daysAgo: 5, score: 74, feedback: [])
        ]

        let snapshot = TrendsInsightsEngine.buildSnapshot(sessions: sessions)

        XCTAssertEqual(snapshot.troubleAreas.first?.issueKind, .squatHeelsLift)
        XCTAssertEqual(snapshot.troubleAreas.first?.burden ?? 0, 2.85, accuracy: 0.001)
        XCTAssertEqual(snapshot.troubleAreas.dropFirst().first?.issueKind, .squatKneeValgus)
        XCTAssertEqual(snapshot.troubleAreas.dropFirst().first?.burden ?? 0, 1.25, accuracy: 0.001)
    }

    func testBuildSnapshot_classifiesTrendDirections() {
        let sessions: [Session] = [
            makeSession(daysAgo: 1, score: 70, feedback: [
                feedback(.squatKneeValgus, severity: .critical),
                feedback(.squatHipShift),
            ]),
            makeSession(daysAgo: 2, score: 71, feedback: [
                feedback(.squatKneeValgus, severity: .critical),
                feedback(.squatHeelsLift),
                feedback(.squatHipShift),
            ]),
            makeSession(daysAgo: 3, score: 72, feedback: [
                feedback(.squatKneeValgus),
                feedback(.squatHeelsLift, severity: .critical),
                feedback(.squatHipShift),
            ]),
            makeSession(daysAgo: 4, score: 73, feedback: [
                feedback(.squatHeelsLift, severity: .critical),
                feedback(.squatHipShift),
            ]),
            makeSession(daysAgo: 5, score: 74, feedback: [])
        ]

        let snapshot = TrendsInsightsEngine.buildSnapshot(sessions: sessions)
        let rowsByKind = Dictionary(uniqueKeysWithValues: snapshot.troubleAreas.map { ($0.issueKind, $0) })

        XCTAssertEqual(rowsByKind[.squatHeelsLift]?.direction, .improving)
        XCTAssertEqual(rowsByKind[.squatKneeValgus]?.direction, .worsening)
        XCTAssertEqual(rowsByKind[.squatHipShift]?.direction, .stable)
    }

    func testBuildSnapshot_recommendationMappingIncludesAnkleMobilityRule() {
        let sessions: [Session] = [
            makeSession(daysAgo: 1, score: 65, feedback: [feedback(.squatHeelsLift)]),
            makeSession(daysAgo: 2, score: 66, feedback: [feedback(.squatDepthTooShallow)]),
            makeSession(daysAgo: 3, score: 67, feedback: [feedback(.squatIncompleteROM)]),
            makeSession(daysAgo: 4, score: 68, feedback: []),
            makeSession(daysAgo: 5, score: 69, feedback: [])
        ]

        let snapshot = TrendsInsightsEngine.buildSnapshot(sessions: sessions)
        let ankleCard = snapshot.recommendations.first { $0.id == "ankle_mobility" }

        XCTAssertNotNil(ankleCard)
        XCTAssertTrue(ankleCard?.title.localizedCaseInsensitiveContains("dorsiflexion") ?? false)
    }

    func testBuildSnapshot_confidenceClassificationBySessionFrequency() {
        let sessions: [Session] = [
            makeSession(daysAgo: 1, score: 70, feedback: [feedback(.squatHeelsLift), feedback(.squatKneeValgus), feedback(.squatHipShift)]),
            makeSession(daysAgo: 2, score: 71, feedback: [feedback(.squatHeelsLift), feedback(.squatKneeValgus)]),
            makeSession(daysAgo: 3, score: 72, feedback: [feedback(.squatHeelsLift)]),
            makeSession(daysAgo: 4, score: 73, feedback: [feedback(.squatHeelsLift)]),
            makeSession(daysAgo: 5, score: 74, feedback: [])
        ]

        let snapshot = TrendsInsightsEngine.buildSnapshot(sessions: sessions)
        let rowsByKind = Dictionary(uniqueKeysWithValues: snapshot.troubleAreas.map { ($0.issueKind, $0) })

        XCTAssertEqual(rowsByKind[.squatHeelsLift]?.confidence, .high)
        XCTAssertEqual(rowsByKind[.squatKneeValgus]?.confidence, .medium)
        XCTAssertEqual(rowsByKind[.squatHipShift]?.confidence, .low)
    }

    func testBuildSnapshot_deterministicOrderingWhenBurdenAndFrequencyTie() {
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
