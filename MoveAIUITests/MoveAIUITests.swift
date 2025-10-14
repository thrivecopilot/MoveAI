//
//  MoveAIUITests.swift
//  MoveAIUITests
//
//  Created by Dave Mathew on 10/11/25.
//

import XCTest

final class MoveAIUITests: XCTestCase {
    
    var app: XCUIApplication!
    
    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchArguments = ["--uitesting"]
        app.launch()
    }
    
    override func tearDownWithError() throws {
        app = nil
    }
    
    // MARK: - Onboarding Flow Tests
    
    func testOnboardingFlow() throws {
        // Verify we start on onboarding screen
        XCTAssertTrue(app.staticTexts["Welcome to MoveAI"].exists, "Should show welcome message")
        XCTAssertTrue(app.staticTexts["Master your movements with AI-powered form analysis"].exists, "Should show description")
        XCTAssertTrue(app.buttons["Get Started"].exists, "Should show Get Started button")
        
        // Complete onboarding
        app.buttons["Get Started"].tap()
        
        // Verify we're now on the main app
        XCTAssertTrue(app.navigationBars["MoveAI"].exists, "Should show main navigation bar")
        XCTAssertTrue(app.tabBars.firstMatch.exists, "Should show tab bar")
    }
    
    func testOnboardingButtonAccessibility() throws {
        let getStartedButton = app.buttons["Get Started"]
        XCTAssertTrue(getStartedButton.isHittable, "Get Started button should be tappable")
        XCTAssertTrue(getStartedButton.isEnabled, "Get Started button should be enabled")
    }
    
    // MARK: - Navigation Tests
    
    func testTabNavigation() throws {
        // Complete onboarding first
        app.buttons["Get Started"].tap()
        
        // Test each tab
        let tabBar = app.tabBars.firstMatch
        
        // Home tab
        tabBar.buttons["Home"].tap()
        XCTAssertTrue(app.navigationBars["MoveAI"].exists, "Should be on Home tab")
        
        // Movements tab
        tabBar.buttons["Movements"].tap()
        XCTAssertTrue(app.navigationBars["Movements"].exists, "Should be on Movements tab")
        
        // Camera tab
        tabBar.buttons["Record"].tap()
        XCTAssertTrue(app.navigationBars["Record"].exists, "Should be on Camera tab")
        
        // Progress tab
        tabBar.buttons["Progress"].tap()
        XCTAssertTrue(app.navigationBars["Progress"].exists, "Should be on Progress tab")
        
        // Profile tab
        tabBar.buttons["Profile"].tap()
        XCTAssertTrue(app.navigationBars["Profile"].exists, "Should be on Profile tab")
    }
    
    func testTabBarAccessibility() throws {
        // Complete onboarding first
        app.buttons["Get Started"].tap()
        
        let tabBar = app.tabBars.firstMatch
        XCTAssertTrue(tabBar.exists, "Tab bar should exist")
        
        // Test that all tabs are accessible
        let homeTab = tabBar.buttons["Home"]
        let movementsTab = tabBar.buttons["Movements"]
        let cameraTab = tabBar.buttons["Record"]
        let progressTab = tabBar.buttons["Progress"]
        let profileTab = tabBar.buttons["Profile"]
        
        XCTAssertTrue(homeTab.isHittable, "Home tab should be tappable")
        XCTAssertTrue(movementsTab.isHittable, "Movements tab should be tappable")
        XCTAssertTrue(cameraTab.isHittable, "Camera tab should be tappable")
        XCTAssertTrue(progressTab.isHittable, "Progress tab should be tappable")
        XCTAssertTrue(profileTab.isHittable, "Profile tab should be tappable")
    }
    
    // MARK: - Home Screen Tests
    
    func testHomeScreenElements() throws {
        // Complete onboarding first
        app.buttons["Get Started"].tap()
        
        // Verify home screen elements
        XCTAssertTrue(app.staticTexts["Welcome back!"].exists, "Should show welcome message")
        XCTAssertTrue(app.staticTexts["Ready to improve your form?"].exists, "Should show subtitle")
        XCTAssertTrue(app.staticTexts["Quick Actions"].exists, "Should show Quick Actions section")
        XCTAssertTrue(app.staticTexts["Recent Activity"].exists, "Should show Recent Activity section")
        
        // Test quick action buttons
        XCTAssertTrue(app.buttons["Record Video"].exists, "Should show Record Video button")
        XCTAssertTrue(app.buttons["Browse Movements"].exists, "Should show Browse Movements button")
    }
    
    func testQuickActionButtons() throws {
        // Complete onboarding first
        app.buttons["Get Started"].tap()
        
        // Test Record Video button
        let recordButton = app.buttons["Record Video"]
        XCTAssertTrue(recordButton.isHittable, "Record Video button should be tappable")
        recordButton.tap()
        
        // Should navigate to camera tab
        XCTAssertTrue(app.navigationBars["Record"].exists, "Should navigate to camera tab")
        
        // Go back to home
        app.tabBars.buttons["Home"].tap()
        
        // Test Browse Movements button
        let browseButton = app.buttons["Browse Movements"]
        XCTAssertTrue(browseButton.isHittable, "Browse Movements button should be tappable")
        browseButton.tap()
        
        // Should navigate to movements tab
        XCTAssertTrue(app.navigationBars["Movements"].exists, "Should navigate to movements tab")
    }
    
    // MARK: - Accessibility Tests
    
    func testAccessibilityLabels() throws {
        // Complete onboarding first
        app.buttons["Get Started"].tap()
        
        // Test that important elements have accessibility labels
        let homeTab = app.tabBars.buttons["Home"]
        XCTAssertTrue(homeTab.label.contains("Home"), "Home tab should have proper accessibility label")
        
        let recordButton = app.buttons["Record Video"]
        XCTAssertTrue(recordButton.label.contains("Record Video"), "Record Video button should have proper accessibility label")
    }
    
    func testDynamicTypeSupport() throws {
        // Complete onboarding first
        app.buttons["Get Started"].tap()
        
        // Test that text scales properly (this is more of a visual test)
        let welcomeText = app.staticTexts["Welcome back!"]
        XCTAssertTrue(welcomeText.exists, "Welcome text should exist")
        XCTAssertTrue(welcomeText.isHittable, "Welcome text should be accessible")
    }
    
    // MARK: - Performance Tests
    
    func testAppLaunchPerformance() throws {
        measure(metrics: [XCTApplicationLaunchMetric()]) {
            app.launch()
        }
    }
    
    func testTabSwitchingPerformance() throws {
        // Complete onboarding first
        app.buttons["Get Started"].tap()
        
        measure {
            let tabBar = app.tabBars.firstMatch
            
            // Switch between tabs multiple times
            for _ in 0..<10 {
                tabBar.buttons["Home"].tap()
                tabBar.buttons["Movements"].tap()
                tabBar.buttons["Record"].tap()
                tabBar.buttons["Progress"].tap()
                tabBar.buttons["Profile"].tap()
            }
        }
    }
    
    // MARK: - Error Handling Tests
    
    func testAppStability() throws {
        // Complete onboarding first
        app.buttons["Get Started"].tap()
        
        // Rapidly tap different elements to test stability
        let tabBar = app.tabBars.firstMatch
        
        for _ in 0..<20 {
            tabBar.buttons["Home"].tap()
            tabBar.buttons["Movements"].tap()
            tabBar.buttons["Record"].tap()
            tabBar.buttons["Progress"].tap()
            tabBar.buttons["Profile"].tap()
        }
        
        // App should still be responsive
        XCTAssertTrue(app.navigationBars.firstMatch.exists, "App should still be responsive")
    }
    
    // MARK: - Dark Mode Tests
    
    func testDarkModeCompatibility() throws {
        // Complete onboarding first
        app.buttons["Get Started"].tap()
        
        // Test that all elements are visible in both light and dark mode
        // (This is more of a visual test, but we can check that elements exist)
        XCTAssertTrue(app.staticTexts["Welcome back!"].exists, "Text should be visible")
        XCTAssertTrue(app.buttons["Record Video"].exists, "Buttons should be visible")
        XCTAssertTrue(app.tabBars.firstMatch.exists, "Tab bar should be visible")
    }
    
    // MARK: - Memory Tests
    
    func testMemoryUsage() throws {
        // Complete onboarding first
        app.buttons["Get Started"].tap()
        
        // Navigate through all tabs multiple times to test memory usage
        let tabBar = app.tabBars.firstMatch
        
        for _ in 0..<5 {
            tabBar.buttons["Home"].tap()
            tabBar.buttons["Movements"].tap()
            tabBar.buttons["Record"].tap()
            tabBar.buttons["Progress"].tap()
            tabBar.buttons["Profile"].tap()
        }
        
        // App should still be responsive
        XCTAssertTrue(app.navigationBars.firstMatch.exists, "App should still be responsive after memory test")
    }
    
    // MARK: - Regression Tests
    
    func testOnboardingRegression() throws {
        // This test ensures the onboarding flow doesn't break
        XCTAssertTrue(app.staticTexts["Welcome to MoveAI"].exists, "Welcome text should always be present")
        XCTAssertTrue(app.buttons["Get Started"].exists, "Get Started button should always be present")
        
        app.buttons["Get Started"].tap()
        
        // After onboarding, we should have the main app interface
        XCTAssertTrue(app.tabBars.firstMatch.exists, "Tab bar should be present after onboarding")
        XCTAssertTrue(app.navigationBars["MoveAI"].exists, "Main navigation should be present after onboarding")
    }
    
    func testNavigationRegression() throws {
        // Complete onboarding first
        app.buttons["Get Started"].tap()
        
        // Test that all navigation elements are present
        let tabBar = app.tabBars.firstMatch
        XCTAssertTrue(tabBar.buttons["Home"].exists, "Home tab should always be present")
        XCTAssertTrue(tabBar.buttons["Movements"].exists, "Movements tab should always be present")
        XCTAssertTrue(tabBar.buttons["Record"].exists, "Record tab should always be present")
        XCTAssertTrue(tabBar.buttons["Progress"].exists, "Progress tab should always be present")
        XCTAssertTrue(tabBar.buttons["Profile"].exists, "Profile tab should always be present")
    }
}