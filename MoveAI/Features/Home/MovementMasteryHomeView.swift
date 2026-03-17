//
//  MovementMasteryHomeView.swift
//  MoveAI
//
//  Created by Dave Mathew on 10/11/25.
//  Requirements: docs/screens/video-review.md
//

import SwiftUI

struct MovementMasteryHomeView: View {
    @AppStorage("isSignedIn") private var isSignedIn = false
    @AppStorage("hasHealthPermissions") private var hasHealthPermissions = false
    @AppStorage("userHeight") private var userHeight: Double = 0
    @AppStorage("userWeight") private var userWeight: Double = 0
    @AppStorage("userAge") private var userAge: Int = 0

    @State private var selectedMovement: MovementType?
    @State private var showingCamera = false
    @State private var showingVideoImport = false
    @StateObject private var sessionManager: SessionManager
    @StateObject private var cameraService = CameraService()
    @State private var powerliftingRowHeights: [String: CGFloat] = [:]
    @State private var powerliftingChipWidths: [String: CGFloat] = [:]
    @State private var showingMuayThaiTechniqueSelection = false
    @State private var selectedMuayThaiTechnique: MuayThaiTechnique?
    @State private var selectedFightStance: FightStance?
    @State private var didConfirmMuayThaiTechniqueSelection = false

    init() {
        _sessionManager = StateObject(wrappedValue: SessionManager())
    }

    init(sessionManager: SessionManager) {
        _sessionManager = StateObject(wrappedValue: sessionManager)
    }

    @State private var showingSessionHistory = false
    @State private var cameraView: CameraCaptureView?
    @State private var showingActionSheet = false
    @State private var pendingSession: Session?
    @State private var showingSessionDetail = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: CoachTheme.Surfaces.sectionSpacing) {
                    welcomeHeader
                    movementCategoriesSection

                    if !sessionManager.sessions.isEmpty {
                        recentActivitySection
                    }
                }
                .padding(.horizontal, CoachTheme.Surfaces.screenHorizontalPadding)
                .padding(.vertical, CoachTheme.Surfaces.screenVerticalPadding)
            }
            .navigationTitle("MoveAI")
            .navigationBarTitleDisplayMode(.large)
            .navigationDestination(isPresented: $showingSessionDetail) {
                if let session = pendingSession {
                    SessionDetailView(
                        session: session,
                        sessionManager: sessionManager,
                        onExit: {
                            showingSessionDetail = false
                            pendingSession = nil
                        }
                    )
                }
            }
            .coachNavigationChrome()
            .coachScreenContainer()
            .accessibilityIdentifier(AccessibilityID.Home.root)
            .accessibilityValue(powerliftingLayoutProbeValue)
        }
        .sheet(isPresented: $showingCamera) {
            if let cameraView = cameraView {
                cameraView
            }
        }
        .sheet(isPresented: $showingVideoImport) {
            if let movement = selectedMovement {
                VideoImportView(
                    movementType: movement,
                    technique: movement == .muayThai ? selectedMuayThaiTechnique : nil,
                    fightStance: movement == .muayThai ? selectedFightStance : nil,
                    sessionManager: sessionManager,
                    onVideoProcessed: { _ in },
                    onSessionCreated: { session in
                        pendingSession = session
                        showingVideoImport = false
                    }
                )
            } else {
                movementSelectionMissingView(
                    title: "Unable to start upload",
                    closeAction: { showingVideoImport = false }
                )
            }
        }
        .sheet(isPresented: $showingMuayThaiTechniqueSelection, onDismiss: {
            if !didConfirmMuayThaiTechniqueSelection {
                selectedMovement = nil
                selectedMuayThaiTechnique = nil
                selectedFightStance = nil
            }
            didConfirmMuayThaiTechniqueSelection = false
        }) {
            MuayThaiTechniqueSelectionView { technique, stance in
                selectedMovement = .muayThai
                selectedMuayThaiTechnique = technique
                selectedFightStance = stance
                didConfirmMuayThaiTechniqueSelection = true
                showingMuayThaiTechniqueSelection = false
                showingActionSheet = true
            }
        }
        .confirmationDialog("Choose Option", isPresented: $showingActionSheet, presenting: selectedMovement) { movement in
            Button("Record New Video") {
                cameraView = CameraCaptureView(
                    movementType: movement,
                    technique: movement == .muayThai ? selectedMuayThaiTechnique : nil,
                    fightStance: movement == .muayThai ? selectedFightStance : nil,
                    cameraService: cameraService,
                    sessionManager: sessionManager,
                    onRecordingComplete: { _ in },
                    onSessionCreated: { session in
                        pendingSession = session
                        showingCamera = false
                    }
                )

                showingCamera = true
            }

            Button("Upload Existing Video") {
                showingVideoImport = true
            }

            Button("Cancel", role: .cancel) {
                selectedMovement = nil
                selectedMuayThaiTechnique = nil
                selectedFightStance = nil
            }
        }
        .onChange(of: showingCamera) { isShowing in
            if !isShowing {
                selectedMovement = nil
                selectedMuayThaiTechnique = nil
                selectedFightStance = nil
                cameraView = nil
                if pendingSession != nil {
                    showingSessionDetail = true
                }
            }
        }
        .onChange(of: showingVideoImport) { isShowing in
            if !isShowing {
                selectedMovement = nil
                selectedMuayThaiTechnique = nil
                selectedFightStance = nil
                if pendingSession != nil {
                    showingSessionDetail = true
                }
            }
        }
    }

    private var welcomeHeader: some View {
        CoachCard(elevated: true) {
            HStack(alignment: .center) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Master Your Movements")
                        .font(CoachTheme.Typography.cardTitle)

                    Text("Start a new session or review your recent workouts")
                        .font(CoachTheme.Typography.body)
                        .foregroundColor(.secondary)
                }

                Spacer()

                Image(systemName: "dumbbell.fill")
                    .font(.system(size: 36, weight: .semibold))
                    .foregroundColor(CoachTheme.Palette.accent)
            }
        }
        .accessibilityIdentifier(AccessibilityID.Home.welcomeHeader)
    }

    private var movementCategoriesSection: some View {
        VStack(alignment: .leading, spacing: CoachTheme.Surfaces.groupSpacing) {
            Text("Start Session")
                .font(CoachTheme.Typography.title)

            VStack(spacing: 0) {
                MovementCategoryCard(
                    title: "Powerlifting",
                    description: "Master the fundamental compound movements",
                    icon: "figure.strengthtraining.traditional",
                    color: .blue,
                    movements: [
                        MovementOption(
                            type: .squat,
                            title: "Squat",
                            subtitle: nil,
                            difficulty: .intermediate
                        ),
                        MovementOption(
                            type: .deadlift,
                            title: "Deadlift",
                            subtitle: nil,
                            difficulty: .intermediate
                        ),
                        MovementOption(
                            type: .benchPress,
                            title: "Bench Press",
                            subtitle: nil,
                            difficulty: .beginner
                        )
                    ],
                    onMovementSelected: { movementType in
                        beginSessionSelection(for: movementType)
                    },
                    onRowHeightsChanged: { rowHeights in
                        powerliftingRowHeights = rowHeights
                    },
                    onChipWidthsChanged: { chipWidths in
                        powerliftingChipWidths = chipWidths
                    }
                )
                .accessibilityIdentifier(AccessibilityID.Home.powerliftingCard)
            }

            MovementCategoryCard(
                title: "Muay Thai",
                description: "Technique-focused analysis for striking fundamentals",
                icon: "figure.kickboxing",
                color: .red,
                movements: [
                    MovementOption(
                        type: .muayThai,
                        title: "Muay Thai",
                        subtitle: nil,
                        difficulty: .intermediate
                    )
                ],
                onMovementSelected: { movementType in
                    beginSessionSelection(for: movementType)
                }
            )

            VStack(spacing: CoachTheme.Surfaces.groupSpacing) {
                ComingSoonCategoryCard(
                    title: "Olympic Lifting",
                    description: "Snatch, Clean & Jerk",
                    icon: "figure.strengthtraining.traditional",
                    color: .orange
                )

                ComingSoonCategoryCard(
                    title: "Bodyweight",
                    description: "Push-ups, Pull-ups, Dips",
                    icon: "figure.strengthtraining.traditional",
                    color: .green
                )
            }
        }
        .accessibilityIdentifier(AccessibilityID.Home.startSessionSection)
    }

    private var recentActivitySection: some View {
        VStack(alignment: .leading, spacing: CoachTheme.Surfaces.groupSpacing) {
            HStack {
                Text("Recent Sessions")
                    .font(CoachTheme.Typography.title)

                Spacer()

                NavigationLink(destination: SessionHistoryView(sessionManager: sessionManager)) {
                    Text("View All")
                        .font(CoachTheme.Typography.subtitle)
                        .foregroundColor(CoachTheme.Palette.accent)
                }
                .accessibilityIdentifier(AccessibilityID.Home.viewAllButton)
            }

            if sessionManager.sessions.isEmpty {
                EmptyStateCard(
                    icon: "video.fill",
                    title: "No sessions yet",
                    description: "Start by recording your first movement to see your progress here"
                )
            } else {
                VStack(spacing: 10) {
                    ForEach(sessionManager.recentSessions(limit: 3)) { session in
                        NavigationLink(destination: SessionDetailView(session: session, sessionManager: sessionManager, onExit: nil)) {
                            RecentSessionCard(session: session)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
        .accessibilityIdentifier(AccessibilityID.Home.recentSessions)
    }

    private func beginSessionSelection(for movementType: MovementType) {
        selectedMovement = movementType
        if movementType == .muayThai {
            didConfirmMuayThaiTechniqueSelection = false
            selectedMuayThaiTechnique = nil
            selectedFightStance = nil
            showingMuayThaiTechniqueSelection = true
            return
        }

        showingActionSheet = true
    }
    private func movementSelectionMissingView(
        title: String,
        closeAction: @escaping () -> Void
    ) -> some View {
        NavigationStack {
            VStack(spacing: 16) {
                Image(systemName: "exclamationmark.triangle")
                    .font(.system(size: 36))
                    .foregroundColor(.orange)

                Text(title)
                    .font(.headline)

                Text("Please reselect a movement and try again.")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)

                Button("Close") {
                    closeAction()
                }
                .buttonStyle(.borderedProminent)
            }
            .padding()
            .navigationTitle("Upload Video")
            .navigationBarTitleDisplayMode(.inline)
        }
    }

    private var expectedPowerliftingMovementIDs: [String] {
        [MovementType.squat.rawValue, MovementType.deadlift.rawValue, MovementType.benchPress.rawValue]
    }

    private var powerliftingLayoutProbeValue: String {
        let ready = expectedPowerliftingMovementIDs.allSatisfy {
            powerliftingRowHeights[$0] != nil && powerliftingChipWidths[$0] != nil
        }

        let rows = expectedPowerliftingMovementIDs.map { id in
            HomePowerliftingLayoutProbeRowPayload(
                id: id,
                rowHeight: roundedToTenth(powerliftingRowHeights[id] ?? 0),
                chipWidth: roundedToTenth(powerliftingChipWidths[id] ?? 0)
            )
        }

        let payload = HomePowerliftingLayoutProbePayload(
            schemaVersion: 1,
            ready: ready,
            rows: rows
        )

        let encoder = JSONEncoder()
        guard
            let data = try? encoder.encode(payload),
            let json = String(data: data, encoding: .utf8)
        else {
            return "{\"schemaVersion\":1,\"ready\":false,\"rows\":[]}"
        }

        return json
    }

    private func roundedToTenth(_ value: CGFloat) -> Double {
        guard value.isFinite else { return 0 }
        return (Double(value) * 10).rounded() / 10
    }
}

struct MovementCategoryCard: View {
    let title: String
    let description: String
    let icon: String
    let color: Color
    let movements: [MovementOption]
    let onMovementSelected: (MovementType) -> Void
    var onRowHeightsChanged: (([String: CGFloat]) -> Void)? = nil
    var onChipWidthsChanged: (([String: CGFloat]) -> Void)? = nil

    var body: some View {
        CoachCard {
            VStack(alignment: .leading, spacing: CoachTheme.Surfaces.groupSpacing) {
                HStack {
                    Image(systemName: icon)
                        .font(.title2)
                        .foregroundColor(color)
                        .frame(width: 30)

                    VStack(alignment: .leading, spacing: 4) {
                        Text(title)
                            .font(CoachTheme.Typography.subtitle)

                        Text(description)
                            .font(CoachTheme.Typography.meta)
                            .foregroundColor(.secondary)
                    }

                    Spacer()
                }

                VStack(spacing: 8) {
                    ForEach(movements, id: \.type) { movement in
                        MovementOptionRow(
                            movement: movement,
                            onTap: {
                                onMovementSelected(movement.type)
                            }
                        )
                    }
                }
            }
        }
        .onPreferenceChange(MovementOptionRowHeightPreferenceKey.self) { value in
            onRowHeightsChanged?(value)
        }
        .onPreferenceChange(MovementOptionChipWidthPreferenceKey.self) { value in
            onChipWidthsChanged?(value)
        }
    }
}

struct MovementOption {
    let type: MovementType
    let title: String
    let subtitle: String?
    let difficulty: DifficultyLevel
}

struct MovementOptionRow: View {
    @Environment(\.colorScheme) private var colorScheme

    let movement: MovementOption
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 12) {
                Image(systemName: movement.type.icon)
                    .font(.title3)
                    .foregroundColor(CoachTheme.Palette.accent)
                    .frame(width: 24)

                VStack(alignment: .leading, spacing: 2) {
                    Text(movement.title)
                        .font(CoachTheme.Typography.subtitle)

                    if let subtitle = movement.subtitle {
                        Text(subtitle)
                            .font(CoachTheme.Typography.meta)
                            .foregroundColor(.secondary)
                    }
                }

                Spacer()

                CoachChip(
                    title: movement.difficulty.rawValue,
                    tint: Color(movement.difficulty.color),
                    minWidth: CoachTheme.Surfaces.difficultyChipMinWidth
                )
                .background(
                    GeometryReader { proxy in
                        Color.clear.preference(
                            key: MovementOptionChipWidthPreferenceKey.self,
                            value: [movement.type.rawValue: proxy.size.width]
                        )
                    }
                )

                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .frame(minHeight: CoachTheme.Surfaces.rowMinHeight)
            .padding(.vertical, CoachTheme.Surfaces.rowVerticalPadding)
            .padding(.horizontal, CoachTheme.Surfaces.rowHorizontalPadding)
            .background(CoachTheme.Palette.secondarySurface(for: colorScheme))
            .clipShape(RoundedRectangle(cornerRadius: CoachTheme.Surfaces.rowCornerRadius, style: .continuous))
            .background(
                GeometryReader { proxy in
                    Color.clear.preference(
                        key: MovementOptionRowHeightPreferenceKey.self,
                        value: [movement.type.rawValue: proxy.size.height]
                    )
                }
            )
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("\(AccessibilityID.Home.movementOption).\(movement.type.rawValue)")
    }
}

struct ComingSoonCategoryCard: View {
    @Environment(\.colorScheme) private var colorScheme

    let title: String
    let description: String
    let icon: String
    let color: Color

    var body: some View {
        CoachCard {
            HStack {
                Image(systemName: icon)
                    .font(.title2)
                    .foregroundColor(color.opacity(0.7))
                    .frame(width: 30)

                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(CoachTheme.Typography.subtitle)
                        .foregroundColor(.secondary)

                    Text(description)
                        .font(CoachTheme.Typography.meta)
                        .foregroundColor(.secondary)
                }

                Spacer()

                Text("Coming Soon")
                    .font(CoachTheme.Typography.caption)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 5)
                    .background(CoachTheme.Palette.secondarySurface(for: colorScheme))
                    .clipShape(Capsule())
                    .foregroundColor(.secondary)
            }
        }
        .opacity(0.85)
    }
}

struct StatCard: View {
    let icon: String
    let title: String
    let value: String
    let color: Color

    var body: some View {
        CoachCard {
            VStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.title3)
                    .foregroundColor(color)

                Text(title)
                    .font(CoachTheme.Typography.meta)
                    .foregroundColor(.secondary)

                Text(value)
                    .font(CoachTheme.Typography.subtitle)
            }
        }
    }
}

struct EmptyStateCard: View {
    let icon: String
    let title: String
    let description: String

    var body: some View {
        CoachCard {
            VStack(spacing: 12) {
                Image(systemName: icon)
                    .font(.system(size: 40))
                    .foregroundColor(.secondary)

                Text(title)
                    .font(CoachTheme.Typography.subtitle)
                    .foregroundColor(.secondary)

                Text(description)
                    .font(CoachTheme.Typography.meta)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity)
        }
    }
}

struct RecentSessionCard: View {
    @Environment(\.colorScheme) private var colorScheme

    let session: Session

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: session.movementType.icon)
                .font(.title3)
                .foregroundColor(CoachTheme.Palette.accent)
                .frame(width: 24)

            VStack(alignment: .leading, spacing: 2) {
                Text(session.displayName)
                    .font(CoachTheme.Typography.subtitle)

                Text(session.formattedDate)
                    .font(CoachTheme.Typography.meta)
                    .foregroundColor(.secondary)
            }

            Spacer()

            if let score = session.score {
                CoachChip(title: "\(Int(score))", tint: scoreColor(Int(score)))
            } else {
                Image(systemName: "clock")
                    .font(.caption)
                    .foregroundColor(.orange)
            }
        }
        .padding(.vertical, CoachTheme.Surfaces.rowVerticalPadding)
        .padding(.horizontal, CoachTheme.Surfaces.rowHorizontalPadding)
        .background(CoachTheme.Palette.secondarySurface(for: colorScheme))
        .clipShape(RoundedRectangle(cornerRadius: CoachTheme.Surfaces.rowCornerRadius, style: .continuous))
    }

    private func scoreColor(_ score: Int) -> Color {
        if score >= 80 {
            return .green
        } else if score >= 60 {
            return .orange
        } else {
            return .red
        }
    }
}

private struct MovementOptionRowHeightPreferenceKey: PreferenceKey {
    static var defaultValue: [String: CGFloat] = [:]

    static func reduce(value: inout [String: CGFloat], nextValue: () -> [String: CGFloat]) {
        value.merge(nextValue(), uniquingKeysWith: { _, new in new })
    }
}

private struct MovementOptionChipWidthPreferenceKey: PreferenceKey {
    static var defaultValue: [String: CGFloat] = [:]

    static func reduce(value: inout [String: CGFloat], nextValue: () -> [String: CGFloat]) {
        value.merge(nextValue(), uniquingKeysWith: { _, new in new })
    }
}

private struct HomePowerliftingLayoutProbePayload: Encodable {
    let schemaVersion: Int
    let ready: Bool
    let rows: [HomePowerliftingLayoutProbeRowPayload]
}

private struct HomePowerliftingLayoutProbeRowPayload: Encodable {
    let id: String
    let rowHeight: Double
    let chipWidth: Double
}

#Preview {
    MovementMasteryHomeView()
        .environmentObject(TabBarVisibility())
}
