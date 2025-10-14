//
//  AppAction.swift
//  MoveAI
//
//  Created by Dave Mathew on 10/11/25.
//

import Foundation

enum AppAction: Equatable {
    case health(HealthAction)
    case navigation(RouteAction)
}

enum RouteAction: Equatable {
    case navigateToHealthFetch
    case navigateToHealthConfirm
    case navigateToHome
}

