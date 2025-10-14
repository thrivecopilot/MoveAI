//
//  HealthFetchState.swift
//  MoveAI
//
//  Created by Dave Mathew on 10/11/25.
//

import Foundation

enum HealthFetchState: Equatable {
    case idle
    case loading
    case loaded(HealthProfile)
    case failed(String)
    
    var isLoading: Bool {
        if case .loading = self { return true }
        return false
    }
    
    var isLoaded: Bool {
        if case .loaded = self { return true }
        return false
    }
    
    var isFailed: Bool {
        if case .failed = self { return true }
        return false
    }
    
    var profile: HealthProfile? {
        if case .loaded(let profile) = self { return profile }
        return nil
    }
    
    var errorMessage: String? {
        if case .failed(let message) = self { return message }
        return nil
    }
}

