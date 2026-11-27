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
            Log.video.debug("📷 CameraService: hasPermission changed from \(oldValue) to \(self.hasPermission)")
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
    @Published var currentCameraPosition: AVCaptureDevice.Position = .back
    private var videoInput: AVCaptureDeviceInput?
    
    override init() {
        super.init()
        Log.video.debug("📷 CameraService: Initializing CameraService")
        Log.video.debug("📷 CameraService: Initial hasPermission: \(self.hasPermission)")
        checkPermissions()
    }
    
    // MARK: - Permission Management
    
    func checkPermissions() {
        Log.video.debug("📷 CameraService: Checking camera permissions...")
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            Log.video.debug("✅ CameraService: Camera permission already granted")
            hasPermission = true
            // Note: setupCaptureSession() will be called by requestPermissionAndSetup()
        case .notDetermined:
            Log.video.debug("❓ CameraService: Camera permission not determined, requesting...")
            requestPermission()
        case .denied, .restricted:
            Log.video.error("CameraService: Camera permission denied or restricted")
            hasPermission = false
            errorMessage = "Camera access is required to record movements"
        @unknown default:
            Log.video.error("CameraService: Unknown camera permission status")
            hasPermission = false
        }
    }
    
    private func requestPermission() {
        Log.video.debug("📷 CameraService: Requesting camera permission...")
        AVCaptureDevice.requestAccess(for: .video) { [weak self] granted in
            DispatchQueue.main.async {
                Log.video.debug("📷 CameraService: Permission request result: \(granted)")
                self?.hasPermission = granted
                if granted {
                    Log.video.debug("✅ CameraService: Permission granted, setting up capture session...")
                    self?.setupCaptureSession()
                } else {
                    Log.video.error("CameraService: Permission denied")
                    self?.errorMessage = "Camera access denied. Please enable in Settings."
                }
            }
        }
    }
    
    // MARK: - Capture Session Setup
    
    func setupCaptureSession() {
        guard hasPermission else { 
            Log.video.error("CameraService: No permission to setup capture session")
            return 
        }
        
        Log.video.debug("📷 CameraService: Setting up capture session...")
        
        captureSession.beginConfiguration()
        
        // Configure session preset for high quality video
        if captureSession.canSetSessionPreset(.high) {
            captureSession.sessionPreset = .high
        }
        
        // Add video input
        guard let videoDevice = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: currentCameraPosition),
              let videoInput = try? AVCaptureDeviceInput(device: videoDevice),
              captureSession.canAddInput(videoInput) else {
            errorMessage = "Failed to setup camera input"
            Log.video.error("CameraService: Failed to setup camera input")
            captureSession.commitConfiguration()
            return
        }
        
        self.videoInput = videoInput
        captureSession.addInput(videoInput)
        Log.video.debug("✅ CameraService: Video input added for \(self.currentCameraPosition == .back ? "back" : "front") camera")
        
        // Add video output for recording
        let movieOutput = AVCaptureMovieFileOutput()
        if captureSession.canAddOutput(movieOutput) {
            captureSession.addOutput(movieOutput)
            videoOutput = movieOutput
            Log.video.debug("✅ CameraService: Video output added")
        } else {
            Log.video.error("CameraService: Failed to add video output")
        }
        
        // Add video data output for pose detection
        let dataOutput = AVCaptureVideoDataOutput()
        dataOutput.setSampleBufferDelegate(self, queue: DispatchQueue(label: "video.data.queue"))
        dataOutput.videoSettings = [kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA]
        
        if captureSession.canAddOutput(dataOutput) {
            captureSession.addOutput(dataOutput)
            videoDataOutput = dataOutput
            Log.video.debug("✅ CameraService: Video data output added for pose detection")
        } else {
            Log.video.error("CameraService: Failed to add video data output")
        }
        
        // Configure video output settings
        if let connection = movieOutput.connection(with: .video) {
            if connection.isVideoStabilizationSupported {
                connection.preferredVideoStabilizationMode = .auto
            }
        }
        
        captureSession.commitConfiguration()
        Log.video.debug("✅ CameraService: Capture session configured successfully")
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
    
    func getVideoDimensions() -> CGSize {
        guard let videoOutput = videoDataOutput,
              let connection = videoOutput.connection(with: .video),
              let videoDevice = videoInput?.device else {
            Log.video.error("CameraService: Cannot get video dimensions - no video output or device")
            return CGSize(width: 1920, height: 1080) // Default fallback
        }
        
        let formatDescription = videoDevice.activeFormat.formatDescription
        let dimensions = CMVideoFormatDescriptionGetDimensions(formatDescription)
        let size = CGSize(width: Int(dimensions.width), height: Int(dimensions.height))
        
        Log.video.debug("📷 CameraService: Video dimensions: \(String(describing: size))")
        return size
    }
    
    // MARK: - Permission & Setup Management
    
    func requestPermissionAndSetup(completion: (() -> Void)? = nil) {
        Log.video.debug("📷 CameraService: Requesting permission and setting up...")
        checkPermissions()
        
        // If permission is already granted, set up the capture session
        if hasPermission {
            Log.video.debug("📷 CameraService: Permission already granted, setting up capture session...")
            setupCaptureSession()
            completion?()
        }
    }
    
    // MARK: - Session Management
    
    func startSession() {
        guard !captureSession.isRunning else { 
            Log.video.debug("📷 CameraService: Session already running")
            return 
        }
        
        Log.video.debug("📷 CameraService: Starting capture session...")
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            self?.captureSession.startRunning()
            Log.video.debug("✅ CameraService: Capture session started")
        }
    }
    
    func stopSession() {
        guard captureSession.isRunning else { 
            Log.video.debug("📷 CameraService: Session already stopped")
            return 
        }
        
        Log.video.debug("📷 CameraService: Stopping capture session...")
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            self?.captureSession.stopRunning()
            Log.video.debug("✅ CameraService: Capture session stopped")
        }
    }
    
    // MARK: - Pose Detection Control
    
    func enablePoseDetection() {
        isPoseDetectionEnabled = true
        poseAnalysisService.reset()
        Log.video.debug("✅ CameraService: Pose detection enabled")
    }
    
    func disablePoseDetection() {
        isPoseDetectionEnabled = false
        poseAnalysisService.reset()
        Log.video.debug("📷 CameraService: Pose detection disabled")
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
            Log.video.error("CameraService: Failed to get pixel buffer from sample buffer")
            return 
        }
        
        Task { @MainActor in
            // Only process frames when pose detection is enabled
            guard isPoseDetectionEnabled else { 
                Log.video.warning("CameraService: Pose detection disabled, skipping frame")
                return 
            }
            Log.video.debug("📷 CameraService: Processing frame for pose detection - isPoseDetectionEnabled: \(self.isPoseDetectionEnabled)")
            await poseAnalysisService.analyzeFrame(pixelBuffer)
        }
    }
    
    // MARK: - Camera Flip
    
    func flipCamera() {
        guard hasPermission else { return }
        
        // Toggle camera position
        currentCameraPosition = currentCameraPosition == .back ? .front : .back
        
        // Remove current video input
        if let videoInput = videoInput {
            captureSession.removeInput(videoInput)
        }
        
        // Add new video input with flipped camera
        guard let videoDevice = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: currentCameraPosition),
              let newVideoInput = try? AVCaptureDeviceInput(device: videoDevice),
              captureSession.canAddInput(newVideoInput) else {
            Log.video.error("CameraService: Failed to flip camera")
            return
        }
        
        self.videoInput = newVideoInput
        captureSession.addInput(newVideoInput)
        Log.video.debug("✅ CameraService: Camera flipped to \(self.currentCameraPosition == .back ? "back" : "front")")
    }
}
