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
    @State private var selectedMovement: MovementType?
    @State private var captureMode: CaptureMode
    @State private var pendingSession: Session?
    @State private var showingSessionDetail = false
    @State private var didAutoPresentCapture = false

    private let defaultMovement: MovementType?
    private let autoPresentCapture: Bool

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
            VStack(spacing: 10) {
                Picker("Mode", selection: $captureMode) {
                    Text("Record").tag(CaptureMode.record)
                    Text("Upload").tag(CaptureMode.upload)
                }
                .pickerStyle(.segmented)
                .padding(.horizontal, 16)
                .accessibilityElement(children: .contain)
                .accessibilityIdentifier(AccessibilityID.MovementSelection.modePicker)

                ScrollView {
                    LazyVGrid(columns: [
                        GridItem(.flexible()),
                        GridItem(.flexible()),
                    ], spacing: 14) {
                        ForEach(MovementType.allCases) { movement in
                            MovementSelectionCard(
                                movement: movement,
                                onTap: {
                                    selectedMovement = movement
                                    if captureMode == .record {
                                        showingCamera = true
                                    } else {
                                        showingVideoImport = true
                                    }
                                }
                            )
                            .accessibilityIdentifier("\(AccessibilityID.MovementSelection.card).\(movement.rawValue)")
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .accessibilityIdentifier(AccessibilityID.MovementSelection.grid)
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
            .sheet(isPresented: $showingCamera) {
                if let movement = selectedMovement {
                    CameraCaptureView(
                        movementType: movement,
                        cameraService: cameraService,
                        sessionManager: sessionManager,
                        onRecordingComplete: { _ in },
                        onSessionCreated: { session in
                            pendingSession = session
                            showingCamera = false
                        }
                    )
                }
            }
            .sheet(isPresented: $showingVideoImport) {
                if let movement = selectedMovement {
                    VideoImportView(
                        movementType: movement,
                        sessionManager: sessionManager,
                        onVideoProcessed: { _ in },
                        onSessionCreated: { session in
                            pendingSession = session
                            showingVideoImport = false
                        }
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
            .onAppear {
                triggerAutoCaptureIfNeeded()
            }
            .coachNavigationChrome()
            .coachScreenContainer()
            .accessibilityIdentifier(AccessibilityID.MovementSelection.root)
        }
    }

    private func triggerAutoCaptureIfNeeded() {
        guard autoPresentCapture, !didAutoPresentCapture, let movement = defaultMovement else { return }
        didAutoPresentCapture = true
        selectedMovement = movement

        if captureMode == .record {
            showingCamera = true
        } else {
            showingVideoImport = true
        }
    }
}

struct MovementSelectionCard: View {
    @Environment(\.colorScheme) private var colorScheme

    let movement: MovementType
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 12) {
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
