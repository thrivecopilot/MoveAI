// Requirements: docs/screens/video-review.md

import SwiftUI

struct PlaybackControlsBar: View {
    @ObservedObject var playback: PlaybackController
    let analysisResult: AnalysisResult?
    var issueMarkers: [VideoTimelineView.IssueMarker] = []
    var highlightedFeedbackIds: Set<UUID> = []
    var onMarkerTap: ((VideoTimelineView.IssueMarker) -> Void)?
    
    private let barBackground = Color(red: 0.07, green: 0.09, blue: 0.13)
    private let barStroke = Color.white.opacity(0.08)
    private let accent = Color(red: 0.24, green: 0.86, blue: 1.0)
    private let good = Color(red: 0.16, green: 0.97, blue: 0.65)
    private let issue = Color(red: 1.0, green: 0.42, blue: 0.42)
    private let muted = Color.white.opacity(0.7)
    
    var body: some View {
        VStack(spacing: 6) {
            HStack(spacing: 14) {
                Button(action: { playback.togglePlayPause() }) {
                    Image(systemName: playback.isPlaying ? "pause.fill" : "play.fill")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.white)
                        .frame(width: 28, height: 28)
                        .background(Color.white.opacity(0.08))
                        .clipShape(Circle())
                }
                .disabled(playback.playerStatus != .readyToPlay)
                
                if playback.duration > 0 {
                    let markers = issueMarkers.isEmpty ? TimelineMarkers.from(analysisResult).issueMarkers : issueMarkers
                    VideoTimelineView(
                        duration: playback.duration,
                        currentTime: $playback.currentTime,
                        goodMoments: [],
                        issueMarkers: markers,
                        highlightedFeedbackIds: highlightedFeedbackIds,
                        onSeek: { playback.performSeek(to: $0) },
                        style: .ticks,
                        trackColor: muted.opacity(0.35),
                        fillColor: accent.opacity(0.2),
                        thumbColor: .white,
                        thumbStroke: accent,
                        timeColor: muted,
                        goodMarkerColor: good,
                        issueMarkerColor: issue,
                        showTimeLabels: false,
                        onMarkerTap: onMarkerTap
                    )
                    .frame(maxWidth: .infinity)
                }
                
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
        }
        .frame(maxWidth: .infinity)
        .background(barBackground.ignoresSafeArea(.container, edges: .bottom))
        .overlay(
            Rectangle()
                .fill(barStroke)
                .frame(height: 1),
            alignment: .top
        )
    }
}
