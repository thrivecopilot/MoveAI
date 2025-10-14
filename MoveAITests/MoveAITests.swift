//
//  MoveAITests.swift
//  MoveAITests
//
//  Created by Dave Mathew on 10/11/25.
//

import XCTest
@testable import MoveAI

@MainActor
final class MoveAITests: XCTestCase {
    
    // MARK: - AppStateManager Tests
    
    func testAppStateManagerInitialization() throws {
        let appState = AppStateManager()
        
        // Test initial state
        XCTAssertFalse(appState.isOnboardingCompleted, "Onboarding should not be completed initially")
        XCTAssertFalse(appState.isPremiumUser, "User should not be premium initially")
        XCTAssertTrue(appState.showAds, "Ads should be shown initially")
        XCTAssertEqual(appState.selectedTab, .home, "Default tab should be home")
        XCTAssertNil(appState.currentUser, "Current user should be nil initially")
    }
    
    func testOnboardingCompletion() throws {
        let appState = AppStateManager()
        
        // Complete onboarding
        appState.completeOnboarding()
        
        XCTAssertTrue(appState.isOnboardingCompleted, "Onboarding should be completed")
    }
    
    func testPremiumUpgrade() throws {
        let appState = AppStateManager()
        
        // Upgrade to premium
        appState.upgradeToPremium()
        
        XCTAssertTrue(appState.isPremiumUser, "User should be premium")
        XCTAssertFalse(appState.showAds, "Ads should not be shown for premium users")
    }
    
    func testErrorHandling() throws {
        let appState = AppStateManager()
        
        // Set an error
        appState.setError("Test error message")
        
        XCTAssertEqual(appState.errorMessage, "Test error message", "Error message should be set")
        
        // Clear error
        appState.clearError()
        
        XCTAssertNil(appState.errorMessage, "Error message should be cleared")
    }
    
    // MARK: - MovementManager Tests
    
    func testMovementManagerInitialization() throws {
        let movementManager = MovementManager()
        
        // Test initial state
        XCTAssertFalse(movementManager.isLoading, "Should not be loading initially")
        XCTAssertNil(movementManager.errorMessage, "Should not have error message initially")
        XCTAssertNil(movementManager.selectedMovement, "Should not have selected movement initially")
        
        // Should have default movements loaded
        XCTAssertGreaterThan(movementManager.movements.count, 0, "Should have default movements loaded")
    }
    
    func testDefaultMovements() throws {
        let movementManager = MovementManager()
        
        // Check that we have the expected powerlifting movements
        let movementNames = movementManager.movements.map { $0.name }
        
        XCTAssertTrue(movementNames.contains("Barbell Back Squat"), "Should contain Barbell Back Squat")
        XCTAssertTrue(movementNames.contains("Conventional Deadlift"), "Should contain Conventional Deadlift")
        XCTAssertTrue(movementNames.contains("Barbell Bench Press"), "Should contain Barbell Bench Press")
        XCTAssertTrue(movementNames.contains("Overhead Press"), "Should contain Overhead Press")
        XCTAssertTrue(movementNames.contains("Barbell Row"), "Should contain Barbell Row")
    }
    
    func testMovementSearch() throws {
        let movementManager = MovementManager()
        
        // Test search functionality
        let squatResults = movementManager.searchMovements("squat")
        XCTAssertGreaterThan(squatResults.count, 0, "Should find squat movements")
        
        let deadliftResults = movementManager.searchMovements("deadlift")
        XCTAssertGreaterThan(deadliftResults.count, 0, "Should find deadlift movements")
        
        let emptyResults = movementManager.searchMovements("")
        XCTAssertEqual(emptyResults.count, movementManager.movements.count, "Empty search should return all movements")
    }
    
    func testMovementFiltering() throws {
        let movementManager = MovementManager()
        
        // Test category filtering
        let powerliftingMovements = movementManager.getMovementsByCategory(.powerlifting)
        XCTAssertGreaterThan(powerliftingMovements.count, 0, "Should have powerlifting movements")
        
        // Test difficulty filtering
        let intermediateMovements = movementManager.getMovementsByDifficulty(.intermediate)
        XCTAssertGreaterThan(intermediateMovements.count, 0, "Should have intermediate movements")
    }
    
    func testGoalManagement() throws {
        let movementManager = MovementManager()
        
        // Create a test goal
        let testMovement = movementManager.movements.first!
        let testGoal = MovementGoal(movementId: testMovement.id, priority: .high, targetScore: 85.0)
        
        // Add goal
        movementManager.addGoal(testGoal)
        
        XCTAssertEqual(movementManager.userGoals.count, 1, "Should have one goal")
        XCTAssertEqual(movementManager.userGoals.first?.movementId, testMovement.id, "Goal should reference correct movement")
        
        // Test getting goals for movement
        let goalsForMovement = movementManager.getGoalsForMovement(testMovement.id)
        XCTAssertEqual(goalsForMovement.count, 1, "Should find goal for movement")
        
        // Update goal
        var updatedGoal = testGoal
        updatedGoal.targetScore = 90.0
        movementManager.updateGoal(updatedGoal)
        
        XCTAssertEqual(movementManager.userGoals.first?.targetScore, 90.0, "Goal should be updated")
        
        // Delete goal
        movementManager.deleteGoal(testGoal)
        XCTAssertEqual(movementManager.userGoals.count, 0, "Should have no goals after deletion")
    }
    
    // MARK: - Model Tests
    
    func testUserProfileModel() throws {
        let profile = UserProfile(
            height: 180.0,
            weight: 80.0,
            age: 25,
            experienceLevel: .intermediate
        )
        
        XCTAssertEqual(profile.height, 180.0, "Height should be set correctly")
        XCTAssertEqual(profile.weight, 80.0, "Weight should be set correctly")
        XCTAssertEqual(profile.age, 25, "Age should be set correctly")
        XCTAssertEqual(profile.experienceLevel, .intermediate, "Experience level should be set correctly")
        XCTAssertTrue(profile.goals.isEmpty, "Goals should be empty initially")
    }
    
    func testMovementModel() throws {
        let movement = Movement(
            name: "Test Movement",
            category: .powerlifting,
            description: "Test description",
            idealForm: IdealForm(),
            difficulty: .beginner,
            equipment: [.barbell, .plates]
        )
        
        XCTAssertEqual(movement.name, "Test Movement", "Name should be set correctly")
        XCTAssertEqual(movement.category, .powerlifting, "Category should be set correctly")
        XCTAssertEqual(movement.difficulty, .beginner, "Difficulty should be set correctly")
        XCTAssertEqual(movement.equipment.count, 2, "Should have 2 equipment items")
        XCTAssertTrue(movement.equipment.contains(.barbell), "Should contain barbell")
        XCTAssertTrue(movement.equipment.contains(.plates), "Should contain plates")
    }
    
    func testKeyPointModel() throws {
        let keyPoint = KeyPoint(
            joint: .knee,
            position: .flexed,
            importance: .high,
            mentalCue: "Keep knees over toes",
            correctiveExercise: "Box squats",
            description: "Maintain proper knee alignment"
        )
        
        XCTAssertEqual(keyPoint.joint, .knee, "Joint should be set correctly")
        XCTAssertEqual(keyPoint.position, .flexed, "Position should be set correctly")
        XCTAssertEqual(keyPoint.importance, .high, "Importance should be set correctly")
        XCTAssertEqual(keyPoint.mentalCue, "Keep knees over toes", "Mental cue should be set correctly")
    }
    
    // MARK: - Enum Tests
    
    func testExperienceLevelEnum() throws {
        XCTAssertEqual(ExperienceLevel.allCases.count, 4, "Should have 4 experience levels")
        
        let beginner = ExperienceLevel.beginner
        XCTAssertEqual(beginner.description, "New to powerlifting", "Beginner description should be correct")
        
        let expert = ExperienceLevel.expert
        XCTAssertEqual(expert.description, "Competitive level", "Expert description should be correct")
    }
    
    func testDifficultyLevelEnum() throws {
        XCTAssertEqual(DifficultyLevel.allCases.count, 4, "Should have 4 difficulty levels")
        
        let beginner = DifficultyLevel.beginner
        XCTAssertEqual(beginner.color, "green", "Beginner color should be green")
        
        let expert = DifficultyLevel.expert
        XCTAssertEqual(expert.color, "red", "Expert color should be red")
    }
    
    func testJointTypeEnum() throws {
        XCTAssertEqual(JointType.allCases.count, 9, "Should have 9 joint types")
        
        let knee = JointType.knee
        XCTAssertEqual(knee.icon, "circle.fill", "Knee icon should be correct")
        
        let spine = JointType.spine
        XCTAssertEqual(spine.icon, "line.3.horizontal", "Spine icon should be correct")
    }
    
    // MARK: - Performance Tests
    
    func testMovementManagerPerformance() throws {
        let movementManager = MovementManager()
        
        // Test search performance
        measure {
            for _ in 0..<100 {
                _ = movementManager.searchMovements("squat")
            }
        }
    }
    
    func testModelCreationPerformance() throws {
        measure {
            for _ in 0..<1000 {
                _ = UserProfile(
                    height: Double.random(in: 150...200),
                    weight: Double.random(in: 50...150),
                    age: Int.random(in: 18...65),
                    experienceLevel: ExperienceLevel.allCases.randomElement()!
                )
            }
        }
    }
    
    // MARK: - Integration Tests
    
    func testAppStateAndMovementManagerIntegration() throws {
        let appState = AppStateManager()
        let movementManager = MovementManager()
        
        // Test that both managers can work together
        appState.completeOnboarding()
        XCTAssertTrue(appState.isOnboardingCompleted, "Onboarding should be completed")
        
        // Test that movement manager still works after app state changes
        let movements = movementManager.movements
        XCTAssertGreaterThan(movements.count, 0, "Should still have movements")
        
        // Test tab switching
        appState.selectedTab = .movements
        XCTAssertEqual(appState.selectedTab, .movements, "Tab should be switched to movements")
    }
    
    // MARK: - Error Handling Tests
    
    func testInvalidDataHandling() throws {
        let movementManager = MovementManager()
        
        // Test with invalid movement ID
        let invalidGoal = MovementGoal(movementId: UUID(), priority: .high, targetScore: 85.0)
        movementManager.addGoal(invalidGoal)
        
        let goalsForInvalidMovement = movementManager.getGoalsForMovement(invalidGoal.movementId)
        XCTAssertEqual(goalsForInvalidMovement.count, 1, "Should still add goal even with invalid movement ID")
    }
    
    // MARK: - Data Persistence Tests
    
    func testUserDefaultsPersistence() throws {
        let appState = AppStateManager()
        
        // Complete onboarding
        appState.completeOnboarding()
        
        // Create new instance to test persistence
        let newAppState = AppStateManager()
        
        // Note: This test might fail in test environment due to UserDefaults isolation
        // In a real app, this would test that the state persists between app launches
        XCTAssertTrue(newAppState.isOnboardingCompleted, "Onboarding state should persist")
    }
}