import Foundation
import Vision

// MARK: - Pose Keypoint Model
struct PoseKeypoint: Identifiable, Codable {
    let id: UUID
    let name: String
    let position: CGPoint
    let confidence: Float
    let timestamp: Date
    
    init(name: String, position: CGPoint, confidence: Float, timestamp: Date = Date()) {
        self.id = UUID()
        self.name = name
        self.position = position
        self.confidence = confidence
        self.timestamp = timestamp
    }
}

// MARK: - Pose Detection Result
struct PoseDetectionResult: Codable {
    let keypoints: [PoseKeypoint]
    let timestamp: Date
    let frameIndex: Int
    
    init(keypoints: [PoseKeypoint], frameIndex: Int) {
        self.keypoints = keypoints
        self.timestamp = Date()
        self.frameIndex = frameIndex
    }
}

// MARK: - Body Joint Names (matching Vision framework)
enum BodyJoint: String, CaseIterable {
    // Head and neck
    case nose = "nose"
    case leftEye = "leftEye"
    case rightEye = "rightEye"
    case leftEar = "leftEar"
    case rightEar = "rightEar"
    
    // Torso
    case neck = "neck"
    case leftShoulder = "leftShoulder"
    case rightShoulder = "rightShoulder"
    case leftElbow = "leftElbow"
    case rightElbow = "rightElbow"
    case leftWrist = "leftWrist"
    case rightWrist = "rightWrist"
    
    // Core
    case leftHip = "leftHip"
    case rightHip = "rightHip"
    case root = "root"
    
    // Legs
    case leftKnee = "leftKnee"
    case rightKnee = "rightKnee"
    case leftAnkle = "leftAnkle"
    case rightAnkle = "rightAnkle"
    case leftHeel = "leftHeel"
    case rightHeel = "rightHeel"
    case leftFootIndex = "leftFootIndex"
    case rightFootIndex = "rightFootIndex"
    
    var displayName: String {
        switch self {
        case .nose: return "Nose"
        case .leftEye, .rightEye: return "Eye"
        case .leftEar, .rightEar: return "Ear"
        case .neck: return "Neck"
        case .leftShoulder, .rightShoulder: return "Shoulder"
        case .leftElbow, .rightElbow: return "Elbow"
        case .leftWrist, .rightWrist: return "Wrist"
        case .leftHip, .rightHip: return "Hip"
        case .root: return "Root"
        case .leftKnee, .rightKnee: return "Knee"
        case .leftAnkle, .rightAnkle: return "Ankle"
        case .leftHeel, .rightHeel: return "Heel"
        case .leftFootIndex, .rightFootIndex: return "Foot"
        }
    }
    
    var isLeftSide: Bool {
        return rawValue.hasPrefix("left")
    }
    
    var isRightSide: Bool {
        return rawValue.hasPrefix("right")
    }
}
