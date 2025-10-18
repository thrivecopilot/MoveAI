import Foundation
import Vision
import AVFoundation
import UIKit

@MainActor
class PoseAnalysisService: ObservableObject {
    @Published var isAnalyzing = false
    @Published var currentPose: PoseDetectionResult?
    @Published var poseHistory: [PoseDetectionResult] = []
    
    private let visionQueue = DispatchQueue(label: "pose.analysis.queue", qos: .userInitiated)
    private var frameCount = 0
    
    // MARK: - Pose Detection
    
    func analyzeFrame(_ pixelBuffer: CVPixelBuffer) {
        guard !isAnalyzing else { 
            print("⚠️ PoseAnalysisService: Skipping frame - already analyzing")
            return 
        }
        
        isAnalyzing = true
        frameCount += 1
        let currentFrameCount = frameCount
        
        print("🔍 PoseAnalysisService: Starting analysis for frame \(currentFrameCount)")
        
        visionQueue.async { [weak self] in
            Task { @MainActor in
                await self?.performPoseDetection(on: pixelBuffer, frameIndex: currentFrameCount)
            }
        }
    }
    
    private func performPoseDetection(on pixelBuffer: CVPixelBuffer, frameIndex: Int) async {
        print("🔍 PoseAnalysisService: Creating pose detection request for frame \(frameIndex)")
        
        let request = VNDetectHumanBodyPoseRequest { [weak self] request, error in
            DispatchQueue.main.async {
                guard let self = self else { return }
                self.isAnalyzing = false
                
                if let error = error {
                    print("❌ PoseAnalysisService: Pose detection failed for frame \(frameIndex) - \(error.localizedDescription)")
                    return
                }
                
                guard let observations = request.results as? [VNHumanBodyPoseObservation] else {
                    print("⚠️ PoseAnalysisService: No observations returned for frame \(frameIndex)")
                    // Store empty frame to maintain sequence
                    self.processPoseObservation(nil, frameIndex: frameIndex)
                    return
                }
                
                print("🔍 PoseAnalysisService: Found \(observations.count) pose observations in frame \(frameIndex)")
                
                if let observation = observations.first {
                    self.processPoseObservation(observation, frameIndex: frameIndex)
                } else {
                    print("⚠️ PoseAnalysisService: No pose detected in frame \(frameIndex)")
                    // Store empty frame to maintain sequence
                    self.processPoseObservation(nil, frameIndex: frameIndex)
                }
            }
        }
        
        // Use default revision for better compatibility
        
        let handler = VNImageRequestHandler(cvPixelBuffer: pixelBuffer, orientation: .up)
        
        do {
            print("🔍 PoseAnalysisService: Performing pose detection for frame \(frameIndex)")
            try handler.perform([request])
        } catch {
            DispatchQueue.main.async {
                self.isAnalyzing = false
                print("❌ PoseAnalysisService: Failed to perform pose detection for frame \(frameIndex) - \(error.localizedDescription)")
            }
        }
    }
    
    private func processPoseObservation(_ observation: VNHumanBodyPoseObservation?, frameIndex: Int) {
        var keypoints: [PoseKeypoint] = []
        
        // Handle case where no pose was detected
        guard let observation = observation else {
            print("⚠️ PoseAnalysisService: No pose data for frame \(frameIndex), storing empty frame")
            let poseResult = PoseDetectionResult(keypoints: [], frameIndex: frameIndex)
            DispatchQueue.main.async {
                self.currentPose = poseResult
                self.poseHistory.append(poseResult)
                
                // Keep only last 1000 frames to prevent memory issues (supports ~33 seconds at 30fps)
                if self.poseHistory.count > 1000 {
                    self.poseHistory.removeFirst(self.poseHistory.count - 1000)
                }
            }
            return
        }
        
        // Extract keypoints for each body joint using the correct Vision framework API
        let jointNames: [VNHumanBodyPoseObservation.JointName] = [
            .nose, .leftEye, .rightEye, .leftEar, .rightEar,
            .neck, .leftShoulder, .rightShoulder, .leftElbow, .rightElbow,
            .leftWrist, .rightWrist, .leftHip, .rightHip, .root,
            .leftKnee, .rightKnee, .leftAnkle, .rightAnkle
        ]
        
        print("🔍 PoseAnalysisService: Processing \(jointNames.count) joints for frame \(frameIndex)")
        
        for jointName in jointNames {
            do {
                let point = try observation.recognizedPoint(jointName)
                
                // Lower confidence threshold to catch more keypoints
                if point.confidence > 0.1 {
                    // Store raw Vision coordinates - we'll handle coordinate transformation in the overlay
                    let keypoint = PoseKeypoint(
                        name: String(describing: jointName),
                        position: CGPoint(x: point.location.x, y: point.location.y),
                        confidence: point.confidence
                    )
                    keypoints.append(keypoint)
                    print("✅ PoseAnalysisService: Detected \(jointName) at (\(String(format: "%.3f", point.location.x)), \(String(format: "%.3f", point.location.y))) with confidence \(String(format: "%.2f", point.confidence))")
                } else {
                    print("⚠️ PoseAnalysisService: \(jointName) confidence too low: \(String(format: "%.2f", point.confidence))")
                }
            } catch {
                print("❌ PoseAnalysisService: Failed to get \(jointName): \(error.localizedDescription)")
                continue
            }
        }
        
        let poseResult = PoseDetectionResult(keypoints: keypoints, frameIndex: frameIndex)
        DispatchQueue.main.async {
            self.currentPose = poseResult
            self.poseHistory.append(poseResult)
            
            // Keep only last 1000 frames to prevent memory issues (supports ~33 seconds at 30fps)
            if self.poseHistory.count > 1000 {
                self.poseHistory.removeFirst(self.poseHistory.count - 1000)
            }
        }
        
        print("✅ PoseAnalysisService: Detected \(keypoints.count) keypoints in frame \(frameIndex)")
        
        // Log keypoint details for debugging
        for keypoint in keypoints {
            print("  - \(keypoint.name): (\(String(format: "%.2f", keypoint.position.x)), \(String(format: "%.2f", keypoint.position.y))) conf: \(String(format: "%.2f", keypoint.confidence))")
        }
    }
    
    // MARK: - Powerlifting-Specific Analysis
    
    func analyzeSquatForm() -> SquatAnalysis? {
        guard let currentPose = currentPose else { return nil }
        
        let leftHip = currentPose.keypoints.first { $0.name == BodyJoint.leftHip.rawValue }
        let rightHip = currentPose.keypoints.first { $0.name == BodyJoint.rightHip.rawValue }
        let leftKnee = currentPose.keypoints.first { $0.name == BodyJoint.leftKnee.rawValue }
        let rightKnee = currentPose.keypoints.first { $0.name == BodyJoint.rightKnee.rawValue }
        let leftAnkle = currentPose.keypoints.first { $0.name == BodyJoint.leftAnkle.rawValue }
        let rightAnkle = currentPose.keypoints.first { $0.name == BodyJoint.rightAnkle.rawValue }
        
        guard let hip = leftHip ?? rightHip,
              let ankle = leftAnkle ?? rightAnkle else {
            return nil
        }
        
        // Calculate knee angle
        let leftKneePoint = leftKnee?.position ?? CGPoint.zero
        let rightKneePoint = rightKnee?.position ?? CGPoint.zero
        let kneePosition = leftKneePoint != CGPoint.zero ? leftKneePoint : rightKneePoint
        
        let kneeAngle = calculateAngle(
            point1: hip.position,
            point2: kneePosition,
            point3: ankle.position
        )
        
        // Calculate hip depth (how low the hips are)
        let hipDepth = hip.position.y
        
        return SquatAnalysis(
            kneeAngle: kneeAngle,
            hipDepth: hipDepth,
            isAtDepth: kneeAngle < 90, // Simplified depth check
            kneeValgus: calculateKneeValgus(leftKnee: leftKnee, rightKnee: rightKnee),
            timestamp: currentPose.timestamp
        )
    }
    
    func analyzeDeadliftForm() -> DeadliftAnalysis? {
        guard let currentPose = currentPose else { return nil }
        
        let leftHip = currentPose.keypoints.first { $0.name == BodyJoint.leftHip.rawValue }
        let rightHip = currentPose.keypoints.first { $0.name == BodyJoint.rightHip.rawValue }
        let leftKnee = currentPose.keypoints.first { $0.name == BodyJoint.leftKnee.rawValue }
        let rightKnee = currentPose.keypoints.first { $0.name == BodyJoint.rightKnee.rawValue }
        let leftShoulder = currentPose.keypoints.first { $0.name == BodyJoint.leftShoulder.rawValue }
        let rightShoulder = currentPose.keypoints.first { $0.name == BodyJoint.rightShoulder.rawValue }
        
        guard let hip = leftHip ?? rightHip,
              let _ = leftKnee ?? rightKnee,
              let shoulder = leftShoulder ?? rightShoulder else {
            return nil
        }
        
        // Calculate back angle (shoulder to hip angle)
        let backAngle = calculateAngle(
            point1: CGPoint(x: shoulder.position.x, y: shoulder.position.y - 50), // Vertical reference
            point2: shoulder.position,
            point3: hip.position
        )
        
        return DeadliftAnalysis(
            backAngle: backAngle,
            hipHeight: hip.position.y,
            shoulderHeight: shoulder.position.y,
            isBackStraight: backAngle > 160, // Simplified straight back check
            timestamp: currentPose.timestamp
        )
    }
    
    func analyzeBenchPressForm() -> BenchPressAnalysis? {
        guard let currentPose = currentPose else { return nil }
        
        let leftShoulder = currentPose.keypoints.first { $0.name == BodyJoint.leftShoulder.rawValue }
        let rightShoulder = currentPose.keypoints.first { $0.name == BodyJoint.rightShoulder.rawValue }
        let leftElbow = currentPose.keypoints.first { $0.name == BodyJoint.leftElbow.rawValue }
        let rightElbow = currentPose.keypoints.first { $0.name == BodyJoint.rightElbow.rawValue }
        let leftWrist = currentPose.keypoints.first { $0.name == BodyJoint.leftWrist.rawValue }
        let rightWrist = currentPose.keypoints.first { $0.name == BodyJoint.rightWrist.rawValue }
        
        guard let shoulder = leftShoulder ?? rightShoulder,
              let elbow = leftElbow ?? rightElbow,
              let wrist = leftWrist ?? rightWrist else {
            return nil
        }
        
        // Calculate elbow angle
        let elbowAngle = calculateAngle(
            point1: shoulder.position,
            point2: elbow.position,
            point3: wrist.position
        )
        
        return BenchPressAnalysis(
            elbowAngle: elbowAngle,
            barPath: wrist.position.y,
            isAtChest: elbowAngle < 90, // Simplified chest touch check
            armSymmetry: calculateArmSymmetry(leftElbow: leftElbow, rightElbow: rightElbow),
            timestamp: currentPose.timestamp
        )
    }
    
    // MARK: - Helper Functions
    
    private func calculateAngle(point1: CGPoint, point2: CGPoint, point3: CGPoint) -> Double {
        let vector1 = CGPoint(x: point1.x - point2.x, y: point1.y - point2.y)
        let vector2 = CGPoint(x: point3.x - point2.x, y: point3.y - point2.y)
        
        let dotProduct = vector1.x * vector2.x + vector1.y * vector2.y
        let magnitude1 = sqrt(vector1.x * vector1.x + vector1.y * vector1.y)
        let magnitude2 = sqrt(vector2.x * vector2.x + vector2.y * vector2.y)
        
        let cosAngle = dotProduct / (magnitude1 * magnitude2)
        let angle = acos(max(-1, min(1, cosAngle))) * 180 / .pi
        
        return angle
    }
    
    private func calculateKneeValgus(leftKnee: PoseKeypoint?, rightKnee: PoseKeypoint?) -> Double {
        guard let leftKnee = leftKnee, let rightKnee = rightKnee else { return 0 }
        return abs(leftKnee.position.x - rightKnee.position.x)
    }
    
    private func calculateArmSymmetry(leftElbow: PoseKeypoint?, rightElbow: PoseKeypoint?) -> Double {
        guard let leftElbow = leftElbow, let rightElbow = rightElbow else { return 0 }
        return abs(leftElbow.position.y - rightElbow.position.y)
    }
    
    // MARK: - Reset
    
    func reset() {
        currentPose = nil
        poseHistory.removeAll()
        frameCount = 0
    }
}

// MARK: - Movement-Specific Analysis Models

struct SquatAnalysis: Codable {
    let kneeAngle: Double
    let hipDepth: Double
    let isAtDepth: Bool
    let kneeValgus: Double
    let timestamp: Date
}

struct DeadliftAnalysis: Codable {
    let backAngle: Double
    let hipHeight: Double
    let shoulderHeight: Double
    let isBackStraight: Bool
    let timestamp: Date
}

struct BenchPressAnalysis: Codable {
    let elbowAngle: Double
    let barPath: Double
    let isAtChest: Bool
    let armSymmetry: Double
    let timestamp: Date
}
