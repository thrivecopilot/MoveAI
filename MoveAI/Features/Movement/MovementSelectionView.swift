//
//  MovementSelectionView.swift
//  MoveAI
//
//  Created by Dave Mathew on 10/11/25.
//  Requirements: docs/screens/video-review.md
//

import SwiftUI

struct MovementSelectionView: View {
    @StateObject private var sessionManager = SessionManager()
    @State private var cameraService = CameraService()
    @State private var showingCamera = false
    @State private var showingVideoImport = false
    @State private var showingMuayThaiTechniqueSelection = false
    @State private var selectedMovement: MovementType?
    @State private var selectedTechnique: MuayThaiTechnique?
    @State private var selectedFightStance: FightStance?
    @State private var captureMode: CaptureMode
    @State private var pendingSession: Session?
    @State private var showingSessionDetail = false
    @State private var didAutoPresentCapture = false
    @State private var pendingCaptureAfterTechniqueSelection = false

    private let defaultMovement: MovementType?
    private let autoPresentCapture: Bool

    private var strengthMovements: [MovementType] {
        MovementType.allCases.filter { $0 != .muayThai && $0 != .running }
    }

    enum CaptureMode {
        case record
        case upload
    }

    init(
        defaultMovement: MovementType? = nil,
        defaultCaptureMode: CaptureMode = .record,
        autoPresentCapture: Bool = false
    ) {
        self.defaultMovement = defaultMovement
        self.autoPresentCapture = autoPresentCapture
        _captureMode = State(initialValue: defaultCaptureMode)
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: CoachTheme.Surfaces.groupSpacing) {
                Picker("Mode", selection: $captureMode) {
                    Text("Record").tag(CaptureMode.record)
                    Text("Upload").tag(CaptureMode.upload)
                }
                .pickerStyle(.segmented)
                .padding(.horizontal, CoachTheme.Surfaces.screenHorizontalPadding)
                .accessibilityElement(children: .contain)
                .accessibilityIdentifier(AccessibilityID.MovementSelection.modePicker)

                ScrollView {
                    VStack(alignment: .leading, spacing: CoachTheme.Surfaces.groupSpacing) {
                        Text("Muay Thai")
                            .font(.headline)
                            .padding(.horizontal, CoachTheme.Surfaces.screenHorizontalPadding)

                        MovementSelectionCard(
                            movement: .muayThai,
                            onTap: {
                                selectedMovement = .muayThai
                                showingMuayThaiTechniqueSelection = true
                            }
                        )
                        .padding(.horizontal, CoachTheme.Surfaces.screenHorizontalPadding)
                        .accessibilityIdentifier("\(AccessibilityID.MovementSelection.card).\(MovementType.muayThai.rawValue)")

                        Text("Running")
                            .font(.headline)
                            .padding(.horizontal, CoachTheme.Surfaces.screenHorizontalPadding)

                        MovementSelectionCard(
                            movement: .running,
                            onTap: {
                                selectedMovement = .running
                                selectedTechnique = nil
                                selectedFightStance = nil
                                presentCaptureFlow()
                            }
                        )
                        .padding(.horizontal, CoachTheme.Surfaces.screenHorizontalPadding)
                        .accessibilityIdentifier("\(AccessibilityID.MovementSelection.card).\(MovementType.running.rawValue)")

                        Text("Strength Training")
                            .font(.headline)
                            .padding(.horizontal, CoachTheme.Surfaces.screenHorizontalPadding)

                        LazyVGrid(columns: [
                            GridItem(.flexible()),
                            GridItem(.flexible()),
                        ], spacing: CoachTheme.Surfaces.groupSpacing) {
                            ForEach(strengthMovements) { movement in
                                MovementSelectionCard(
                                    movement: movement,
                                    onTap: {
                                        selectedMovement = movement
                                        selectedTechnique = nil
                                        selectedFightStance = nil
                                        presentCaptureFlow()
                                    }
                                )
                                .accessibilityIdentifier("\(AccessibilityID.MovementSelection.card).\(movement.rawValue)")
                            }
                        }
                        .padding(.horizontal, CoachTheme.Surfaces.screenHorizontalPadding)
                        .accessibilityIdentifier(AccessibilityID.MovementSelection.grid)
                    }
                    .padding(.vertical, CoachTheme.Surfaces.rowVerticalPadding)
                }
            }
            .navigationTitle(captureMode == .record ? "Record Movement" : "Upload Video")
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
            .sheet(isPresented: $showingMuayThaiTechniqueSelection) {
                MuayThaiTechniqueSelectionView { technique, stance in
                    selectedMovement = .muayThai
                    selectedTechnique = technique
                    selectedFightStance = stance
                    pendingCaptureAfterTechniqueSelection = true
                    showingMuayThaiTechniqueSelection = false
                }
            }
            .sheet(isPresented: $showingCamera) {
                if let movement = selectedMovement {
                    CameraCaptureView(
                        movementType: movement,
                        technique: movement == .muayThai ? selectedTechnique : nil,
                        fightStance: movement == .muayThai ? selectedFightStance : nil,
                        cameraService: cameraService,
                        sessionManager: sessionManager,
                        onRecordingComplete: { _ in },
                        onSessionCreated: { session in
                            pendingSession = session
                            showingCamera = false
                        }
                    )
                } else {
                    movementSelectionMissingView(
                        title: "Unable to start camera",
                        closeAction: { showingCamera = false }
                    )
                }
            }
            .sheet(isPresented: $showingVideoImport) {
                if let movement = selectedMovement {
                    VideoImportView(
                        movementType: movement,
                        technique: movement == .muayThai ? selectedTechnique : nil,
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
            .onChange(of: showingCamera) { isShowing in
                if !isShowing, pendingSession != nil {
                    showingSessionDetail = true
                }
            }
            .onChange(of: showingVideoImport) { isShowing in
                if !isShowing, pendingSession != nil {
                    showingSessionDetail = true
                }
            }
            .onChange(of: showingMuayThaiTechniqueSelection) { isShowing in
                guard !isShowing, pendingCaptureAfterTechniqueSelection else { return }
                pendingCaptureAfterTechniqueSelection = false
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                    guard selectedMovement != nil else { return }
                    presentCaptureFlow()
                }
            }
            .onAppear {
                triggerAutoCaptureIfNeeded()
            }
            .coachNavigationChrome()
            .coachScreenContainer()
            .accessibilityIdentifier(AccessibilityID.MovementSelection.root)
        }
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
            .navigationTitle(captureMode == .record ? "Record Movement" : "Upload Video")
            .navigationBarTitleDisplayMode(.inline)
        }
    }

    private func presentCaptureFlow() {
        guard selectedMovement != nil else { return }

        if captureMode == .record {
            showingCamera = true
        } else {
            showingVideoImport = true
        }
    }

    private func triggerAutoCaptureIfNeeded() {
        guard autoPresentCapture, !didAutoPresentCapture, let movement = defaultMovement else { return }
        didAutoPresentCapture = true

        selectedMovement = movement
        if movement == .muayThai {
            showingMuayThaiTechniqueSelection = true
            return
        }

        presentCaptureFlow()
    }
}

struct MovementSelectionCard: View {
    @Environment(\.colorScheme) private var colorScheme

    let movement: MovementType
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            VStack(spacing: CoachTheme.Surfaces.groupSpacing) {
                Image(systemName: movement.icon)
                    .font(.system(size: 36, weight: .semibold))
                    .foregroundColor(CoachTheme.Palette.accent)

                VStack(spacing: 6) {
                    Text(movement.displayName)
                        .font(CoachTheme.Typography.subtitle)
                        .foregroundColor(.primary)

                    Text(movement.description)
                        .font(CoachTheme.Typography.meta)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .lineLimit(3)
                }
            }
            .frame(maxWidth: .infinity)
            .frame(height: 168)
            .padding(.horizontal, 8)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(CoachTheme.Palette.surfaceFill(for: colorScheme))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(CoachTheme.Palette.stroke(for: colorScheme), lineWidth: 1)
            )
            .shadow(color: .black.opacity(colorScheme == .dark ? 0.18 : 0.06), radius: 10, x: 0, y: 6)
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    MovementSelectionView()
}
