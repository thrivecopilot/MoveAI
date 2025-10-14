//
//  AppStateManager.swift
//  MoveAI
//
//  Created by Dave Mathew on 10/11/25.
//

import Foundation
import SwiftUI

@MainActor
class AppStateManager: ObservableObject {
    @Published var isOnboardingCompleted: Bool = false
    @Published var currentUser: UserProfile?
    @Published var isLoading: Bool = false
    @Published var errorMessage: String?
    
    // Navigation state
    @Published var selectedTab: TabSelection = .home
    @Published var navigationPath: NavigationPath = NavigationPath()
    
    // Feature flags for monetization
    @Published var isPremiumUser: Bool = false
    @Published var showAds: Bool = true
    
    private let userDefaults = UserDefaults.standard
    private let onboardingKey = "isOnboardingCompleted"
    private let premiumKey = "isPremiumUser"
    
    init() {
        DebugManager.shared.log("AppStateManager initialized", category: "AppState")
        loadUserState()
        DebugManager.shared.log("AppStateManager loaded - onboarding completed: \(isOnboardingCompleted)", category: "AppState")
    }
    
    // MARK: - User State Management
    
    func completeOnboarding() {
        DebugManager.shared.logUserAction("Complete Onboarding", context: "AppStateManager")
        isOnboardingCompleted = true
        userDefaults.set(true, forKey: onboardingKey)
    }
    
    func setCurrentUser(_ user: UserProfile) {
        currentUser = user
        saveUserProfile(user)
        DebugManager.shared.log("Current user set: \(user.name)", category: "AppState")
    }
    
    func updateUserProfile(_ user: UserProfile) {
        currentUser = user
        saveUserProfile(user)
        DebugManager.shared.log("User profile updated: \(user.name)", category: "AppState")
    }
    
    func logout() {
        currentUser = nil
        isOnboardingCompleted = false
        userDefaults.removeObject(forKey: onboardingKey)
        userDefaults.removeObject(forKey: premiumKey)
        DebugManager.shared.log("User logged out", category: "AppState")
    }
    
    // MARK: - Premium Features
    
    func upgradeToPremium() {
        isPremiumUser = true
        showAds = false
        userDefaults.set(true, forKey: premiumKey)
    }
    
    func downgradeFromPremium() {
        isPremiumUser = false
        showAds = true
        userDefaults.set(false, forKey: premiumKey)
    }
    
    // MARK: - Error Handling
    
    func setError(_ message: String) {
        errorMessage = message
        DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
            self.errorMessage = nil
        }
    }
    
    func clearError() {
        errorMessage = nil
    }
    
    // MARK: - Private Methods
    
    private func loadUserState() {
        isOnboardingCompleted = userDefaults.bool(forKey: onboardingKey)
        isPremiumUser = userDefaults.bool(forKey: premiumKey)
        showAds = !isPremiumUser
        
        // Load user profile if exists
        if let userData = userDefaults.data(forKey: "currentUser"),
           let user = try? JSONDecoder().decode(UserProfile.self, from: userData) {
            currentUser = user
        }
    }
    
    private func saveUserProfile(_ user: UserProfile) {
        if let userData = try? JSONEncoder().encode(user) {
            userDefaults.set(userData, forKey: "currentUser")
        }
    }
}

enum TabSelection: String, CaseIterable {
    case home = "Home"
    case movements = "Movements"
    case camera = "Camera"
    case progress = "Progress"
    case profile = "Profile"
    
    var icon: String {
        switch self {
        case .home: return "house.fill"
        case .movements: return "dumbbell.fill"
        case .camera: return "camera.fill"
        case .progress: return "chart.line.uptrend.xyaxis"
        case .profile: return "person.fill"
        }
    }
}
