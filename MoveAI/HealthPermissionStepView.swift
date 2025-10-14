//
//  HealthPermissionStepView.swift
//  MoveAI
//
//  Created by Dave Mathew on 10/11/25.
//

import SwiftUI
import HealthKit

struct HealthPermissionStepView: View {
    @ObservedObject var healthManager: HealthManager
    let onPermissionGranted: () -> Void
    
    @AppStorage("userHeight") private var userHeight: Double = 0
    @AppStorage("userWeight") private var userWeight: Double = 0
    @AppStorage("userAge") private var userAge: Int = 0
    
    @State private var isRequesting = false
    @State private var errorMessage: String?
    @State private var showPermissionDenied = false
    @State private var hasSyncedData = false
    
    var body: some View {
        VStack(spacing: 32) {
            Spacer()
            
            VStack(spacing: 24) {
                Image(systemName: "heart.fill")
                    .font(.system(size: 60))
                    .foregroundColor(.red)
                
                VStack(spacing: 16) {
                    Text("Connect Apple Health")
                        .font(.title2)
                        .fontWeight(.semibold)
                    
                    Text("Sync your health data to automatically fill your profile")
                        .font(.body)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
            }
            
            Spacer()
            
            VStack(spacing: 16) {
                // Request permissions button
                Button(action: {
                    if hasSyncedData {
                        onPermissionGranted()
                    } else {
                        requestHealthPermissions()
                    }
                }) {
                    HStack {
                        Image(systemName: "heart.fill")
                        Text(hasSyncedData ? "Continue" : "Connect Apple Health")
                    }
                    .font(.headline)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 50)
                    .background(Color.red)
                    .cornerRadius(8)
                }
                .buttonStyle(.plain)
                .disabled(isRequesting)
                
                if isRequesting {
                    HStack {
                        ProgressView()
                            .scaleEffect(0.8)
                        Text("Waiting for your response...")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                
                // Show synced data summary
                if hasSyncedData {
                    VStack(spacing: 8) {
                        Text("✓ Data synced successfully!")
                            .font(.caption)
                            .foregroundColor(.green)
                        
                        if userHeight > 0 || userWeight > 0 || userAge > 0 {
                            VStack(spacing: 4) {
                                if userHeight > 0 {
                                    Text("Height: \(formatHeight(userHeight))")
                                        .font(.caption2)
                                        .foregroundColor(.secondary)
                                }
                                if userWeight > 0 {
                                    Text("Weight: \(formatWeight(userWeight))")
                                        .font(.caption2)
                                        .foregroundColor(.secondary)
                                }
                                if userAge > 0 {
                                    Text("Age: \(userAge) years")
                                        .font(.caption2)
                                        .foregroundColor(.secondary)
                                }
                            }
                        }
                    }
                    .padding()
                    .background(Color.green.opacity(0.1))
                    .cornerRadius(8)
                }
                
                // Show permission denied message with retry option
                if showPermissionDenied {
                    VStack(spacing: 12) {
                        Text("Health permissions were not granted")
                            .font(.caption)
                            .foregroundColor(.orange)
                        
                        Text("You can enable them later in Settings > Privacy & Security > Health, or try again now.")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                        
                        Button("Try Again") {
                            showPermissionDenied = false
                            requestHealthPermissions()
                        }
                        .buttonStyle(.bordered)
                        .font(.caption)
                    }
                    .padding()
                    .background(Color.orange.opacity(0.1))
                    .cornerRadius(8)
                }
                
                // Skip button for users who want to proceed without HealthKit
                Button("Skip for now") {
                    onPermissionGranted()
                }
                .buttonStyle(.bordered)
                .disabled(isRequesting)
                
                // Error message
                if let errorMessage = errorMessage {
                    Text(errorMessage)
                        .font(.caption)
                        .foregroundColor(.red)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                }
            }
            .padding(.horizontal)
            
            Spacer()
            
        }
        .padding()
        .onAppear {
            // Check if permissions are already granted
            if healthManager.hasPermissions {
                onPermissionGranted()
            }
        }
    }
    
    private func requestHealthPermissions() {
        isRequesting = true
        errorMessage = nil
        showPermissionDenied = false
        
        Task {
            do {
                let granted = try await healthManager.requestPermissions()
                
                await MainActor.run {
                    isRequesting = false
                    
                    if granted {
                        // Try to sync health data
                        syncHealthData()
                    } else {
                        // If permissions were denied, show retry option
                        // This could be due to timing issues or actual denial
                        showPermissionDenied = true
                    }
                }
            } catch {
                await MainActor.run {
                    isRequesting = false
                    errorMessage = "Failed to request Health permissions: \(error.localizedDescription)"
                }
            }
        }
    }
    
    private func syncHealthData() {
        Task {
            // Use static method to sync with HealthKit
            if let syncedProfile = await UserProfile.fromHealthKit(HKHealthStore()) {
                await MainActor.run {
                    // Update AppStorage with synced data
                    if syncedProfile.height > 0 {
                        userHeight = syncedProfile.height
                    }
                    if syncedProfile.weight > 0 {
                        userWeight = syncedProfile.weight
                    }
                    if syncedProfile.age > 0 {
                        userAge = syncedProfile.age
                    }
                    
                    hasSyncedData = true
                }
            } else {
                await MainActor.run {
                    // Even if no data was synced, we still have permissions
                    hasSyncedData = true
                }
            }
        }
    }
    
    private func formatHeight(_ heightInCm: Double) -> String {
        let totalInches = heightInCm / 2.54
        let feet = Int(totalInches / 12)
        let inches = Int(totalInches.truncatingRemainder(dividingBy: 12))
        return "\(feet)'\(inches)\""
    }
    
    private func formatWeight(_ weightInKg: Double) -> String {
        let pounds = weightInKg * 2.20462
        return "\(Int(pounds)) lbs"
    }
}

#Preview {
    HealthPermissionStepView(
        healthManager: HealthManager(),
        onPermissionGranted: {}
    )
}
