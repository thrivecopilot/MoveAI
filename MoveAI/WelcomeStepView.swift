//
//  WelcomeStepView.swift
//  MoveAI
//
//  Created by Dave Mathew on 10/11/25.
//

import SwiftUI

struct WelcomeStepView: View {
    var body: some View {
        VStack(spacing: 20) {
            Spacer(minLength: 18)

            CoachCard(elevated: true) {
                VStack(spacing: 20) {
                    Image(systemName: "dumbbell.fill")
                        .font(.system(size: 72, weight: .semibold))
                        .foregroundColor(CoachTheme.Palette.accent)

                    VStack(spacing: 12) {
                        Text("Welcome to MoveAI")
                            .font(CoachTheme.Typography.screenTitle)
                            .multilineTextAlignment(.center)

                        Text("Master your movements with AI-powered form analysis")
                            .font(CoachTheme.Typography.body)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                    }
                }
                .frame(maxWidth: .infinity)
            }

            CoachCard {
                VStack(spacing: 14) {
                    FeatureRow(
                        icon: "applelogo",
                        title: "Sign in with Apple",
                        description: "Secure authentication with your Apple ID"
                    )

                    FeatureRow(
                        icon: "heart.fill",
                        title: "Health Integration",
                        description: "Connect with Apple Health for personalized insights"
                    )

                    FeatureRow(
                        icon: "brain.head.profile",
                        title: "AI Analysis",
                        description: "Get instant feedback on your movement technique"
                    )
                }
            }

            Spacer(minLength: 18)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier(AccessibilityID.Onboarding.welcome)
    }
}

struct FeatureRow: View {
    let icon: String
    let title: String
    let description: String

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundColor(CoachTheme.Palette.accent)
                .frame(width: 28)

            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(CoachTheme.Typography.subtitle)
                Text(description)
                    .font(CoachTheme.Typography.meta)
                    .foregroundColor(.secondary)
            }

            Spacer()
        }
    }
}

#Preview {
    WelcomeStepView()
}
