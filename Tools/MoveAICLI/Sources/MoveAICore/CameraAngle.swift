//
//  CameraAngle.swift
//  MoveAICore
//
//  Camera angle enum for analysis.
//

import Foundation

enum CameraAngle: String, CaseIterable, Codable {
    case front = "Front"
    case side = "Side"
    case back = "Back"
    case diagonal = "Diagonal"
}
