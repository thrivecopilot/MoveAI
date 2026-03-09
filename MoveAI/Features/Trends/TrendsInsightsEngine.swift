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

    var coachingLabel: String {
        switch self {
        case .improving:
            return "Improving"
        case .stable:
            return "Stable"
        case .worsening:
            return "Needs Attention"
        }
    }

    var sfSymbolName: String {
        switch self {
        case .improving:
            return "arrow.down.right"
        case .stable:
            return "arrow.right"
        case .worsening:
            return "arrow.up.right"
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

struct PrimaryFixModel {
    let issueKind: MovementIssueKind
    let headline: String
    let evidenceLine: String
    let direction: TrendDirection
    let confidence: InsightConfidence
    let severityMixText: String
    let impactStatement: String
    let quickFixCue: String
}

struct TodayCueModel {
    let cue: String
    let subtitle: String
}

struct MovementQualityDimensionScore: Identifiable {
    let dimension: MovementQualityDimension
    let score: Int
    let delta: Int
    let direction: TrendDirection

    var id: String { dimension.rawValue }

    var deltaText: String {
        if delta > 0 {
            return "+\(delta)"
        }
        if delta < 0 {
            return "\(delta)"
        }
        return "0"
    }
}

struct TroubleFixCardModel: Identifiable {
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
    let likelyCause: String
    let recommendedDrills: [String]
    let whenItUsuallyOccurs: String
    let targetGoal: String
    let impactStatement: String

    var frequencyText: String {
        "\(sessionsSeenCount)/\(sessionsDenominator) sessions"
    }

    var severityMixText: String {
        "\(criticalCount) critical, \(warningCount) warning events"
    }
}

struct DrillPlaylistModel {
    let title: String
    let durationText: String
    let drills: [String]
    let frequencyRecommendation: String
}

struct ExpertResourceCardModel: Identifiable, Hashable {
    let id: String
    let creator: String
    let title: String
    let issueAssociation: String
    let url: URL
    let thumbnailToken: String
}

struct ProgressNarrativeModel {
    let scoreChangeText: String
    let burdenLabel: String
    let contributors: [String]
    let summary: String
}

struct SmallWinModel: Identifiable, Hashable {
    let id: String
    let text: String
}

struct TrendsSnapshot {
    let movement: MovementType
    let lookback: Int
    let lookbackLabel: String
    let analyzedSessionCount: Int
    let hasEnoughData: Bool
    let lowDataHint: String?

    let primaryFix: PrimaryFixModel?
    let todayCue: TodayCueModel?
    let qualitySummary: [MovementQualityDimensionScore]
    let troubleAreas: [TroubleFixCardModel]
    let quickRoutine: DrillPlaylistModel?
    let expertDiscovery: [ExpertResourceCardModel]

    let scoreTrend: [TrendPoint]
    let averageScoreLastLookback: Double?
    let scoreChangeVsPreviousLookback: Double?
    let burdenTrend: TrendDirection
    let progressNarrative: ProgressNarrativeModel

    let smallWins: [SmallWinModel]
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
        let lowDataHint: String? = hasEnoughData
            ? nil
            : "Record at least 3 analyzed \(movement.displayName.lowercased()) sessions to unlock reliable coaching trends."

        var issueAccumulators: [MovementIssueKind: IssueAccumulator] = [:]
        var perSessionBurden: [Double] = Array(repeating: 0, count: recent.count)

        for (sessionIndex, session) in recent.enumerated() {
            guard let feedback = session.analysisResult?.feedback else { continue }
            let recencyWeight = recencyWeightForIndex(sessionIndex)

            for item in feedback {
                guard item.severity == .warning || item.severity == .critical else { continue }
                guard let kind = MovementIssueResolver.resolve(for: item) else { continue }

                let severityWeight = severityWeight(for: item.severity)
                perSessionBurden[sessionIndex] += severityWeight

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

        let troubleAreas: [TroubleFixCardModel] = issueAccumulators.values
            .map { accumulator in
                let entry = MovementCueCatalog.entry(for: accumulator.kind)
                let seenCount = accumulator.sessionsSeen.count
                let drills = topDrills(for: accumulator.kind, limit: 3)

                return TroubleFixCardModel(
                    id: accumulator.kind.rawValue,
                    issueKind: accumulator.kind,
                    title: issueTitle(for: accumulator.kind),
                    burden: accumulator.burden,
                    warningCount: accumulator.warningCount,
                    criticalCount: accumulator.criticalCount,
                    sessionsSeenCount: seenCount,
                    sessionsDenominator: max(lookback, 1),
                    direction: classifyBurdenTrend(newestValue: accumulator.newestWindowBurden, previousValue: accumulator.previousWindowBurden),
                    confidence: confidence(forSessionsSeen: seenCount),
                    likelyCause: entry?.oneLineDescription ?? "Recurring form pattern detected across recent sessions.",
                    recommendedDrills: drills,
                    whenItUsuallyOccurs: entry?.phaseSummaryText ?? "Varies by rep and fatigue.",
                    targetGoal: TrendsMappings.targetGoal(for: accumulator.kind),
                    impactStatement: TrendsMappings.impactStatement(for: accumulator.kind)
                )
            }
            .sorted { lhs, rhs in
                if lhs.burden != rhs.burden { return lhs.burden > rhs.burden }
                if lhs.sessionsSeenCount != rhs.sessionsSeenCount { return lhs.sessionsSeenCount > rhs.sessionsSeenCount }
                return lhs.issueKind.rawValue < rhs.issueKind.rawValue
            }

        let primaryFix = buildPrimaryFix(from: troubleAreas, lookback: lookback)
        let todayCue = buildTodayCue(from: primaryFix)
        let qualitySummary = buildQualitySummary(from: recent)
        let quickRoutine = buildQuickRoutine(from: primaryFix)

        let topIssueFallback = troubleAreas.prefix(2).map(\.issueKind)
        let expertDiscovery = TrendsExpertCatalog
            .filtered(for: primaryFix?.issueKind, fallbackIssues: topIssueFallback)
            .prefix(4)
            .map {
                ExpertResourceCardModel(
                    id: $0.id,
                    creator: $0.creator,
                    title: $0.title,
                    issueAssociation: $0.issueAssociation,
                    url: $0.url,
                    thumbnailToken: $0.thumbnailToken
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
        let burdenTrend = classifyBurdenTrend(newestValue: burdenNewest, previousValue: burdenPrevious)

        let progressNarrative = buildProgressNarrative(
            scoreChange: scoreChange,
            burdenTrend: burdenTrend,
            troubleAreas: troubleAreas
        )

        let smallWins = buildSmallWins(troubleAreas: troubleAreas, qualitySummary: qualitySummary)

        return TrendsSnapshot(
            movement: movement,
            lookback: lookback,
            lookbackLabel: lookbackLabel,
            analyzedSessionCount: analyzed.count,
            hasEnoughData: hasEnoughData,
            lowDataHint: lowDataHint,
            primaryFix: primaryFix,
            todayCue: todayCue,
            qualitySummary: qualitySummary,
            troubleAreas: Array(troubleAreas.prefix(3)),
            quickRoutine: quickRoutine,
            expertDiscovery: Array(expertDiscovery),
            scoreTrend: scoreTrend,
            averageScoreLastLookback: averageScoreLast,
            scoreChangeVsPreviousLookback: scoreChange,
            burdenTrend: burdenTrend,
            progressNarrative: progressNarrative,
            smallWins: smallWins
        )
    }

    private static func buildPrimaryFix(from troubleAreas: [TroubleFixCardModel], lookback: Int) -> PrimaryFixModel? {
        guard let topIssue = troubleAreas.first else { return nil }
        let cue = MovementCueCatalog.entry(for: topIssue.issueKind)?.quickFix ?? "Apply focused control on this pattern in the next session."

        return PrimaryFixModel(
            issueKind: topIssue.issueKind,
            headline: topIssue.title,
            evidenceLine: "Seen in \(topIssue.sessionsSeenCount) of last \(lookback) sessions",
            direction: topIssue.direction,
            confidence: topIssue.confidence,
            severityMixText: topIssue.severityMixText,
            impactStatement: topIssue.impactStatement,
            quickFixCue: cue
        )
    }

    private static func buildTodayCue(from primaryFix: PrimaryFixModel?) -> TodayCueModel? {
        guard let primaryFix else { return nil }
        return TodayCueModel(
            cue: primaryFix.quickFixCue,
            subtitle: "Use this cue on your first 3 working sets."
        )
    }

    private static func buildQuickRoutine(from primaryFix: PrimaryFixModel?) -> DrillPlaylistModel? {
        guard let primaryFix else { return nil }

        let drills = topDrills(for: primaryFix.issueKind, limit: 3)
        guard !drills.isEmpty else { return nil }

        let durationMinutes = max(6, drills.count * 2)
        return DrillPlaylistModel(
            title: "Quick Fix Routine",
            durationText: "\(durationMinutes) min",
            drills: drills,
            frequencyRecommendation: TrendsMappings.frequencyRecommendation(for: primaryFix.issueKind)
        )
    }

    private static func buildQualitySummary(from sessions: [Session]) -> [MovementQualityDimensionScore] {
        MovementQualityDimension.allCases.map { dimension in
            var weightedPenalty = 0.0
            var newestPenalty = 0.0
            var previousPenalty = 0.0

            for (index, session) in sessions.enumerated() {
                guard let feedback = session.analysisResult?.feedback else { continue }
                let recencyWeight = recencyWeightForIndex(index)

                for item in feedback {
                    guard item.severity == .warning || item.severity == .critical else { continue }
                    guard let kind = MovementIssueResolver.resolve(for: item) else { continue }
                    guard TrendsMappings.dimensions(for: kind).contains(dimension) else { continue }

                    let weight = severityWeight(for: item.severity)
                    weightedPenalty += weight * recencyWeight

                    if index < 2 {
                        newestPenalty += weight
                    } else if index < 4 {
                        previousPenalty += weight
                    }
                }
            }

            let score = clampedScore(100 - (weightedPenalty * 8.0))
            let newestScore = clampedScore(100 - (newestPenalty * 10.0))
            let previousScore = clampedScore(100 - (previousPenalty * 10.0))
            let delta = newestScore - previousScore
            let direction = qualityDirection(forDelta: delta)

            return MovementQualityDimensionScore(
                dimension: dimension,
                score: Int(score.rounded()),
                delta: Int(delta.rounded()),
                direction: direction
            )
        }
    }

    private static func buildProgressNarrative(
        scoreChange: Double?,
        burdenTrend: TrendDirection,
        troubleAreas: [TroubleFixCardModel]
    ) -> ProgressNarrativeModel {
        let contributors = Array(troubleAreas.prefix(2).map(\.title))

        let scoreChangeText: String = {
            guard let scoreChange else { return "N/A" }
            return String(format: "%+.1f", scoreChange)
        }()

        let summary: String = {
            if let scoreChange {
                if scoreChange >= 2 {
                    return "Movement score is trending up. Keep reinforcing your top cue and routine."
                }
                if scoreChange <= -2 {
                    return "Score dipped versus the previous block. Focus on your primary fix before adding load."
                }
            }

            switch burdenTrend {
            case .improving:
                return "Warning and critical burden is improving even with stable score changes."
            case .stable:
                return "Form trend is stable. Consistency work will unlock clearer gains."
            case .worsening:
                return "Issue burden is rising. Address the top trouble area before progressing intensity."
            }
        }()

        return ProgressNarrativeModel(
            scoreChangeText: scoreChangeText,
            burdenLabel: burdenTrend.coachingLabel,
            contributors: contributors,
            summary: summary
        )
    }

    private static func buildSmallWins(
        troubleAreas: [TroubleFixCardModel],
        qualitySummary: [MovementQualityDimensionScore]
    ) -> [SmallWinModel] {
        var wins: [SmallWinModel] = troubleAreas
            .filter { $0.direction == .improving }
            .prefix(2)
            .map {
                SmallWinModel(
                    id: "improvement.\($0.issueKind.rawValue)",
                    text: "\($0.title) improved over recent sessions"
                )
            }

        if wins.isEmpty {
            let stableDimensions = qualitySummary
                .filter { $0.score >= 70 && $0.direction != .worsening }
                .prefix(2)

            wins.append(contentsOf: stableDimensions.map {
                SmallWinModel(
                    id: "dimension.\($0.dimension.rawValue)",
                    text: "\($0.dimension.title) stayed consistent"
                )
            })
        }

        if wins.isEmpty {
            wins = [
                SmallWinModel(
                    id: "fallback.consistency",
                    text: "Consistency is improving. Keep collecting sessions for clearer trend signals."
                )
            ]
        }

        return Array(wins.prefix(2))
    }

    private static func topDrills(for kind: MovementIssueKind, limit: Int) -> [String] {
        guard let entry = MovementCueCatalog.entry(for: kind) else { return [] }

        let ordered = entry.recommendedDrills
        var unique: [String] = []

        for drill in ordered {
            let cleaned = drill.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !cleaned.isEmpty else { continue }
            if unique.contains(cleaned) { continue }
            unique.append(cleaned)
            if unique.count == limit { break }
        }

        return unique
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

    private static func classifyBurdenTrend(newestValue: Double, previousValue: Double) -> TrendDirection {
        if previousValue <= 0 {
            if newestValue > 0 { return .worsening }
            return .stable
        }

        let change = (newestValue - previousValue) / previousValue
        if change <= -0.2 { return .improving }
        if change >= 0.2 { return .worsening }
        return .stable
    }

    private static func qualityDirection(forDelta delta: Double) -> TrendDirection {
        if delta >= 3 {
            return .improving
        }
        if delta <= -3 {
            return .worsening
        }
        return .stable
    }

    private static func clampedScore(_ rawValue: Double) -> Double {
        min(max(rawValue, 40), 100)
    }

    private static func mean(_ values: [Double]) -> Double? {
        guard !values.isEmpty else { return nil }
        return values.reduce(0, +) / Double(values.count)
    }

    private static func issueTitle(for kind: MovementIssueKind) -> String {
        if let entry = MovementCueCatalog.entry(for: kind) {
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
