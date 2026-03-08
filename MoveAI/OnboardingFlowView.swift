//
//  OnboardingFlowView.swift
//  MoveAI
//
//  Created by Dave Mathew on 10/11/25.
//

import SwiftUI

struct OnboardingFlowView: View {
    @Binding var isSignedIn: Bool
    @Binding var hasHealthPermissions: Bool

    @State private var currentStep = 0
    @State private var appleAuthManager = AppleAuthManager()
    @State private var healthManager = HealthManager()

    private let steps = ["Welcome", "Apple Sign In", "Health Permissions", "Personal Info"]

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                HStack(spacing: 8) {
                    ForEach(0..<steps.count, id: \.self) { index in
                        Capsule()
                            .fill(index <= currentStep ? CoachTheme.Palette.accent : Color.gray.opacity(0.30))
                            .frame(height: 6)
                            .animation(CoachTheme.Motion.standard, value: currentStep)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 14)
                .accessibilityIdentifier(AccessibilityID.Onboarding.progress)

                TabView(selection: $currentStep) {
                    WelcomeStepView()
                        .tag(0)
                        .accessibilityIdentifier(AccessibilityID.Onboarding.welcome)

                    AppleSignInStepView(
                        appleAuthManager: appleAuthManager,
                        onSignInSuccess: {
                            isSignedIn = true
                            moveToNextStep()
                        }
                    )
                    .tag(1)
                    .accessibilityIdentifier(AccessibilityID.Onboarding.signIn)

                    HealthPermissionStepView(
                        healthManager: healthManager,
                        onPermissionGranted: {
                            hasHealthPermissions = true
                            moveToNextStep()
                        }
                    )
                    .tag(2)
                    .accessibilityIdentifier(AccessibilityID.Onboarding.health)

                    PersonalInfoStepView(
                        onComplete: {
                            // Final onboarding step intentionally keeps this closure-only behavior.
                        }
                    )
                    .tag(3)
                    .accessibilityIdentifier(AccessibilityID.Onboarding.personalInfo)
                }
                .tabViewStyle(PageTabViewStyle(indexDisplayMode: .never))
                .animation(CoachTheme.Motion.standard, value: currentStep)
            }
            .navigationBarHidden(true)
            .coachScreenContainer()
            .accessibilityIdentifier(AccessibilityID.Onboarding.root)
            .accessibilityElement(children: .contain)
        }
    }

    private func moveToNextStep() {
        withAnimation(CoachTheme.Motion.standard) {
            currentStep += 1
        }
    }
}

#Preview {
    OnboardingFlowView(
        isSignedIn: .constant(false),
        hasHealthPermissions: .constant(false)
    )
}
