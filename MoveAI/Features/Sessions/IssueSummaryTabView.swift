import Foundation
import SwiftUI

struct IssueSummaryTabView: View {
    let issues: [IssueSummary]
    let selectedIssueId: UUID?
    let onSelectIssue: (IssueSummary) -> Void
    let onSelectOccurrence: (IssueSummary, IssueOccurrence) -> Void
    
    var body: some View {
        ScrollView {
            if issues.isEmpty {
                Text("No issues yet")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .padding(.top, 40)
                    .accessibilityIdentifier(AccessibilityID.Issues.emptyText)
            } else {
                LazyVStack(spacing: 12) {
                    ForEach(issues) { issue in
                        IssueSummaryCard(
                            issue: issue,
                            isSelected: issue.id == selectedIssueId,
                            onSelectIssue: onSelectIssue,
                            onSelectOccurrence: onSelectOccurrence
                        )
                    }
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 16)
            }
        }
        .accessibilityIdentifier(AccessibilityID.Issues.root)
        .accessibilityElement(children: .contain)
    }
}

private struct IssueSummaryCard: View {
    let issue: IssueSummary
    let isSelected: Bool
    let onSelectIssue: (IssueSummary) -> Void
    let onSelectOccurrence: (IssueSummary, IssueOccurrence) -> Void
    
    private let cardBackground = Color(red: 0.08, green: 0.10, blue: 0.14)
    private let strokeColor = Color.white.opacity(0.08)
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top, spacing: 10) {
                VStack(alignment: .leading, spacing: 6) {
                    Text(issue.title)
                        .font(.subheadline)
                        .foregroundColor(.primary)
                        .lineLimit(2)
                    
                    Text(issue.category.displayName.uppercased())
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
                
                Spacer(minLength: 0)

                severityPill(issue.severity)
            }

            if let quickFix = issue.cues.first?.shortText, !quickFix.isEmpty {
                Text(quickFix)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(2)
            }

            if let metric = primaryMetric(from: issue.worstOccurrence.metrics) {
                metricMiniCard(metric)
            }

            HStack(spacing: 8) {
                Text("\(issue.momentsCount) moment\(issue.momentsCount == 1 ? "" : "s")")
                    .font(.caption)
                    .foregroundColor(.secondary)
                if let worstValue = issue.worstValue {
                    Text("·")
                        .foregroundColor(.secondary)
                    Text("Worst \(worstValue)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            timestampChips
        }
        .padding(.vertical, 14)
        .padding(.horizontal, 14)
        .background(cardBackground)
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(isSelected ? Color.white.opacity(0.2) : strokeColor, lineWidth: 1)
        )
        .cornerRadius(14)
        .contentShape(Rectangle())
        .onTapGesture {
            onSelectIssue(issue)
        }
        .accessibilityIdentifier("\(AccessibilityID.Issues.issueCard).\(issue.id.uuidString)")
    }

    private func primaryMetric(from metrics: [FeedbackMetric]) -> FeedbackMetric? {
        let priority: [FeedbackMetricKind] = [
            .squatTorsoInstabilityDegrees,
            .squatTorsoBiasDegrees,
            .squatBalanceDriftShinLengths
        ]
        for kind in priority {
            if let metric = metrics.first(where: { $0.kind == kind }) {
                return metric
            }
        }
        return metrics.first
    }

    
    private func metricMiniCard(_ metric: FeedbackMetric) -> some View {
        let title = metricTitle(metric)
        let value = metricValue(metric)

        return VStack(alignment: .leading, spacing: 4) {
            Text(title.uppercased())
                .font(.caption2)
                .foregroundColor(.secondary)
            Text(value)
                .font(.subheadline)
                .fontWeight(.semibold)
                .foregroundColor(.primary)
                .lineLimit(1)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.white.opacity(0.06))
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(Color.white.opacity(0.08), lineWidth: 1)
        )
        .cornerRadius(10)
        .accessibilityIdentifier("IssueMetricCard")
    }

    private func metricTitle(_ metric: FeedbackMetric) -> String {
        let base: String
        switch metric.kind {
        case .squatTorsoBiasDegrees:
            base = "Torso bias"
        case .squatTorsoInstabilityDegrees:
            base = "Torso instability"
        case .squatBalanceDriftShinLengths:
            base = "Balance drift"
        default:
            base = metric.kind.rawValue
        }
        if let phase = metric.phase {
            return "\(base) (\(phaseLabel(phase)))"
        }
        return base
    }

    private func metricValue(_ metric: FeedbackMetric) -> String {
        switch metric.unit {
        case .degrees:
            return String(format: "%+.1f°", metric.value)
        case .shinLengths:
            return String(format: "%.2f shin lengths", metric.value)
        case .percent:
            return String(format: "%.0f%%", metric.value)
        case .ratio:
            return String(format: "%.2f", metric.value)
        case .count:
            return String(format: "%.0f", metric.value)
        case .unknown:
            return String(format: "%.2f", metric.value)
        }
    }

    private func phaseLabel(_ phase: SquatPhaseType) -> String {
        switch phase {
        case .setup: return "setup"
        case .descent: return "descent"
        case .bottom: return "bottom"
        case .ascent: return "ascent"
        }
    }

    private var timestampChips: some View {
        let displayed = Array(issue.occurrences.prefix(4))
        let remaining = max(0, issue.occurrences.count - displayed.count)
        
        return FlowLayout(spacing: 6) {
            ForEach(displayed) { occ in
                Button {
                    onSelectOccurrence(issue, occ)
                } label: {
                    Text(timeString(occ.time))
                        .font(.caption2)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.white.opacity(0.08))
                        .foregroundColor(.primary)
                        .cornerRadius(6)
                }
                .buttonStyle(.plain)
            }
            
            if remaining > 0 {
                Text("+\(remaining)")
                    .font(.caption2)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.white.opacity(0.05))
                    .foregroundColor(.secondary)
                    .cornerRadius(6)
            }
        }
    }
    
    private func severityPill(_ severity: FeedbackSeverity) -> some View {
        Text(severity.displayName.uppercased())
            .font(.caption2)
            .fontWeight(.semibold)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(severityColor(severity).opacity(0.2))
            .foregroundColor(severityColor(severity))
            .cornerRadius(8)
    }
    
    private func severityColor(_ severity: FeedbackSeverity) -> Color {
        switch severity {
        case .critical: return Color(red: 1.0, green: 0.42, blue: 0.42)
        case .warning: return Color(red: 1.0, green: 0.68, blue: 0.3)
        case .good: return Color(red: 0.16, green: 0.97, blue: 0.65)
        case .excellent: return Color(red: 0.24, green: 0.86, blue: 1.0)
        }
    }
    
    private func timeString(_ t: TimeInterval) -> String {
        let m = Int(t) / 60
        let s = Int(t) % 60
        return String(format: "%d:%02d", m, s)
    }
}

#if DEBUG
#Preview("Issues Summary Tab") {
    IssueSummaryTabView(
        issues: IssueSummaryBuilder.from(PreviewData.analysisResult().feedback),
        selectedIssueId: nil,
        onSelectIssue: { _ in },
        onSelectOccurrence: { _, _ in }
    )
}
#endif
