//
//  VideoTimelineView.swift
//  MoveAI
//
//  Timeline scrubber with good moment markers (●) and needs-improvement markers (▲).
//  Scrubbing updates playback; tapping a marker snaps to that time.
//

import SwiftUI

struct VideoTimelineView: View {
    enum TimelineStyle {
        case bar
        case ticks
    }
    
    let duration: TimeInterval
    @Binding var currentTime: TimeInterval
    let goodMoments: [TimeInterval]
    let issueMarkers: [IssueMarker]
    var highlightedFeedbackIds: Set<UUID> = []
    var onSeek: (TimeInterval) -> Void
    var style: TimelineStyle = .bar
    
    var trackColor: Color = Color(.systemGray5)
    var fillColor: Color = Color.accentColor.opacity(0.4)
    var thumbColor: Color = .white
    var thumbStroke: Color = Color.accentColor
    var timeColor: Color = .secondary
    var goodMarkerColor: Color = .green
    var issueMarkerColor: Color = .orange
    var showTimeLabels: Bool = true
    
    struct IssueMarker: Identifiable {
        let id: UUID
        let timestamp: TimeInterval
        let label: String?
    }
    
    @State private var isDragging = false
    
    private var trackHeight: CGFloat { style == .ticks ? 20 : 28 }
    private let markerTapSnapThreshold: TimeInterval = 0.3
    
    var body: some View {
        VStack(spacing: 4) {
            ZStack(alignment: .leading) {
                track
                markersOverlay
                thumb
            }
            .frame(height: trackHeight)
            
            if showTimeLabels {
                HStack {
                    Text(timeString(currentTime))
                        .font(.caption)
                        .foregroundColor(timeColor)
                    Spacer()
                    Text(timeString(duration))
                        .font(.caption)
                        .foregroundColor(timeColor)
                }
            }
        }
        .padding(.horizontal, 4)
    }
    
    private var track: some View {
        Group {
            if style == .ticks {
                Capsule()
                    .fill(trackColor)
                    .frame(height: 2)
                    .overlay(
                        GeometryReader { geo in
                            Rectangle()
                                .fill(fillColor)
                                .frame(width: duration > 0 ? geo.size.width * CGFloat(currentTime / duration) : 0, height: 2)
                                .animation(.none, value: currentTime)
                        }
                        .clipShape(Capsule()),
                        alignment: .leading
                    )
            } else {
                RoundedRectangle(cornerRadius: 4)
                    .fill(trackColor)
                    .overlay(
                        GeometryReader { geo in
                            Rectangle()
                                .fill(fillColor)
                                .frame(width: duration > 0 ? geo.size.width * CGFloat(currentTime / duration) : 0)
                                .animation(.none, value: currentTime)
                        }
                        .clipShape(RoundedRectangle(cornerRadius: 4)),
                        alignment: .leading
                    )
            }
        }
    }
    
    private var markersOverlay: some View {
        GeometryReader { geo in
            let w = geo.size.width
            let safeDuration = max(duration, 0.01)
            
            ForEach(goodMoments, id: \.self) { t in
                let x = w * CGFloat(t / safeDuration)
                if style == .ticks {
                    Rectangle()
                        .fill(goodMarkerColor)
                        .frame(width: 2, height: 10)
                        .position(x: x, y: trackHeight / 2)
                        .allowsHitTesting(true)
                        .onTapGesture { onSeek(t) }
                } else {
                    Circle()
                        .fill(goodMarkerColor)
                        .frame(width: 8, height: 8)
                        .overlay(Circle().stroke(Color.white, lineWidth: 1))
                        .position(x: x, y: trackHeight / 2)
                        .allowsHitTesting(true)
                        .onTapGesture { onSeek(t) }
                }
            }
            
            ForEach(issueMarkers) { m in
                let x = w * CGFloat(m.timestamp / safeDuration)
                let highlighted = highlightedFeedbackIds.isEmpty || highlightedFeedbackIds.contains(m.id)
                if style == .ticks {
                    Rectangle()
                        .fill(highlighted ? issueMarkerColor : issueMarkerColor.opacity(0.4))
                        .frame(width: 2, height: 10)
                        .position(x: x, y: trackHeight / 2)
                        .allowsHitTesting(true)
                        .onTapGesture { onSeek(m.timestamp) }
                } else {
                    Image(systemName: "triangle.fill")
                        .font(.system(size: 8))
                        .foregroundColor(highlighted ? issueMarkerColor : issueMarkerColor.opacity(0.4))
                        .rotationEffect(.degrees(-180))
                        .position(x: x, y: trackHeight / 2)
                        .allowsHitTesting(true)
                        .onTapGesture { onSeek(m.timestamp) }
                }
            }
        }
    }
    
    private var thumb: some View {
        GeometryReader { geo in
            let w = geo.size.width
            let safeDuration = max(duration, 0.01)
            let x = w * CGFloat(currentTime / safeDuration)
            Circle()
                .fill(thumbColor)
                .frame(width: style == .ticks ? 10 : 14, height: style == .ticks ? 10 : 14)
                .shadow(color: .black.opacity(0.3), radius: 2)
                .overlay(Circle().stroke(thumbStroke, lineWidth: style == .ticks ? 1.2 : 1.5))
                .position(x: x, y: trackHeight / 2)
                .gesture(
                    DragGesture(minimumDistance: 0)
                        .onChanged { value in
                            let newFraction = value.location.x / w
                            let t = TimeInterval(newFraction) * duration
                            onSeek(max(0, min(t, duration)))
                        }
                )
        }
    }
    
    private func timeString(_ t: TimeInterval) -> String {
        let m = Int(t) / 60
        let s = Int(t) % 60
        return String(format: "%d:%02d", m, s)
    }
}

/// Build good moments and issue markers from analysis result.
/// Rep times are converted to video-relative (0-based); feedback timestamps are already relative.
struct TimelineMarkers {
    var goodMoments: [TimeInterval]
    var issueMarkers: [VideoTimelineView.IssueMarker]
    
    static func from(_ result: AnalysisResult?) -> TimelineMarkers {
        guard let result = result else {
            return TimelineMarkers(goodMoments: [], issueMarkers: [])
        }
        var good: [TimeInterval] = []
        if let reps = result.reps, !reps.isEmpty {
            let videoStart = reps.map(\.startTime).min() ?? 0
            for rep in reps where rep.isFullRep && rep.reachedDepth {
                good.append(rep.bottomTime - videoStart)
            }
        }
        let issues = result.feedback
            .filter { $0.severity == .warning || $0.severity == .critical }
            .map { VideoTimelineView.IssueMarker(id: $0.id, timestamp: $0.timestamp, label: $0.message) }
        return TimelineMarkers(goodMoments: good, issueMarkers: issues)
    }
}
