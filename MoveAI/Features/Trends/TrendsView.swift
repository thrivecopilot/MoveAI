import SafariServices
import SwiftUI

struct TrendsView: View {
    @EnvironmentObject var sessionManager: SessionManager

    private let selectedMovement: MovementType = .squat
    private let lookback = 5

    @State private var expandedIssueId: String?
    @State private var selectedExpertIssue: MovementIssueKind?
    @State private var isExpertSheetPresented = false
    @State private var showTrackWorkout = false
    @State private var routineCompletedDrills: Set<String> = []
    @State private var safariRoute: SafariRoute?

    private var snapshot: TrendsSnapshot {
        TrendsInsightsEngine.buildSnapshot(
            sessions: sessionManager.sessions,
            movement: selectedMovement,
            lookback: lookback
        )
    }

    var body: some View {
        NavigationView {
            ZStack {
                LinearGradient(
                    colors: [
                        Color(red: 0.04, green: 0.08, blue: 0.14),
                        Color(red: 0.06, green: 0.10, blue: 0.16),
                        Color(.systemBackground),
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .ignoresSafeArea()

                ScrollViewReader { proxy in
                    ScrollView {
                        VStack(spacing: 18) {
                            filterBar

                            if let lowDataHint = snapshot.lowDataHint {
                                lowDataHintCard(text: lowDataHint)
                            }

                            primaryFixSection(proxy: proxy)
                            todaysCueSection
                            movementQualitySection
                            troubleAreasSection
                            quickRoutineSection
                            expertDiscoverySection
                            progressSection
                            smallWinsSection
                        }
                        .padding(.horizontal, 16)
                        .padding(.top, 8)
                        .padding(.bottom, 28)
                    }
                }
            }
            .navigationTitle("Trends")
            .navigationBarTitleDisplayMode(.large)
            .accessibilityIdentifier(AccessibilityID.Trends.root)
            .accessibilityElement(children: .contain)
        }
        .sheet(isPresented: $isExpertSheetPresented) {
            expertSheet
        }
        .sheet(isPresented: $showTrackWorkout) {
            MovementSelectionView(
                defaultMovement: .squat,
                defaultCaptureMode: .record,
                autoPresentCapture: true
            )
        }
        .sheet(item: $safariRoute) { route in
            SafariSheet(url: route.url)
                .ignoresSafeArea()
        }
    }

    private var accentColor: Color {
        Color(red: 0.24, green: 0.86, blue: 1.0)
    }

    private var accentGradient: LinearGradient {
        LinearGradient(
            colors: [accentColor, accentColor.opacity(0.7)],
            startPoint: .leading,
            endPoint: .trailing
        )
    }

    private var filterBar: some View {
        HStack(spacing: 10) {
            filterChip(
                icon: selectedMovement.icon,
                title: selectedMovement.displayName,
                tint: accentColor,
                isHighlighted: true
            )
            .accessibilityIdentifier(AccessibilityID.Trends.filterMovement)

            filterChip(
                icon: "clock.arrow.circlepath",
                title: snapshot.lookbackLabel,
                tint: .secondary,
                isHighlighted: false
            )

            Spacer()
        }
    }

    private func filterChip(icon: String, title: String, tint: Color, isHighlighted: Bool) -> some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .font(.caption.weight(.semibold))
            Text(title)
                .font(.subheadline.weight(isHighlighted ? .semibold : .medium))
        }
        .foregroundColor(isHighlighted ? tint : .secondary)
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(
            Capsule()
                .fill(isHighlighted ? tint.opacity(0.18) : Color(.secondarySystemBackground).opacity(0.88))
        )
        .overlay(
            Capsule()
                .stroke(isHighlighted ? tint.opacity(0.35) : Color.white.opacity(0.08), lineWidth: 1)
        )
    }

    private func lowDataHintCard(text: String) -> some View {
        TrendsCard {
            HStack(alignment: .top, spacing: 10) {
                Image(systemName: "info.circle.fill")
                    .foregroundColor(.orange)

                Text(text)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
        }
    }

    private func primaryFixSection(proxy: ScrollViewProxy) -> some View {
        TrendsCard(cornerRadius: 20, useGradient: true, contentPadding: 16) {
            VStack(alignment: .leading, spacing: 14) {
                cardEyebrow("Primary Fix This Week")

                if let primaryFix = snapshot.primaryFix {
                    Text(primaryFix.headline)
                        .font(.title3.weight(.bold))

                    Text(primaryFix.evidenceLine)
                        .font(.subheadline)
                        .foregroundColor(.secondary)

                    HStack(spacing: 8) {
                        TrendBadge(
                            title: primaryFix.direction.coachingLabel,
                            color: directionColor(primaryFix.direction)
                        )

                        TrendBadge(
                            title: primaryFix.confidence.label,
                            color: confidenceColor(primaryFix.confidence)
                        )

                        TrendBadge(
                            title: compactSeverityText(primaryFix.severityMixText),
                            color: .orange
                        )
                        .accessibilityLabel(primaryFix.severityMixText)
                    }

                    HStack(alignment: .top, spacing: 8) {
                        Image(systemName: "waveform.path.ecg")
                            .font(.caption.weight(.semibold))
                            .foregroundColor(accentColor)
                            .padding(.top, 2)

                        Text(primaryFix.impactStatement)
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }

                    VStack(spacing: 8) {
                        actionButton(
                            title: "Fix It",
                            systemImage: "wrench.and.screwdriver",
                            identifier: AccessibilityID.Trends.primaryFixActionFixIt,
                            style: .primary
                        ) {
                            expandedIssueId = primaryFix.issueKind.rawValue
                            withAnimation(.spring(response: 0.32, dampingFraction: 0.88)) {
                                proxy.scrollTo(fixCardAnchorID(primaryFix.issueKind.rawValue), anchor: .center)
                            }
                        }

                        HStack(spacing: 8) {
                            actionButton(
                                title: "Watch Examples",
                                systemImage: "play.rectangle",
                                identifier: AccessibilityID.Trends.primaryFixActionWatchExamples,
                                style: .secondary
                            ) {
                                selectedExpertIssue = primaryFix.issueKind
                                isExpertSheetPresented = true
                            }

                            actionButton(
                                title: "Track During Workout",
                                systemImage: "record.circle",
                                identifier: AccessibilityID.Trends.primaryFixActionTrackWorkout,
                                style: .secondary
                            ) {
                                showTrackWorkout = true
                            }
                        }
                    }
                } else {
                    Text("No recurring issues detected yet. Keep recording sessions to unlock coaching guidance.")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
            }
        }
        .accessibilityIdentifier(AccessibilityID.Trends.primaryFixCard)
    }

    private var todaysCueSection: some View {
        TrendsCard {
            VStack(alignment: .leading, spacing: 10) {
                sectionTitle(icon: "bolt.fill", title: "Today’s Cue")

                if let cue = snapshot.todayCue {
                    Text(cue.cue)
                        .font(.subheadline.weight(.semibold))

                    Text(cue.subtitle)
                        .font(.caption)
                        .foregroundColor(.secondary)

                    Button {
                        showTrackWorkout = true
                    } label: {
                        Label("Practice Mode", systemImage: "figure.strengthtraining.traditional")
                            .font(.caption.weight(.semibold))
                            .foregroundColor(accentColor)
                    }
                    .buttonStyle(.plain)
                } else {
                    Text("Record a few sessions to get cue-specific coaching before your workout.")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
            }
        }
        .accessibilityIdentifier(AccessibilityID.Trends.todayCue)
    }

    private var movementQualitySection: some View {
        TrendsCard {
            VStack(alignment: .leading, spacing: 12) {
                sectionTitle(icon: "dial.medium", title: "Movement Quality")

                ForEach(snapshot.qualitySummary) { dimension in
                    VStack(alignment: .leading, spacing: 8) {
                        HStack(spacing: 8) {
                            Text(dimension.dimension.title)
                                .font(.subheadline.weight(.medium))

                            Spacer()

                            TrendDeltaChip(
                                text: dimension.deltaText,
                                direction: dimension.direction
                            )

                            Text("\(dimension.score)")
                                .font(.subheadline.weight(.semibold))
                                .monospacedDigit()
                        }

                        GeometryReader { geometry in
                            ZStack(alignment: .leading) {
                                Capsule()
                                    .fill(Color.white.opacity(0.10))

                                Capsule()
                                    .fill(directionColor(dimension.direction).opacity(0.88))
                                    .frame(width: geometry.size.width * CGFloat(Double(dimension.score) / 100.0))
                            }
                        }
                        .frame(height: 9)
                    }
                    .padding(10)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(
                        RoundedRectangle(cornerRadius: 10)
                            .fill(Color(.systemBackground).opacity(0.25))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 10)
                            .stroke(Color.white.opacity(0.07), lineWidth: 1)
                    )
                    .accessibilityIdentifier("\(AccessibilityID.Trends.qualityDimension).\(dimension.dimension.rawValue)")
                }
            }
        }
        .accessibilityIdentifier(AccessibilityID.Trends.qualitySummary)
    }

    private var troubleAreasSection: some View {
        TrendsCard {
            VStack(alignment: .leading, spacing: 10) {
                sectionTitle(icon: "exclamationmark.triangle.fill", title: "Trouble Areas")

                if snapshot.troubleAreas.isEmpty {
                    Text("No warning or critical issues in recent squat sessions.")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                } else {
                    ForEach(Array(snapshot.troubleAreas.enumerated()), id: \.element.id) { index, issue in
                        troubleFixCard(issue: issue, rank: index + 1)
                            .id(fixCardAnchorID(issue.id))
                            .accessibilityIdentifier("\(AccessibilityID.Trends.fixCard).\(issue.issueKind.rawValue)")
                    }
                }
            }
        }
        .accessibilityIdentifier(AccessibilityID.Trends.troubleAreaList)
    }

    private func troubleFixCard(issue: TroubleFixCardModel, rank: Int) -> some View {
        let isExpanded = expandedIssueId == issue.id

        return VStack(alignment: .leading, spacing: 8) {
            Button {
                withAnimation(.spring(response: 0.30, dampingFraction: 0.88)) {
                    expandedIssueId = isExpanded ? nil : issue.id
                }
            } label: {
                VStack(alignment: .leading, spacing: 8) {
                    HStack(spacing: 8) {
                        Text("#\(rank)")
                            .font(.caption.weight(.semibold))
                            .foregroundColor(.secondary)

                        Text(issue.title)
                            .font(.subheadline.weight(.semibold))
                            .foregroundColor(.primary)

                        Spacer()

                        Image(systemName: issue.direction.sfSymbolName)
                            .foregroundColor(directionColor(issue.direction))
                            .font(.caption.weight(.semibold))

                        Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                            .foregroundColor(.secondary)
                            .font(.caption.weight(.semibold))
                    }

                    HStack(spacing: 6) {
                        TrendBadge(title: issue.frequencyText, color: accentColor)
                        TrendBadge(title: compactSeverityText(issue.severityMixText), color: .orange)
                            .accessibilityLabel(issue.severityMixText)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(12)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color(.systemBackground).opacity(0.25))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color.white.opacity(0.08), lineWidth: 1)
                )
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("\(AccessibilityID.Trends.fixCard).\(issue.issueKind.rawValue)")

            if isExpanded {
                VStack(alignment: .leading, spacing: 10) {
                    Text(issue.likelyCause)
                        .font(.caption)
                        .foregroundColor(.secondary)

                    if !issue.recommendedDrills.isEmpty {
                        Text("Recommended drills")
                            .font(.caption.weight(.semibold))

                        ForEach(issue.recommendedDrills, id: \.self) { drill in
                            HStack(spacing: 6) {
                                Image(systemName: "checkmark.circle")
                                    .font(.caption)
                                    .foregroundColor(accentColor)
                                Text(drill)
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                    }

                    HStack(spacing: 6) {
                        Image(systemName: "clock")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Text("Usually occurs: \(issue.whenItUsuallyOccurs)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }

                    HStack(spacing: 6) {
                        Image(systemName: "target")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Text("Target: \(issue.targetGoal)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }

                    Button("Watch Examples") {
                        selectedExpertIssue = issue.issueKind
                        isExpertSheetPresented = true
                    }
                    .font(.caption.weight(.semibold))
                    .foregroundColor(accentColor)
                    .buttonStyle(.plain)
                }
                .padding(12)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color(.systemBackground).opacity(0.22))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color.white.opacity(0.06), lineWidth: 1)
                )
                .transition(.move(edge: .top).combined(with: .opacity))
            }
        }
    }

    private var quickRoutineSection: some View {
        TrendsCard {
            VStack(alignment: .leading, spacing: 10) {
                sectionTitle(icon: "list.bullet.rectangle", title: "Quick Fix Routine")

                if let routine = snapshot.quickRoutine {
                    HStack(spacing: 8) {
                        Text(routine.title)
                            .font(.subheadline.weight(.semibold))

                        Spacer()

                        Text("\(routineCompletedDrills.count)/\(routine.drills.count) complete")
                            .font(.caption2.weight(.semibold))
                            .foregroundColor(.secondary)

                        Text(routine.durationText)
                            .font(.caption.weight(.semibold))
                            .foregroundColor(.secondary)
                    }

                    ForEach(routine.drills, id: \.self) { drill in
                        Button {
                            toggleRoutineDrill(drill)
                        } label: {
                            HStack(spacing: 8) {
                                Image(systemName: routineCompletedDrills.contains(drill) ? "checkmark.circle.fill" : "circle")
                                    .foregroundColor(routineCompletedDrills.contains(drill) ? .green : .secondary)

                                Text(drill)
                                    .font(.subheadline)
                                    .foregroundColor(.primary)

                                Spacer()
                            }
                            .padding(.vertical, 8)
                            .padding(.horizontal, 10)
                            .background(
                                RoundedRectangle(cornerRadius: 10)
                                    .fill(Color(.systemBackground).opacity(0.20))
                            )
                        }
                        .buttonStyle(.plain)
                    }

                    Text(routine.frequencyRecommendation)
                        .font(.caption)
                        .foregroundColor(.secondary)

                    Button {
                        routineCompletedDrills = Set(routine.drills)
                    } label: {
                        Label("Start Routine", systemImage: "play.fill")
                            .font(.caption.weight(.semibold))
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .background(accentGradient.opacity(0.24))
                            .foregroundColor(accentColor)
                            .clipShape(Capsule())
                    }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier(AccessibilityID.Trends.quickRoutineStart)
                } else {
                    Text("Recommendations unlock as recurring patterns emerge across sessions.")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
            }
        }
        .accessibilityIdentifier(AccessibilityID.Trends.quickRoutine)
    }

    private var expertDiscoverySection: some View {
        TrendsCard {
            VStack(alignment: .leading, spacing: 10) {
                sectionTitle(icon: "play.rectangle.on.rectangle", title: "Learn From Experts")

                if snapshot.expertDiscovery.isEmpty {
                    Text("Expert recommendations will appear once recurring issues are detected.")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                } else {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 12) {
                            ForEach(Array(snapshot.expertDiscovery.enumerated()), id: \.element.id) { index, card in
                                Button {
                                    safariRoute = SafariRoute(url: card.url)
                                } label: {
                                    VStack(alignment: .leading, spacing: 8) {
                                        RoundedRectangle(cornerRadius: 10)
                                            .fill(
                                                LinearGradient(
                                                    colors: [accentColor.opacity(0.26), accentColor.opacity(0.08)],
                                                    startPoint: .topLeading,
                                                    endPoint: .bottomTrailing
                                                )
                                            )
                                            .frame(height: 72)
                                            .overlay(
                                                HStack {
                                                    Image(systemName: card.thumbnailToken)
                                                        .font(.title3)
                                                        .foregroundColor(accentColor)
                                                    Spacer()
                                                    Image(systemName: "arrow.up.right.square")
                                                        .font(.caption.weight(.semibold))
                                                        .foregroundColor(.secondary)
                                                }
                                                .padding(.horizontal, 10)
                                            )

                                        Text(card.creator)
                                            .font(.caption.weight(.semibold))
                                            .foregroundColor(.secondary)

                                        Text(card.title)
                                            .font(.subheadline.weight(.semibold))
                                            .foregroundColor(.primary)
                                            .multilineTextAlignment(.leading)
                                            .lineLimit(2)

                                        Text(card.issueAssociation)
                                            .font(.caption2)
                                            .foregroundColor(.secondary)
                                    }
                                    .padding(12)
                                    .frame(width: 224, alignment: .leading)
                                    .background(
                                        RoundedRectangle(cornerRadius: 14)
                                            .fill(Color(.systemBackground).opacity(0.24))
                                    )
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 14)
                                            .stroke(Color.white.opacity(0.08), lineWidth: 1)
                                    )
                                }
                                .buttonStyle(.plain)
                                .accessibilityIdentifier("\(AccessibilityID.Trends.expertCard).\(index)")
                            }
                        }
                    }
                }
            }
        }
        .accessibilityIdentifier(AccessibilityID.Trends.expertSection)
    }

    private var progressSection: some View {
        TrendsCard {
            VStack(alignment: .leading, spacing: 12) {
                sectionTitle(icon: "chart.line.uptrend.xyaxis", title: "Progress Trend")

                ScoreSparkline(points: snapshot.scoreTrend)
                    .frame(height: 96)

                HStack(spacing: 12) {
                    TrendMetric(
                        label: "Avg score (last 5)",
                        value: formatScore(snapshot.averageScoreLastLookback)
                    )

                    TrendMetric(
                        label: "Change vs previous 5",
                        value: snapshot.progressNarrative.scoreChangeText
                    )

                    TrendMetric(
                        label: "Warning/Critical burden",
                        value: snapshot.progressNarrative.burdenLabel
                    )
                }

                if !snapshot.progressNarrative.contributors.isEmpty {
                    HStack(spacing: 6) {
                        ForEach(snapshot.progressNarrative.contributors, id: \.self) { contributor in
                            Text(contributor)
                                .font(.caption.weight(.medium))
                                .padding(.horizontal, 8)
                                .padding(.vertical, 6)
                                .background(Color.orange.opacity(0.15))
                                .clipShape(Capsule())
                        }
                    }
                }

                Text(snapshot.progressNarrative.summary)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .accessibilityIdentifier(AccessibilityID.Trends.progressNarrative)
    }

    private var smallWinsSection: some View {
        TrendsCard {
            VStack(alignment: .leading, spacing: 10) {
                sectionTitle(icon: "checkmark.seal.fill", title: "Small Wins")

                if snapshot.smallWins.isEmpty {
                    Text("Consistency is improving. Keep collecting sessions for clearer trend signals.")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                } else {
                    VStack(alignment: .leading, spacing: 8) {
                        ForEach(snapshot.smallWins) { win in
                            HStack(spacing: 8) {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundColor(.green)
                                    .font(.caption)

                                Text(win.text)
                                    .font(.caption.weight(.medium))
                                    .foregroundColor(.primary)
                            }
                            .padding(.horizontal, 10)
                            .padding(.vertical, 8)
                            .background(Color.green.opacity(0.12))
                            .clipShape(RoundedRectangle(cornerRadius: 10))
                        }
                    }
                }
            }
        }
        .accessibilityIdentifier(AccessibilityID.Trends.smallWins)
    }

    private var expertSheet: some View {
        NavigationView {
            List(activeExpertResources) { resource in
                Button {
                    safariRoute = SafariRoute(url: resource.url)
                } label: {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(resource.creator)
                            .font(.caption.weight(.semibold))
                            .foregroundColor(.secondary)
                        Text(resource.title)
                            .font(.subheadline.weight(.semibold))
                            .foregroundColor(.primary)
                        Text(resource.issueAssociation)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .padding(.vertical, 4)
                }
            }
            .navigationTitle("Watch Examples")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") {
                        isExpertSheetPresented = false
                    }
                }
            }
        }
    }

    private var activeExpertResources: [ExpertResourceCardModel] {
        let issues = snapshot.troubleAreas.map(\.issueKind)
        return TrendsExpertCatalog
            .filtered(for: selectedExpertIssue ?? snapshot.primaryFix?.issueKind, fallbackIssues: issues)
            .prefix(8)
            .map {
                ExpertResourceCardModel(
                    id: $0.id,
                    creator: $0.creator,
                    title: $0.title,
                    issueAssociation: $0.issueAssociation,
                    url: $0.url,
                    thumbnailToken: $0.thumbnailToken
                )
            }
    }

    private func compactSeverityText(_ text: String) -> String {
        text
            .replacingOccurrences(of: " critical", with: "C")
            .replacingOccurrences(of: " warning events", with: "W")
            .replacingOccurrences(of: " warning event", with: "W")
            .replacingOccurrences(of: ", ", with: " • ")
    }

    private func cardEyebrow(_ title: String) -> some View {
        Text(title.uppercased())
            .font(.caption2.weight(.bold))
            .kerning(0.6)
            .foregroundColor(accentColor.opacity(0.95))
    }

    private func sectionTitle(icon: String, title: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .font(.subheadline.weight(.semibold))
                .foregroundColor(accentColor)
            Text(title)
                .font(.headline.weight(.semibold))
            Spacer()
        }
    }

    private enum ActionButtonStyle {
        case primary
        case secondary
    }

    private func actionButton(
        title: String,
        systemImage: String,
        identifier: String,
        style: ActionButtonStyle,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Label {
                Text(title)
                    .font(.caption.weight(.semibold))
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
                    .minimumScaleFactor(0.8)
            } icon: {
                Image(systemName: systemImage)
                    .font(.caption.weight(.semibold))
            }
            .frame(maxWidth: .infinity)
            .padding(.horizontal, 8)
            .padding(.vertical, 9)
            .background(buttonBackground(style: style))
            .foregroundColor(buttonForeground(style: style))
            .clipShape(RoundedRectangle(cornerRadius: 10))
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(buttonBorder(style: style), lineWidth: 1)
            )
        }
        .accessibilityIdentifier(identifier)
        .buttonStyle(.plain)
    }

    private func buttonBackground(style: ActionButtonStyle) -> some ShapeStyle {
        switch style {
        case .primary:
            return AnyShapeStyle(accentColor.opacity(0.22))
        case .secondary:
            return AnyShapeStyle(Color(.systemBackground).opacity(0.24))
        }
    }

    private func buttonForeground(style: ActionButtonStyle) -> Color {
        switch style {
        case .primary:
            return accentColor
        case .secondary:
            return .primary
        }
    }

    private func buttonBorder(style: ActionButtonStyle) -> Color {
        switch style {
        case .primary:
            return accentColor.opacity(0.35)
        case .secondary:
            return Color.white.opacity(0.08)
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

    private func formatScore(_ value: Double?) -> String {
        guard let value else { return "N/A" }
        return String(format: "%.1f", value)
    }

    private func toggleRoutineDrill(_ drill: String) {
        if routineCompletedDrills.contains(drill) {
            routineCompletedDrills.remove(drill)
        } else {
            routineCompletedDrills.insert(drill)
        }
    }

    private func fixCardAnchorID(_ issueID: String) -> String {
        "trends.fix.\(issueID)"
    }
}

private struct TrendsCard<Content: View>: View {
    var cornerRadius: CGFloat = 16
    var useGradient: Bool = false
    var contentPadding: CGFloat = 14
    @ViewBuilder let content: Content

    var body: some View {
        content
            .padding(contentPadding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: cornerRadius)
                    .fill(backgroundFill)
            )
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius)
                    .stroke(Color.white.opacity(useGradient ? 0.16 : 0.08), lineWidth: 1)
            )
            .shadow(color: Color.black.opacity(useGradient ? 0.22 : 0.12), radius: 12, x: 0, y: 8)
    }

    private var backgroundFill: LinearGradient {
        if useGradient {
            return LinearGradient(
                colors: [
                    Color(red: 0.10, green: 0.17, blue: 0.25),
                    Color(red: 0.07, green: 0.12, blue: 0.19),
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        }

        return LinearGradient(
            colors: [
                Color(.secondarySystemBackground).opacity(0.95),
                Color(.tertiarySystemBackground).opacity(0.94),
            ],
            startPoint: .top,
            endPoint: .bottom
        )
    }
}

private struct TrendBadge: View {
    let title: String
    let color: Color

    var body: some View {
        Text(title)
            .font(.caption.weight(.semibold))
            .lineLimit(1)
            .minimumScaleFactor(0.82)
            .allowsTightening(true)
            .padding(.horizontal, 10)
            .frame(height: 28)
            .background(color.opacity(0.15))
            .foregroundColor(color)
            .clipShape(Capsule())
    }
}

private struct TrendDeltaChip: View {
    let text: String
    let direction: TrendDirection

    var body: some View {
        Text(text)
            .font(.caption2.weight(.semibold))
            .padding(.horizontal, 6)
            .padding(.vertical, 4)
            .background(chipColor.opacity(0.2))
            .foregroundColor(chipColor)
            .clipShape(Capsule())
    }

    private var chipColor: Color {
        switch direction {
        case .improving:
            return .green
        case .stable:
            return .orange
        case .worsening:
            return .red
        }
    }
}

private struct TrendMetric: View {
    let label: String
    let value: String

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(value)
                .font(.subheadline.weight(.semibold))
                .lineLimit(1)
                .minimumScaleFactor(0.8)
            Text(label)
                .font(.caption2)
                .foregroundColor(.secondary)
                .lineLimit(2)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private struct ScoreSparkline: View {
    let points: [TrendPoint]

    var body: some View {
        GeometryReader { geometry in
            if points.count < 2 {
                RoundedRectangle(cornerRadius: 10)
                    .fill(Color.white.opacity(0.08))
            } else {
                let values = points.map { $0.score }
                let minValue = values.min() ?? 0
                let maxValue = values.max() ?? 1
                let range = max(maxValue - minValue, 1)

                let chartPoints: [CGPoint] = points.indices.map { index in
                    let x = (CGFloat(index) / CGFloat(points.count - 1)) * geometry.size.width
                    let yRatio = (points[index].score - minValue) / range
                    let y = geometry.size.height - (CGFloat(yRatio) * geometry.size.height)
                    return CGPoint(x: x, y: y)
                }

                ZStack {
                    RoundedRectangle(cornerRadius: 10)
                        .fill(Color(.systemBackground).opacity(0.22))

                    VStack(spacing: 0) {
                        ForEach(0..<3, id: \.self) { _ in
                            Rectangle()
                                .fill(Color.white.opacity(0.05))
                                .frame(height: 1)
                            Spacer()
                        }
                    }
                    .padding(.vertical, 10)

                    Path { path in
                        guard let first = chartPoints.first, let last = chartPoints.last else { return }
                        path.move(to: CGPoint(x: first.x, y: geometry.size.height))
                        path.addLine(to: first)
                        for point in chartPoints.dropFirst() {
                            path.addLine(to: point)
                        }
                        path.addLine(to: CGPoint(x: last.x, y: geometry.size.height))
                        path.closeSubpath()
                    }
                    .fill(
                        LinearGradient(
                            colors: [
                                Color(red: 0.24, green: 0.86, blue: 1.0).opacity(0.24),
                                Color(red: 0.24, green: 0.86, blue: 1.0).opacity(0.02),
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )

                    Path { path in
                        for (index, point) in chartPoints.enumerated() {
                            if index == 0 {
                                path.move(to: point)
                            } else {
                                path.addLine(to: point)
                            }
                        }
                    }
                    .stroke(
                        Color(red: 0.24, green: 0.86, blue: 1.0),
                        style: StrokeStyle(lineWidth: 3, lineCap: .round, lineJoin: .round)
                    )

                    ForEach(chartPoints.indices, id: \.self) { index in
                        Circle()
                            .fill(Color(.systemBackground))
                            .frame(width: 8, height: 8)
                            .overlay(
                                Circle()
                                    .stroke(Color(red: 0.24, green: 0.86, blue: 1.0), lineWidth: 2)
                            )
                            .position(chartPoints[index])
                    }
                }
            }
        }
    }
}

private struct SafariRoute: Identifiable {
    let id = UUID()
    let url: URL
}

private struct SafariSheet: UIViewControllerRepresentable {
    let url: URL

    func makeUIViewController(context: Context) -> SFSafariViewController {
        SFSafariViewController(url: url)
    }

    func updateUIViewController(_ uiViewController: SFSafariViewController, context: Context) {}
}

#Preview {
    TrendsView()
        .environmentObject(SessionManager())
}
