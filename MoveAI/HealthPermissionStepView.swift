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
        VStack(spacing: 20) {
            Spacer(minLength: 20)

            CoachCard(elevated: true) {
                VStack(spacing: 18) {
                    Image(systemName: "heart.fill")
                        .font(.system(size: 54, weight: .semibold))
                        .foregroundColor(.red)

                    VStack(spacing: 10) {
                        Text("Connect Apple Health")
                            .font(CoachTheme.Typography.cardTitle)

                        Text("Sync your health data to automatically fill your profile")
                            .font(CoachTheme.Typography.body)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                    }
                }
                .frame(maxWidth: .infinity)
            }

            CoachCard {
                VStack(spacing: 12) {
                    Button(action: {
                        if hasSyncedData {
                            onPermissionGranted()
                        } else {
                            requestHealthPermissions()
                        }
                    }) {
                        Label(hasSyncedData ? "Continue" : "Connect Apple Health", systemImage: "heart.fill")
                    }
                    .buttonStyle(CoachPrimaryButtonStyle())
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
                        .background(Color.green.opacity(0.12))
                        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                    }

                    if showPermissionDenied {
                        VStack(spacing: 10) {
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
                            .buttonStyle(CoachSecondaryButtonStyle())
                        }
                        .padding()
                        .background(Color.orange.opacity(0.12))
                        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                    }

                    Button("Skip for now") {
                        onPermissionGranted()
                    }
                    .buttonStyle(CoachSecondaryButtonStyle())
                    .disabled(isRequesting)

                    if let errorMessage = errorMessage {
                        Text(errorMessage)
                            .font(.caption)
                            .foregroundColor(.red)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)
                    }
                }
            }

            Spacer(minLength: 20)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .onAppear {
            if healthManager.hasPermissions {
                onPermissionGranted()
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier(AccessibilityID.Onboarding.health)
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
                        syncHealthData()
                    } else {
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
            let healthService = HealthService()
            do {
                let profile = try await healthService.fetchProfile()
                await MainActor.run {
                    if profile.heightFeet > 0 {
                        userHeight = Double(profile.heightFeet * 12 + profile.heightInches)
                    }
                    if profile.weightLbs > 0 {
                        userWeight = Double(profile.weightLbs)
                    }
                    if profile.age > 0 {
                        userAge = profile.age
                    }

                    hasSyncedData = true
                }
            } catch {
                await MainActor.run {
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
