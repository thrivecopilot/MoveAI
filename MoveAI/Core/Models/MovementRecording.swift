//
//  MovementRecording.swift
//  MoveAI
//
//  Created by Dave Mathew on 10/11/25.
//

import Foundation
import UIKit

struct MovementRecording: Identifiable, Codable {
    let id: UUID
    let movementType: MovementType
    let videoURL: URL
    let timestamp: Date
    let duration: TimeInterval
    var analysisResult: AnalysisResult?
    
    init(movementType: MovementType, videoURL: URL, duration: TimeInterval) {
        self.id = UUID()
        self.movementType = movementType
        self.videoURL = videoURL
        self.timestamp = Date()
        self.duration = duration
        self.analysisResult = nil
    }
}

struct AnalysisResult: Codable {
    let score: Double // 0-100 overall form score
    let feedback: [FormFeedback]
    let timestamp: Date
    
    init(score: Double, feedback: [FormFeedback]) {
        self.score = score
        self.feedback = feedback
        self.timestamp = Date()
    }
}

struct FormFeedback: Codable, Identifiable {
    let id: UUID
    let category: FeedbackCategory
    let message: String
    let severity: FeedbackSeverity
    let timestamp: TimeInterval // When in the video this applies
    
    init(category: FeedbackCategory, message: String, severity: FeedbackSeverity, timestamp: TimeInterval) {
        self.id = UUID()
        self.category = category
        self.message = message
        self.severity = severity
        self.timestamp = timestamp
    }
}

enum FeedbackCategory: String, CaseIterable, Codable {
    case posture = "posture"
    case rangeOfMotion = "range_of_motion"
    case tempo = "tempo"
    case stability = "stability"
    case safety = "safety"
    
    var displayName: String {
        switch self {
        case .posture:
            return "Posture"
        case .rangeOfMotion:
            return "Range of Motion"
        case .tempo:
            return "Tempo"
        case .stability:
            return "Stability"
        case .safety:
            return "Safety"
        }
    }
    
    var icon: String {
        switch self {
        case .posture:
            return "figure.walk"
        case .rangeOfMotion:
            return "arrow.up.arrow.down"
        case .tempo:
            return "metronome"
        case .stability:
            return "balance"
        case .safety:
            return "exclamationmark.triangle"
        }
    }
}

enum FeedbackSeverity: String, CaseIterable, Codable {
    case excellent = "excellent"
    case good = "good"
    case warning = "warning"
    case critical = "critical"
    
    var displayName: String {
        switch self {
        case .excellent:
            return "Excellent"
        case .good:
            return "Good"
        case .warning:
            return "Needs Improvement"
        case .critical:
            return "Critical Issue"
        }
    }
    
    var color: String {
        switch self {
        case .excellent:
            return "green"
        case .good:
            return "blue"
        case .warning:
            return "orange"
        case .critical:
            return "red"
        }
    }
}

