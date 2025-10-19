import SwiftUI
import Vision

struct PoseOverlayView: View {
    let pose: PoseDetectionResult?
    let previewSize: CGSize
    
    // Transform Vision coordinates to display coordinates
    // Vision coordinates are normalized (0-1) in the raw video frame
    // Display coordinates are in the actual camera preview area
    private func transformVisionToDisplay(visionPoint: CGPoint, displaySize: CGSize) -> CGPoint {
        // Vision uses bottom-left origin, SwiftUI uses top-left origin
        // First, flip Y coordinate
        let flippedY = 1.0 - visionPoint.y
        
        // For now, use simple 1:1 mapping to test
        // TODO: Add proper aspect ratio and cropping calculations
        let screenX = visionPoint.x * displaySize.width
        let screenY = flippedY * displaySize.height
        
        return CGPoint(x: screenX, y: screenY)
    }
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                let _ = print("🎨 PoseOverlayView: Rendering with pose: \(pose != nil ? "exists" : "nil"), size: \(geometry.size)")
                if let pose = pose {
                    // Pose data - apply rotation only to pose elements
                    ZStack {
                        ForEach(pose.keypoints) { keypoint in
                            // Use geometry.size for dynamic sizing instead of previewSize
                            let actualSize = previewSize == .zero ? geometry.size : previewSize
                            
                            // Transform Vision coordinates to display coordinates
                            // Vision coordinates are normalized (0-1) in the raw video frame
                            // We need to map them to the actual camera preview area
                            let transformedPoint = transformVisionToDisplay(
                                visionPoint: keypoint.position,
                                displaySize: actualSize
                            )
                            
                            Circle()
                                .fill(keypointColor(for: keypoint))
                                .frame(width: 8, height: 8)
                                .position(x: transformedPoint.x, y: transformedPoint.y)
                                .onAppear {
                                    print("🎯 PoseOverlayView: \(keypoint.name) at normalized (\(String(format: "%.3f", keypoint.position.x)), \(String(format: "%.3f", keypoint.position.y))) -> display (\(String(format: "%.1f", transformedPoint.x)), \(String(format: "%.1f", transformedPoint.y))) in size \(actualSize)")
                                }
                        }
                        
                        // Draw skeleton connections
                        SkeletonView(pose: pose, previewSize: previewSize == .zero ? geometry.size : previewSize)
                    }
                    .rotationEffect(.degrees(90)) // Rotate only pose elements
                } else {
                    // Show a subtle indicator when no pose is detected yet - NO ROTATION
                    VStack {
                        Spacer()
                        HStack {
                            Spacer()
                            Text("Position yourself in frame")
                                .font(.caption)
                                .foregroundColor(.white)
                                .padding(8)
                                .background(Color.black.opacity(0.6))
                                .cornerRadius(8)
                            Spacer()
                        }
                        Spacer()
                    }
                }
            }
        }
    }
    
    private func keypointColor(for keypoint: PoseKeypoint) -> Color {
        // Color based on confidence level
        if keypoint.confidence > 0.7 {
            return .green
        } else if keypoint.confidence > 0.4 {
            return .yellow
        } else {
            return .red
        }
    }
}

struct SkeletonView: View {
    let pose: PoseDetectionResult
    let previewSize: CGSize
    
    var body: some View {
        Canvas { context, size in
            drawSkeleton(context: context, size: size)
        }
    }
    
    // Transform Vision coordinates to display coordinates
    private func transformVisionToDisplay(visionPoint: CGPoint, displaySize: CGSize) -> CGPoint {
        // Vision uses bottom-left origin, SwiftUI uses top-left origin
        // First, flip Y coordinate
        let flippedY = 1.0 - visionPoint.y
        
        // For now, use simple 1:1 mapping to test
        // TODO: Add proper aspect ratio and cropping calculations
        let screenX = visionPoint.x * displaySize.width
        let screenY = flippedY * displaySize.height
        
        return CGPoint(x: screenX, y: screenY)
    }
    
    private func drawSkeleton(context: GraphicsContext, size: CGSize) {
        let keypoints = pose.keypoints
        
        // Define skeleton connections (simplified)
        let connections: [(String, String)] = [
            // Head and neck
            ("nose", "leftEye"),
            ("nose", "rightEye"),
            ("leftEye", "leftEar"),
            ("rightEye", "rightEar"),
            ("leftEar", "neck"),
            ("rightEar", "neck"),
            
            // Torso
            ("neck", "leftShoulder"),
            ("neck", "rightShoulder"),
            ("leftShoulder", "leftElbow"),
            ("rightShoulder", "rightElbow"),
            ("leftElbow", "leftWrist"),
            ("rightElbow", "rightWrist"),
            
            // Core
            ("leftShoulder", "leftHip"),
            ("rightShoulder", "rightHip"),
            ("leftHip", "rightHip"),
            
            // Legs
            ("leftHip", "leftKnee"),
            ("rightHip", "rightKnee"),
            ("leftKnee", "leftAnkle"),
            ("rightKnee", "rightAnkle"),
            ("leftAnkle", "leftHeel"),
            ("rightAnkle", "rightHeel"),
            ("leftHeel", "leftFootIndex"),
            ("rightHeel", "rightFootIndex")
        ]
        
        for (startJoint, endJoint) in connections {
            guard let startPoint = keypoints.first(where: { $0.name == startJoint }),
                  let endPoint = keypoints.first(where: { $0.name == endJoint }),
                  startPoint.confidence > 0.3 && endPoint.confidence > 0.3 else {
                continue
            }
            
            // Transform Vision coordinates to display coordinates
            let start = transformVisionToDisplay(visionPoint: startPoint.position, displaySize: previewSize)
            let end = transformVisionToDisplay(visionPoint: endPoint.position, displaySize: previewSize)
            
            var path = Path()
            path.move(to: start)
            path.addLine(to: end)
            
            context.stroke(
                path,
                with: .color(.white),
                lineWidth: 2
            )
        }
    }
}

#Preview {
    let mockKeypoints = [
        PoseKeypoint(name: "nose", position: CGPoint(x: 0.5, y: 0.2), confidence: 0.9),
        PoseKeypoint(name: "leftShoulder", position: CGPoint(x: 0.4, y: 0.3), confidence: 0.8),
        PoseKeypoint(name: "rightShoulder", position: CGPoint(x: 0.6, y: 0.3), confidence: 0.8),
        PoseKeypoint(name: "leftHip", position: CGPoint(x: 0.45, y: 0.6), confidence: 0.7),
        PoseKeypoint(name: "rightHip", position: CGPoint(x: 0.55, y: 0.6), confidence: 0.7),
        PoseKeypoint(name: "leftKnee", position: CGPoint(x: 0.45, y: 0.8), confidence: 0.6),
        PoseKeypoint(name: "rightKnee", position: CGPoint(x: 0.55, y: 0.8), confidence: 0.6)
    ]
    
    let mockPose = PoseDetectionResult(keypoints: mockKeypoints, frameIndex: 1)
    
    return PoseOverlayView(
        pose: mockPose,
        previewSize: CGSize(width: 300, height: 400)
    )
    .background(Color.black)
}
