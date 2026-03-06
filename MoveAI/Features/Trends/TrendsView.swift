//
//  TrendsView.swift
//  MoveAI
//
//  Created by Dave Mathew on 10/18/25.
//

import SwiftUI

struct TrendsView: View {
    @EnvironmentObject var sessionManager: SessionManager

    private let selectedMovement: MovementType = .squat
    private let lookback = 5

    private var snapshot: TrendsSnapshot {
        TrendsInsightsEngine.buildSnapshot(
            sessions: sessionManager.sessions,
            movement: selectedMovement,
            lookback: lookback
        )
    }

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 16) {
                    filterBar

                    if let lowDataHint = snapshot.lowDataHint {
                        TrendsCard {
                            HStack(alignment: .top, spacing: 10) {
                                Image(systemName: "info.circle.fill")
                                    .foregroundColor(.orange)
                                Text(lowDataHint)
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                            }
                        }
                    }

                    focusSection
                    progressSection
                    troubleAreaSection
                    recommendationsSection
                    whatImprovedSection
                }
                .padding(16)
                .padding(.bottom, 24)
            }
            .navigationTitle("Trends")
            .navigationBarTitleDisplayMode(.large)
            .accessibilityIdentifier(AccessibilityID.Trends.root)
            .accessibilityElement(children: .contain)
        }
    }

    private var filterBar: some View {
        HStack(spacing: 10) {
            HStack(spacing: 6) {
                Image(systemName: selectedMovement.icon)
                    .font(.caption)
                Text(selectedMovement.displayName)
                    .font(.subheadline.weight(.semibold))
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(Color(red: 0.24, green: 0.86, blue: 1.0).opacity(0.16))
            .clipShape(Capsule())
            .accessibilityIdentifier(AccessibilityID.Trends.filterMovement)

            HStack(spacing: 6) {
                Image(systemName: "clock.arrow.circlepath")
                    .font(.caption)
                Text(snapshot.lookbackLabel)
                    .font(.subheadline.weight(.medium))
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(Color(.systemGray6))
            .clipShape(Capsule())

            Spacer()
        }
    }

    private var focusSection: some View {
        TrendsCard {
            VStack(alignment: .leading, spacing: 10) {
                sectionTitle(icon: "scope", title: "Focus This Week")

                if let focus = snapshot.focus {
                    Text(focus.headline)
                        .font(.headline)

                    Text(focus.evidenceLine)
                        .font(.subheadline)
                        .foregroundColor(.secondary)

                    HStack(spacing: 8) {
                        TrendBadge(
                            title: focus.direction.label,
                            color: directionColor(focus.direction)
                        )

                        TrendBadge(
                            title: focus.confidence.label,
                            color: confidenceColor(focus.confidence)
                        )
                    }
                } else {
                    Text("No recurring issues detected yet.")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
            }
        }
        .accessibilityIdentifier(AccessibilityID.Trends.focusCard)
    }

    private var progressSection: some View {
        TrendsCard {
            VStack(alignment: .leading, spacing: 12) {
                sectionTitle(icon: "chart.line.uptrend.xyaxis", title: "Progress")

                ScoreSparkline(points: snapshot.scoreTrend)
                    .frame(height: 86)

                HStack(spacing: 12) {
                    TrendMetric(
                        label: "Avg score (last 5)",
                        value: formatScore(snapshot.averageScoreLastLookback)
                    )

                    TrendMetric(
                        label: "Change vs previous 5",
                        value: formatChange(snapshot.scoreChangeVsPreviousLookback)
                    )

                    TrendMetric(
                        label: "Warning/Critical burden",
                        value: snapshot.burdenTrend.label
                    )
                }
            }
        }
        .accessibilityIdentifier(AccessibilityID.Trends.progressCard)
    }

    private var troubleAreaSection: some View {
        TrendsCard {
            VStack(alignment: .leading, spacing: 10) {
                sectionTitle(icon: "exclamationmark.triangle.fill", title: "Trouble Areas")

                if snapshot.troubleAreas.isEmpty {
                    Text("No warning or critical issues in recent sessions.")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                } else {
                    ForEach(Array(snapshot.troubleAreas.enumerated()), id: \.element.id) { index, row in
                        VStack(alignment: .leading, spacing: 4) {
                            HStack(spacing: 8) {
                                Text("#\(index + 1)")
                                    .font(.caption.weight(.semibold))
                                    .foregroundColor(.secondary)

                                Text(row.title)
                                    .font(.subheadline.weight(.semibold))

                                Spacer()

                                Image(systemName: directionIcon(row.direction))
                                    .foregroundColor(directionColor(row.direction))
                                    .font(.caption.weight(.semibold))
                            }

                            Text("\(row.frequencyText) • \(row.severityMixText)")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        .padding(.vertical, 2)
                    }
                }
            }
        }
        .accessibilityIdentifier(AccessibilityID.Trends.troubleAreaList)
    }

    private var recommendationsSection: some View {
        TrendsCard {
            VStack(alignment: .leading, spacing: 12) {
                sectionTitle(icon: "bolt.heart.fill", title: "Next Recommendations")

                if snapshot.recommendations.isEmpty {
                    Text("Keep recording sessions. Recommendations unlock as recurring patterns emerge.")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                } else {
                    ForEach(Array(snapshot.recommendations.enumerated()), id: \.element.id) { index, card in
                        VStack(alignment: .leading, spacing: 6) {
                            Text(card.title)
                                .font(.subheadline.weight(.semibold))

                            Text(card.actionProtocol)
                                .font(.subheadline)

                            Text(card.rationale)
                                .font(.caption)
                                .foregroundColor(.secondary)

                            Text(card.expectedOutcome)
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        .padding(10)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color(.systemGray6))
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                        .accessibilityIdentifier("\(AccessibilityID.Trends.recommendationCard).\(index)")
                    }
                }
            }
        }
    }

    private var whatImprovedSection: some View {
        TrendsCard {
            VStack(alignment: .leading, spacing: 10) {
                sectionTitle(icon: "checkmark.seal.fill", title: "What Improved")

                if snapshot.improvements.isEmpty {
                    Text("No clear improvements yet in recent sessions.")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                } else {
                    HStack(spacing: 8) {
                        ForEach(snapshot.improvements, id: \.self) { improvement in
                            Text(improvement)
                                .font(.caption.weight(.medium))
                                .padding(.horizontal, 10)
                                .padding(.vertical, 8)
                                .background(Color.green.opacity(0.15))
                                .clipShape(Capsule())
                        }
                    }
                }
            }
        }
        .accessibilityIdentifier(AccessibilityID.Trends.whatImproved)
    }

    private func sectionTitle(icon: String, title: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .foregroundColor(Color(red: 0.24, green: 0.86, blue: 1.0))
            Text(title)
                .font(.headline)
            Spacer()
        }
    }

    private func directionColor(_ direction: TrendDirection) -> Color {
        switch direction {
        case .improving:
            return .green
        case .stable:
            return .orange
        case .worsening:
            return .red
        }
    }

    private func confidenceColor(_ confidence: InsightConfidence) -> Color {
        switch confidence {
        case .high:
            return .green
        case .medium:
            return .orange
        case .low:
            return .blue
        }
    }

    private func directionIcon(_ direction: TrendDirection) -> String {
        switch direction {
        case .improving:
            return "arrow.down.right"
        case .stable:
            return "arrow.right"
        case .worsening:
            return "arrow.up.right"
        }
    }

    private func formatScore(_ value: Double?) -> String {
        guard let value else { return "N/A" }
        return String(format: "%.1f", value)
    }

    private func formatChange(_ value: Double?) -> String {
        guard let value else { return "N/A" }
        return String(format: "%+.1f", value)
    }
}

private struct TrendsCard<Content: View>: View {
    @ViewBuilder let content: Content

    var body: some View {
        content
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 14)
                    .fill(Color(.secondarySystemBackground))
            )
    }
}

private struct TrendBadge: View {
    let title: String
    let color: Color

    var body: some View {
        Text(title)
            .font(.caption.weight(.semibold))
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(color.opacity(0.15))
            .foregroundColor(color)
            .clipShape(Capsule())
    }
}

private struct TrendMetric: View {
    let label: String
    let value: String

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(value)
                .font(.subheadline.weight(.semibold))
            Text(label)
                .font(.caption2)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private struct ScoreSparkline: View {
    let points: [TrendPoint]

    var body: some View {
        GeometryReader { geometry in
            if points.count < 2 {
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color(.systemGray5))
            } else {
                let values = points.map { $0.score }
                let minValue = values.min() ?? 0
                let maxValue = values.max() ?? 1
                let range = max(maxValue - minValue, 1)

                ZStack {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color(.systemGray6))

                    Path { path in
                        for index in points.indices {
                            let x = (CGFloat(index) / CGFloat(points.count - 1)) * geometry.size.width
                            let yRatio = (points[index].score - minValue) / range
                            let y = geometry.size.height - (CGFloat(yRatio) * geometry.size.height)

                            if index == 0 {
                                path.move(to: CGPoint(x: x, y: y))
                            } else {
                                path.addLine(to: CGPoint(x: x, y: y))
                            }
                        }
                    }
                    .stroke(
                        Color(red: 0.24, green: 0.86, blue: 1.0),
                        style: StrokeStyle(lineWidth: 3, lineCap: .round, lineJoin: .round)
                    )

                    ForEach(points.indices, id: \.self) { index in
                        let x = (CGFloat(index) / CGFloat(points.count - 1)) * geometry.size.width
                        let yRatio = (points[index].score - minValue) / range
                        let y = geometry.size.height - (CGFloat(yRatio) * geometry.size.height)

                        Circle()
                            .fill(Color(.systemBackground))
                            .frame(width: 8, height: 8)
                            .overlay(
                                Circle()
                                    .stroke(Color(red: 0.24, green: 0.86, blue: 1.0), lineWidth: 2)
                            )
                            .position(x: x, y: y)
                    }
                }
            }
        }
    }
}

#Preview {
    TrendsView()
        .environmentObject(SessionManager())
}
