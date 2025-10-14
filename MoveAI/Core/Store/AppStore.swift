//
//  AppStore.swift
//  MoveAI
//
//  Created by Dave Mathew on 10/11/25.
//

import Foundation

@MainActor
class AppStore: ObservableObject {
    @Published private(set) var state: AppState
    
    private let services: Services
    
    init(services: Services = .live) {
        self.state = AppState()
        self.services = services
    }
    
    func send(_ action: AppAction) {
        switch action {
        case .health(let healthAction):
            handleHealthAction(healthAction)
        case .navigation(let routeAction):
            handleRouteAction(routeAction)
        }
    }
    
    private func handleHealthAction(_ action: HealthAction) {
        switch action {
        case .healthProfileRequested:
            state.healthFetchState = .loading
            
            Task {
                do {
                    let profile = try await services.health.fetchProfile()
                    await MainActor.run {
                        state.healthFetchState = .loaded(profile)
                        state.route = .healthConfirm
                    }
                } catch {
                    await MainActor.run {
                        state.healthFetchState = .failed(error.localizedDescription)
                    }
                }
            }
            
        case .healthProfileSucceeded(let profile):
            state.healthFetchState = .loaded(profile)
            state.route = .healthConfirm
            
        case .healthProfileFailed(let error):
            state.healthFetchState = .failed(error)
            
        case .healthProfileConfirmed:
            state.route = .home
        }
    }
    
    private func handleRouteAction(_ action: RouteAction) {
        switch action {
        case .navigateToHealthFetch:
            state.route = .healthFetch
        case .navigateToHealthConfirm:
            state.route = .healthConfirm
        case .navigateToHome:
            state.route = .home
        }
    }
}

// MARK: - Services
struct Services {
    let health: HealthServiceProtocol
    
    static let live = Services(
        health: HealthService()
    )
    
    static let demo = Services(
        health: DemoHealthService()
    )
}

