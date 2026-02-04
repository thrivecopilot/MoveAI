//
//  VideoPlayerView.swift
//  MoveAI
//
//  Created by Dave Mathew on 10/11/25.
//

import SwiftUI
import AVKit
import AVFoundation

struct VideoPlayerView: View {
    let videoURL: URL
    let poseData: [PoseDetectionResult]?
    let isRecordedLive: Bool  // true for live camera recordings, false for uploaded videos
    @State private var player: AVPlayer?
    @State private var isPlaying = false
    @State private var currentTime: Double = 0
    @State private var duration: Double = 0
    @State private var showingPoseOverlay = true
    @State private var currentFrameIndex = 0
    @State private var videoSize: CGSize = CGSize(width: 1920, height: 1080)
    @State private var videoFrameRate: Double = 30.0
    @State private var poseFrameRate: Double = 30.0
    @State private var showControls = true
    @State private var playerStatus: AVPlayerItem.Status = .unknown
    @StateObject private var statusObserver = PlayerStatusObserver()
    @Binding var seekToTime: TimeInterval?
    var onFullScreenToggle: (() -> Void)?
    var isFullScreenMode: Bool = false
    
    init(videoURL: URL, poseData: [PoseDetectionResult]?, isRecordedLive: Bool = false, seekToTime: Binding<TimeInterval?> = .constant(nil), onFullScreenToggle: (() -> Void)? = nil, isFullScreenMode: Bool = false) {
        self.videoURL = videoURL
        self.poseData = poseData
        self.isRecordedLive = isRecordedLive
        self._seekToTime = seekToTime
        self.onFullScreenToggle = onFullScreenToggle
        self.isFullScreenMode = isFullScreenMode
    }
    
    var body: some View {
        Group {
            if isFullScreenMode {
                fullscreenView
            } else {
                normalView
            }
        }
        .onAppear {
            setupPlayer()
        }
        .onReceive(Timer.publish(every: 0.1, on: .main, in: .common).autoconnect()) { _ in
            updateCurrentTime()
        }
        .onReceive(statusObserver.$status) { newStatus in
            playerStatus = newStatus
        }
        .onChange(of: seekToTime) { newValue in
            if let time = newValue {
                performSeek(to: time)
                seekToTime = nil
            }
        }
    }
    
    // MARK: - Fullscreen View
    private var fullscreenView: some View {
        ZStack {
            // Video Player
            if let player = player {
                VideoPlayer(player: player)
                    .aspectRatio(DeviceInfo.screenWidth / DeviceInfo.screenHeight, contentMode: .fill)
                    .clipped()
                    .overlay(poseOverlay)
            } else {
                Rectangle()
                    .fill(Color.black)
                    .aspectRatio(DeviceInfo.screenWidth / DeviceInfo.screenHeight, contentMode: .fill)
                    .overlay(loadingOverlay)
            }
            
            // Controls Overlay
            if showControls {
                VStack {
                    Spacer()
                    controlsView
                        .padding(.horizontal)
                        .padding(.bottom, 20)
                        .background(Color.black.opacity(0.7))
                        .cornerRadius(12)
                }
            }
        }
        .onTapGesture {
            withAnimation(.easeInOut(duration: 0.3)) {
                showControls.toggle()
            }
        }
    }
    
    // MARK: - Normal View
    private var normalView: some View {
        VStack(spacing: 0) {
            // Video Player with Pose Overlay (Instagram-style: fills width, vertical 9:16 aspect ratio)
            GeometryReader { geometry in
                let availableWidth = geometry.size.width  // Accounts for parent padding
                let fullVideoHeight = availableWidth * 16 / 9  // Full 9:16 aspect ratio (portrait iPhone video)
                let visibleHeight = fullVideoHeight * 0.85  // Show only 85% vertically (crop top/bottom)
                
                if let player = player {
                    ZStack(alignment: .topLeading) {
                        VideoPlayer(player: player)
                            .frame(width: availableWidth, height: fullVideoHeight)  // Full dimensions
                            .aspectRatio(9/16, contentMode: .fill)  // 9:16 vertical video, fill and crop
                            .frame(width: availableWidth, height: visibleHeight, alignment: .top)  // Crop from top, show 85%
                            .clipped()
                            .cornerRadius(8)
                        
                        // Pose overlay matches FULL video dimensions (not visible/cropped area)
                        // Then clipped to match the same visible region as the video
                        if showingPoseOverlay, let poseData = poseData, !poseData.isEmpty {
                            PoseOverlayView(
                                pose: currentPose,
                                previewSize: CGSize(width: availableWidth, height: fullVideoHeight),  // Use FULL dimensions for coordinates
                                flipXAxis: true,  // Flip X-axis for video playback
                                isUploadedVideo: !isRecordedLive  // Use camera feed transformation for live recordings
                            )
                            .frame(width: availableWidth, height: visibleHeight, alignment: .top)  // Clip from top, matching video
                            .clipped()
                            .allowsHitTesting(false)
                        }
                    }
                    .frame(width: availableWidth, height: visibleHeight)
                    .cornerRadius(8)
                } else {
                    Rectangle()
                        .fill(Color.black)
                        .frame(width: availableWidth, height: visibleHeight)
                        .overlay(loadingOverlay)
                        .cornerRadius(8)
                }
            }
            .frame(maxWidth: .infinity)  // Fill available width
            .frame(height: UIScreen.main.bounds.width * 16 / 9 * 0.85)  // Explicit height to prevent expansion
            .fixedSize(horizontal: false, vertical: true)  // Prevent vertical expansion
            
            // Controls Below Video
            controlsView
                .padding(.horizontal)
                .padding(.top, 8)
        }
        .fixedSize(horizontal: false, vertical: false)  // Allow natural sizing
    }
    
    // MARK: - Pose Overlay
    private var poseOverlay: some View {
        Group {
            if showingPoseOverlay, let poseData = poseData, !poseData.isEmpty {
                GeometryReader { geometry in
                    PoseOverlayView(
                        pose: currentPose,
                        previewSize: geometry.size,
                        flipXAxis: true,  // Flip X-axis for video playback
                        isUploadedVideo: !isRecordedLive  // Use camera feed transformation for live recordings
                    )
                    .allowsHitTesting(false)
                }
            }
        }
    }
    
    // MARK: - Loading Overlay
    private var loadingOverlay: some View {
        VStack {
            if playerStatus == .failed {
                Image(systemName: "exclamationmark.triangle")
                    .font(.system(size: 40))
                    .foregroundColor(.red)
                Text("Video failed to load")
                    .foregroundColor(.red)
            } else {
                ProgressView()
                    .scaleEffect(1.5)
                Text("Loading video...")
                    .foregroundColor(.white)
            }
        }
    }
    
    // MARK: - Controls View
    private var controlsView: some View {
        VStack(spacing: 8) {
            // Progress Bar
            if duration > 0 {
                VStack(spacing: 4) {
                    Slider(
                        value: Binding(
                            get: { currentTime },
                            set: { newTime in
                                performSeek(to: newTime)
                            }
                        ),
                        in: 0...duration
                    )
                    .accentColor(.blue)
                    
                    HStack {
                        Text(timeString(currentTime))
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        Spacer()
                        
                        Text(timeString(duration))
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }
            
            // Control Buttons
            HStack(spacing: 16) {
                // Play/Pause Button
                Button(action: togglePlayPause) {
                    Image(systemName: isPlaying ? "pause.circle.fill" : "play.circle.fill")
                        .font(.system(size: 32))
                        .foregroundColor(.blue)
                }
                .disabled(playerStatus != .readyToPlay)
                
                // Fullscreen Button
                if let onFullScreenToggle = onFullScreenToggle {
                    Button(action: onFullScreenToggle) {
                        Image(systemName: "arrow.up.left.and.arrow.down.right")
                            .font(.system(size: 24))
                            .foregroundColor(.blue)
                    }
                }
                
                Spacer()
                
                // Pose Overlay Toggle
                if poseData != nil && !poseData!.isEmpty {
                    Button(action: togglePoseOverlay) {
                        HStack(spacing: 4) {
                            Image(systemName: showingPoseOverlay ? "figure.stand" : "figure.stand.line.dotted.figure.stand")
                                .font(.title3)
                            Text(showingPoseOverlay ? "Hide" : "Show")
                                .font(.caption)
                        }
                        .foregroundColor(.blue)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.blue.opacity(0.1))
                        .cornerRadius(16)
                    }
                }
            }
            
            // Frame Info
            if let poseData = poseData, !poseData.isEmpty {
                Text("Frame \(currentFrameIndex + 1)/\(poseData.count) • \(String(format: "%.1f", poseFrameRate))fps • \(String(format: "%.1f", currentTime))s")
                    .font(.caption2)
                    .foregroundColor(.secondary)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Color(.systemGray6))
                    .cornerRadius(6)
            }
        }
    }
    
    // MARK: - Computed Properties
    private var currentPose: PoseDetectionResult? {
        guard let poseData = poseData, !poseData.isEmpty else { return nil }
        
        // Calculate pose frame rate dynamically
        let calculatedPoseFrameRate = duration > 0 ? Double(poseData.count) / duration : 30.0
        let effectivePoseFrameRate = calculatedPoseFrameRate > 0 ? calculatedPoseFrameRate : 30.0
        
        // Update pose frame rate if it's significantly different
        if abs(poseFrameRate - effectivePoseFrameRate) > 1.0 {
            poseFrameRate = effectivePoseFrameRate
        }
        
        // Calculate frame index based on actual pose frame rate
        let targetFrameIndex = Int(currentTime * poseFrameRate)
        let frameIndex = min(max(targetFrameIndex, 0), poseData.count - 1)
        
        return poseData[frameIndex]
    }
    
    // MARK: - Methods
    private func setupPlayer() {
        player = AVPlayer(url: videoURL)
        
        // Observe player status
        if let player = player, let playerItem = player.currentItem {
            statusObserver.observePlayerItem(playerItem)
            
            // Get video duration and dimensions
            Task {
                if let duration = try? await player.currentItem?.asset.load(.duration) {
                    await MainActor.run {
                        self.duration = CMTimeGetSeconds(duration)
                    }
                }
                
                // Get video dimensions and frame rate
                if let asset = player.currentItem?.asset {
                    let tracks = try? await asset.loadTracks(withMediaType: .video)
                    if let videoTrack = tracks?.first {
                        let size = try? await videoTrack.load(.naturalSize)
                        let frameRate = try? await videoTrack.load(.nominalFrameRate)
                        let preferredTransform = try? await videoTrack.load(.preferredTransform)
                        // #region agent log
                        let logData: [String: Any] = [
                            "hypothesisId": "H2,H3",
                            "naturalSize": size != nil ? "\(size!.width)x\(size!.height)" : "nil",
                            "preferredTransform": preferredTransform != nil ? "\(preferredTransform!)" : "nil",
                            "frameRate": frameRate != nil ? Double(frameRate!) : 0
                        ]
                        VideoProcessingHelpers.writeDebugLog("Video player track info", data: logData, location: "VideoPlayerView.swift:305")
                        // #endregion
                        await MainActor.run {
                            if let size = size {
                                self.videoSize = size
                            }
                            if let frameRate = frameRate {
                                self.videoFrameRate = Double(frameRate)
                            }
                        }
                    }
                }
            }
            
            // Add observer for playback end
            NotificationCenter.default.addObserver(
                forName: .AVPlayerItemDidPlayToEndTime,
                object: player.currentItem,
                queue: .main
            ) { _ in
                isPlaying = false
                player.seek(to: .zero)
            }
        }
    }
    
    private func togglePlayPause() {
        guard let player = player, playerStatus == .readyToPlay else { return }
        
        if isPlaying {
            player.pause()
        } else {
            player.play()
        }
        isPlaying.toggle()
    }
    
    private func performSeek(to time: Double) {
        guard let player = player else { return }
        
        let cmTime = CMTime(seconds: time, preferredTimescale: 600)
        player.seek(to: cmTime)
        currentTime = time
        
        // Update frame index based on current time
        updateFrameIndex()
    }
    
    
    private func updateCurrentTime() {
        guard let player = player, isPlaying else { return }
        
        let time = CMTimeGetSeconds(player.currentTime())
        if !time.isNaN && !time.isInfinite {
            currentTime = time
            updateFrameIndex()
        }
    }
    
    private func updateFrameIndex() {
        guard let poseData = poseData, !poseData.isEmpty, duration > 0 else { return }
        
        // Calculate pose frame rate dynamically
        let calculatedPoseFrameRate = Double(poseData.count) / duration
        let effectivePoseFrameRate = calculatedPoseFrameRate > 0 ? calculatedPoseFrameRate : 30.0
        
        // Update pose frame rate if it's significantly different
        if abs(poseFrameRate - effectivePoseFrameRate) > 1.0 {
            poseFrameRate = effectivePoseFrameRate
        }
        
        // Calculate frame index based on actual pose frame rate
        let targetFrameIndex = Int(currentTime * poseFrameRate)
        currentFrameIndex = min(max(targetFrameIndex, 0), poseData.count - 1)
    }
    
    private func togglePoseOverlay() {
        showingPoseOverlay.toggle()
    }
    
    private func timeString(_ time: Double) -> String {
        let minutes = Int(time) / 60
        let seconds = Int(time) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
}

// MARK: - Player Status Observer
class PlayerStatusObserver: NSObject, ObservableObject {
    @Published var status: AVPlayerItem.Status = .unknown
    
    func observePlayerItem(_ playerItem: AVPlayerItem) {
        playerItem.addObserver(self, forKeyPath: "status", options: [.new], context: nil)
    }
    
    override func observeValue(forKeyPath keyPath: String?, of object: Any?, change: [NSKeyValueChangeKey : Any]?, context: UnsafeMutableRawPointer?) {
        if keyPath == "status" {
            if let playerItem = object as? AVPlayerItem {
                DispatchQueue.main.async {
                    self.status = playerItem.status
                    if playerItem.status == .readyToPlay {
                        print("🎬 VideoPlayerView: Player is ready to play")
                    } else if playerItem.status == .failed {
                        print("❌ VideoPlayerView: Player failed to load: \(playerItem.error?.localizedDescription ?? "Unknown error")")
                    }
                }
            }
        }
    }
    
    deinit {
        // Remove observer if needed
    }
}

// MARK: - CALayer-based Pose Overlay
struct PoseOverlayViewCALayer: UIViewRepresentable {
    let pose: PoseDetectionResult?
    let videoSize: CGSize
    let containerSize: CGSize
    
    func makeUIView(context: Context) -> UIView {
        let view = UIView()
        view.backgroundColor = UIColor.clear
        return view
    }
    
    func updateUIView(_ uiView: UIView, context: Context) {
        // Remove existing pose layers
        uiView.layer.sublayers?.removeAll { $0.name == "poseLayer" }
        
        guard let pose = pose else { return }
        
        // Create pose layer
        let poseLayer = CALayer()
        poseLayer.name = "poseLayer"
        poseLayer.frame = uiView.bounds
        poseLayer.backgroundColor = UIColor.clear.cgColor
        
        // Add keypoints
        for keypoint in pose.keypoints {
            let keypointLayer = createKeypointLayer(for: keypoint, in: uiView.bounds)
            poseLayer.addSublayer(keypointLayer)
        }
        
        // Add skeleton lines
        let skeletonLayer = createSkeletonLayer(for: pose, in: uiView.bounds)
        poseLayer.addSublayer(skeletonLayer)
        
        uiView.layer.addSublayer(poseLayer)
    }
    
    private func createKeypointLayer(for keypoint: PoseKeypoint, in bounds: CGRect) -> CALayer {
        let layer = CAShapeLayer()
        
        // Calculate aspect ratio to properly scale coordinates
        let videoAspectRatio = videoSize.width / videoSize.height
        let containerAspectRatio = bounds.width / bounds.height
        
        var scaledWidth = bounds.width
        var scaledHeight = bounds.height
        var offsetX: CGFloat = 0
        var offsetY: CGFloat = 0
        
        if videoAspectRatio > containerAspectRatio {
            // Video is wider - fit to width
            scaledHeight = bounds.width / videoAspectRatio
            offsetY = (bounds.height - scaledHeight) / 2
        } else {
            // Video is taller - fit to height
            scaledWidth = bounds.height * videoAspectRatio
            offsetX = (bounds.width - scaledWidth) / 2
        }
        
        // Convert normalized coordinates to scaled video coordinates
        // Apply Y-flip to match Vision's bottom-left origin to UIKit's top-left origin
        let flippedY = 1.0 - keypoint.position.y
        let screenX = keypoint.position.x * scaledWidth + offsetX
        let screenY = flippedY * scaledHeight + offsetY
        
        // Create circle path
        let radius: CGFloat = 4
        let path = UIBezierPath(arcCenter: CGPoint(x: screenX, y: screenY), 
                               radius: radius, 
                               startAngle: 0, 
                               endAngle: 2 * .pi, 
                               clockwise: true)
        
        layer.path = path.cgPath
        layer.fillColor = keypointColor(for: keypoint).cgColor
        layer.strokeColor = UIColor.white.cgColor
        layer.lineWidth = 1
        
        return layer
    }
    
    private func createSkeletonLayer(for pose: PoseDetectionResult, in bounds: CGRect) -> CAShapeLayer {
        let layer = CAShapeLayer()
        let path = UIBezierPath()
        
        // Define skeleton connections
        let connections = [
            ("leftShoulder", "rightShoulder"),
            ("leftShoulder", "leftElbow"),
            ("leftElbow", "leftWrist"),
            ("rightShoulder", "rightElbow"),
            ("rightElbow", "rightWrist"),
            ("leftShoulder", "leftHip"),
            ("rightShoulder", "rightHip"),
            ("leftHip", "rightHip"),
            ("leftHip", "leftKnee"),
            ("leftKnee", "leftAnkle"),
            ("rightHip", "rightKnee"),
            ("rightKnee", "rightAnkle")
        ]
        
        // Calculate aspect ratio to properly scale coordinates (same as keypoints)
        let videoAspectRatio = videoSize.width / videoSize.height
        let containerAspectRatio = bounds.width / bounds.height
        
        var scaledWidth = bounds.width
        var scaledHeight = bounds.height
        var offsetX: CGFloat = 0
        var offsetY: CGFloat = 0
        
        if videoAspectRatio > containerAspectRatio {
            // Video is wider - fit to width
            scaledHeight = bounds.width / videoAspectRatio
            offsetY = (bounds.height - scaledHeight) / 2
        } else {
            // Video is taller - fit to height
            scaledWidth = bounds.height * videoAspectRatio
            offsetX = (bounds.width - scaledWidth) / 2
        }
        
        for (startName, endName) in connections {
            if let startPoint = pose.keypoints.first(where: { $0.name == startName }),
               let endPoint = pose.keypoints.first(where: { $0.name == endName }) {
                
                // Apply Y-flip to match Vision's bottom-left origin to UIKit's top-left origin
                let startFlippedY = 1.0 - startPoint.position.y
                let endFlippedY = 1.0 - endPoint.position.y
                
                let startX = startPoint.position.x * scaledWidth + offsetX
                let startY = startFlippedY * scaledHeight + offsetY
                let endX = endPoint.position.x * scaledWidth + offsetX
                let endY = endFlippedY * scaledHeight + offsetY
                
                path.move(to: CGPoint(x: startX, y: startY))
                path.addLine(to: CGPoint(x: endX, y: endY))
            }
        }
        
        layer.path = path.cgPath
        layer.strokeColor = UIColor.blue.cgColor
        layer.lineWidth = 2
        layer.fillColor = UIColor.clear.cgColor
        
        return layer
    }
    
    private func keypointColor(for keypoint: PoseKeypoint) -> UIColor {
        // Color keypoints based on confidence
        let confidence = keypoint.confidence
        if confidence > 0.7 {
            return UIColor.green
        } else if confidence > 0.4 {
            return UIColor.yellow
        } else {
            return UIColor.red
        }
    }
}

#Preview {
    VideoPlayerView(
        videoURL: URL(fileURLWithPath: "/path/to/video.mp4"),
        poseData: nil
    )
}