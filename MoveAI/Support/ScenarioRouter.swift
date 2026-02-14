//
//  ScenarioRouter.swift
//  MoveAI
//
//  Debug-only UI scenario routing for deterministic screenshots.
//

#if DEBUG
import SwiftUI
import UIKit

enum UIScenario: String, CaseIterable {
    case sessionHistoryLoaded = "SessionHistory_loaded"
    case sessionHistoryEmpty = "SessionHistory_empty"
    case sessionHistoryError = "SessionHistory_error"
    case sessionHistoryLongText = "SessionHistory_longText"
    case videoReviewOverviewCollapsed = "VideoReview_overview_collapsed"
    case videoReviewOverviewMedium = "VideoReview_overview_medium"
    case videoReviewOverviewExpanded = "VideoReview_overview_expanded"
}

struct ScenarioSettings {
    let appearance: ColorScheme?
    let sizeCategory: ContentSizeCategory?
    let disableAnimations: Bool

    init(arguments: [String]) {
        appearance = ScenarioSettings.parseAppearance(arguments)
        sizeCategory = ScenarioSettings.parseSizeCategory(arguments)
        disableAnimations = arguments.contains("-uiDisableAnimations") || arguments.contains("-uiDisableAnimation")
    }

    private static func parseAppearance(_ arguments: [String]) -> ColorScheme? {
        guard let value = value(after: "-uiAppearance", in: arguments) else { return nil }
        switch value.lowercased() {
        case "dark":
            return .dark
        case "light":
            return .light
        default:
            return nil
        }
    }

    private static func parseSizeCategory(_ arguments: [String]) -> ContentSizeCategory? {
        guard let value = value(after: "-uiTextSize", in: arguments) else { return nil }
        switch value.lowercased() {
        case "default":
            return nil
        case "large", "accessibilitylarge":
            return .accessibilityLarge
        case "xl", "accessibilityextralarge":
            return .accessibilityExtraLarge
        case "xxl", "accessibilityextraextralarge":
            return .accessibilityExtraExtraLarge
        case "xxxl", "accessibilityextraextraextralarge":
            return .accessibilityExtraExtraExtraLarge
        default:
            return nil
        }
    }

    private static func value(after flag: String, in arguments: [String]) -> String? {
        guard let index = arguments.firstIndex(of: flag), index + 1 < arguments.count else { return nil }
        return arguments[index + 1]
    }
}

enum ScenarioRouter {
    @MainActor
    static func rootView() -> AnyView? {
        let arguments = ProcessInfo.processInfo.arguments
        guard let scenario = currentScenario(arguments) else { return nil }
        let settings = ScenarioSettings(arguments: arguments)
        return AnyView(ScenarioHostView(scenario: scenario, settings: settings))
    }

    private static func currentScenario(_ arguments: [String]) -> UIScenario? {
        guard let index = arguments.firstIndex(of: "-uiScenario"), index + 1 < arguments.count else { return nil }
        let name = arguments[index + 1]
        return UIScenario(rawValue: name)
    }
}

@MainActor
struct ScenarioHostView: View {
    let scenario: UIScenario
    let settings: ScenarioSettings

    @StateObject private var sessionManager: SessionManager

    init(scenario: UIScenario, settings: ScenarioSettings) {
        self.scenario = scenario
        self.settings = settings

        let manager = SessionManager()
        manager.sessions = ScenarioFixtures.sessions(for: scenario)
        _sessionManager = StateObject(wrappedValue: manager)

        if settings.disableAnimations {
            UIView.setAnimationsEnabled(false)
        }
    }

    var body: some View {
        var view = ScenarioViews.view(for: scenario, sessionManager: sessionManager)

        if let appearance = settings.appearance {
            view = AnyView(view.preferredColorScheme(appearance))
        }

        if let sizeCategory = settings.sizeCategory {
            view = AnyView(view.environment(\.sizeCategory, sizeCategory))
        }

        return view
            .transaction { transaction in
                if settings.disableAnimations {
                    transaction.disablesAnimations = true
                    transaction.animation = nil
                }
            }
            .accessibilityIdentifier("ScenarioRoot_\(scenario.rawValue)")
            .accessibilityElement(children: .contain)
    }
}

@MainActor
private enum ScenarioViews {
    static func view(for scenario: UIScenario, sessionManager: SessionManager) -> AnyView {
        switch scenario {
        case .sessionHistoryLoaded:
            return AnyView(SessionHistoryView(sessionManager: sessionManager))
        case .sessionHistoryEmpty:
            return AnyView(SessionHistoryView(sessionManager: sessionManager))
        case .sessionHistoryError:
            return AnyView(
                SessionHistoryView(
                    sessionManager: sessionManager,
                    errorMessage: "We couldn't load your sessions. Please check your connection and try again."
                )
            )
        case .sessionHistoryLongText:
            return AnyView(SessionHistoryView(sessionManager: sessionManager, notesLineLimit: 3))
        case .videoReviewOverviewCollapsed:
            return videoReviewView(sessionManager: sessionManager, sheetState: .collapsed)
        case .videoReviewOverviewMedium:
            return videoReviewView(sessionManager: sessionManager, sheetState: .medium)
        case .videoReviewOverviewExpanded:
            return videoReviewView(sessionManager: sessionManager, sheetState: .expanded)
        }
    }

    private static func videoReviewView(
        sessionManager: SessionManager,
        sheetState: AnalysisSheetState
    ) -> AnyView {
        guard let session = sessionManager.sessions.first else {
            return AnyView(Text("Missing VideoReview fixture data"))
        }
        return AnyView(
            VideoReviewLayoutView(
                session: session,
                sessionManager: sessionManager,
                initialSheetState: sheetState,
                initialTab: .overview
            )
            .environmentObject(TabBarVisibility())
        )
    }
}

private enum ScenarioFixtures {
    static func sessions(for scenario: UIScenario) -> [Session] {
        switch scenario {
        case .sessionHistoryLoaded:
            return loadedSessions()
        case .sessionHistoryEmpty:
            return []
        case .sessionHistoryError:
            return []
        case .sessionHistoryLongText:
            return longTextSessions()
        case .videoReviewOverviewCollapsed,
             .videoReviewOverviewMedium,
             .videoReviewOverviewExpanded:
            return [videoReviewSession()]
        }
    }

    private static func loadedSessions() -> [Session] {
        return [
            makeSession(
                movementType: .squat,
                timestamp: fixedDate(daysAgo: 1),
                score: 92,
                notes: "Great depth and control."
            ),
            makeSession(
                movementType: .deadlift,
                timestamp: fixedDate(daysAgo: 3),
                score: 78,
                notes: "Focus on neutral spine."
            ),
            makeSession(
                movementType: .benchPress,
                timestamp: fixedDate(daysAgo: 5),
                score: nil,
                notes: nil
            )
        ]
    }

    private static func longTextSessions() -> [Session] {
        return [
            makeSession(
                movementType: .squat,
                timestamp: fixedDate(daysAgo: 2),
                score: 88,
                notes: "Long note: keep knees tracking over toes, brace your core, and maintain a neutral spine through the entire movement to maximize stability and safety."
            ),
            makeSession(
                movementType: .deadlift,
                timestamp: fixedDate(daysAgo: 6),
                score: 64,
                notes: "Long note: set your lats, push the floor away, and avoid rounding at lockout. Pause at the top to confirm full hip extension."
            )
        ]
    }

    private static func videoReviewSession() -> Session {
        let analysisResult = PreviewData.analysisResult()
        return Session(
            movementType: .squat,
            videoURL: PreviewData.placeholderVideoURL,
            timestamp: fixedDate(daysAgo: 2),
            analysisResult: analysisResult,
            poseData: nil,
            notes: "Keep notes short and actionable. Focus on depth, bracing, and consistent tempo.",
            isRecordedLive: false
        )
    }

    private static func makeSession(
        movementType: MovementType,
        timestamp: Date,
        score: Double?,
        notes: String?
    ) -> Session {
        let analysisResult = score.map { AnalysisResult(score: $0, feedback: []) }
        return Session(
            movementType: movementType,
            videoURL: URL(fileURLWithPath: "/dev/null"),
            timestamp: timestamp,
            analysisResult: analysisResult,
            notes: notes,
            isRecordedLive: false
        )
    }

    private static func fixedDate(daysAgo: Int) -> Date {
        let base = Date(timeIntervalSince1970: 1_735_689_600) // 2025-01-01 00:00:00 UTC
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0) ?? .current
        return calendar.date(byAdding: .day, value: -daysAgo, to: base) ?? base
    }
}
#endif
