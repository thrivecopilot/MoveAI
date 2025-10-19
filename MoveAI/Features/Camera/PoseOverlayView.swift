import SwiftUI
import Vision
import AVFoundation

struct PoseOverlayView: View {
    let pose: PoseDetectionResult?
    let previewSize: CGSize
    
    // Transform Vision coordinates to display coordinates
    // Vision coordinates are normalized (0-1) in the raw video frame
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                let _ = print("🎨 PoseOverlayView: Rendering with pose: \(pose != nil ? "exists" : "nil"), size: \(geometry.size)")
                
                // DEBUG: Add corner markers to show overlay bounds
                VStack {
                    HStack {
                        // Top-left corner marker
                        Circle()
                            .fill(Color.red)
                            .frame(width: 12, height: 12)
                        Spacer()
                        // Top-right corner marker
                        Circle()
                            .fill(Color.red)
                            .frame(width: 12, height: 12)
                    }
                    Spacer()
                    HStack {
                        // Bottom-left corner marker
                        Circle()
                            .fill(Color.red)
                            .frame(width: 12, height: 12)
                        Spacer()
                        // Bottom-right corner marker
                        Circle()
                            .fill(Color.red)
                            .frame(width: 12, height: 12)
                    }
                }
                .padding(8)
                
                // DEBUG: Add center crosshair
                VStack {
                    Spacer()
                    HStack {
                        Spacer()
                        ZStack {
                            Rectangle()
                                .fill(Color.yellow)
                                .frame(width: 2, height: 20)
                            Rectangle()
                                .fill(Color.yellow)
                                .frame(width: 20, height: 2)
                        }
                        Spacer()
                    }
                    Spacer()
                }
                
                // DEBUG: Add size indicator
                VStack {
                    HStack {
                        Text("Size: \(Int(geometry.size.width))×\(Int(geometry.size.height))")
                            .font(.caption2)
                            .foregroundColor(.white)
                            .padding(4)
                            .background(Color.black.opacity(0.7))
                            .cornerRadius(4)
                        Spacer()
                    }
                    .padding(8)
                    Spacer()
                }
                
                if let pose = pose {
                    // Pose data - apply rotation only to pose elements
                    ZStack {
                        ForEach(pose.keypoints) { keypoint in
                            // Use geometry.size for dynamic sizing instead of previewSize
                            let actualSize = previewSize == .zero ? geometry.size : previewSize
                            
                            // Vision uses bottom-left origin, SwiftUI uses top-left origin
                            // First, flip Y coordinate to convert from Vision to SwiftUI coordinate system
                            let flippedY = 1.0 - keypoint.position.y
                            
                            // Apply 90-degree rotation to the coordinates before mapping to screen
                            // This rotates the coordinate system to match the camera orientation
                            let rotatedX = flippedY  // Y becomes X after 90-degree rotation
                            let rotatedY = keypoint.position.x  // X becomes Y after 90-degree rotation (no flip needed)
                            
                            // Map rotated coordinates to screen space
                            let screenX = rotatedX * actualSize.width
                            let screenY = rotatedY * actualSize.height
                            
                            Circle()
                                .fill(keypointColor(for: keypoint))
                                .frame(width: 8, height: 8)
                                .position(x: screenX, y: screenY)
                                .onAppear {
                                    print("🎯 PoseOverlayView: \(keypoint.name) at normalized (\(String(format: "%.3f", keypoint.position.x)), \(String(format: "%.3f", keypoint.position.y))) -> flipped Y (\(String(format: "%.3f", 1.0 - keypoint.position.y))) -> screen (\(String(format: "%.1f", screenX)), \(String(format: "%.1f", screenY))) in actualSize \(actualSize)")
                                }
                        }
                        
                        // Draw skeleton connections
                        SkeletonView(pose: pose, previewSize: previewSize == .zero ? geometry.size : previewSize)
                    }
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
            
            // Apply Y-coordinate flip and 90-degree rotation to convert from Vision to SwiftUI coordinate system
            let flippedStartY = 1.0 - startPoint.position.y
            let flippedEndY = 1.0 - endPoint.position.y
            
            // Apply 90-degree rotation to the coordinates before mapping to screen
            let startRotatedX = flippedStartY  // Y becomes X after 90-degree rotation
            let startRotatedY = startPoint.position.x  // X becomes Y after 90-degree rotation (no flip needed)
            let endRotatedX = flippedEndY  // Y becomes X after 90-degree rotation
            let endRotatedY = endPoint.position.x  // X becomes Y after 90-degree rotation (no flip needed)
            
            let start = CGPoint(
                x: startRotatedX * previewSize.width,
                y: startRotatedY * previewSize.height
            )
            let end = CGPoint(
                x: endRotatedX * previewSize.width,
                y: endRotatedY * previewSize.height
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
    
    PoseOverlayView(
        pose: mockPose,
        previewSize: CGSize(width: 300, height: 400)
    )
    .background(Color.black)
}
