//
//  ProfileView.swift
//  MoveAI
//
//  Created by Dave Mathew on 10/18/25.
//

import SwiftUI

struct ProfileView: View {
    @EnvironmentObject var sessionManager: SessionManager
    @EnvironmentObject var appleAuthManager: AppleAuthManager
    @AppStorage("userHeight") private var userHeight: Double = 0
    @AppStorage("userWeight") private var userWeight: Double = 0
    @AppStorage("userAge") private var userAge: Int = 0
    @AppStorage("isSignedIn") private var isSignedIn = false
    @AppStorage("hasHealthPermissions") private var hasHealthPermissions = false
    @State private var showingDeleteConfirmation = false

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: CoachTheme.Surfaces.sectionSpacing) {
                    headerCard

                    CoachCard {
                        VStack(alignment: .leading, spacing: CoachTheme.Surfaces.groupSpacing) {
                            CoachSectionHeader(icon: "heart.fill", title: "Health Information", tint: .red)

                            VStack(spacing: CoachTheme.Surfaces.groupSpacing) {
                                ProfileInfoRow(
                                    icon: "ruler",
                                    title: "Height",
                                    value: formatHeight(userHeight)
                                )

                                ProfileInfoRow(
                                    icon: "scalemass",
                                    title: "Weight",
                                    value: formatWeight(userWeight)
                                )

                                ProfileInfoRow(
                                    icon: "calendar",
                                    title: "Age",
                                    value: "\(userAge) years old"
                                )
                            }
                        }
                    }
                    .accessibilityIdentifier(AccessibilityID.Profile.healthCard)

                    CoachCard {
                        VStack(alignment: .leading, spacing: CoachTheme.Surfaces.groupSpacing) {
                            CoachSectionHeader(icon: "chart.bar.fill", title: "Quick Stats", tint: .green)

                            VStack(spacing: CoachTheme.Surfaces.groupSpacing) {
                                ProfileInfoRow(
                                    icon: "video.fill",
                                    title: "Total Sessions",
                                    value: "\(sessionManager.sessions.count)"
                                )

                                ProfileInfoRow(
                                    icon: "clock.fill",
                                    title: "This Week",
                                    value: "\(sessionsThisWeek()) sessions"
                                )

                                ProfileInfoRow(
                                    icon: "trophy.fill",
                                    title: "Favorite Movement",
                                    value: mostFrequentMovement()
                                )
                            }
                        }
                    }
                    .accessibilityIdentifier(AccessibilityID.Profile.quickStatsCard)

                    CoachCard {
                        VStack(alignment: .leading, spacing: CoachTheme.Surfaces.groupSpacing) {
                            CoachSectionHeader(icon: "gearshape.fill", title: "Settings", tint: .secondary)

                            VStack(spacing: 0) {
                                SettingsRow(
                                    icon: "pencil",
                                    title: "Edit Profile",
                                    action: { }
                                )

                                Divider()

                                SettingsRow(
                                    icon: "bell",
                                    title: "Notifications",
                                    action: { }
                                )

                                Divider()

                                SettingsRow(
                                    icon: "questionmark.circle",
                                    title: "Help & Support",
                                    action: { }
                                )
                            }
                        }
                    }
                    .accessibilityIdentifier(AccessibilityID.Profile.settingsCard)

                    accountCard

                    Spacer(minLength: CoachTheme.Surfaces.sectionSpacing)
                }
                .padding(.horizontal, CoachTheme.Surfaces.screenHorizontalPadding)
                .padding(.vertical, CoachTheme.Surfaces.screenVerticalPadding)
            }
            .navigationTitle("Profile")
            .navigationBarTitleDisplayMode(.large)
            .coachNavigationChrome()
            .coachScreenContainer()
            .accessibilityIdentifier(AccessibilityID.Profile.root)
        }
    }

    private var accountCard: some View {
        CoachCard {
            VStack(alignment: .leading, spacing: CoachTheme.Surfaces.groupSpacing) {
                CoachSectionHeader(icon: "person.crop.circle.badge.checkmark", title: "Account", tint: .blue)

                VStack(spacing: 0) {
                    SettingsRow(
                        icon: "rectangle.portrait.and.arrow.right",
                        title: "Sign Out",
                        action: signOut
                    )
                    .accessibilityIdentifier(AccessibilityID.Profile.signOutButton)

                    Divider()

                    Button(action: { showingDeleteConfirmation = true }) {
                        HStack {
                            Image(systemName: "trash")
                                .foregroundColor(.red)
                                .frame(width: 20)

                            Text("Delete Account & Data")
                                .font(CoachTheme.Typography.body)
                                .foregroundColor(.red)

                            Spacer()
                        }
                        .padding(.vertical, CoachTheme.Surfaces.rowVerticalPadding)
                    }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier(AccessibilityID.Profile.deleteAccountButton)
                }
            }
        }
        .accessibilityIdentifier(AccessibilityID.Profile.accountCard)
        .confirmationDialog(
            "Delete account and all data?",
            isPresented: $showingDeleteConfirmation,
            titleVisibility: .visible
        ) {
            Button("Delete Everything", role: .destructive, action: deleteAccount)
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This permanently removes your sign-in, profile, and every recorded session and video from this device. This cannot be undone.")
        }
    }

    private func signOut() {
        appleAuthManager.signOut()
        isSignedIn = false
    }

    private func deleteAccount() {
        sessionManager.deleteAllData()
        userHeight = 0
        userWeight = 0
        userAge = 0
        hasHealthPermissions = false
        appleAuthManager.signOut()
        isSignedIn = false
    }

    private var headerCard: some View {
        CoachCard(elevated: true) {
            VStack(spacing: 8) {
                Image(systemName: "person.circle.fill")
                    .font(.system(size: 74))
                    .foregroundColor(CoachTheme.Palette.accent)

                Text("Your Profile")
                    .font(CoachTheme.Typography.cardTitle)
            }
            .frame(maxWidth: .infinity)
        }
        .accessibilityIdentifier(AccessibilityID.Profile.header)
    }

    private func formatHeight(_ heightInCm: Double) -> String {
        ProfileUnits.formatHeight(cm: heightInCm)
    }

    private func formatWeight(_ weightInKg: Double) -> String {
        ProfileUnits.formatWeight(kg: weightInKg)
    }

    private func sessionsThisWeek() -> Int {
        let calendar = Calendar.current
        let now = Date()
        let weekAgo = calendar.date(byAdding: .day, value: -7, to: now) ?? now

        return sessionManager.sessions.filter { session in
            session.timestamp >= weekAgo
        }.count
    }

    private func mostFrequentMovement() -> String {
        let movements = sessionManager.sessions.map { $0.movementType }
        let counts = Dictionary(grouping: movements, by: { $0 }).mapValues { $0.count }

        if let mostFrequent = counts.max(by: { $0.value < $1.value }) {
            return mostFrequent.key.rawValue.capitalized
        }
        return "None yet"
    }
}

struct ProfileInfoRow: View {
    let icon: String
    let title: String
    let value: String

    var body: some View {
        HStack {
            Image(systemName: icon)
                .foregroundColor(CoachTheme.Palette.accent)
                .frame(width: 20)

            Text(title)
                .font(CoachTheme.Typography.body)
                .foregroundColor(.secondary)

            Spacer()

            Text(value)
                .font(CoachTheme.Typography.subtitle)
        }
    }
}

struct SettingsRow: View {
    let icon: String
    let title: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack {
                Image(systemName: icon)
                    .foregroundColor(CoachTheme.Palette.accent)
                    .frame(width: 20)

                Text(title)
                    .font(CoachTheme.Typography.body)
                    .foregroundColor(.primary)

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding(.vertical, CoachTheme.Surfaces.rowVerticalPadding)
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    ProfileView()
        .environmentObject(SessionManager())
        .environmentObject(AppleAuthManager())
}
