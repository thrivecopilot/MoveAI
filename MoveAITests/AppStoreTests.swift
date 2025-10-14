//
//  AppStoreTests.swift
//  MoveAI
//
//  Created by Dave Mathew on 10/11/25.
//

import XCTest
@testable import MoveAI

@MainActor
class AppStoreTests: XCTestCase {
    var store: AppStore!
    
    override func setUp() {
        super.setUp()
        store = AppStore(services: .demo)
    }
    
    override func tearDown() {
        store = nil
        super.tearDown()
    }
    
    func testHealthProfileRequested() {
        // Given
        XCTAssertEqual(store.state.healthFetchState, .idle)
        
        // When
        store.send(.health(.healthProfileRequested))
        
        // Then
        XCTAssertEqual(store.state.healthFetchState, .loading)
    }
    
    func testHealthProfileSucceeded() {
        // Given
        let profile = HealthProfile.demo
        
        // When
        store.send(.health(.healthProfileSucceeded(profile)))
        
        // Then
        XCTAssertEqual(store.state.healthFetchState, .loaded(profile))
        XCTAssertEqual(store.state.route, .healthConfirm)
    }
    
    func testHealthProfileFailed() {
        // Given
        let errorMessage = "Test error"
        
        // When
        store.send(.health(.healthProfileFailed(errorMessage)))
        
        // Then
        XCTAssertEqual(store.state.healthFetchState, .failed(errorMessage))
    }
    
    func testHealthProfileConfirmed() {
        // Given
        let profile = HealthProfile.demo
        
        // When
        store.send(.health(.healthProfileConfirmed))
        
        // Then
        XCTAssertEqual(store.state.route, .home)
    }
    
    func testNavigationActions() {
        // Test navigateToHealthFetch
        store.send(.navigation(.navigateToHealthFetch))
        XCTAssertEqual(store.state.route, .healthFetch)
        
        // Test navigateToHealthConfirm
        store.send(.navigation(.navigateToHealthConfirm))
        XCTAssertEqual(store.state.route, .healthConfirm)
        
        // Test navigateToHome
        store.send(.navigation(.navigateToHome))
        XCTAssertEqual(store.state.route, .home)
    }
}
