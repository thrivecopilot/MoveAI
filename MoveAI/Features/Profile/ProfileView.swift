//
//  ProfileView.swift
//  MoveAI
//
//  Created by Dave Mathew on 10/18/25.
//

import SwiftUI

struct ProfileView: View {
    @EnvironmentObject var sessionManager: SessionManager
    @AppStorage("userHeight") private var userHeight: Double = 0
    @AppStorage("userWeight") private var userWeight: Double = 0
    @AppStorage("userAge") private var userAge: Int = 0

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 18) {
                    headerCard

                    CoachCard {
                        VStack(alignment: .leading, spacing: 12) {
                            CoachSectionHeader(icon: "heart.fill", title: "Health Information", tint: .red)

                            VStack(spacing: 12) {
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
                        VStack(alignment: .leading, spacing: 12) {
                            CoachSectionHeader(icon: "chart.bar.fill", title: "Quick Stats", tint: .green)

                            VStack(spacing: 12) {
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
                        VStack(alignment: .leading, spacing: 12) {
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

                    Spacer(minLength: 20)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
            }
            .navigationTitle("Profile")
            .navigationBarTitleDisplayMode(.large)
            .coachNavigationChrome()
            .coachScreenContainer()
            .accessibilityIdentifier(AccessibilityID.Profile.root)
        }
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

    private func formatHeight(_ height: Double) -> String {
        if height == 0 { return "Not set" }
        let feet = Int(height / 12)
        let inches = Int(height.truncatingRemainder(dividingBy: 12))
        return "\(feet)'\(inches)\""
    }

    private func formatWeight(_ weight: Double) -> String {
        if weight == 0 { return "Not set" }
        return "\(Int(weight)) lbs"
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
            .padding(.vertical, 10)
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    ProfileView()
        .environmentObject(SessionManager())
}
