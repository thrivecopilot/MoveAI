//
//  CameraService.swift
//  MoveAI
//
//  Created by Dave Mathew on 10/11/25.
//

import Foundation
import AVFoundation
import UIKit

@MainActor
class CameraService: NSObject, ObservableObject {
    @Published var isRecording = false
    @Published var recordingDuration: TimeInterval = 0
    @Published var hasPermission = false
    @Published var errorMessage: String?
    
    private let captureSession = AVCaptureSession()
    private var videoOutput: AVCaptureMovieFileOutput?
    private var recordingTimer: Timer?
    private var recordingStartTime: Date?
    
    override init() {
        super.init()
        checkPermissions()
    }
    
    // MARK: - Permission Management
    
    func checkPermissions() {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            hasPermission = true
        case .notDetermined:
            requestPermission()
        case .denied, .restricted:
            hasPermission = false
            errorMessage = "Camera access is required to record movements"
        @unknown default:
            hasPermission = false
        }
    }
    
    private func requestPermission() {
        AVCaptureDevice.requestAccess(for: .video) { [weak self] granted in
            DispatchQueue.main.async {
                self?.hasPermission = granted
                if granted {
                    self?.setupCaptureSession()
                } else {
                    self?.errorMessage = "Camera access denied. Please enable in Settings."
                }
            }
        }
    }
    
    // MARK: - Capture Session Setup
    
    func setupCaptureSession() {
        guard hasPermission else { return }
        
        captureSession.beginConfiguration()
        
        // Add video input
        guard let videoDevice = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back),
              let videoInput = try? AVCaptureDeviceInput(device: videoDevice),
              captureSession.canAddInput(videoInput) else {
            errorMessage = "Failed to setup camera input"
            captureSession.commitConfiguration()
            return
        }
        
        captureSession.addInput(videoInput)
        
        // Add video output
        let movieOutput = AVCaptureMovieFileOutput()
        if captureSession.canAddOutput(movieOutput) {
            captureSession.addOutput(movieOutput)
            videoOutput = movieOutput
        }
        
        captureSession.commitConfiguration()
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
