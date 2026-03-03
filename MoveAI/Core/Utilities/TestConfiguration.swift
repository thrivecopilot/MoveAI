//
//  TestConfiguration.swift
//  MoveAI
//
//  Created by Dave Mathew on 10/11/25.
//

import Foundation

struct TestConfiguration {
    static let shared = TestConfiguration()

    // MARK: - Test Flags

    var isUITesting: Bool {
        ProcessInfo.processInfo.arguments.contains("--uitesting")
    }

    var isDebugMode: Bool {
        #if DEBUG
        return true
        #else
        return false
        #endif
    }

    // MARK: - Test Data

    // Mock user profile data - now handled via @AppStorage
    var mockUserProfile: (height: Double, weight: Double, age: Int) {
        (
            height: 180.0,
            weight: 80.0,
            age: 25
        )
    }

    var mockMovements: [Movement] {
        [
            Movement(
                name: "Test Squat",
                category: .powerlifting,
                description: "Test squat movement",
                idealForm: IdealForm(),
                difficulty: .beginner,
                equipment: [.barbell, .plates]
            ),
            Movement(
                name: "Test Deadlift",
                category: .powerlifting,
                description: "Test deadlift movement",
                idealForm: IdealForm(),
                difficulty: .intermediate,
                equipment: [.barbell, .plates]
            )
        ]
    }

    // MARK: - Performance Thresholds

    struct PerformanceThresholds {
        static let maxAppLaunchTime: TimeInterval = 3.0
        static let maxTabSwitchTime: TimeInterval = 0.5
        static let maxViewLoadTime: TimeInterval = 1.0
        static let maxMemoryUsage: UInt64 = 100 * 1024 * 1024 // 100MB
    }

    // MARK: - Test Utilities

    /// Clear persisted state that can leak across simulator test runs.
    ///
    /// Note: Xcode sometimes reuses the same simulator instance (no fresh clone),
    /// so we proactively clear onboarding/session data for determinism.
    func resetAppState() {
        guard isUITesting else { return }

        let defaults = UserDefaults.standard
        for key in [
            // Legacy keys
            "isOnboardingCompleted",
            "isPremiumUser",
            "currentUser",

            // Current onboarding / profile keys
            "isSignedIn",
            "hasHealthPermissions",
            "userHeight",
            "userWeight",
            "userAge"
        ] {
            defaults.removeObject(forKey: key)
        }

        // Clear persisted sessions for deterministic UI tests.
        let fileManager = FileManager.default
        let sessionsDirectory = fileManager.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("Sessions", isDirectory: true)
        try? fileManager.removeItem(at: sessionsDirectory)
    }

    /// Apply deterministic defaults so UI tests can start on the main app without
    /// having to navigate through Apple Sign In / Health permissions.
    func configureUserDefaultsForUITesting() {
        guard isUITesting else { return }

        resetAppState()

        let defaults = UserDefaults.standard
        defaults.set(true, forKey: "isSignedIn")
        defaults.set(true, forKey: "hasHealthPermissions")

        // Seed realistic personal info values (cm/kg) so profile-related UI has data.
        defaults.set(177.8, forKey: "userHeight")
        defaults.set(81.64656, forKey: "userWeight")
        defaults.set(31, forKey: "userAge")
    }

    @MainActor
    func setupTestEnvironment() {
        guard isUITesting else { return }
        configureUserDefaultsForUITesting()
        DebugManager.shared.clearLogs()
        DebugManager.shared.clearPerformanceMetrics()
    }
}

// MARK: - Test Extensions

extension AppStateManager {
    func setupForTesting() {
        if TestConfiguration.shared.isUITesting {
            isOnboardingCompleted = false
            // User profile data now managed via @AppStorage
            isLoading = false
            errorMessage = nil
            selectedTab = .home
            isPremiumUser = false
            showAds = true
        }
    }
}

extension MovementManager {
    func setupForTesting() {
        if TestConfiguration.shared.isUITesting {
            isLoading = false
            errorMessage = nil
            selectedMovement = nil
            // Keep default movements for testing
        }
    }
}
