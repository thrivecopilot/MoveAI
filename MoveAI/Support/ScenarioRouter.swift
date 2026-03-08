//
//  ScenarioRouter.swift
//  MoveAI
//
//  Debug-only UI scenario routing for deterministic UI verification.
//

#if DEBUG
import SwiftUI
import UIKit

enum UIScenario: String, CaseIterable {
    case sessionHistoryLoaded = "SessionHistory_loaded"
    case sessionHistoryEmpty = "SessionHistory_empty"
    case sessionHistoryError = "SessionHistory_error"
    case sessionHistoryLongText = "SessionHistory_longText"
    case homeLoaded = "Home_loaded"
    case profileLoaded = "Profile_loaded"
    case movementSelectionDefault = "MovementSelection_default"
    case onboardingWelcome = "Onboarding_welcome"
    case onboardingSignin = "Onboarding_signin"
    case onboardingHealth = "Onboarding_health"
    case onboardingPersonalInfo = "Onboarding_personalInfo"
    case videoReviewOverviewCollapsed = "VideoReview_overview_collapsed"
    case videoReviewOverviewMedium = "VideoReview_overview_medium"
    case videoReviewOverviewExpanded = "VideoReview_overview_expanded"
    case workoutSummaryDefault = "WorkoutSummary_default"
    case poseOverlayDetected = "PoseOverlay_detected"
    case poseOverlayHighlights = "PoseOverlay_highlights"
    case poseOverlayNoPose = "PoseOverlay_noPose"
    case dataInputPrefilled = "DataInput_prefilled"
    case trendsSquatFocus = "Trends_squat_focus"
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

        ScenarioFixtures.configurePersistentState(for: scenario)

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
        case .homeLoaded:
            return AnyView(MovementMasteryHomeView(sessionManager: sessionManager))
        case .profileLoaded:
            return AnyView(ProfileView().environmentObject(sessionManager))
        case .movementSelectionDefault:
            return AnyView(MovementSelectionView())
        case .onboardingWelcome:
            return AnyView(WelcomeStepView())
        case .onboardingSignin:
            return AnyView(AppleSignInStepView(appleAuthManager: AppleAuthManager(), onSignInSuccess: {}))
        case .onboardingHealth:
            return AnyView(HealthPermissionStepView(healthManager: HealthManager(), onPermissionGranted: {}))
        case .onboardingPersonalInfo:
            return AnyView(PersonalInfoStepView(onComplete: {}))
        case .videoReviewOverviewCollapsed:
            return videoReviewView(sessionManager: sessionManager, sheetState: .collapsed)
        case .videoReviewOverviewMedium:
            return videoReviewView(sessionManager: sessionManager, sheetState: .medium)
        case .videoReviewOverviewExpanded:
            return videoReviewView(sessionManager: sessionManager, sheetState: .expanded)
        case .workoutSummaryDefault:
            return AnyView(OverviewTabView(analysisResult: PreviewData.analysisResult()))
        case .poseOverlayDetected:
            return poseOverlayView(pose: ScenarioFixtures.poseOverlayDetected())
        case .poseOverlayHighlights:
            return poseOverlayView(
                pose: ScenarioFixtures.poseOverlayDetected(),
                highlightedJoints: [.leftHip: .warning, .rightHip: .critical]
            )
        case .poseOverlayNoPose:
            return poseOverlayView(pose: nil)
        case .dataInputPrefilled:
            return AnyView(PersonalInfoStepView(onComplete: {}))
        case .trendsSquatFocus:
            return AnyView(TrendsView().environmentObject(sessionManager))
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

    private static func poseOverlayView(pose: PoseDetectionResult?, highlightedJoints: [BodyJoint: FeedbackSeverity] = [:]) -> AnyView {
        let keypointCount = pose?.keypoints.count ?? 0
        let frameText: String = {
            guard let pose else { return "Frame --" }
            return "Frame \(pose.frameIndex)"
        }()

        return AnyView(
            ZStack(alignment: .bottomLeading) {
                Color.black
                    .ignoresSafeArea()

                PoseOverlayView(
                    pose: pose,
                    previewSize: CGSize(width: 360, height: 640),
                    flipXAxis: false,
                    isUploadedVideo: true,
                    style: .standard,
                    highlightedJoints: highlightedJoints
                )

                Text("\(frameText) · \(keypointCount) keypoints")
                    .font(.caption.monospacedDigit())
                    .foregroundColor(.white)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(.black.opacity(0.65))
                    .cornerRadius(8)
                    .padding(12)
                    .accessibilityIdentifier("PoseOverlay.MetaLabel")
            }
            .accessibilityIdentifier("PoseOverlayScenario")
            .accessibilityElement(children: .contain)
        )
    }
}

private enum ScenarioFixtures {
    static func sessions(for scenario: UIScenario) -> [Session] {
        switch scenario {
        case .sessionHistoryLoaded, .homeLoaded:
            return loadedSessions()
        case .profileLoaded:
            return loadedSessions()
        case .sessionHistoryEmpty:
            return []
        case .sessionHistoryError:
            return []
        case .sessionHistoryLongText:
            return longTextSessions()
        case .movementSelectionDefault,
             .onboardingWelcome,
             .onboardingSignin,
             .onboardingHealth,
             .onboardingPersonalInfo:
            return []
        case .videoReviewOverviewCollapsed,
             .videoReviewOverviewMedium,
             .videoReviewOverviewExpanded:
            return [videoReviewSession()]
        case .trendsSquatFocus:
            return trendsSquatFocusSessions()
        case .workoutSummaryDefault,
             .poseOverlayDetected,
             .poseOverlayHighlights,
             .poseOverlayNoPose,
             .dataInputPrefilled:
            return []
        }
    }

    static func configurePersistentState(for scenario: UIScenario) {
        guard scenario == .dataInputPrefilled || scenario == .onboardingPersonalInfo else { return }

        let defaults = UserDefaults.standard
        defaults.set(177.8, forKey: "userHeight")
        defaults.set(81.64656, forKey: "userWeight")
        defaults.set(31, forKey: "userAge")
    }

    static func poseOverlayDetected() -> PoseDetectionResult {
        let timestamp = fixedDate(daysAgo: 1)
        let keypoints: [PoseKeypoint] = [
            PoseKeypoint(name: "nose", position: CGPoint(x: 0.52, y: 0.15), confidence: 0.94, timestamp: timestamp),
            PoseKeypoint(name: "leftShoulder", position: CGPoint(x: 0.41, y: 0.32), confidence: 0.89, timestamp: timestamp),
            PoseKeypoint(name: "rightShoulder", position: CGPoint(x: 0.62, y: 0.31), confidence: 0.90, timestamp: timestamp),
            PoseKeypoint(name: "leftHip", position: CGPoint(x: 0.45, y: 0.57), confidence: 0.87, timestamp: timestamp),
            PoseKeypoint(name: "rightHip", position: CGPoint(x: 0.58, y: 0.57), confidence: 0.88, timestamp: timestamp),
            PoseKeypoint(name: "leftKnee", position: CGPoint(x: 0.46, y: 0.77), confidence: 0.84, timestamp: timestamp),
            PoseKeypoint(name: "rightKnee", position: CGPoint(x: 0.57, y: 0.77), confidence: 0.83, timestamp: timestamp)
        ]
        return PoseDetectionResult(keypoints: keypoints, frameIndex: 42, timestamp: timestamp)
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

    private static func trendsSquatFocusSessions() -> [Session] {
        return [
            makeAnalyzedSquatSession(
                daysAgo: 1,
                score: 62,
                feedback: [
                    FormFeedback(category: .safety, message: "Heels lifted off floor", severity: .critical, timestamp: 4.1, repNumber: 1, issueKind: .squatHeelsLift),
                    FormFeedback(category: .rangeOfMotion, message: "Depth too shallow", severity: .warning, timestamp: 4.3, repNumber: 1, issueKind: .squatDepthTooShallow),
                    FormFeedback(category: .safety, message: "Knees caving inward", severity: .warning, timestamp: 4.6, repNumber: 1, issueKind: .squatKneeValgus)
                ]
            ),
            makeAnalyzedSquatSession(
                daysAgo: 2,
                score: 65,
                feedback: [
                    FormFeedback(category: .rangeOfMotion, message: "Heels lifting at bottom", severity: .warning, timestamp: 6.2, repNumber: 1, issueKind: .squatHeelsLift),
                    FormFeedback(category: .rangeOfMotion, message: "Knees stayed back", severity: .warning, timestamp: 6.4, repNumber: 1, issueKind: .squatKneesStayedBack),
                    FormFeedback(category: .stability, message: "Foot arch collapsing", severity: .warning, timestamp: 6.6, repNumber: 1, issueKind: .squatFootCollapse)
                ]
            ),
            makeAnalyzedSquatSession(
                daysAgo: 3,
                score: 68,
                feedback: [
                    FormFeedback(category: .rangeOfMotion, message: "Depth too shallow", severity: .warning, timestamp: 5.1, repNumber: 1, issueKind: .squatDepthTooShallow),
                    FormFeedback(category: .rangeOfMotion, message: "Incomplete range of motion", severity: .warning, timestamp: 5.4, repNumber: 1, issueKind: .squatIncompleteROM),
                    FormFeedback(category: .rangeOfMotion, message: "Heels lifting at bottom", severity: .warning, timestamp: 5.8, repNumber: 1, issueKind: .squatHeelsLift)
                ]
            ),
            makeAnalyzedSquatSession(
                daysAgo: 4,
                score: 72,
                feedback: [
                    FormFeedback(category: .safety, message: "Knees caving inward", severity: .warning, timestamp: 6.9, repNumber: 1, issueKind: .squatKneeValgus),
                    FormFeedback(category: .stability, message: "Hip shift to one side", severity: .warning, timestamp: 7.2, repNumber: 1, issueKind: .squatHipShift)
                ]
            ),
            makeAnalyzedSquatSession(
                daysAgo: 5,
                score: 74,
                feedback: [
                    FormFeedback(category: .rangeOfMotion, message: "Heels lifting at bottom", severity: .warning, timestamp: 5.0, repNumber: 1, issueKind: .squatHeelsLift),
                    FormFeedback(category: .posture, message: "Torso leaning forward", severity: .warning, timestamp: 5.3, repNumber: 1, issueKind: .squatForwardLean)
                ]
            ),
            makeAnalyzedSquatSession(
                daysAgo: 6,
                score: 66,
                feedback: [
                    FormFeedback(category: .rangeOfMotion, message: "Heels lifted off floor", severity: .critical, timestamp: 4.0, repNumber: 1, issueKind: .squatHeelsLift),
                    FormFeedback(category: .rangeOfMotion, message: "Depth too shallow", severity: .critical, timestamp: 4.4, repNumber: 1, issueKind: .squatDepthTooShallow)
                ]
            ),
            makeAnalyzedSquatSession(
                daysAgo: 7,
                score: 64,
                feedback: [
                    FormFeedback(category: .rangeOfMotion, message: "Heels lifting at bottom", severity: .warning, timestamp: 5.9, repNumber: 1, issueKind: .squatHeelsLift),
                    FormFeedback(category: .posture, message: "Posterior pelvic tuck", severity: .warning, timestamp: 6.2, repNumber: 1, issueKind: .squatButtWink)
                ]
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

    private static func makeAnalyzedSquatSession(
        daysAgo: Int,
        score: Double,
        feedback: [FormFeedback]
    ) -> Session {
        Session(
            movementType: .squat,
            videoURL: URL(fileURLWithPath: "/dev/null"),
            timestamp: fixedDate(daysAgo: daysAgo),
            analysisResult: AnalysisResult(score: score, feedback: feedback),
            notes: "Scenario fixture for trends insights.",
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
