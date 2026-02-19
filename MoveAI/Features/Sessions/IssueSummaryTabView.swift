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
