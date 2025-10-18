//
//  CameraService.swift
//  MoveAI
//
//  Created by Dave Mathew on 10/11/25.
//

import Foundation
import AVFoundation
import UIKit
import Vision

@MainActor
class CameraService: NSObject, ObservableObject {
    @Published var isRecording = false
    @Published var recordingDuration: TimeInterval = 0
    @Published var hasPermission = false {
        didSet {
            print("📷 CameraService: hasPermission changed from \(oldValue) to \(hasPermission)")
        }
    }
    
    // Pose analysis
    @Published var poseAnalysisService = PoseAnalysisService()
    @Published var isPoseDetectionEnabled = true
    @Published var errorMessage: String?
    
    private let captureSession = AVCaptureSession()
    private var videoOutput: AVCaptureMovieFileOutput?
    private var videoDataOutput: AVCaptureVideoDataOutput?
    private var recordingTimer: Timer?
    private var recordingStartTime: Date?
    
    override init() {
        super.init()
        print("📷 CameraService: Initializing CameraService")
        print("📷 CameraService: Initial hasPermission: \(hasPermission)")
        checkPermissions()
    }
    
    // MARK: - Permission Management
    
    func checkPermissions() {
        print("📷 CameraService: Checking camera permissions...")
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            print("✅ CameraService: Camera permission already granted")
            hasPermission = true
            // Note: setupCaptureSession() will be called by requestPermissionAndSetup()
        case .notDetermined:
            print("❓ CameraService: Camera permission not determined, requesting...")
            requestPermission()
        case .denied, .restricted:
            print("❌ CameraService: Camera permission denied or restricted")
            hasPermission = false
            errorMessage = "Camera access is required to record movements"
        @unknown default:
            print("❌ CameraService: Unknown camera permission status")
            hasPermission = false
        }
    }
    
    private func requestPermission() {
        print("📷 CameraService: Requesting camera permission...")
        AVCaptureDevice.requestAccess(for: .video) { [weak self] granted in
            DispatchQueue.main.async {
                print("📷 CameraService: Permission request result: \(granted)")
                self?.hasPermission = granted
                if granted {
                    print("✅ CameraService: Permission granted, setting up capture session...")
                    self?.setupCaptureSession()
                } else {
                    print("❌ CameraService: Permission denied")
                    self?.errorMessage = "Camera access denied. Please enable in Settings."
                }
            }
        }
    }
    
    // MARK: - Capture Session Setup
    
    func setupCaptureSession() {
        guard hasPermission else { 
            print("❌ CameraService: No permission to setup capture session")
            return 
        }
        
        print("📷 CameraService: Setting up capture session...")
        
        captureSession.beginConfiguration()
        
        // Configure session preset for high quality video
        if captureSession.canSetSessionPreset(.high) {
            captureSession.sessionPreset = .high
        }
        
        // Add video input
        guard let videoDevice = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back),
              let videoInput = try? AVCaptureDeviceInput(device: videoDevice),
              captureSession.canAddInput(videoInput) else {
            errorMessage = "Failed to setup camera input"
            print("❌ CameraService: Failed to setup camera input")
            captureSession.commitConfiguration()
            return
        }
        
        captureSession.addInput(videoInput)
        print("✅ CameraService: Video input added")
        
        // Add video output for recording
        let movieOutput = AVCaptureMovieFileOutput()
        if captureSession.canAddOutput(movieOutput) {
            captureSession.addOutput(movieOutput)
            videoOutput = movieOutput
            print("✅ CameraService: Video output added")
        } else {
            print("❌ CameraService: Failed to add video output")
        }
        
        // Add video data output for pose detection
        let dataOutput = AVCaptureVideoDataOutput()
        dataOutput.setSampleBufferDelegate(self, queue: DispatchQueue(label: "video.data.queue"))
        dataOutput.videoSettings = [kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA]
        
        if captureSession.canAddOutput(dataOutput) {
            captureSession.addOutput(dataOutput)
            videoDataOutput = dataOutput
            print("✅ CameraService: Video data output added for pose detection")
        } else {
            print("❌ CameraService: Failed to add video data output")
        }
        
        // Configure video output settings
        if let connection = movieOutput.connection(with: .video) {
            if connection.isVideoStabilizationSupported {
                connection.preferredVideoStabilizationMode = .auto
            }
        }
        
        captureSession.commitConfiguration()
        print("✅ CameraService: Capture session configured successfully")
    }
    
    // MARK: - Recording Control
    
    func startRecording(for movementType: MovementType) {
        guard hasPermission, let videoOutput = videoOutput else {
            errorMessage = "Camera not ready for recording"
            return
        }
        
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let fileName = "\(movementType.rawValue)_\(Date().timeIntervalSince1970).mov"
        let fileURL = documentsPath.appendingPathComponent(fileName)
        
        videoOutput.startRecording(to: fileURL, recordingDelegate: self)
        
        isRecording = true
        recordingStartTime = Date()
        recordingDuration = 0
        
        // Start timer for duration tracking
        recordingTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
            Task { @MainActor in
                guard let self = self, let startTime = self.recordingStartTime else { return }
                self.recordingDuration = Date().timeIntervalSince(startTime)
            }
        }
    }
    
    func stopRecording() -> URL? {
        guard isRecording, let videoOutput = videoOutput else { return nil }
        
        videoOutput.stopRecording()
        isRecording = false
        recordingTimer?.invalidate()
        recordingTimer = nil
        
        return videoOutput.outputFileURL
    }
    
    // MARK: - Preview Layer
    
    func createPreviewLayer() -> AVCaptureVideoPreviewLayer {
        let previewLayer = AVCaptureVideoPreviewLayer(session: captureSession)
        previewLayer.videoGravity = .resizeAspectFill
        return previewLayer
    }
    
    // MARK: - Permission & Setup Management
    
    func requestPermissionAndSetup(completion: (() -> Void)? = nil) {
        print("📷 CameraService: Requesting permission and setting up...")
        checkPermissions()
        
        // If permission is already granted, set up the capture session
        if hasPermission {
            print("📷 CameraService: Permission already granted, setting up capture session...")
            setupCaptureSession()
            completion?()
        }
    }
    
    // MARK: - Session Management
    
    func startSession() {
        guard !captureSession.isRunning else { 
            print("📷 CameraService: Session already running")
            return 
        }
        
        print("📷 CameraService: Starting capture session...")
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            self?.captureSession.startRunning()
            print("✅ CameraService: Capture session started")
        }
    }
    
    func stopSession() {
        guard captureSession.isRunning else { 
            print("📷 CameraService: Session already stopped")
            return 
        }
        
        print("📷 CameraService: Stopping capture session...")
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            self?.captureSession.stopRunning()
            print("✅ CameraService: Capture session stopped")
        }
    }
    
    // MARK: - Pose Detection Control
    
    func enablePoseDetection() {
        isPoseDetectionEnabled = true
        poseAnalysisService.reset()
        print("✅ CameraService: Pose detection enabled")
    }
    
    func disablePoseDetection() {
        isPoseDetectionEnabled = false
        poseAnalysisService.reset()
        print("📷 CameraService: Pose detection disabled")
    }
}

// MARK: - AVCaptureFileOutputRecordingDelegate

extension CameraService: AVCaptureFileOutputRecordingDelegate {
    nonisolated func fileOutput(_ output: AVCaptureFileOutput, didFinishRecordingTo outputFileURL: URL, from connections: [AVCaptureConnection], error: Error?) {
        Task { @MainActor in
            if let error = error {
                self.errorMessage = "Recording failed: \(error.localizedDescription)"
            }
        }
    }
}

// MARK: - AVCaptureVideoDataOutputSampleBufferDelegate

extension CameraService: AVCaptureVideoDataOutputSampleBufferDelegate {
    nonisolated func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { 
            print("❌ CameraService: Failed to get pixel buffer from sample buffer")
            return 
        }
        
        Task { @MainActor in
            // Only process frames when pose detection is enabled
            guard isPoseDetectionEnabled else { 
                print("⚠️ CameraService: Pose detection disabled, skipping frame")
                return 
            }
            print("📷 CameraService: Processing frame for pose detection")
            poseAnalysisService.analyzeFrame(pixelBuffer)
        }
    }
}
