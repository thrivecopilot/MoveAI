import AVFoundation
import SwiftUI
import Vision

enum PoseOverlayStyle: String {
    case standard
    case telemetry
}

struct PoseOverlayView: View {
    let pose: PoseDetectionResult?
    let previewSize: CGSize
    let flipXAxis: Bool
    let isUploadedVideo: Bool  // Distinguish between camera feed and uploaded videos
    let style: PoseOverlayStyle
    let highlightedJoints: [BodyJoint: FeedbackSeverity]

    // Transform Vision coordinates to display coordinates
    // Vision coordinates are normalized (0-1) in the raw video frame

    init(
        pose: PoseDetectionResult?,
        previewSize: CGSize,
        flipXAxis: Bool,
        isUploadedVideo: Bool = false,
        style: PoseOverlayStyle = .standard,
        highlightedJoints: [BodyJoint: FeedbackSeverity] = [:]
    ) {
        self.pose = pose
        self.previewSize = previewSize
        self.flipXAxis = flipXAxis
        self.isUploadedVideo = isUploadedVideo
        self.style = style
        self.highlightedJoints = highlightedJoints
    }

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                if let pose = pose {
                    // Pose data - apply rotation only to pose elements
                    ZStack {
                        ForEach(pose.keypoints) { keypoint in
                            let highlightSeverity = BodyJoint(rawValue: keypoint.name).flatMap { highlightedJoints[$0] }
                            KeypointView(
                                keypoint: keypoint,
                                actualSize: previewSize == .zero ? geometry.size : previewSize,
                                flipXAxis: flipXAxis,
                                isUploadedVideo: isUploadedVideo,
                                keypointColor: keypointColor(for: keypoint, highlightSeverity: highlightSeverity),
                                highlightSeverity: highlightSeverity,
                                frameIndex: pose.frameIndex,
                                style: style
                            )
                        }

                        // Draw skeleton connections
                        SkeletonView(
                            pose: pose,
                            previewSize: previewSize == .zero ? geometry.size : previewSize,
                            flipXAxis: flipXAxis,
                            isUploadedVideo: isUploadedVideo,
                            style: style,
                            highlightedJoints: highlightedJoints
                        )
                        .accessibilityIdentifier("PoseOverlay.Skeleton")
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
                                .accessibilityIdentifier("PoseOverlay.EmptyStateMessage")
                            Spacer()
                        }
                        Spacer()
                    }
                }
            }
        }
        .accessibilityIdentifier("PoseOverlayView")
        .accessibilityLabel("Pose Overlay")
        .accessibilityValue(poseAccessibilityValue)
        .accessibilityElement(children: .contain)
    }

    private var poseAccessibilityValue: String {
        let frame = pose.map { String($0.frameIndex) } ?? "none"
        let keypointCount = pose?.keypoints.count ?? 0
        let source = isUploadedVideo ? "uploaded" : "camera"

        var value = "frame=\(frame),keypoints=\(keypointCount),style=\(style.rawValue),source=\(source)"

        if !highlightedJoints.isEmpty {
            let highlights = highlightedJoints
                .sorted { $0.key.rawValue < $1.key.rawValue }
                .map { "\($0.key.rawValue):\($0.value.rawValue)" }
                .joined(separator: "|")
            value += ",highlights=\(highlights)"
        }

        return value
    }

    private func keypointColor(for keypoint: PoseKeypoint, highlightSeverity: FeedbackSeverity?) -> Color {
        if let severity = highlightSeverity {
            return highlightColor(for: severity)
        }

        // Color based on confidence level
        switch style {
        case .standard:
            if keypoint.confidence > 0.7 {
                return .green
            } else if keypoint.confidence > 0.4 {
                return .yellow
            } else {
                return .red
            }
        case .telemetry:
            if keypoint.confidence > 0.7 {
                return Color(red: 0.24, green: 0.86, blue: 1.0)
            } else if keypoint.confidence > 0.4 {
                return Color(red: 1.0, green: 0.78, blue: 0.35)
            } else {
                return Color(red: 1.0, green: 0.42, blue: 0.42)
            }
        }
    }

    private func highlightColor(for severity: FeedbackSeverity) -> Color {
        switch style {
        case .standard:
            switch severity {
            case .critical:
                return .red
            case .warning:
                return .yellow
            case .good, .excellent:
                return .green
            }
        case .telemetry:
            switch severity {
            case .critical:
                return Color(red: 1.0, green: 0.42, blue: 0.42)
            case .warning:
                return Color(red: 1.0, green: 0.78, blue: 0.35)
            case .good:
                return Color(red: 0.16, green: 0.97, blue: 0.65)
            case .excellent:
                return Color(red: 0.24, green: 0.86, blue: 1.0)
            }
        }
    }
}

private struct KeypointView: View {
    let keypoint: PoseKeypoint
    let actualSize: CGSize
    let flipXAxis: Bool
    let isUploadedVideo: Bool
    let keypointColor: Color
    let highlightSeverity: FeedbackSeverity?
    let frameIndex: Int
    let style: PoseOverlayStyle

    private var screenPosition: CGPoint {
        // Vision uses bottom-left origin, SwiftUI uses top-left origin
        // First, flip Y coordinate to convert from Vision to SwiftUI coordinate system
        let flippedY = 1.0 - keypoint.position.y

        let finalX: CGFloat
        let finalY: CGFloat

        if isUploadedVideo {
            // For uploaded videos: frames are already correctly oriented after appliesPreferredTrackTransform
            // Only apply Y-flip (no 90-degree rotation, no X-flip needed)
            finalX = keypoint.position.x
            finalY = flippedY
        } else {
            // For camera feed: apply 90-degree rotation to match camera orientation
            let rotatedX = flippedY  // Y becomes X after 90-degree rotation
            let rotatedY = keypoint.position.x  // X becomes Y after 90-degree rotation (no flip needed)

            // Apply X-axis flip for video playback if needed
            finalX = flipXAxis ? (1.0 - rotatedX) : rotatedX
            finalY = rotatedY
        }

        // Map coordinates to screen space
        return CGPoint(
            x: finalX * actualSize.width,
            y: finalY * actualSize.height
        )
    }

    private var accessibilityValue: String {
        let base = "confidence=\(String(format: "%.2f", keypoint.confidence)),frame=\(frameIndex)"
        guard let highlightSeverity else { return base }
        return base + ",highlight=\(highlightSeverity.rawValue)"
    }

    var body: some View {
        Circle()
            .fill(keypointColor)
            .frame(width: style == .telemetry ? 7 : 8, height: style == .telemetry ? 7 : 8)
            .overlay(
                Circle()
                    .stroke(Color.white.opacity(style == .telemetry ? 0.6 : 0.3), lineWidth: style == .telemetry ? 1.2 : 1)
            )
            .shadow(color: style == .telemetry ? keypointColor.opacity(0.6) : .clear, radius: style == .telemetry ? 4 : 0)
            .position(x: screenPosition.x, y: screenPosition.y)
            .accessibilityElement(children: .ignore)
            .accessibilityIdentifier("PoseOverlay.Keypoint.\(keypoint.name)")
            .accessibilityLabel(keypoint.name)
            .accessibilityValue(accessibilityValue)
            .onAppear {
                // #region agent log
                if keypoint.name == "nose" {
                    let flippedY = 1.0 - keypoint.position.y
                    let logData: [String: Any] = [
                        "hypothesisId": "H1,H4",
                        "keypointName": keypoint.name,
                        "originalX": keypoint.position.x,
                        "originalY": keypoint.position.y,
                        "flippedY": flippedY,
                        "isUploadedVideo": isUploadedVideo,
                        "finalX": isUploadedVideo ? keypoint.position.x : (flipXAxis ? (1.0 - flippedY) : flippedY),
                        "finalY": isUploadedVideo ? flippedY : keypoint.position.x,
                        "screenX": screenPosition.x,
                        "screenY": screenPosition.y,
                        "previewSize": "\(actualSize.width)x\(actualSize.height)",
                        "flipXAxis": flipXAxis
                    ]
                    VideoProcessingHelpers.writeDebugLog("Coordinate transformation", data: logData, location: "PoseOverlayView.swift:38")
                }
                // #endregion
                // Only log keypoints relevant for depth analysis
                let depthKeypoints = ["lefthip", "righthip", "leftknee", "rightknee"]
                if depthKeypoints.contains(keypoint.name.lowercased()) {
                    print("🎯 PoseOverlayView: \(keypoint.name) at normalized (\(String(format: "%.3f", keypoint.position.x)), \(String(format: "%.3f", keypoint.position.y))) -> screen (\(String(format: "%.1f", screenPosition.x)), \(String(format: "%.1f", screenPosition.y))) in actualSize \(actualSize) [original frame: \(frameIndex), isUploadedVideo: \(isUploadedVideo)]")
                }
            }
    }
}

struct SkeletonView: View {
    let pose: PoseDetectionResult
    let previewSize: CGSize
    let flipXAxis: Bool
    let isUploadedVideo: Bool
    let style: PoseOverlayStyle
    let highlightedJoints: [BodyJoint: FeedbackSeverity]

    var body: some View {
        Canvas { context, size in
            drawSkeleton(context: context, size: size)
        }
    }

    private var defaultStrokeColor: Color {
        style == .telemetry ? Color(red: 0.24, green: 0.86, blue: 1.0) : .white
    }

    private func highlightColor(for severity: FeedbackSeverity) -> Color {
        switch style {
        case .standard:
            switch severity {
            case .critical:
                return .red
            case .warning:
                return .yellow
            case .good, .excellent:
                return defaultStrokeColor
            }
        case .telemetry:
            switch severity {
            case .critical:
                return Color(red: 1.0, green: 0.42, blue: 0.42)
            case .warning:
                return Color(red: 1.0, green: 0.78, blue: 0.35)
            case .good, .excellent:
                return defaultStrokeColor
            }
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

            let start: CGPoint
            let end: CGPoint

            if isUploadedVideo {
                // For uploaded videos: only apply Y-flip (no 90-degree rotation, no X-flip needed)
                let flippedStartY = 1.0 - startPoint.position.y
                let flippedEndY = 1.0 - endPoint.position.y

                start = CGPoint(
                    x: startPoint.position.x * previewSize.width,
                    y: flippedStartY * previewSize.height
                )
                end = CGPoint(
                    x: endPoint.position.x * previewSize.width,
                    y: flippedEndY * previewSize.height
                )
            } else {
                // For camera feed: apply Y-flip and 90-degree rotation
                let flippedStartY = 1.0 - startPoint.position.y
                let flippedEndY = 1.0 - endPoint.position.y

                // Apply 90-degree rotation to the coordinates before mapping to screen
                let startRotatedX = flippedStartY  // Y becomes X after 90-degree rotation
                let startRotatedY = startPoint.position.x  // X becomes Y after 90-degree rotation (no flip needed)
                let endRotatedX = flippedEndY  // Y becomes X after 90-degree rotation
                let endRotatedY = endPoint.position.x  // X becomes Y after 90-degree rotation (no flip needed)

                // Apply X-axis flip for video playback if needed
                let startFinalX = flipXAxis ? (1.0 - startRotatedX) : startRotatedX
                let endFinalX = flipXAxis ? (1.0 - endRotatedX) : endRotatedX

                start = CGPoint(
                    x: startFinalX * previewSize.width,
                    y: startRotatedY * previewSize.height
                )
                end = CGPoint(
                    x: endFinalX * previewSize.width,
                    y: endRotatedY * previewSize.height
                )
            }

            let startSeverity = BodyJoint(rawValue: startJoint).flatMap { highlightedJoints[$0] }
            let endSeverity = BodyJoint(rawValue: endJoint).flatMap { highlightedJoints[$0] }
            let segmentSeverity: FeedbackSeverity? = {
                if startSeverity == .critical || endSeverity == .critical { return .critical }
                if startSeverity == .warning || endSeverity == .warning { return .warning }
                return nil
            }()

            var path = Path()
            path.move(to: start)
            path.addLine(to: end)

            context.stroke(
                path,
                with: .color(segmentSeverity.map(highlightColor) ?? defaultStrokeColor),
                lineWidth: style == .telemetry ? 2.6 : 2
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
        previewSize: CGSize(width: 300, height: 400),
        flipXAxis: false,
        isUploadedVideo: false
    )
    .background(Color.black)
}
