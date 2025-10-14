//
//  VideoAnalysis.swift
//  MoveAI
//
//  Created by Dave Mathew on 10/11/25.
//

import Foundation
import CoreGraphics

struct VideoRecording: Codable, Identifiable {
    let id: UUID
    var movementId: UUID
    var fileURL: URL
    var duration: TimeInterval
    var qualityScore: Double
    var cameraAngle: CameraAngle
    var createdAt: Date
    var analysisStatus: AnalysisStatus
    var analysis: PoseAnalysis?
    
    init(
        id: UUID = UUID(),
        movementId: UUID,
        fileURL: URL,
        duration: TimeInterval,
        qualityScore: Double = 0.0,
        cameraAngle: CameraAngle = .side,
        createdAt: Date = Date(),
        analysisStatus: AnalysisStatus = .pending,
        analysis: PoseAnalysis? = nil
    ) {
        self.id = id
        self.movementId = movementId
        self.fileURL = fileURL
        self.duration = duration
        self.qualityScore = qualityScore
        self.cameraAngle = cameraAngle
        self.createdAt = createdAt
        self.analysisStatus = analysisStatus
        self.analysis = analysis
    }
}

enum CameraAngle: String, CaseIterable, Codable {
    case front = "Front"
    case side = "Side"
    case back = "Back"
    case diagonal = "Diagonal"
    
    var description: String {
        switch self {
        case .front: return "Camera positioned in front of the lifter"
        case .side: return "Camera positioned to the side of the lifter"
        case .back: return "Camera positioned behind the lifter"
        case .diagonal: return "Camera positioned at a diagonal angle"
        }
    }
    
    var icon: String {
        switch self {
        case .front: return "camera.fill"
        case .side: return "camera.rotate.fill"
        case .back: return "camera.viewfinder"
        case .diagonal: return "camera.metering.matrix"
        }
    }
}

enum AnalysisStatus: String, CaseIterable, Codable {
    case pending = "Pending"
    case processing = "Processing"
    case completed = "Completed"
    case failed = "Failed"
    
    var color: String {
        switch self {
        case .pending: return "gray"
        case .processing: return "blue"
        case .completed: return "green"
        case .failed: return "red"
        }
    }
    
    var icon: String {
        switch self {
        case .pending: return "clock.fill"
        case .processing: return "gear.circle.fill"
        case .completed: return "checkmark.circle.fill"
        case .failed: return "xmark.circle.fill"
        }
    }
}

struct PoseAnalysis: Codable {
    var frameAnalyses: [FrameAnalysis]
    var overallScore: Double
    var keyIssues: [FormIssue]
    var recommendations: [Recommendation]
    var progressMetrics: ProgressMetrics
    var processingTime: TimeInterval
    var analyzedAt: Date
    
    init(
        frameAnalyses: [FrameAnalysis] = [],
        overallScore: Double = 0.0,
        keyIssues: [FormIssue] = [],
        recommendations: [Recommendation] = [],
        progressMetrics: ProgressMetrics = ProgressMetrics(),
        processingTime: TimeInterval = 0.0,
        analyzedAt: Date = Date()
    ) {
        self.frameAnalyses = frameAnalyses
        self.overallScore = overallScore
        self.keyIssues = keyIssues
        self.recommendations = recommendations
        self.progressMetrics = progressMetrics
        self.processingTime = processingTime
        self.analyzedAt = analyzedAt
    }
}

struct FrameAnalysis: Codable, Identifiable {
    let id: UUID
    var timestamp: TimeInterval
    var jointPositions: [JointType: CGPoint]
    var jointAngles: [JointType: Double]
    var deviations: [JointDeviation]
    var frameScore: Double
    var confidence: Double
    
    init(
        id: UUID = UUID(),
        timestamp: TimeInterval,
        jointPositions: [JointType: CGPoint] = [:],
        jointAngles: [JointType: Double] = [:],
        deviations: [JointDeviation] = [],
        frameScore: Double = 0.0,
        confidence: Double = 0.0
    ) {
        self.id = id
        self.timestamp = timestamp
        self.jointPositions = jointPositions
        self.jointAngles = jointAngles
        self.deviations = deviations
        self.frameScore = frameScore
        self.confidence = confidence
    }
}

struct JointDeviation: Codable, Identifiable {
    let id: UUID
    var joint: JointType
    var expectedAngle: Double
    var actualAngle: Double
    var deviation: Double
    var severity: DeviationSeverity
    
    init(
        id: UUID = UUID(),
        joint: JointType,
        expectedAngle: Double,
        actualAngle: Double,
        severity: DeviationSeverity = .minor
    ) {
        self.id = id
        self.joint = joint
        self.expectedAngle = expectedAngle
        self.actualAngle = actualAngle
        self.deviation = abs(actualAngle - expectedAngle)
        self.severity = severity
    }
}

enum DeviationSeverity: String, CaseIterable, Codable {
    case minor = "Minor"
    case moderate = "Moderate"
    case major = "Major"
    case critical = "Critical"
    
    var color: String {
        switch self {
        case .minor: return "green"
        case .moderate: return "yellow"
        case .major: return "orange"
        case .critical: return "red"
        }
    }
    
    var threshold: Double {
        switch self {
        case .minor: return 5.0
        case .moderate: return 15.0
        case .major: return 30.0
        case .critical: return 45.0
        }
    }
}

struct FormIssue: Codable, Identifiable {
    let id: UUID
    var severity: IssueSeverity
    var description: String
    var mentalCue: String
    var correctiveExercise: String?
    var affectedJoints: [JointType]
    var frequency: Double // How often this issue occurs (0.0 to 1.0)
    var impact: Double // Impact on overall score (0.0 to 1.0)
    
    init(
        id: UUID = UUID(),
        severity: IssueSeverity,
        description: String,
        mentalCue: String,
        correctiveExercise: String? = nil,
        affectedJoints: [JointType],
        frequency: Double = 0.0,
        impact: Double = 0.0
    ) {
        self.id = id
        self.severity = severity
        self.description = description
        self.mentalCue = mentalCue
        self.correctiveExercise = correctiveExercise
        self.affectedJoints = affectedJoints
        self.frequency = frequency
        self.impact = impact
    }
}

struct Recommendation: Codable, Identifiable {
    let id: UUID
    var type: RecommendationType
    var title: String
    var description: String
    var priority: RecommendationPriority
    var actionItems: [String]
    var resources: [String] // URLs or references to additional resources
    
    init(
        id: UUID = UUID(),
        type: RecommendationType,
        title: String,
        description: String,
        priority: RecommendationPriority = .medium,
        actionItems: [String] = [],
        resources: [String] = []
    ) {
        self.id = id
        self.type = type
        self.title = title
        self.description = description
        self.priority = priority
        self.actionItems = actionItems
        self.resources = resources
    }
}

enum RecommendationType: String, CaseIterable, Codable {
    case technique = "Technique"
    case mobility = "Mobility"
    case strength = "Strength"
    case recovery = "Recovery"
    case equipment = "Equipment"
    case programming = "Programming"
    
    var icon: String {
        switch self {
        case .technique: return "figure.walk"
        case .mobility: return "arrow.up.and.down"
        case .strength: return "dumbbell.fill"
        case .recovery: return "bed.double.fill"
        case .equipment: return "wrench.and.screwdriver.fill"
        case .programming: return "calendar"
        }
    }
}

enum RecommendationPriority: String, CaseIterable, Codable {
    case low = "Low"
    case medium = "Medium"
    case high = "High"
    case urgent = "Urgent"
    
    var color: String {
        switch self {
        case .low: return "green"
        case .medium: return "blue"
        case .high: return "orange"
        case .urgent: return "red"
        }
    }
}

struct ProgressMetrics: Codable {
    var scoreTrend: [ScoreEntry]
    var improvementRate: Double
    var consistencyScore: Double
    var masteredCues: [String]
    var currentFocus: [String]
    var lastAnalysis: Date?
    
    init(
        scoreTrend: [ScoreEntry] = [],
        improvementRate: Double = 0.0,
        consistencyScore: Double = 0.0,
        masteredCues: [String] = [],
        currentFocus: [String] = [],
        lastAnalysis: Date? = nil
    ) {
        self.scoreTrend = scoreTrend
        self.improvementRate = improvementRate
        self.consistencyScore = consistencyScore
        self.masteredCues = masteredCues
        self.currentFocus = currentFocus
        self.lastAnalysis = lastAnalysis
    }
}

struct ScoreEntry: Codable, Identifiable {
    let id: UUID
    var date: Date
    var score: Double
    var videoId: UUID
    var notes: String?
    
    init(
        id: UUID = UUID(),
        date: Date,
        score: Double,
        videoId: UUID,
        notes: String? = nil
    ) {
        self.id = id
        self.date = date
        self.score = score
        self.videoId = videoId
        self.notes = notes
    }
}

