//
//  VideoPlayerView.swift
//  MoveAI
//
//  Created by Dave Mathew on 10/11/25.
//  Requirements: docs/screens/video-review.md
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
    /// When true, ignore aspect ratio height constraints and fill the container.
    var isFullBleed: Bool = false
    
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
    var cueOverlay: CoachingCueOverlay?
    var cueTopPadding: CGFloat = 12
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
    
    init(videoURL: URL, poseData: [PoseDetectionResult]?, isRecordedLive: Bool = false, analysisResult: AnalysisResult? = nil, highlightedFeedbackIds: Set<UUID> = [], constrainedHeight: CGFloat? = nil, maxVisibleHeightRatio: CGFloat = 0.85, seekToTime: Binding<TimeInterval?> = .constant(nil), onFullScreenToggle: (() -> Void)? = nil, isFullScreenMode: Bool = false, playback: PlaybackController, cueOverlay: CoachingCueOverlay? = nil, cueTopPadding: CGFloat = 12, isFullBleed: Bool = false, onExitFullScreen: (() -> Void)? = nil, fullScreenTitle: String? = nil) {
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
        self.cueOverlay = cueOverlay
        self.cueTopPadding = cueTopPadding
        self.isFullBleed = isFullBleed
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
        .onChange(of: playback.currentTime) { _ in
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
            
            if let cueOverlay {
                CueOverlayView(overlay: cueOverlay)
                    .padding(.top, cueTopPadding)
                    .padding(.horizontal, 16)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                    .transition(.opacity)
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
                let containerHeight = geometry.size.height
                
                if isFullBleed {
                    // Full-bleed review surface: edge-to-edge with aspect fill (no letterboxing).
                    let displaySize: CGSize = {
                        if let ds = playback.videoDisplaySize, ds.width > 0, ds.height > 0 {
                            return ds
                        }
                        let h = availableWidth * DeviceInfo.screenHeight / DeviceInfo.screenWidth
                        return CGSize(width: availableWidth, height: h)
                    }()
                    let fillSize = VideoSurfaceLayoutCalculator.filledSize(
                        containerSize: CGSize(width: availableWidth, height: containerHeight),
                        displaySize: displaySize
                    )
                    let filledWidth = fillSize.width
                    let filledHeight = fillSize.height

                    Group {
                        if let player = playback.player {
                            ZStack {
                                PlayerContainerView(player: player, useAspectFit: false)
                                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                                    .clipped()
                                if showingPoseOverlay, let poseData = poseData, !poseData.isEmpty {
                                    PoseOverlayView(
                                        pose: currentPose,
                                        previewSize: fillSize,
                                        flipXAxis: true,
                                        isUploadedVideo: !isRecordedLive,
                                        style: .telemetry,
                                        highlightedJoints: activeHighlightedJoints
                                    )
                                    .frame(width: filledWidth, height: filledHeight)
                                    .position(x: availableWidth / 2, y: containerHeight / 2)
                                    .allowsHitTesting(false)
                                }
                                if let cueOverlay {
                                    CueOverlayView(overlay: cueOverlay)
                                        .padding(.top, cueTopPadding)
                                        .padding(.horizontal, 12)
                                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                                        .transition(.opacity)
                                }
                            }
                            .frame(width: availableWidth, height: containerHeight)
                            .clipped()
                            .cornerRadius(0)
                        } else {
                            Rectangle()
                                .fill(telemetryBackground)
                                .frame(width: availableWidth, height: containerHeight)
                                .overlay(loadingOverlay)
                                .cornerRadius(0)
                        }
                    }
                    .accessibilityIdentifier("VideoReview.VideoSurface")
                    .accessibilityElement(children: .contain)
                } else {
                    // Non-fullBleed: original 16:9 / scale behavior.
                    let baseVideoHeight = availableWidth * 16 / 9
                    let baseSize = CGSize(width: availableWidth, height: baseVideoHeight)
                    let visibleHeight = min(videoHeight, baseVideoHeight * maxVisibleHeightRatio)
                    let scale = max(1.0, visibleHeight / baseVideoHeight)
                    
                    if let player = playback.player {
                        let videoLayer = ZStack(alignment: .topLeading) {
                            PlayerContainerView(player: player, useAspectFit: false)
                                .frame(width: baseSize.width, height: baseSize.height)
                            if showingPoseOverlay, let poseData = poseData, !poseData.isEmpty {
                                PoseOverlayView(
                                    pose: currentPose,
                                    previewSize: baseSize,
                                    flipXAxis: true,
                                    isUploadedVideo: !isRecordedLive,
                                    style: .telemetry,
                                    highlightedJoints: activeHighlightedJoints
                                )
                                .frame(width: baseSize.width, height: baseSize.height)
                                .allowsHitTesting(false)
                            }
                        }
                        .frame(width: baseSize.width, height: baseSize.height)
                        .scaleEffect(scale, anchor: .top)
                        .frame(width: availableWidth, height: visibleHeight, alignment: .top)
                        .clipped()
                        .cornerRadius(12)
                        
                        ZStack(alignment: .topLeading) {
                            videoLayer
                            if let cueOverlay {
                                CueOverlayView(overlay: cueOverlay)
                                    .padding(.top, cueTopPadding)
                                    .padding(.horizontal, 12)
                                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                                    .transition(.opacity)
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
                        style: .telemetry,
                        highlightedJoints: activeHighlightedJoints
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
    private var activeHighlightedJoints: [BodyJoint: FeedbackSeverity] {
        guard let feedback = analysisResult?.feedback else { return [:] }
        return PoseOverlayHighlighting.activeHighlightedJoints(
            feedback: feedback,
            at: playback.currentTime,
            tolerance: 0.2
        )
    }

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
    /// When true (e.g. review full-bleed), use aspect fit so entire frame is visible; otherwise aspect fill.
    var useAspectFit: Bool = false
    
    func makeUIViewController(context: Context) -> AVPlayerViewController {
        let controller = AVPlayerViewController()
        controller.player = player
        controller.showsPlaybackControls = false
        controller.videoGravity = VideoSurfaceLayoutCalculator.videoGravity(useAspectFit: useAspectFit)
        return controller
    }
    
    func updateUIViewController(_ uiViewController: AVPlayerViewController, context: Context) {
        if uiViewController.player !== player {
            uiViewController.player = player
        }
        uiViewController.showsPlaybackControls = false
        uiViewController.videoGravity = VideoSurfaceLayoutCalculator.videoGravity(useAspectFit: useAspectFit)
    }
}

enum VideoSurfaceLayoutCalculator {
    static func filledSize(containerSize: CGSize, displaySize: CGSize) -> CGSize {
        let safeContainerWidth = max(containerSize.width, 1)
        let safeContainerHeight = max(containerSize.height, 1)
        let safeDisplayWidth = max(displaySize.width, 1)
        let safeDisplayHeight = max(displaySize.height, 1)
        let fillScale = max(safeContainerWidth / safeDisplayWidth, safeContainerHeight / safeDisplayHeight)

        return CGSize(
            width: safeDisplayWidth * fillScale,
            height: safeDisplayHeight * fillScale
        )
    }

    static func videoGravity(useAspectFit: Bool) -> AVLayerVideoGravity {
        useAspectFit ? .resizeAspect : .resizeAspectFill
    }
}

// MARK: - Shared Playback Controller
@MainActor
final class PlaybackController: ObservableObject {
    enum SeekPrecision {
        case interactive
        case exact

        var tolerance: CMTime {
            switch self {
            case .interactive:
                return CMTime(seconds: 1.0 / 20.0, preferredTimescale: 600)
            case .exact:
                return .zero
            }
        }
    }

    @Published var player: AVPlayer?
    @Published var isPlaying = false
    @Published var currentTime: Double = 0
    @Published var duration: Double = 0
    @Published var playerStatus: AVPlayerItem.Status = .unknown
    @Published var nominalFrameRate: Double = 30.0
    /// Display size of the video (naturalSize with preferredTransform applied). Used for aspect-fit layout; nil until loaded.
    @Published var videoDisplaySize: CGSize?

    private let videoURL: URL
    private let statusObserver = PlayerStatusObserver()
    private var didSetup = false
    private var latestSeekRequestID: Int = 0
    private var timeObserverToken: Any?
    private var endOfPlaybackObserver: NSObjectProtocol?
    /// Plain (non-@Published) reference so deinit can detach the time observer;
    /// @Published accessors are main-actor-isolated and unavailable in deinit.
    private var observedPlayer: AVPlayer?

    init(videoURL: URL) {
        self.videoURL = videoURL
    }

    deinit {
        if let timeObserverToken, let observedPlayer {
            observedPlayer.removeTimeObserver(timeObserverToken)
        }
        if let endOfPlaybackObserver {
            NotificationCenter.default.removeObserver(endOfPlaybackObserver)
        }
    }

    func setup() {
        guard !didSetup else { return }
        didSetup = true

        let player = AVPlayer(url: videoURL)
        self.player = player
        self.observedPlayer = player

        if let playerItem = player.currentItem {
            statusObserver.observePlayerItem(playerItem)
            statusObserver.onStatusChange = { [weak self] status in
                self?.playerStatus = status
            }
        }

        // Drives playback-position UI. Fires only while the player's time
        // advances — unlike a free-running Timer, it costs nothing while paused.
        timeObserverToken = player.addPeriodicTimeObserver(
            forInterval: CMTime(seconds: 0.1, preferredTimescale: 600),
            queue: .main
        ) { [weak self] time in
            guard let self else { return }
            let seconds = CMTimeGetSeconds(time)
            if seconds.isFinite, !seconds.isNaN, self.isPlaying {
                self.currentTime = seconds
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
                    if let frameRate, frameRate > 0 {
                        await MainActor.run {
                            self.nominalFrameRate = Double(frameRate)
                        }
                    }
                    // Display size for aspect-fit layout (orientation from preferredTransform).
                    if let naturalSize = size, let transform = preferredTransform {
                        let transformed = naturalSize.applying(transform)
                        let displaySize = CGSize(width: abs(transformed.width), height: abs(transformed.height))
                        await MainActor.run {
                            self.videoDisplaySize = displaySize
                        }
                    }
                }
            }
        }
        
        endOfPlaybackObserver = NotificationCenter.default.addObserver(
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
    
    func performSeek(to time: Double, precision: SeekPrecision = .exact) {
        guard let player else { return }

        let clampedTime: Double = {
            let upperBound = duration.isFinite && duration > 0 ? duration : max(time, 0)
            return max(0, min(time, upperBound))
        }()

        latestSeekRequestID += 1
        let requestID = latestSeekRequestID
        let targetTime = CMTime(seconds: clampedTime, preferredTimescale: 600)
        let tolerance = precision.tolerance

        player.seek(to: targetTime, toleranceBefore: tolerance, toleranceAfter: tolerance) { [weak self] finished in
            Task { @MainActor in
                guard let self else { return }
                guard requestID == self.latestSeekRequestID else { return }

                let resolvedTime = CMTimeGetSeconds(player.currentTime())
                if finished, resolvedTime.isFinite, !resolvedTime.isNaN {
                    self.currentTime = resolvedTime
                } else {
                    self.currentTime = clampedTime
                }
            }
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

    // Block-based observation invalidates itself when this object (or the
    // token) deallocates — old-style addObserver had no matching removeObserver
    // and could crash when the player item outlived this observer.
    private var statusObservation: NSKeyValueObservation?

    func observePlayerItem(_ playerItem: AVPlayerItem) {
        statusObservation = playerItem.observe(\.status, options: [.new]) { [weak self] playerItem, _ in
            DispatchQueue.main.async {
                self?.status = playerItem.status
                self?.onStatusChange?(playerItem.status)
                if playerItem.status == .failed {
                    print("❌ VideoPlayerView: Player failed to load: \(playerItem.error?.localizedDescription ?? "Unknown error")")
                }
            }
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
