//
//  GroupedIssuesTabView.swift
//  MoveAI
//
//  Issues tab: grouped, coach-like feedback cards with timestamp chips.
//

import SwiftUI

struct GroupedIssuesTabView: View {
    let analysisResult: AnalysisResult
    var onSeekToTime: ((TimeInterval) -> Void)?

    private var grouped: [GroupedIssue] {
        GroupedIssue.from(analysisResult.feedback)
    }

    var body: some View {
        ScrollView {
            LazyVStack(spacing: 10) {
                ForEach(grouped) { group in
                    GroupedIssueCard(
                        group: group,
                        onSeekToTime: onSeekToTime
                    )
                    .accessibilityIdentifier("\(AccessibilityID.Issues.issueCard).\(group.id.uuidString)")
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
        }
        .accessibilityIdentifier(AccessibilityID.Issues.root)
        .accessibilityElement(children: .contain)
    }
}

/// One grouped issue (same category + message pattern) with all timestamps.
struct GroupedIssue: Identifiable {
    let id: UUID
    let category: FeedbackCategory
    let title: String
    let isIssue: Bool
    let count: Int
    let worstSeverity: FeedbackSeverity
    let worstTimestamp: TimeInterval
    let worstMetric: String?
    let timestamps: [TimeInterval]
    let feedback: [FormFeedback]

    static func from(_ feedback: [FormFeedback]) -> [GroupedIssue] {
        let byKey = Dictionary(grouping: feedback) { item -> String in
            "\(item.category.rawValue):\(item.message)"
        }
        return byKey.compactMap { _, items -> GroupedIssue? in
            guard let first = items.first else { return nil }
            let isIssue = items.contains { $0.severity == .warning || $0.severity == .critical }
            let worst = items.max { a, b in
                severityOrder(a.severity) < severityOrder(b.severity)
            }
            let worstTimestamp = worst?.timestamp ?? first.timestamp
            let timestamps = items.map(\.timestamp).sorted()
            return GroupedIssue(
                id: first.id,
                category: first.category,
                title: first.message,
                isIssue: isIssue,
                count: items.count,
                worstSeverity: worst?.severity ?? first.severity,
                worstTimestamp: worstTimestamp,
                worstMetric: nil,
                timestamps: timestamps,
                feedback: items
            )
        }
        .sorted { severityOrder($0.worstSeverity) > severityOrder($1.worstSeverity) }
    }
}

private func severityOrder(_ s: FeedbackSeverity) -> Int {
    switch s {
    case .critical: return 4
    case .warning:  return 3
    case .good:     return 2
    case .excellent: return 1
    }
}

struct GroupedIssueCard: View {
    @Environment(\.colorScheme) private var colorScheme

    let group: GroupedIssue
    var onSeekToTime: ((TimeInterval) -> Void)?

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top, spacing: 10) {
                Image(systemName: group.isIssue ? "exclamationmark.triangle.fill" : "checkmark.circle.fill")
                    .font(.caption)
                    .foregroundColor(group.isIssue ? .orange : .green)
                    .frame(width: 20, alignment: .center)
                Text(group.title)
                    .font(.subheadline)
                    .foregroundColor(.primary)
                Spacer(minLength: 0)
            }

            HStack(spacing: 8) {
                CoachChip(
                    title: "\(group.count) moment\(group.count == 1 ? "" : "s")",
                    tint: group.isIssue ? .orange : .green
                )
                if let metric = group.worstMetric {
                    Text(metric)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }

            FlowLayout(spacing: 6) {
                ForEach(Array(group.timestamps.enumerated()), id: \.offset) { _, t in
                    Button {
                        onSeekToTime?(t)
                    } label: {
                        Text(timeString(t))
                            .font(.caption)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(CoachTheme.Palette.secondarySurface(for: colorScheme))
                            .foregroundColor(.primary)
                            .cornerRadius(6)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(CoachTheme.Palette.surfaceFill(for: colorScheme))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(CoachTheme.Palette.stroke(for: colorScheme), lineWidth: 1)
        )
        .contentShape(Rectangle())
        .onTapGesture {
            onSeekToTime?(group.worstTimestamp)
        }
    }

    private func timeString(_ t: TimeInterval) -> String {
        let m = Int(t) / 60
        let s = Int(t) % 60
        return String(format: "%d:%02d", m, s)
    }
}

/// Simple flow layout for timestamp chips.
struct FlowLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let result = arrange(subviews: subviews, in: proposal.width ?? .infinity)
        return result.size
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let result = arrange(subviews: subviews, in: bounds.width)
        for (idx, pos) in result.positions.enumerated() where idx < subviews.count {
            subviews[idx].place(at: CGPoint(x: bounds.minX + pos.x, y: bounds.minY + pos.y), proposal: .unspecified)
        }
    }

    private func arrange(subviews: Subviews, in width: CGFloat) -> (size: CGSize, positions: [CGPoint]) {
        var positions: [CGPoint] = []
        var x: CGFloat = 0
        var y: CGFloat = 0
        var rowHeight: CGFloat = 0
        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x + size.width > width, x > 0 {
                x = 0
                y += rowHeight + spacing
                rowHeight = 0
            }
            positions.append(CGPoint(x: x, y: y))
            rowHeight = max(rowHeight, size.height)
            x += size.width + spacing
        }
        let totalHeight = y + rowHeight
        return (CGSize(width: width, height: totalHeight), positions)
    }
}

#if DEBUG
#Preview("Issues tab") {
    GroupedIssuesTabView(
        analysisResult: PreviewData.analysisResult(),
        onSeekToTime: nil
    )
}
#endif
