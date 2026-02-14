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
    @State private var captureMode: CaptureMode = .record
    @State private var pendingSession: Session?
    @State private var showingSessionDetail = false
    
    enum CaptureMode {
        case record
        case upload
    }
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Mode Selection
                Picker("Mode", selection: $captureMode) {
                    Text("Record").tag(CaptureMode.record)
                    Text("Upload").tag(CaptureMode.upload)
                }
                .pickerStyle(.segmented)
                .padding()
                
                ScrollView {
                    LazyVGrid(columns: [
                        GridItem(.flexible()),
                        GridItem(.flexible())
                    ], spacing: 20) {
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
                        }
                    }
                    .padding()
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
                        onRecordingComplete: { recording in
                            // Session is created in CameraCaptureView
                            print("Recording completed: \(recording.id)")
                        },
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
                        onVideoProcessed: { recording in
                            // Session is created in VideoImportView
                            print("Video processed: \(recording.id)")
                        },
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
        }
    }
}

struct MovementSelectionCard: View {
    let movement: MovementType
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 16) {
                Image(systemName: movement.icon)
                    .font(.system(size: 40))
                    .foregroundColor(.accentColor)
                
                VStack(spacing: 8) {
                    Text(movement.displayName)
                        .font(.headline)
                        .foregroundColor(.primary)
                    
                    Text(movement.description)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .lineLimit(3)
                }
            }
            .frame(maxWidth: .infinity)
            .frame(height: 160)
            .padding()
            .background(Color(.systemGray6))
            .cornerRadius(16)
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    MovementSelectionView()
}
