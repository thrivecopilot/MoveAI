//
//  OverviewTabView.swift
//  MoveAI
//
//  Overview tab: score, rep summary, top fixes (technique/safety).
//

import SwiftUI

struct OverviewTabView: View {
    let analysisResult: AnalysisResult
    
    private var repStats: (total: Int, good: Int, warning: Int) {
        guard let reps = analysisResult.reps, !reps.isEmpty else {
            return (0, 0, 0)
        }
        let depthByRep: [Int: [DepthAnalysis]] = Dictionary(
            grouping: (analysisResult.depthMetrics ?? []).compactMap { m in
                m.repNumber.map { (rep: $0, metric: m) }
            },
            by: { $0.rep }
        ).mapValues { $0.map(\.metric) }
        var good = 0, warning = 0
        for rep in reps {
            let reachedDepth: Bool
            if let metrics = depthByRep[rep.repNumber], let deepest = metrics.max(by: { $0.depthPercentage < $1.depthPercentage }) {
                reachedDepth = deepest.isAtDepth
            } else {
                reachedDepth = true
            }
            if rep.isFullRep && reachedDepth { good += 1 }
            else { warning += 1 }
        }
        return (reps.count, good, warning)
    }
    
    var body: some View {
        ScrollView {
            VStack(spacing: 28) {
                scoreAndSummaryRow
                topFixesSection
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 24)
        }
        .accessibilityIdentifier(AccessibilityID.Overview.root)
    }
    
    private var scoreAndSummaryRow: some View {
        let stats = repStats
        return AnyView(
            HStack(alignment: .center, spacing: 16) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Score")
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundColor(.secondary)
                        .accessibilityIdentifier(AccessibilityID.Overview.scoreLabel)
                    Text("\(Int(analysisResult.score))")
                        .font(.system(size: 28, weight: .bold))
                        .foregroundColor(scoreColor(analysisResult.score))
                        .accessibilityIdentifier(AccessibilityID.Overview.scoreValue)
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .background(Color.white.opacity(0.06))
                .overlay(
                    RoundedRectangle(cornerRadius: 14)
                        .stroke(Color.white.opacity(0.08), lineWidth: 1)
                )
                .cornerRadius(14)
                
                if stats.total > 0 {
                    VStack(alignment: .leading, spacing: 6) {
                        sectionLabel("Rep Summary")
                        Text("\(stats.total) total  ·  \(stats.good) good  ·  \(stats.warning) need attention")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .lineLimit(2)
                            .accessibilityIdentifier(AccessibilityID.Overview.repSummary)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                } else {
                    Spacer(minLength: 0)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        )
    }
    
    private var topFixesSection: some View {
        let issues = analysisResult.feedback.filter { $0.severity == .warning || $0.severity == .critical }
        let wins = analysisResult.feedback.filter { $0.severity == .excellent || $0.severity == .good }
        if issues.isEmpty && wins.isEmpty { return AnyView(EmptyView()) }
        return AnyView(
            VStack(alignment: .leading, spacing: 12) {
                sectionLabel("Top Fixes")
                VStack(alignment: .leading, spacing: 0) {
                    ForEach(issues.prefix(2)) { item in
                        row(text: item.message, icon: "exclamationmark.triangle.fill", color: .orange)
                        if item.id != issues.prefix(2).last?.id {
                            Divider().padding(.vertical, 6)
                        }
                    }
                    ForEach(wins.prefix(1)) { item in
                        if !issues.prefix(2).isEmpty { Divider().padding(.vertical, 6) }
                        row(text: item.message, icon: "checkmark.circle.fill", color: .green)
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .accessibilityIdentifier(AccessibilityID.Overview.topFixes)
        )
    }

    private func sectionLabel(_ title: String) -> some View {
        Text(title.uppercased())
            .font(.caption)
            .fontWeight(.medium)
            .foregroundColor(.secondary)
    }
    
    private func row(text: String, icon: String, color: Color) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: icon)
                .font(.caption)
                .foregroundColor(color)
                .frame(width: 20, alignment: .center)
            Text(text)
                .font(.subheadline)
                .foregroundColor(.primary)
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
