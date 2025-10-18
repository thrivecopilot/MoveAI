import SwiftUI
import Vision

struct PoseOverlayView: View {
    let pose: PoseDetectionResult?
    let previewSize: CGSize
    
    var body: some View {
        if let pose = pose {
            GeometryReader { geometry in
                ZStack {
                ForEach(pose.keypoints) { keypoint in
                    // Use raw Vision coordinates (no Y-flip) to match recorded video overlay
                    let screenX = keypoint.position.x * geometry.size.width
                    let screenY = keypoint.position.y * geometry.size.height
                    
                    Circle()
                        .fill(keypointColor(for: keypoint))
                        .frame(width: 8, height: 8)
                        .position(x: screenX, y: screenY)
                        .onAppear {
                            print("🎯 PoseOverlayView: \(keypoint.name) at normalized (\(String(format: "%.3f", keypoint.position.x)), \(String(format: "%.3f", keypoint.position.y))) -> screen (\(String(format: "%.1f", screenX)), \(String(format: "%.1f", screenY))) in geometry \(geometry.size)")
                        }
                }
                    
                    // Draw skeleton connections
                    SkeletonView(pose: pose, previewSize: geometry.size)
                }
                .rotationEffect(.degrees(90)) // Rotate 90 degrees clockwise to match recorded video
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
            
            // Use raw Vision coordinates (no Y-flip) to match recorded video overlay
            let start = CGPoint(
                x: startPoint.position.x * previewSize.width,
                y: startPoint.position.y * previewSize.height
            )
            let end = CGPoint(
                x: endPoint.position.x * previewSize.width,
                y: endPoint.position.y * previewSize.height
            )
            
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
