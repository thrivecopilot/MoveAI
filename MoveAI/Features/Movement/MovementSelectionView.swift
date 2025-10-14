//
//  MovementSelectionView.swift
//  MoveAI
//
//  Created by Dave Mathew on 10/11/25.
//

import SwiftUI

struct MovementSelectionView: View {
    @State private var cameraService = CameraService()
    @State private var showingCamera = false
    @State private var selectedMovement: MovementType?
    
    var body: some View {
        NavigationView {
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
                                showingCamera = true
                            }
                        )
                    }
                }
                .padding()
            }
            .navigationTitle("Record Movement")
            .navigationBarTitleDisplayMode(.large)
            .sheet(isPresented: $showingCamera) {
                if let movement = selectedMovement {
                    CameraCaptureView(
                        movementType: movement,
                        cameraService: cameraService,
                        onRecordingComplete: { recording in
                            // TODO: Save recording and show results
                            print("Recording completed: \(recording.id)")
                        }
                    )
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
