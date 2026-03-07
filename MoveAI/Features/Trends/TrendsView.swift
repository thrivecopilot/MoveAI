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
            ScrollViewReader { proxy in
                ScrollView {
                    VStack(spacing: 16) {
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
                    .padding(16)
                    .padding(.bottom, 24)
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
            .background(accentColor.opacity(0.16))
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
        TrendsCard(cornerRadius: 18, useGradient: true) {
            VStack(alignment: .leading, spacing: 12) {
                sectionTitle(icon: "target", title: "Primary Fix This Week")

                if let primaryFix = snapshot.primaryFix {
                    Text(primaryFix.headline)
                        .font(.headline)

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
                            title: primaryFix.severityMixText,
                            color: .orange
                        )
                    }

                    Text(primaryFix.impactStatement)
                        .font(.subheadline)
                        .foregroundColor(.secondary)

                    HStack(spacing: 8) {
                        actionButton(
                            title: "Fix It",
                            identifier: AccessibilityID.Trends.primaryFixActionFixIt,
                            filled: true
                        ) {
                            expandedIssueId = primaryFix.issueKind.rawValue
                            withAnimation(.easeInOut(duration: 0.25)) {
                                proxy.scrollTo(fixCardAnchorID(primaryFix.issueKind.rawValue), anchor: .center)
                            }
                        }

                        actionButton(
                            title: "Watch Examples",
                            identifier: AccessibilityID.Trends.primaryFixActionWatchExamples,
                            filled: false
                        ) {
                            selectedExpertIssue = primaryFix.issueKind
                            isExpertSheetPresented = true
                        }

                        actionButton(
                            title: "Track During Workout",
                            identifier: AccessibilityID.Trends.primaryFixActionTrackWorkout,
                            filled: false
                        ) {
                            showTrackWorkout = true
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
            VStack(alignment: .leading, spacing: 8) {
                sectionTitle(icon: "bolt.fill", title: "Today’s Cue")

                if let cue = snapshot.todayCue {
                    Text(cue.cue)
                        .font(.subheadline.weight(.semibold))

                    Text(cue.subtitle)
                        .font(.caption)
                        .foregroundColor(.secondary)

                    Button("Practice Mode") {
                        showTrackWorkout = true
                    }
                    .font(.caption.weight(.semibold))
                    .foregroundColor(accentColor)
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
            VStack(alignment: .leading, spacing: 10) {
                sectionTitle(icon: "dial.medium", title: "Movement Quality")

                ForEach(snapshot.qualitySummary) { dimension in
                    VStack(alignment: .leading, spacing: 6) {
                        HStack {
                            Text(dimension.dimension.title)
                                .font(.subheadline.weight(.medium))

                            Spacer()

                            Text("\(dimension.score)")
                                .font(.subheadline.weight(.semibold))

                            TrendDeltaChip(
                                text: dimension.deltaText,
                                direction: dimension.direction
                            )
                        }

                        GeometryReader { geometry in
                            ZStack(alignment: .leading) {
                                Capsule()
                                    .fill(Color(.systemGray5))

                                Capsule()
                                    .fill(directionColor(dimension.direction).opacity(0.8))
                                    .frame(width: geometry.size.width * CGFloat(Double(dimension.score) / 100.0))
                            }
                        }
                        .frame(height: 8)
                    }
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
                withAnimation(.easeInOut(duration: 0.2)) {
                    expandedIssueId = isExpanded ? nil : issue.id
                }
            } label: {
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
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("\(AccessibilityID.Trends.fixCard).\(issue.issueKind.rawValue)")

            Text("\(issue.frequencyText) • \(issue.severityMixText)")
                .font(.caption)
                .foregroundColor(.secondary)

            if isExpanded {
                VStack(alignment: .leading, spacing: 8) {
                    Text(issue.likelyCause)
                        .font(.caption)
                        .foregroundColor(.secondary)

                    if !issue.recommendedDrills.isEmpty {
                        Text("Recommended drills")
                            .font(.caption.weight(.semibold))

                        ForEach(issue.recommendedDrills, id: \.self) { drill in
                            Text("• \(drill)")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }

                    Text("Usually occurs: \(issue.whenItUsuallyOccurs)")
                        .font(.caption)
                        .foregroundColor(.secondary)

                    Text("Target: \(issue.targetGoal)")
                        .font(.caption)
                        .foregroundColor(.secondary)

                    Button("Watch Examples") {
                        selectedExpertIssue = issue.issueKind
                        isExpertSheetPresented = true
                    }
                    .font(.caption.weight(.semibold))
                    .foregroundColor(accentColor)
                }
                .padding(10)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color(.systemGray6))
                .clipShape(RoundedRectangle(cornerRadius: 10))
            }
        }
        .padding(.vertical, 2)
    }

    private var quickRoutineSection: some View {
        TrendsCard {
            VStack(alignment: .leading, spacing: 10) {
                sectionTitle(icon: "list.bullet.rectangle", title: "Quick Fix Routine")

                if let routine = snapshot.quickRoutine {
                    HStack {
                        Text(routine.title)
                            .font(.subheadline.weight(.semibold))
                        Spacer()
                        Text(routine.durationText)
                            .font(.caption.weight(.semibold))
                            .foregroundColor(.secondary)
                    }

                    ForEach(routine.drills, id: \.self) { drill in
                        Button {
                            toggleRoutineDrill(drill)
                        } label: {
                            HStack {
                                Image(systemName: routineCompletedDrills.contains(drill) ? "checkmark.circle.fill" : "circle")
                                    .foregroundColor(routineCompletedDrills.contains(drill) ? .green : .secondary)

                                Text(drill)
                                    .font(.subheadline)
                                    .foregroundColor(.primary)

                                Spacer()
                            }
                        }
                        .buttonStyle(.plain)
                    }

                    Text(routine.frequencyRecommendation)
                        .font(.caption)
                        .foregroundColor(.secondary)

                    Button {
                        routineCompletedDrills = Set(routine.drills)
                    } label: {
                        Text("Start Routine")
                            .font(.caption.weight(.semibold))
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .background(accentColor.opacity(0.2))
                            .foregroundColor(accentColor)
                            .clipShape(Capsule())
                    }
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
                        HStack(spacing: 10) {
                            ForEach(Array(snapshot.expertDiscovery.enumerated()), id: \.element.id) { index, card in
                                Button {
                                    safariRoute = SafariRoute(url: card.url)
                                } label: {
                                    VStack(alignment: .leading, spacing: 8) {
                                        HStack {
                                            Image(systemName: card.thumbnailToken)
                                                .font(.headline)
                                                .foregroundColor(accentColor)
                                            Spacer()
                                            Image(systemName: "arrow.up.right.square")
                                                .font(.caption)
                                                .foregroundColor(.secondary)
                                        }

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
                                    .padding(10)
                                    .frame(width: 210, alignment: .leading)
                                    .background(Color(.systemGray6))
                                    .clipShape(RoundedRectangle(cornerRadius: 12))
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
                    .frame(height: 86)

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
                            Text(win.text)
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

    private func sectionTitle(icon: String, title: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .foregroundColor(accentColor)
            Text(title)
                .font(.headline)
            Spacer()
        }
    }

    private func actionButton(
        title: String,
        identifier: String,
        filled: Bool,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Text(title)
                .font(.caption.weight(.semibold))
                .multilineTextAlignment(.center)
                .lineLimit(2)
                .minimumScaleFactor(0.8)
                .frame(maxWidth: .infinity)
                .padding(.horizontal, 8)
                .padding(.vertical, 8)
                .background(filled ? accentColor.opacity(0.25) : Color(.systemGray6))
                .foregroundColor(filled ? accentColor : .primary)
                .clipShape(RoundedRectangle(cornerRadius: 10))
        }
        .accessibilityIdentifier(identifier)
        .buttonStyle(.plain)
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
    var cornerRadius: CGFloat = 14
    var useGradient: Bool = false
    @ViewBuilder let content: Content

    var body: some View {
        content
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: cornerRadius)
                    .fill(backgroundFill)
            )
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius)
                    .stroke(Color.white.opacity(useGradient ? 0.14 : 0.08), lineWidth: 1)
            )
    }

    private var backgroundFill: LinearGradient {
        if useGradient {
            return LinearGradient(
                colors: [
                    Color(red: 0.09, green: 0.16, blue: 0.23),
                    Color(red: 0.06, green: 0.10, blue: 0.16),
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        }

        return LinearGradient(
            colors: [Color(.secondarySystemBackground), Color(.secondarySystemBackground)],
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
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
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
