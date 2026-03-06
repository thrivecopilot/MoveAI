import Foundation

enum TrendDirection: String {
    case improving
    case stable
    case worsening

    var label: String {
        switch self {
        case .improving:
            return "Improving"
        case .stable:
            return "Stable"
        case .worsening:
            return "Worsening"
        }
    }
}

enum InsightConfidence: String {
    case low
    case medium
    case high

    var label: String {
        rawValue.capitalized
    }
}

struct TrendPoint: Identifiable {
    let id: UUID
    let date: Date
    let score: Double
    let burden: Double
}

struct FocusInsight {
    let headline: String
    let evidenceLine: String
    let direction: TrendDirection
    let confidence: InsightConfidence
}

struct TroubleAreaRow: Identifiable {
    let id: String
    let issueKind: MovementIssueKind
    let title: String
    let burden: Double
    let warningCount: Int
    let criticalCount: Int
    let sessionsSeenCount: Int
    let sessionsDenominator: Int
    let direction: TrendDirection
    let confidence: InsightConfidence

    var frequencyText: String {
        "\(sessionsSeenCount)/\(sessionsDenominator) sessions"
    }

    var severityMixText: String {
        "\(criticalCount) critical, \(warningCount) warning events"
    }
}

enum TrendsRecommendationPriority: Int {
    case low = 0
    case medium = 1
    case high = 2
}

struct RecommendationCardModel: Identifiable {
    let id: String
    let title: String
    let actionProtocol: String
    let rationale: String
    let expectedOutcome: String
    let priority: TrendsRecommendationPriority
    let burden: Double
}

struct TrendsSnapshot {
    let movement: MovementType
    let lookback: Int
    let lookbackLabel: String
    let analyzedSessionCount: Int
    let hasEnoughData: Bool
    let lowDataHint: String?

    let focus: FocusInsight?
    let scoreTrend: [TrendPoint]
    let averageScoreLastLookback: Double?
    let scoreChangeVsPreviousLookback: Double?
    let burdenTrend: TrendDirection

    let troubleAreas: [TroubleAreaRow]
    let recommendations: [RecommendationCardModel]
    let improvements: [String]
}

enum TrendsInsightsEngine {
    private static let warningWeight = 1.0
    private static let criticalWeight = 2.0
    private static let lookbackRecencyWeights: [Double] = [1.00, 0.85, 0.70, 0.55, 0.40]

    private struct IssueAccumulator {
        let kind: MovementIssueKind
        var burden: Double = 0
        var warningCount: Int = 0
        var criticalCount: Int = 0
        var sessionsSeen: Set<UUID> = []
        var newestWindowBurden: Double = 0
        var previousWindowBurden: Double = 0
    }

    private struct RecommendationRule {
        let id: String
        let title: String
        let actionProtocol: String
        let expectedOutcome: String
        let triggerKinds: Set<MovementIssueKind>
    }

    static func buildSnapshot(
        sessions: [Session],
        movement: MovementType = .squat,
        lookback: Int = 5
    ) -> TrendsSnapshot {
        let analyzed = sessions
            .filter { $0.movementType == movement && $0.analysisResult != nil }
            .sorted { $0.timestamp > $1.timestamp }

        let recent = Array(analyzed.prefix(lookback))
        let previous = Array(analyzed.dropFirst(lookback).prefix(lookback))

        let lookbackLabel = "Last \(lookback) sessions"
        let hasEnoughData = recent.count >= 3
        let lowDataHint: String? = hasEnoughData ? nil : "Record at least 3 analyzed squat sessions to unlock more reliable trends and recommendations."

        var issueAccumulators: [MovementIssueKind: IssueAccumulator] = [:]
        var perSessionBurden: [Double] = Array(repeating: 0, count: recent.count)
        var perSessionKinds: [Set<MovementIssueKind>] = Array(repeating: [], count: recent.count)

        for (sessionIndex, session) in recent.enumerated() {
            guard let feedback = session.analysisResult?.feedback else { continue }
            let recencyWeight = recencyWeightForIndex(sessionIndex)

            for item in feedback {
                guard item.severity == .warning || item.severity == .critical else { continue }
                guard let kind = MovementIssueResolver.resolve(for: item) else { continue }

                let severityWeight = severityWeight(for: item.severity)
                perSessionBurden[sessionIndex] += severityWeight
                perSessionKinds[sessionIndex].insert(kind)

                var accumulator = issueAccumulators[kind] ?? IssueAccumulator(kind: kind)
                accumulator.burden += severityWeight * recencyWeight
                accumulator.sessionsSeen.insert(session.id)

                if item.severity == .critical {
                    accumulator.criticalCount += 1
                } else {
                    accumulator.warningCount += 1
                }

                if sessionIndex < 2 {
                    accumulator.newestWindowBurden += severityWeight
                } else if sessionIndex < 4 {
                    accumulator.previousWindowBurden += severityWeight
                }

                issueAccumulators[kind] = accumulator
            }
        }

        let troubleAreas: [TroubleAreaRow] = issueAccumulators.values
            .map { accumulator in
                let seenCount = accumulator.sessionsSeen.count
                return TroubleAreaRow(
                    id: accumulator.kind.rawValue,
                    issueKind: accumulator.kind,
                    title: issueTitle(for: accumulator.kind),
                    burden: accumulator.burden,
                    warningCount: accumulator.warningCount,
                    criticalCount: accumulator.criticalCount,
                    sessionsSeenCount: seenCount,
                    sessionsDenominator: max(lookback, 1),
                    direction: classifyTrend(newestValue: accumulator.newestWindowBurden, previousValue: accumulator.previousWindowBurden),
                    confidence: confidence(forSessionsSeen: seenCount)
                )
            }
            .sorted { lhs, rhs in
                if lhs.burden != rhs.burden { return lhs.burden > rhs.burden }
                if lhs.sessionsSeenCount != rhs.sessionsSeenCount { return lhs.sessionsSeenCount > rhs.sessionsSeenCount }
                return lhs.issueKind.rawValue < rhs.issueKind.rawValue
            }

        let focus: FocusInsight? = troubleAreas.first.map {
            FocusInsight(
                headline: $0.title,
                evidenceLine: "Seen in \($0.sessionsSeenCount) of last \(lookback) sessions",
                direction: $0.direction,
                confidence: $0.confidence
            )
        }

        let scoreTrend = recent.reversed().compactMap { session -> TrendPoint? in
            guard let score = session.analysisResult?.score else { return nil }
            return TrendPoint(id: session.id, date: session.timestamp, score: score, burden: 0)
        }

        let recentScores = recent.compactMap { $0.analysisResult?.score }
        let previousScores = previous.compactMap { $0.analysisResult?.score }
        let averageScoreLast = mean(recentScores)
        let averageScorePrevious = previousScores.count == lookback ? mean(previousScores) : nil
        let scoreChange = (averageScoreLast != nil && averageScorePrevious != nil)
            ? (averageScoreLast! - averageScorePrevious!)
            : nil

        let burdenNewest = mean(Array(perSessionBurden.prefix(2))) ?? 0
        let burdenPrevious = mean(Array(perSessionBurden.dropFirst(2).prefix(2))) ?? 0
        let burdenTrend = classifyTrend(newestValue: burdenNewest, previousValue: burdenPrevious)

        let recommendations = buildRecommendations(
            lookback: lookback,
            troubleAreas: troubleAreas,
            perSessionKinds: perSessionKinds,
            recentSessions: recent
        )

        let improvements = troubleAreas
            .filter { $0.direction == .improving }
            .prefix(2)
            .map { "\($0.title) improved over recent sessions" }

        return TrendsSnapshot(
            movement: movement,
            lookback: lookback,
            lookbackLabel: lookbackLabel,
            analyzedSessionCount: analyzed.count,
            hasEnoughData: hasEnoughData,
            lowDataHint: lowDataHint,
            focus: focus,
            scoreTrend: scoreTrend,
            averageScoreLastLookback: averageScoreLast,
            scoreChangeVsPreviousLookback: scoreChange,
            burdenTrend: burdenTrend,
            troubleAreas: Array(troubleAreas.prefix(3)),
            recommendations: recommendations,
            improvements: improvements
        )
    }

    private static func buildRecommendations(
        lookback: Int,
        troubleAreas: [TroubleAreaRow],
        perSessionKinds: [Set<MovementIssueKind>],
        recentSessions: [Session]
    ) -> [RecommendationCardModel] {
        let troubleAreaByKind = Dictionary(uniqueKeysWithValues: troubleAreas.map { ($0.issueKind, $0) })

        let rules: [RecommendationRule] = [
            RecommendationRule(
                id: "ankle_mobility",
                title: "Improve ankle dorsiflexion for depth and balance",
                actionProtocol: "Knee-to-wall dorsiflexion + bent-knee calf stretch, 3x/week before squat sessions",
                expectedOutcome: "Better depth consistency and more stable foot pressure at the bottom.",
                triggerKinds: [
                    .squatHeelsLift,
                    .squatKneesStayedBack,
                    .squatDepthTooShallow,
                    .squatIncompleteROM,
                    .squatFootCollapse,
                ]
            ),
            RecommendationRule(
                id: "knee_tracking",
                title: "Build hip stability to improve knee tracking",
                actionProtocol: "Lateral band walks + split squat tempo work, 3x/week",
                expectedOutcome: "More consistent knee tracking and less frontal-plane drift under fatigue.",
                triggerKinds: [
                    .squatKneeValgus,
                    .squatHipShift,
                    .squatFootCollapse,
                ]
            ),
            RecommendationRule(
                id: "bracing_torso",
                title: "Improve bracing and torso control under load",
                actionProtocol: "90/90 breathing + paused goblet squat, 2-3x/week",
                expectedOutcome: "Better trunk control out of the hole and fewer forward collapses.",
                triggerKinds: [
                    .squatForwardLean,
                    .squatBraceLeak,
                    .squatButtWink,
                ]
            ),
        ]

        let recentCount = max(lookback, 1)
        var cards: [RecommendationCardModel] = []

        for rule in rules {
            let rows = rule.triggerKinds.compactMap { troubleAreaByKind[$0] }
            let burden = rows.reduce(0) { $0 + $1.burden }
            let criticalCount = rows.reduce(0) { $0 + $1.criticalCount }
            let warningCount = rows.reduce(0) { $0 + $1.warningCount }

            let sessionsWithPattern = perSessionKinds.filter { !$0.isDisjoint(with: rule.triggerKinds) }.count
            let triggerReached = sessionsWithPattern >= 3 || burden >= 2.4
            guard triggerReached else { continue }

            let newestBurden = sessionWindowBurden(for: rule.triggerKinds, sessions: recentSessions, range: 0..<2)
            let previousBurden = sessionWindowBurden(for: rule.triggerKinds, sessions: recentSessions, range: 2..<4)
            let direction = classifyTrend(newestValue: newestBurden, previousValue: previousBurden)

            let priority: TrendsRecommendationPriority = {
                if criticalCount >= 2 || direction == .worsening {
                    return .high
                }
                return .medium
            }()

            let rationale = "\(sessionsWithPattern) of last \(recentCount) sessions show this pattern (\(criticalCount) critical, \(warningCount) warning events)."

            cards.append(
                RecommendationCardModel(
                    id: rule.id,
                    title: rule.title,
                    actionProtocol: rule.actionProtocol,
                    rationale: rationale,
                    expectedOutcome: rule.expectedOutcome,
                    priority: priority,
                    burden: burden
                )
            )
        }

        return cards
            .sorted { lhs, rhs in
                if lhs.priority.rawValue != rhs.priority.rawValue { return lhs.priority.rawValue > rhs.priority.rawValue }
                if lhs.burden != rhs.burden { return lhs.burden > rhs.burden }
                return lhs.title < rhs.title
            }
            .prefix(2)
            .map { $0 }
    }

    private static func recencyWeightForIndex(_ index: Int) -> Double {
        if index < lookbackRecencyWeights.count {
            return lookbackRecencyWeights[index]
        }
        return lookbackRecencyWeights.last ?? 0.4
    }

    private static func severityWeight(for severity: FeedbackSeverity) -> Double {
        switch severity {
        case .critical:
            return criticalWeight
        case .warning:
            return warningWeight
        case .good, .excellent:
            return 0
        }
    }

    private static func confidence(forSessionsSeen sessionsSeen: Int) -> InsightConfidence {
        if sessionsSeen >= 4 { return .high }
        if sessionsSeen >= 2 { return .medium }
        return .low
    }

    private static func classifyTrend(newestValue: Double, previousValue: Double) -> TrendDirection {
        if previousValue <= 0 {
            if newestValue > 0 { return .worsening }
            return .stable
        }

        let change = (newestValue - previousValue) / previousValue
        if change <= -0.2 { return .improving }
        if change >= 0.2 { return .worsening }
        return .stable
    }

    private static func sessionWindowBurden(
        for kinds: Set<MovementIssueKind>,
        sessions: [Session],
        range: Range<Int>
    ) -> Double {
        guard !sessions.isEmpty else { return 0 }

        var total = 0.0
        for index in range where index < sessions.count {
            guard let feedback = sessions[index].analysisResult?.feedback else { continue }
            for item in feedback {
                guard item.severity == .warning || item.severity == .critical else { continue }
                guard let kind = MovementIssueResolver.resolve(for: item), kinds.contains(kind) else { continue }
                total += severityWeight(for: item.severity)
            }
        }
        return total
    }

    private static func mean(_ values: [Double]) -> Double? {
        guard !values.isEmpty else { return nil }
        return values.reduce(0, +) / Double(values.count)
    }

    private static func issueTitle(for kind: MovementIssueKind) -> String {
        if let entry = SquatCueLibrary.entry(for: kind) {
            return entry.headline
        }

        let raw = kind.rawValue
            .replacingOccurrences(of: "squat.", with: "")
            .replacingOccurrences(of: "_", with: " ")

        return raw
            .split(separator: " ")
            .map { $0.capitalized }
            .joined(separator: " ")
    }
}
