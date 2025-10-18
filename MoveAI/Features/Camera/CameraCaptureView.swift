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
    
    init(movementType: MovementType, cameraService: CameraService, onRecordingComplete: @escaping (MovementRecording) -> Void) {
        print("📷 CameraCaptureView: Initializing for movement: \(movementType.displayName)")
        self.movementType = movementType
        self.cameraService = cameraService
        self.onRecordingComplete = onRecordingComplete
        print("📷 CameraCaptureView: Camera service hasPermission: \(cameraService.hasPermission)")
    }
    
    var body: some View {
        ZStack {
            // Camera Preview
            if cameraService.hasPermission {
                ZStack {
                    CameraPreviewView(previewLayer: previewLayer)
                        .ignoresSafeArea()
                    
                    // Pose overlay - always show when pose detection is enabled
                    if cameraService.isPoseDetectionEnabled {
                        GeometryReader { geometry in
                            PoseOverlayView(
                                pose: cameraService.poseAnalysisService.currentPose,
                                previewSize: geometry.size // Use actual screen size
                            )
                            .onAppear {
                                print("📱 CameraCaptureView: Pose overlay appeared, currentPose: \(cameraService.poseAnalysisService.currentPose != nil ? "exists" : "nil"), size: \(geometry.size)")
                            }
                            .onChange(of: cameraService.poseAnalysisService.currentPose) { newPose in
                                print("📱 CameraCaptureView: Pose changed! New pose: \(newPose != nil ? "exists" : "nil")")
                            }
                        }
                        .ignoresSafeArea()
                    }
                }
            } else {
                // Permission denied state
                VStack(spacing: 20) {
                    Image(systemName: "camera.fill")
                        .font(.system(size: 60))
                        .foregroundColor(.gray)
                    
                    Text("Camera Access Required")
                        .font(.title2)
                        .fontWeight(.semibold)
                    
                    Text("Please enable camera access in Settings to record your movements.")
                        .multilineTextAlignment(.center)
                        .foregroundColor(.secondary)
                    
                    VStack(spacing: 12) {
                        Button("Request Camera Access") {
                            cameraService.requestPermissionAndSetup()
                        }
                        .buttonStyle(.borderedProminent)
                        
                        Button("Open Settings") {
                            if let settingsURL = URL(string: UIApplication.openSettingsURLString) {
                                UIApplication.shared.open(settingsURL)
                            }
                        }
                        .buttonStyle(.bordered)
                    }
                }
                .padding()
                .background(Color.black.opacity(0.8))
                .ignoresSafeArea()
            }
            
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
                    
                    // Camera flip button
                    Button(action: flipCamera) {
                        Image(systemName: "camera.rotate")
                            .font(.title2)
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
                    
                    // Pose detection controls
                    HStack(spacing: 20) {
                        Button(action: togglePoseDetection) {
                            HStack {
                                Image(systemName: cameraService.isPoseDetectionEnabled ? "figure.walk" : "figure.walk.circle")
                                Text(cameraService.isPoseDetectionEnabled ? "Pose ON" : "Pose OFF")
                            }
                            .padding(.horizontal, 16)
                            .padding(.vertical, 8)
                            .background(cameraService.isPoseDetectionEnabled ? Color.green : Color.gray)
                            .foregroundColor(.white)
                            .cornerRadius(20)
                        }
                        
                        if let pose = cameraService.poseAnalysisService.currentPose {
                            Text("\(pose.keypoints.count) points")
                                .font(.caption)
                                .foregroundColor(.white)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 6)
                                .background(Color.black.opacity(0.6))
                                .cornerRadius(12)
                        }
                    }
                    .padding(.bottom, 10)
                    
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
            print("📷 CameraCaptureView: View appeared")
            // Request permissions and setup
            cameraService.requestPermissionAndSetup()
            
            // Setup preview layer after a short delay to ensure camera service is ready
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                if cameraService.hasPermission {
                    setupPreviewLayer()
                }
            }
        }
        .onDisappear {
            cameraService.stopSession()
        }
        .onChange(of: cameraService.hasPermission) { hasPermission in
            print("📷 CameraCaptureView: Permission changed to: \(hasPermission)")
            if hasPermission {
                setupPreviewLayer()
            }
        }
        .sheet(isPresented: $showingAnalysis) {
            if let recording = completedRecording {
                AnalysisResultsView(recording: recording)
            }
        }
    }
    
    private func setupPreviewLayer() {
        guard cameraService.hasPermission else { 
            print("❌ CameraCaptureView: No camera permission, waiting...")
            return 
        }
        
        print("📷 CameraCaptureView: Setting up preview layer...")
        
        // Create preview layer from the camera service
        if previewLayer == nil {
            previewLayer = cameraService.createPreviewLayer()
            print("✅ CameraCaptureView: Preview layer created")
            
            // Start the session after setup
            cameraService.startSession()
        } else {
            print("📷 CameraCaptureView: Preview layer already exists")
        }
    }
    
    private func toggleRecording() {
        if cameraService.isRecording {
            stopRecording()
        } else {
            startRecording()
        }
    }
    
    private func togglePoseDetection() {
        if cameraService.isPoseDetectionEnabled {
            cameraService.disablePoseDetection()
        } else {
            cameraService.enablePoseDetection()
        }
    }
    
    private func startRecording() {
        // Clear previous pose data before starting new recording
        cameraService.poseAnalysisService.reset()
        cameraService.startRecording(for: movementType)
    }
    
    private func stopRecording() {
        guard let videoURL = cameraService.stopRecording() else { return }
        
        let recording = MovementRecording(
            movementType: movementType,
            videoURL: videoURL,
            duration: cameraService.recordingDuration,
            poseData: cameraService.poseAnalysisService.poseHistory
        )
        
        completedRecording = recording
        showingAnalysis = true
        onRecordingComplete(recording)
    }
    
    private func flipCamera() {
        cameraService.flipCamera()
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
        // Remove existing preview layers
        uiView.layer.sublayers?.removeAll { $0 is AVCaptureVideoPreviewLayer }
        
        // Add new preview layer if available
        if let previewLayer = previewLayer {
            previewLayer.frame = uiView.bounds
            uiView.layer.addSublayer(previewLayer)
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
