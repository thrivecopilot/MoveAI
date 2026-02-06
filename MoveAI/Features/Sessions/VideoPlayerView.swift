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
    var analysisResult: AnalysisResult?
    var highlightedFeedbackIds: Set<UUID> = []
    /// When set (e.g. in review layout), the video + controls area is constrained to this height.
    var constrainedHeight: CGFloat?
    /// Maximum visible portion of the video height (0...1). Default keeps a top-cropped cinematic feel.
    var maxVisibleHeightRatio: CGFloat = 0.85
    
    @State private var showingPoseOverlay = true
    @State private var currentFrameIndex = 0
    @State private var videoSize: CGSize = CGSize(width: 1920, height: 1080)
    @State private var videoFrameRate: Double = 30.0
    @State private var poseFrameRate: Double = 30.0
    @State private var showControls = true
    @Binding var seekToTime: TimeInterval?
    var onFullScreenToggle: (() -> Void)?
    var isFullScreenMode: Bool = false
    @ObservedObject var playback: PlaybackController
    /// Called when user taps exit in fullscreen (e.g. dismiss sheet). Takes precedence over onFullScreenToggle in fullscreen.
    var onExitFullScreen: (() -> Void)?
    /// Title shown in fullscreen top bar (e.g. movement name).
    var fullScreenTitle: String?
    
    private let telemetryBackground = Color(red: 0.04, green: 0.05, blue: 0.07)
    private let telemetryPanel = Color(red: 0.08, green: 0.11, blue: 0.16)
    private let telemetryPanelStroke = Color.white.opacity(0.10)
    private let telemetryAccent = Color(red: 0.24, green: 0.86, blue: 1.0)
    private let telemetryGood = Color(red: 0.16, green: 0.97, blue: 0.65)
    private let telemetryIssue = Color(red: 1.0, green: 0.42, blue: 0.42)
    private let telemetryText = Color(red: 0.90, green: 0.93, blue: 0.97)
    private let telemetryMuted = Color.white.opacity(0.65)
    
    init(videoURL: URL, poseData: [PoseDetectionResult]?, isRecordedLive: Bool = false, analysisResult: AnalysisResult? = nil, highlightedFeedbackIds: Set<UUID> = [], constrainedHeight: CGFloat? = nil, maxVisibleHeightRatio: CGFloat = 0.85, seekToTime: Binding<TimeInterval?> = .constant(nil), onFullScreenToggle: (() -> Void)? = nil, isFullScreenMode: Bool = false, playback: PlaybackController, onExitFullScreen: (() -> Void)? = nil, fullScreenTitle: String? = nil) {
        self.videoURL = videoURL
        self.poseData = poseData
        self.isRecordedLive = isRecordedLive
        self.analysisResult = analysisResult
        self.highlightedFeedbackIds = highlightedFeedbackIds
        self.constrainedHeight = constrainedHeight
        self.maxVisibleHeightRatio = maxVisibleHeightRatio
        self._seekToTime = seekToTime
        self.onFullScreenToggle = onFullScreenToggle
        self.isFullScreenMode = isFullScreenMode
        self.playback = playback
        self.onExitFullScreen = onExitFullScreen
        self.fullScreenTitle = fullScreenTitle
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
            playback.setup()
        }
        .onReceive(Timer.publish(every: 0.1, on: .main, in: .common).autoconnect()) { _ in
            playback.updateCurrentTime()
            updateFrameIndex()
        }
        .onChange(of: seekToTime) { newValue in
            if let time = newValue {
                playback.performSeek(to: time)
                seekToTime = nil
            }
        }
    }
    
    // MARK: - Fullscreen View (original: fill screen, pose overlay matches video frame)
    private var fullscreenView: some View {
        ZStack {
            if let player = playback.player {
                PlayerContainerView(player: player)
                    .aspectRatio(DeviceInfo.screenWidth / DeviceInfo.screenHeight, contentMode: .fill)
                    .clipped()
                    .overlay(poseOverlay)
            } else {
                Rectangle()
                    .fill(telemetryBackground)
                    .aspectRatio(DeviceInfo.screenWidth / DeviceInfo.screenHeight, contentMode: .fill)
                    .overlay(loadingOverlay)
            }
            
            if showControls {
                VStack(spacing: 0) {
                    // Top bar: Done + title (fullscreen only, shown on tap)
                    if isFullScreenMode, onExitFullScreen != nil {
                        HStack {
                            Button(action: { onExitFullScreen?() }) {
                                Label("Done", systemImage: "xmark.circle.fill")
                                    .font(.title3)
                                    .foregroundColor(.white)
                                    .shadow(color: .black.opacity(0.5), radius: 1)
                            }
                            if let title = fullScreenTitle, !title.isEmpty {
                                Text(title)
                                    .font(.headline)
                                    .foregroundColor(.white)
                                    .shadow(color: .black.opacity(0.5), radius: 1)
                                    .lineLimit(1)
                            }
                            Spacer(minLength: 0)
                        }
                        .padding(.horizontal, 20)
                        .padding(.top, 12)
                        .padding(.bottom, 10)
                        .background(
                            LinearGradient(
                                colors: [Color.black.opacity(0.6), Color.black.opacity(0)],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                    }
                    Spacer()
                    Spacer()
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
        let videoHeight: CGFloat = {
            if let h = constrainedHeight {
                return max(0, h)
            }
            return UIScreen.main.bounds.width * 16 / 9 * 0.85
        }()
        
        return VStack(spacing: 0) {
            GeometryReader { geometry in
                let availableWidth = geometry.size.width
                let fullVideoHeight = availableWidth * 16 / 9
                let visibleHeight = min(videoHeight, fullVideoHeight * maxVisibleHeightRatio)
                
                if let player = playback.player {
                    ZStack(alignment: .topLeading) {
                        PlayerContainerView(player: player)
                            .frame(width: availableWidth, height: fullVideoHeight)
                            .aspectRatio(9/16, contentMode: .fill)
                            .frame(width: availableWidth, height: visibleHeight, alignment: .top)
                            .clipped()
                            .cornerRadius(12)
                        
                        if showingPoseOverlay, let poseData = poseData, !poseData.isEmpty {
                            PoseOverlayView(
                                pose: currentPose,
                                previewSize: CGSize(width: availableWidth, height: fullVideoHeight),
                                flipXAxis: true,
                                isUploadedVideo: !isRecordedLive,
                                style: .telemetry
                            )
                            .frame(width: availableWidth, height: visibleHeight, alignment: .top)
                            .clipped()
                            .allowsHitTesting(false)
                        }
                        
                    }
                    .frame(width: availableWidth, height: visibleHeight)
                    .cornerRadius(12)
                } else {
                    Rectangle()
                        .fill(telemetryBackground)
                        .frame(width: availableWidth, height: visibleHeight)
                        .overlay(loadingOverlay)
                        .cornerRadius(12)
                }
            }
            .frame(maxWidth: .infinity)
            .frame(height: videoHeight)
        }
        .modifier(ConstrainedHeightModifier(height: constrainedHeight))
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
                        isUploadedVideo: !isRecordedLive,  // Use camera feed transformation for live recordings
                        style: .telemetry
                    )
                    .allowsHitTesting(false)
                }
            }
        }
    }
    
    // MARK: - Loading Overlay
    private var loadingOverlay: some View {
        VStack {
            if playback.playerStatus == .failed {
                Image(systemName: "exclamationmark.triangle")
                    .font(.system(size: 40))
                    .foregroundColor(.red)
                Text("Video failed to load")
                    .foregroundColor(.red)
            } else {
                ProgressView()
                    .scaleEffect(1.5)
                Text("Loading video...")
                    .foregroundColor(telemetryText)
            }
        }
    }
    
    
    // MARK: - Computed Properties
    private var currentPose: PoseDetectionResult? {
        guard let poseData = poseData, !poseData.isEmpty else { return nil }
        
        // Calculate pose frame rate dynamically
        let calculatedPoseFrameRate = playback.duration > 0 ? Double(poseData.count) / playback.duration : 30.0
        let effectivePoseFrameRate = calculatedPoseFrameRate > 0 ? calculatedPoseFrameRate : 30.0
        
        // Update pose frame rate if it's significantly different
        if abs(poseFrameRate - effectivePoseFrameRate) > 1.0 {
            poseFrameRate = effectivePoseFrameRate
        }
        
        // Calculate frame index based on actual pose frame rate
        let targetFrameIndex = Int(playback.currentTime * poseFrameRate)
        let frameIndex = min(max(targetFrameIndex, 0), poseData.count - 1)
        
        return poseData[frameIndex]
    }
    
    private func updateFrameIndex() {
        guard let poseData = poseData, !poseData.isEmpty, playback.duration > 0 else { return }
        
        // Calculate pose frame rate dynamically
        let calculatedPoseFrameRate = Double(poseData.count) / playback.duration
        let effectivePoseFrameRate = calculatedPoseFrameRate > 0 ? calculatedPoseFrameRate : 30.0
        
        // Update pose frame rate if it's significantly different
        if abs(poseFrameRate - effectivePoseFrameRate) > 1.0 {
            poseFrameRate = effectivePoseFrameRate
        }
        
        // Calculate frame index based on actual pose frame rate
        let targetFrameIndex = Int(playback.currentTime * poseFrameRate)
        currentFrameIndex = min(max(targetFrameIndex, 0), poseData.count - 1)
    }
}

// MARK: - Constrained Height Modifier
private struct ConstrainedHeightModifier: ViewModifier {
    let height: CGFloat?
    func body(content: Content) -> some View {
        if let h = height {
            content.frame(height: h)
        } else {
            content
        }
    }
}

// MARK: - AVPlayer Container (controls disabled)
private struct PlayerContainerView: UIViewControllerRepresentable {
    let player: AVPlayer
    
    func makeUIViewController(context: Context) -> AVPlayerViewController {
        let controller = AVPlayerViewController()
        controller.player = player
        controller.showsPlaybackControls = false
        controller.videoGravity = .resizeAspectFill
        return controller
    }
    
    func updateUIViewController(_ uiViewController: AVPlayerViewController, context: Context) {
        if uiViewController.player !== player {
            uiViewController.player = player
        }
        uiViewController.showsPlaybackControls = false
    }
}

// MARK: - Shared Playback Controller
@MainActor
final class PlaybackController: ObservableObject {
    @Published var player: AVPlayer?
    @Published var isPlaying = false
    @Published var currentTime: Double = 0
    @Published var duration: Double = 0
    @Published var playerStatus: AVPlayerItem.Status = .unknown
    
    private let videoURL: URL
    private let statusObserver = PlayerStatusObserver()
    private var didSetup = false
    
    init(videoURL: URL) {
        self.videoURL = videoURL
    }
    
    func setup() {
        guard !didSetup else { return }
        didSetup = true
        
        let player = AVPlayer(url: videoURL)
        self.player = player
        
        if let playerItem = player.currentItem {
            statusObserver.observePlayerItem(playerItem)
            statusObserver.onStatusChange = { [weak self] status in
                self?.playerStatus = status
            }
        }
        
        Task {
            if let duration = try? await player.currentItem?.asset.load(.duration) {
                self.duration = CMTimeGetSeconds(duration)
            }
            
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
                    VideoProcessingHelpers.writeDebugLog("Video player track info", data: logData, location: "VideoPlayerView.swift:PlaybackController")
                    // #endregion
                }
            }
        }
        
        NotificationCenter.default.addObserver(
            forName: .AVPlayerItemDidPlayToEndTime,
            object: player.currentItem,
            queue: .main
        ) { [weak self] _ in
            self?.isPlaying = false
            player.seek(to: .zero)
        }
    }
    
    func togglePlayPause() {
        guard let player, playerStatus == .readyToPlay else { return }
        if isPlaying {
            player.pause()
        } else {
            player.play()
        }
        isPlaying.toggle()
    }
    
    func performSeek(to time: Double) {
        guard let player else { return }
        let cmTime = CMTime(seconds: time, preferredTimescale: 600)
        player.seek(to: cmTime)
        currentTime = time
    }
    
    func updateCurrentTime() {
        guard let player, isPlaying else { return }
        let time = CMTimeGetSeconds(player.currentTime())
        if !time.isNaN && !time.isInfinite {
            currentTime = time
        }
    }
    
    func timeString(_ time: Double) -> String {
        let minutes = Int(time) / 60
        let seconds = Int(time) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
}

// MARK: - Player Status Observer
class PlayerStatusObserver: NSObject, ObservableObject {
    @Published var status: AVPlayerItem.Status = .unknown
    var onStatusChange: ((AVPlayerItem.Status) -> Void)?
    
    func observePlayerItem(_ playerItem: AVPlayerItem) {
        playerItem.addObserver(self, forKeyPath: "status", options: [.new], context: nil)
    }
    
    override func observeValue(forKeyPath keyPath: String?, of object: Any?, change: [NSKeyValueChangeKey : Any]?, context: UnsafeMutableRawPointer?) {
        if keyPath == "status" {
            if let playerItem = object as? AVPlayerItem {
                DispatchQueue.main.async {
                    self.status = playerItem.status
                    self.onStatusChange?(playerItem.status)
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
        poseData: nil,
        playback: PlaybackController(videoURL: URL(fileURLWithPath: "/path/to/video.mp4"))
    )
}
