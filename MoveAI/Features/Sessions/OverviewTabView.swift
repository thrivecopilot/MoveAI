//
//  OverviewTabView.swift
//  MoveAI
//
//  Overview tab: score, rep summary, top fixes (technique/safety).
//

import SwiftUI

struct OverviewTabView: View {
    @Environment(\.colorScheme) private var colorScheme

    let analysisResult: AnalysisResult
    var isCompact: Bool = false

    private static let nonActionableMuayThaiIssueKinds: Set<MovementIssueKind> = [
        .muayThaiCaptureQualityLimited,
        .muayThaiAnalysisCoverageLimited,
    ]

    private struct DetectionStatusInfo {
        let label: String
        let color: Color
        let note: String
    }

    private var summary: AnalysisSummary? {
        guard let summary = AnalysisSummaryBuilder.buildLegacy(from: analysisResult) else {
            return nil
        }

        if summary.totalUnits <= 0 && summary.warningEvents <= 0 {
            return nil
        }

        return summary
    }

    private func summaryValueText(_ summary: AnalysisSummary) -> String {
        var text = "\(summary.totalUnits) total  ·  \(summary.goodUnits) good  ·  \(summary.unitsNeedingAttention) need attention"

        if summary.warningEvents > 0 {
            let label = summary.warningEvents == 1 ? "warning" : "warnings"
            text += "  ·  \(summary.warningEvents) \(label)"
        }

        return text
    }

    private var detectionStatus: DetectionStatusInfo? {
        guard summary?.unitKind == .strike else { return nil }

        let qualityItems = analysisResult.feedback.filter {
            guard let kind = $0.issueKind else { return false }
            return Self.nonActionableMuayThaiIssueKinds.contains(kind)
        }

        if let quality = qualityItems.first(where: { $0.issueKind == .muayThaiCaptureQualityLimited }) {
            if quality.severity == .critical {
                return DetectionStatusInfo(label: "Failed", color: .red, note: quality.message)
            }
            return DetectionStatusInfo(label: "Limited", color: .orange, note: quality.message)
        }

        if let coverage = qualityItems.first(where: { $0.issueKind == .muayThaiAnalysisCoverageLimited }) {
            return DetectionStatusInfo(label: "Limited", color: .orange, note: coverage.message)
        }

        return DetectionStatusInfo(
            label: "Ready",
            color: .green,
            note: "Core Muay Thai checks ran with sufficient capture quality."
        )
    }

    var body: some View {
        Group {
            if isCompact {
                compactBody
            } else {
                fullBody
            }
        }
        .accessibilityIdentifier("WorkoutSummaryScreen")
        .accessibilityElement(children: .contain)
    }

    private var fullBody: some View {
        ScrollView {
            VStack(spacing: 20) {
                scoreAndSummaryRow
                detectionStatusSection
                topFixesSection
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 16)
        }
    }

    private var compactBody: some View {
        VStack(spacing: 0) {
            scoreAndSummaryRow
        }
        .frame(maxWidth: .infinity, alignment: .topLeading)
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
    }

    private var scoreAndSummaryRow: some View {
        let overviewSummary = summary
        return AnyView(
            HStack(alignment: .center, spacing: 14) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Score")
                        .font(.caption.weight(.semibold))
                        .foregroundColor(.secondary)
                        .accessibilityIdentifier("WorkoutSummary.ScoreTitle")
                    Text("\(Int(analysisResult.score))")
                        .font(.system(size: 28, weight: .bold))
                        .foregroundColor(scoreColor(analysisResult.score))
                        .accessibilityIdentifier("WorkoutSummary.ScoreValue")
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .background(CoachTheme.Palette.secondarySurface(for: colorScheme))
                .overlay(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .stroke(CoachTheme.Palette.stroke(for: colorScheme), lineWidth: 1)
                )
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))

                if let overviewSummary {
                    VStack(alignment: .leading, spacing: 6) {
                        sectionLabel(overviewSummary.unitKind.summaryTitle)
                            .accessibilityIdentifier("WorkoutSummary.RepSummaryTitle")
                        Text(summaryValueText(overviewSummary))
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .lineLimit(isCompact ? 2 : 3)
                            .accessibilityIdentifier("WorkoutSummary.RepSummaryValue")
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                } else {
                    Spacer(minLength: 0)
                }
            }
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(CoachTheme.Palette.surfaceFill(for: colorScheme))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(CoachTheme.Palette.stroke(for: colorScheme), lineWidth: 1)
            )
        )
    }

    private var detectionStatusSection: some View {
        guard let status = detectionStatus else {
            return AnyView(EmptyView())
        }

        return AnyView(
            VStack(alignment: .leading, spacing: 10) {
                sectionLabel("Detection Status")
                HStack(alignment: .center, spacing: 8) {
                    Circle()
                        .fill(status.color)
                        .frame(width: 8, height: 8)
                    Text(status.label)
                        .font(.subheadline.weight(.semibold))
                        .foregroundColor(status.color)
                    Spacer(minLength: 0)
                }
                Text(status.note)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(CoachTheme.Palette.surfaceFill(for: colorScheme))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(CoachTheme.Palette.stroke(for: colorScheme), lineWidth: 1)
            )
            .accessibilityIdentifier("WorkoutSummary.DetectionStatusSection")
        )
    }

    private var topFixesSection: some View {
        let issues = analysisResult.feedback.filter {
            guard ($0.severity == .warning || $0.severity == .critical) else { return false }
            guard let kind = $0.issueKind else { return true }
            return !Self.nonActionableMuayThaiIssueKinds.contains(kind)
        }
        let wins = analysisResult.feedback.filter { $0.severity == .excellent || $0.severity == .good }
        if issues.isEmpty && wins.isEmpty {
            return AnyView(EmptyView())
        }

        return AnyView(
            VStack(alignment: .leading, spacing: 12) {
                sectionLabel("Top Fixes")
                    .accessibilityIdentifier("WorkoutSummary.TopFixesTitle")
                VStack(alignment: .leading, spacing: 0) {
                    ForEach(Array(issues.prefix(2).enumerated()), id: \.offset) { index, item in
                        row(
                            text: item.message,
                            icon: "exclamationmark.triangle.fill",
                            color: .orange,
                            identifier: "WorkoutSummary.IssueRow.\(index)"
                        )
                        if item.id != issues.prefix(2).last?.id {
                            Divider().padding(.vertical, 6)
                        }
                    }
                    ForEach(Array(wins.prefix(1).enumerated()), id: \.offset) { index, item in
                        if !issues.prefix(2).isEmpty {
                            Divider().padding(.vertical, 6)
                        }
                        row(
                            text: item.message,
                            icon: "checkmark.circle.fill",
                            color: .green,
                            identifier: "WorkoutSummary.WinRow.\(index)"
                        )
                    }
                }
            }
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(CoachTheme.Palette.surfaceFill(for: colorScheme))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(CoachTheme.Palette.stroke(for: colorScheme), lineWidth: 1)
            )
            .accessibilityIdentifier("WorkoutSummary.TopFixesSection")
        )
    }

    private func sectionLabel(_ title: String) -> some View {
        Text(title.uppercased())
            .font(.caption)
            .fontWeight(.medium)
            .foregroundColor(.secondary)
    }

    private func row(text: String, icon: String, color: Color, identifier: String) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: icon)
                .font(.caption)
                .foregroundColor(color)
                .frame(width: 20, alignment: .center)
            Text(text)
                .font(.subheadline)
                .foregroundColor(.primary)
                .accessibilityIdentifier(identifier)
            Spacer(minLength: 0)
        }
    }

    private func scoreColor(_ score: Double) -> Color {
        if score >= 80 { return .green }
        if score >= 60 { return .orange }
        return .red
    }
}

#if DEBUG
#Preview("Overview tab") {
    OverviewTabView(analysisResult: PreviewData.analysisResult())
}
#endif
