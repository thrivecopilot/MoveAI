//
//  MovementType.swift
//  MoveAICore
//

import Foundation

enum MovementType: String, CaseIterable, Identifiable, Codable {
    case squat = "squat"
    case deadlift = "deadlift"
    case benchPress = "bench_press"
    case running = "running"
    case muayThai = "muay_thai"

    var id: String { rawValue }
}
