//
//  HealthAction.swift
//  MoveAI
//
//  Created by Dave Mathew on 10/11/25.
//

import Foundation

enum HealthAction: Equatable {
    case healthProfileRequested
    case healthProfileSucceeded(HealthProfile)
    case healthProfileFailed(String)
    case healthProfileConfirmed
}

