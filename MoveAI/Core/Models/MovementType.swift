//
//  MovementType.swift
//  MoveAI
//
//  Created by Dave Mathew on 10/11/25.
//

import Foundation

enum MovementType: String, CaseIterable, Identifiable, Codable {
    case squat = "squat"
    case deadlift = "deadlift"
    case benchPress = "bench_press"
    
    var id: String { rawValue }
    
    var displayName: String {
        switch self {
        case .squat:
            return "Squat"
        case .deadlift:
            return "Deadlift"
        case .benchPress:
            return "Bench Press"
        }
    }
    
    var icon: String {
        switch self {
        case .squat:
            return "figure.strengthtraining.traditional"
        case .deadlift:
            return "figure.strengthtraining.traditional"
        case .benchPress:
            return "figure.strengthtraining.traditional"
        }
    }
    
    var description: String {
        switch self {
        case .squat:
            return "Lower body compound movement focusing on hip and knee extension"
        case .deadlift:
            return "Full body compound movement lifting from ground to standing"
        case .benchPress:
            return "Upper body compound movement pressing weight from chest"
        }
    }
}
