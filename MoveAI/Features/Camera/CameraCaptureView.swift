//
//  CameraCaptureView.swift
//  MoveAI
//
//  Created by Dave Mathew on 10/11/25.
//

import SwiftUI
import AVFoundation

struct CameraCaptureView: View {
    let movementType: MovementType
    @ObservedObject var cameraService: CameraService
    let onRecordingComplete: (MovementRecording) -> Void
    
    @State private var previewLayer: AVCaptureVideoPreviewLayer?
    @State private var showingAnalysis = false
    @State private var completedRecording: MovementRecording?
    
    var body: some View {
        ZStack {
            // Camera Preview
            CameraPreviewView(previewLayer: previewLayer)
                .ignoresSafeArea()
            
            // Overlay UI
            VStack {
                // Top controls
                HStack {
                    Button("Cancel") {
                        // TODO: Handle cancel
                    }
                    .foregroundColor(.white)
                    .padding()
                    
                    Spacer()
                    
                    Text(movementType.displayName)
                        .font(.headline)
                        .foregroundColor(.white)
                        .padding()
                    
                    Spacer()
                    
                    // Placeholder for settings button
                    Button("Settings") {
                        // TODO: Add settings
                    }
                    .foregroundColor(.white)
                    .padding()
                }
                .background(Color.black.opacity(0.3))
                
                Spacer()
                
                // Bottom controls
                VStack(spacing: 20) {
                    // Recording indicator
                    if cameraService.isRecording {
                        HStack {
                            Circle()
                                .fill(Color.red)
                                .frame(width: 12, height: 12)
                                .opacity(0.8)
                            
                            Text("Recording")
                                .font(.headline)
                                .foregroundColor(.white)
                            
                            Text(formatDuration(cameraService.recordingDuration))
                                .font(.system(.caption, design: .monospaced))
                                .foregroundColor(.white)
                        }
                        .padding()
                        .background(Color.black.opacity(0.6))
                        .cornerRadius(20)
                    }
                    
                    // Record button
                    Button(action: toggleRecording) {
                        ZStack {
                            Circle()
                                .fill(cameraService.isRecording ? Color.red : Color.white)
                                .frame(width: 80, height: 80)
                            
                            if cameraService.isRecording {
                                RoundedRectangle(cornerRadius: 4)
                                    .fill(Color.white)
                                    .frame(width: 30, height: 30)
                            } else {
                                Circle()
                                    .fill(Color.red)
                                    .frame(width: 60, height: 60)
                            }
                        }
                    }
                    .disabled(!cameraService.hasPermission)
                    
                    // Instructions
                    Text(cameraService.isRecording ? "Tap to stop recording" : "Tap to start recording")
                        .font(.caption)
                        .foregroundColor(.white)
                        .padding(.horizontal)
                }
                .padding(.bottom, 50)
            }
        }
        .onAppear {
            setupPreviewLayer()
        }
        .sheet(isPresented: $showingAnalysis) {
            if let recording = completedRecording {
                AnalysisResultsView(recording: recording)
            }
        }
    }
    
    private func setupPreviewLayer() {
        guard cameraService.hasPermission else { return }
        cameraService.setupCaptureSession()
        previewLayer = cameraService.createPreviewLayer()
    }
    
    private func toggleRecording() {
        if cameraService.isRecording {
            stopRecording()
        } else {
            startRecording()
        }
    }
    
    private func startRecording() {
        cameraService.startRecording(for: movementType)
    }
    
    private func stopRecording() {
        guard let videoURL = cameraService.stopRecording() else { return }
        
        let recording = MovementRecording(
            movementType: movementType,
            videoURL: videoURL,
            duration: cameraService.recordingDuration
        )
        
        completedRecording = recording
        showingAnalysis = true
        onRecordingComplete(recording)
    }
    
    private func formatDuration(_ duration: TimeInterval) -> String {
        let minutes = Int(duration) / 60
        let seconds = Int(duration) % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }
}

struct CameraPreviewView: UIViewRepresentable {
    let previewLayer: AVCaptureVideoPreviewLayer?
    
    func makeUIView(context: Context) -> UIView {
        let view = UIView()
        view.backgroundColor = .black
        
        if let previewLayer = previewLayer {
            previewLayer.frame = view.bounds
            view.layer.addSublayer(previewLayer)
        }
        
        return view
    }
    
    func updateUIView(_ uiView: UIView, context: Context) {
        if let previewLayer = previewLayer {
            previewLayer.frame = uiView.bounds
        }
    }
}

#Preview {
    CameraCaptureView(
        movementType: .squat,
        cameraService: CameraService(),
        onRecordingComplete: { _ in }
    )
}
