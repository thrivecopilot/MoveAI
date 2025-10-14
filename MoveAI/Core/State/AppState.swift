//
//  AppState.swift
//  MoveAI
//
//  Created by Dave Mathew on 10/11/25.
//

import Foundation

struct AppState: Equatable {
    var healthFetchState: HealthFetchState = .idle
    var route: Route = .onboarding
    
    enum Route: Equatable {
        case onboarding
        case healthFetch
        case healthConfirm
        case home
    }
}

