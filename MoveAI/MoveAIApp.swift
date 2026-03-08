//
//  MoveAIApp.swift
//  MoveAI
//
//  Created by Dave Mathew on 10/11/25.
//

import SwiftUI

@main
struct MoveAIApp: App {
    init() {
        // Ensure deterministic UI tests by clearing onboarding-related defaults on launch.
        // Some Xcode test runners reuse the same simulator instance (no fresh clone),
        // which can otherwise cause onboarding to be skipped unexpectedly.
        if TestConfiguration.shared.isUITesting {
            TestConfiguration.shared.configureUserDefaultsForUITesting()
            Task { @MainActor in
                DebugManager.shared.clearLogs()
                DebugManager.shared.clearPerformanceMetrics()
            }
        }
    }

    var body: some Scene {
        WindowGroup {
            #if DEBUG
            if let scenarioView = ScenarioRouter.rootView() {
                scenarioView
                    .tint(CoachTheme.Palette.accent)
            } else {
                ContentView()
                    .tint(CoachTheme.Palette.accent)
            }
            #else
            ContentView()
                .tint(CoachTheme.Palette.accent)
            #endif
        }
    }
}
