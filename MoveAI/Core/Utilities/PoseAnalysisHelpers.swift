//
//  PoseAnalysisHelpers.swift
//  MoveAI
//
//  Created by Dave Mathew on 10/11/25.
//

import Foundation
import CoreGraphics
import Vision

/// Utility functions for pose analysis calculations
enum PoseAnalysisHelpers {
    
    // MARK: - Keypoint Name Mapping
    
    /// Map Vision framework joint name to consistent string representation
    /// Ensures we always use the same string format (e.g., "leftHip", "rightKnee")
    static func jointNameToString(_ jointName: VNHumanBodyPoseObservation.JointName) -> String {
        switch jointName {
        case .nose: return "nose"
        case .leftEye: return "leftEye"
        case .rightEye: return "rightEye"
        case .leftEar: return "leftEar"
        case .rightEar: return "rightEar"
        case .neck: return "neck"
        case .leftShoulder: return "leftShoulder"
        case .rightShoulder: return "rightShoulder"
        case .leftElbow: return "leftElbow"
        case .rightElbow: return "rightElbow"
        case .leftWrist: return "leftWrist"
        case .rightWrist: return "rightWrist"
        case .leftHip: return "leftHip"
        case .rightHip: return "rightHip"
        case .root: return "root"
        case .leftKnee: return "leftKnee"
        case .rightKnee: return "rightKnee"
        case .leftAnkle: return "leftAnkle"
        case .rightAnkle: return "rightAnkle"
        default:
            // Fallback for any cases we might have missed
            return String(describing: jointName)
        }
    }
    
    // MARK: - Angle Calculations
    
    /// Calculate the angle between three points (point2 is the vertex)
    /// Returns angle in degrees (0-180)
    static func calculateAngle(point1: CGPoint, point2: CGPoint, point3: CGPoint) -> Double {
        let vector1 = CGPoint(x: point1.x - point2.x, y: point1.y - point2.y)
        let vector2 = CGPoint(x: point3.x - point2.x, y: point3.y - point2.y)
        
        let dotProduct = vector1.x * vector2.x + vector1.y * vector2.y
        let magnitude1 = sqrt(vector1.x * vector1.x + vector1.y * vector1.y)
        let magnitude2 = sqrt(vector2.x * vector2.x + vector2.y * vector2.y)
        
        guard magnitude1 > 0 && magnitude2 > 0 else { return 0 }
        
        let cosAngle = dotProduct / (magnitude1 * magnitude2)
        let angle = acos(max(-1, min(1, cosAngle))) * 180 / .pi
        
        return angle
    }
    
    /// Calculate the angle of a line segment relative to vertical (0 = vertical, 90 = horizontal)
    static func calculateVerticalAngle(from point1: CGPoint, to point2: CGPoint) -> Double {
        let dx = point2.x - point1.x
        let dy = point2.y - point1.y
        
        guard dy != 0 else { return 90 } // Horizontal line
        
        let angle = atan2(abs(dx), abs(dy)) * 180 / .pi
        return angle
    }
    
    // MARK: - Distance Calculations
    
    /// Calculate Euclidean distance between two points
    static func distance(from point1: CGPoint, to point2: CGPoint) -> Double {
        let dx = point2.x - point1.x
        let dy = point2.y - point1.y
        return sqrt(dx * dx + dy * dy)
    }
    
    /// Calculate the midpoint between two points
    static func midpoint(_ point1: CGPoint, _ point2: CGPoint) -> CGPoint {
        return CGPoint(
            x: (point1.x + point2.x) / 2,
            y: (point1.y + point2.y) / 2
        )
    }
    
    // MARK: - Keypoint Extraction
    
    /// Extract a keypoint by name from a pose result
    /// Supports both Vision framework joint names and BodyJoint enum raw values
    static func extractKeypoint(_ name: String, from pose: PoseDetectionResult) -> PoseKeypoint? {
        // Try exact match first
        if let keypoint = pose.keypoints.first(where: { $0.name == name }) {
            return keypoint
        }
        
        // Try matching with BodyJoint raw value (Vision framework uses same naming)
        // Vision framework joint names are stored as "leftHip", "rightKnee", etc.
        // which matches BodyJoint.rawValue
        return pose.keypoints.first { $0.name.lowercased() == name.lowercased() }
    }
    
    /// Extract left and right keypoints (e.g., leftHip, rightHip)
    static func extractBilateralKeypoints(
        leftName: String,
        rightName: String,
        from pose: PoseDetectionResult
    ) -> (left: PoseKeypoint?, right: PoseKeypoint?) {
        let left = extractKeypoint(leftName, from: pose)
        let right = extractKeypoint(rightName, from: pose)
        return (left, right)
    }
    
    /// Get the average position of two keypoints (useful for bilateral joints)
    static func averagePosition(_ keypoint1: PoseKeypoint?, _ keypoint2: PoseKeypoint?) -> CGPoint? {
        guard let kp1 = keypoint1, let kp2 = keypoint2 else {
            return keypoint1?.position ?? keypoint2?.position
        }
        return midpoint(kp1.position, kp2.position)
    }
    
    // MARK: - Coordinate Normalization
    
    /// Normalize Y coordinate (0 = top, 1 = bottom) - useful for depth calculations
    static func normalizeY(_ y: Double, minY: Double, maxY: Double) -> Double {
        guard maxY > minY else { return 0.5 }
        return (y - minY) / (maxY - minY)
    }
    
    /// Calculate percentage depth based on starting and current positions
    static func calculateDepthPercentage(
        currentY: Double,
        startY: Double,
        bottomY: Double
    ) -> Double {
        guard startY > bottomY else { return 0 }
        let totalRange = startY - bottomY
        let currentRange = startY - currentY
        return min(100, max(0, (currentRange / totalRange) * 100))
    }
    
    // MARK: - Phase Detection Helpers
    
    /// Detect if a value is at a local minimum (for finding bottom of squat)
    static func isLocalMinimum(
        _ value: Double,
        at index: Int,
        in values: [Double],
        windowSize: Int = 5
    ) -> Bool {
        guard index >= windowSize && index < values.count - windowSize else { return false }
        
        let window = values[(index - windowSize)...(index + windowSize)]
        let minValue = window.min() ?? value
        
        return abs(value - minValue) < 0.01 // Within tolerance
    }
    
    /// Smooth a series of values using moving average
    static func smoothValues(_ values: [Double], windowSize: Int = 3) -> [Double] {
        guard values.count >= windowSize else { return values }
        
        var smoothed: [Double] = []
        for i in 0..<values.count {
            let start = max(0, i - windowSize / 2)
            let end = min(values.count, i + windowSize / 2 + 1)
            let window = values[start..<end]
            smoothed.append(window.reduce(0, +) / Double(window.count))
        }
        return smoothed
    }
    
    // MARK: - Confidence Filtering
    
    /// Filter keypoints by minimum confidence threshold
    static func filterByConfidence(
        _ keypoints: [PoseKeypoint],
        minConfidence: Float = 0.3
    ) -> [PoseKeypoint] {
        return keypoints.filter { $0.confidence >= minConfidence }
    }
    
    /// Check if required keypoints are present with sufficient confidence
    static func hasRequiredKeypoints(
        _ pose: PoseDetectionResult,
        required: [String],
        minConfidence: Float = 0.3
    ) -> Bool {
        let keypoints = filterByConfidence(pose.keypoints, minConfidence: minConfidence)
        let keypointNames = Set(keypoints.map { $0.name })
        return required.allSatisfy { keypointNames.contains($0) }
    }
}

