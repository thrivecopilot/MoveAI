//
//  Movement.swift
//  MoveAI
//
//  Created by Dave Mathew on 10/11/25.
//

import Foundation

struct Movement: Codable, Identifiable {
    let id: UUID
    var name: String
    var category: MovementCategory
    var description: String
    var keyPoints: [KeyPoint]
    var idealForm: IdealForm
    var difficulty: DifficultyLevel
    var equipment: [Equipment]
    var instructions: [String]
    var commonMistakes: [CommonMistake]
    
    init(
        id: UUID = UUID(),
        name: String,
        category: MovementCategory,
        description: String,
        keyPoints: [KeyPoint] = [],
        idealForm: IdealForm,
        difficulty: DifficultyLevel = .intermediate,
        equipment: [Equipment] = [],
        instructions: [String] = [],
        commonMistakes: [CommonMistake] = []
    ) {
        self.id = id
        self.name = name
        self.category = category
        self.description = description
        self.keyPoints = keyPoints
        self.idealForm = idealForm
        self.difficulty = difficulty
        self.equipment = equipment
        self.instructions = instructions
        self.commonMistakes = commonMistakes
    }
}

enum MovementCategory: String, CaseIterable, Codable {
    case powerlifting = "Powerlifting"
    case olympicLifting = "Olympic Lifting"
    case functional = "Functional"
    case accessory = "Accessory"
    case cardio = "Cardio"
    
    var icon: String {
        switch self {
        case .powerlifting: return "dumbbell.fill"
        case .olympicLifting: return "bolt.fill"
        case .functional: return "figure.walk"
        case .accessory: return "plus.circle.fill"
        case .cardio: return "heart.fill"
        }
    }
}

enum DifficultyLevel: String, CaseIterable, Codable {
    case beginner = "Beginner"
    case intermediate = "Intermediate"
    case advanced = "Advanced"
    case expert = "Expert"
    
    var color: String {
        switch self {
        case .beginner: return "green"
        case .intermediate: return "blue"
        case .advanced: return "orange"
        case .expert: return "red"
        }
    }
}

enum Equipment: String, CaseIterable, Codable {
    case barbell = "Barbell"
    case dumbbell = "Dumbbell"
    case kettlebell = "Kettlebell"
    case plates = "Weight Plates"
    case rack = "Power Rack"
    case bench = "Bench"
    case belt = "Weight Belt"
    case shoes = "Weightlifting Shoes"
    case chalk = "Chalk"
    case none = "Bodyweight"
    
    var icon: String {
        switch self {
        case .barbell: return "minus.rectangle.fill"
        case .dumbbell: return "circle.fill"
        case .kettlebell: return "oval.fill"
        case .plates: return "circle.grid.cross.fill"
        case .rack: return "rectangle.3.group.fill"
        case .bench: return "rectangle.fill"
        case .belt: return "rectangle.portrait.fill"
        case .shoes: return "shoe.2.fill"
        case .chalk: return "hand.raised.fill"
        case .none: return "person.fill"
        }
    }
}

struct KeyPoint: Codable, Identifiable {
    let id: UUID
    var joint: JointType
    var position: JointPosition
    var importance: ImportanceLevel
    var mentalCue: String
    var correctiveExercise: String?
    var description: String
    
    init(
        id: UUID = UUID(),
        joint: JointType,
        position: JointPosition,
        importance: ImportanceLevel,
        mentalCue: String,
        correctiveExercise: String? = nil,
        description: String
    ) {
        self.id = id
        self.joint = joint
        self.position = position
        self.importance = importance
        self.mentalCue = mentalCue
        self.correctiveExercise = correctiveExercise
        self.description = description
    }
}

enum JointType: String, CaseIterable, Codable {
    case ankle = "Ankle"
    case knee = "Knee"
    case hip = "Hip"
    case shoulder = "Shoulder"
    case elbow = "Elbow"
    case wrist = "Wrist"
    case neck = "Neck"
    case spine = "Spine"
    case chest = "Chest"
    
    var icon: String {
        switch self {
        case .ankle: return "circle.fill"
        case .knee: return "circle.fill"
        case .hip: return "circle.fill"
        case .shoulder: return "circle.fill"
        case .elbow: return "circle.fill"
        case .wrist: return "circle.fill"
        case .neck: return "circle.fill"
        case .spine: return "line.3.horizontal"
        case .chest: return "heart.fill"
        }
    }
}

enum JointPosition: String, CaseIterable, Codable {
    case neutral = "Neutral"
    case flexed = "Flexed"
    case extended = "Extended"
    case abducted = "Abducted"
    case adducted = "Adducted"
    case rotated = "Rotated"
    case elevated = "Elevated"
    case depressed = "Depressed"
    case retracted = "Retracted"
}

enum ImportanceLevel: String, CaseIterable, Codable {
    case low = "Low"
    case medium = "Medium"
    case high = "High"
    case critical = "Critical"
    
    var color: String {
        switch self {
        case .low: return "green"
        case .medium: return "blue"
        case .high: return "orange"
        case .critical: return "red"
        }
    }
    
    var description: String {
        switch self {
        case .low: return "Minor form issue"
        case .medium: return "Moderate form issue"
        case .high: return "Significant form issue"
        case .critical: return "Dangerous form issue"
        }
    }
}

struct IdealForm: Codable {
    var jointAngles: [JointType: Double] // Target angles in degrees
    var bodyPositions: [String: Double] // Relative positions
    var timing: [String: TimeInterval] // Movement timing
    var breathingPattern: String
    var setupInstructions: [String]
    
    init(
        jointAngles: [JointType: Double] = [:],
        bodyPositions: [String: Double] = [:],
        timing: [String: TimeInterval] = [:],
        breathingPattern: String = "",
        setupInstructions: [String] = []
    ) {
        self.jointAngles = jointAngles
        self.bodyPositions = bodyPositions
        self.timing = timing
        self.breathingPattern = breathingPattern
        self.setupInstructions = setupInstructions
    }
}

struct CommonMistake: Codable, Identifiable {
    let id: UUID
    var name: String
    var description: String
    var severity: IssueSeverity
    var affectedJoints: [JointType]
    var correction: String
    var prevention: String
    
    init(
        id: UUID = UUID(),
        name: String,
        description: String,
        severity: IssueSeverity,
        affectedJoints: [JointType],
        correction: String,
        prevention: String
    ) {
        self.id = id
        self.name = name
        self.description = description
        self.severity = severity
        self.affectedJoints = affectedJoints
        self.correction = correction
        self.prevention = prevention
    }
}

enum IssueSeverity: String, CaseIterable, Codable {
    case minor = "Minor"
    case moderate = "Moderate"
    case severe = "Severe"
    case dangerous = "Dangerous"
    
    var color: String {
        switch self {
        case .minor: return "green"
        case .moderate: return "yellow"
        case .severe: return "orange"
        case .dangerous: return "red"
        }
    }
}
