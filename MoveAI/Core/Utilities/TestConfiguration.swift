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
        return ProcessInfo.processInfo.arguments.contains("--uitesting")
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
        return (
            height: 180.0,
            weight: 80.0,
            age: 25
        )
    }
    
    var mockMovements: [Movement] {
        return [
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
    
    func resetAppState() {
        if isUITesting {
            UserDefaults.standard.removeObject(forKey: "isOnboardingCompleted")
            UserDefaults.standard.removeObject(forKey: "isPremiumUser")
            UserDefaults.standard.removeObject(forKey: "currentUser")
        }
    }
    
    @MainActor
    func setupTestEnvironment() {
        if isUITesting {
            resetAppState()
            DebugManager.shared.clearLogs()
            DebugManager.shared.clearPerformanceMetrics()
        }
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
