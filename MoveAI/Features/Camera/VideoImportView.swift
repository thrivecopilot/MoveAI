//
//  VideoImportView.swift
//  MoveAI
//
//  Created by Dave Mathew on 10/11/25.
//  Requirements: docs/screens/video-review.md
//

import SwiftUI
import PhotosUI
import AVFoundation

struct VideoImportView: View {
    let movementType: MovementType
    let sessionManager: SessionManager
    let onVideoProcessed: (MovementRecording) -> Void
    let onSessionCreated: (Session) -> Void
    
    @StateObject private var videoProcessor = VideoProcessor()
    @State private var selectedItem: PhotosPickerItem?
    @State private var errorMessage: String?
    @State private var showingError = false
    
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationStack {
            ZStack {
                if videoProcessor.isProcessing {
                    processingView
                } else {
                    selectionView
                }
            }
            .navigationTitle("Upload Video")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        if videoProcessor.isProcessing {
                            videoProcessor.cancel()
                        }
                        dismiss()
                    }
                }
            }
            .onChange(of: selectedItem) { newItem in
                Task {
                    await processSelectedVideo(newItem)
                }
            }
            .alert("Error", isPresented: $showingError) {
                Button("OK") { }
            } message: {
                if let errorMessage = errorMessage {
                    Text(errorMessage)
                }
            }
        }
    }
    
    // MARK: - Selection View
    
    private var selectionView: some View {
        VStack(spacing: 32) {
            // Icon
            Image(systemName: "video.fill")
                .font(.system(size: 80))
                .foregroundColor(.accentColor)
            
            // Instructions
            VStack(spacing: 16) {
                Text("Select a Video")
                    .font(.title2)
                    .fontWeight(.semibold)
                
                Text("Choose a video of your \(movementType.displayName.lowercased()) to analyze")
                    .font(.body)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
            }
            
            // Tips
            VStack(alignment: .leading, spacing: 12) {
                Text("Tips for best results:")
                    .font(.headline)
                
                ForEach(VideoCaptureTips.tipsForMovement(movementType), id: \.self) { tip in
                    HStack(alignment: .top, spacing: 8) {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.green)
                            .font(.caption)
                        Text(tip)
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                }
            }
            .padding()
            .background(Color(.systemGray6))
            .cornerRadius(12)
            .padding(.horizontal)
            
            // Select Video Button
            PhotosPicker(
                selection: $selectedItem,
                matching: .videos,
                photoLibrary: .shared()
            ) {
                Label("Choose Video", systemImage: "photo.on.rectangle")
                    .font(.headline)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.accentColor)
                    .cornerRadius(12)
            }
            .padding(.horizontal)
            
            Spacer()
        }
        .padding()
    }
    
    // MARK: - Processing View
    
    private var processingView: some View {
        VStack(spacing: 24) {
            ProgressView(value: videoProcessor.progress)
                .progressViewStyle(.linear)
                .padding(.horizontal)
            
            VStack(spacing: 12) {
                Text(processingStepText)
                    .font(.headline)
                
                Text("\(Int(videoProcessor.progress * 100))% complete")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            
            if videoProcessor.progress > 0.1 {
                VStack(spacing: 8) {
                    Text("This may take a few moments...")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Button("Cancel") {
                        videoProcessor.cancel()
                        dismiss()
                    }
                    .buttonStyle(.bordered)
                }
            }
            
            Spacer()
        }
        .padding()
    }
    
    private var processingStepText: String {
        switch videoProcessor.currentStep {
        case .idle:
            return "Ready"
        case .validating:
            return "Validating video..."
        case .extractingFrames:
            return "Extracting frames..."
        case .analyzingPoses:
            return "Analyzing movement..."
        case .complete:
            return "Complete!"
        }
    }
    
    // MARK: - Video Processing
    
    private func processSelectedVideo(_ item: PhotosPickerItem?) async {
        guard let item = item else { return }
        
        do {
            // Load video data
            guard let data = try await item.loadTransferable(type: Data.self) else {
                throw VideoProcessingError.videoNotReadable
            }
            
            // Save to temporary file
            let tempURL = FileManager.default.temporaryDirectory
                .appendingPathComponent(UUID().uuidString)
                .appendingPathExtension("mov")
            
            try data.write(to: tempURL)
            
            // Process video
            let recording = try await videoProcessor.processVideo(
                tempURL,
                movementType: movementType
            ) { progress in
                // Progress updates handled by VideoProcessor's @Published properties
            }
            
            // Clean up temp file (optional - might want to keep for analysis)
            // try? FileManager.default.removeItem(at: tempURL)
            
            // Create session and show analysis results
            await MainActor.run {
                // Create a session from the processed video (uploaded, not live-recorded)
                let session = Session(
                    movementType: recording.movementType,
                    videoURL: recording.videoURL,
                    timestamp: recording.timestamp,
                    poseData: recording.poseData,
                    isRecordedLive: false  // Uploaded video, not live-recorded
                )
                
                // Add to session manager
                sessionManager.addSession(session)
                
                // Call the callback
                onVideoProcessed(recording)
                
                onSessionCreated(session)
            }
            
        } catch {
            await MainActor.run {
                errorMessage = error.localizedDescription
                showingError = true
            }
        }
    }
}

#Preview {
    VideoImportView(
        movementType: .squat,
        sessionManager: SessionManager(),
        onVideoProcessed: { _ in },
        onSessionCreated: { _ in }
    )
}
