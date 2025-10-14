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
    @State private var userProfile = UserProfile()
    
    // Define onboarding steps
    private let steps = ["Welcome", "Apple Sign In", "Health Permissions", "Personal Info"]
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Progress indicator
                HStack {
                    ForEach(0..<steps.count, id: \.self) { index in
                        Rectangle()
                            .fill(index <= currentStep ? Color.accentColor : Color.gray.opacity(0.3))
                            .frame(height: 4)
                            .animation(.easeInOut(duration: 0.3), value: currentStep)
                    }
                }
                .padding(.horizontal)
                .padding(.top)
                
                // Step content with smooth transitions
                TabView(selection: $currentStep) {
                    WelcomeStepView()
                        .tag(0)
                    
                    AppleSignInStepView(
                        appleAuthManager: appleAuthManager,
                        onSignInSuccess: {
                            isSignedIn = true
                            moveToNextStep()
                        }
                    )
                    .tag(1)
                    
                    HealthPermissionStepView(
                        healthManager: healthManager,
                        onPermissionGranted: {
                            hasHealthPermissions = true
                            moveToNextStep()
                        }
                    )
                    .tag(2)
                    
                    PersonalInfoStepView(
                        userProfile: $userProfile,
                        onComplete: {
                            // Onboarding complete - ContentView will handle navigation
                            // No need to call moveToNextStep() as this is the final step
                        }
                    )
                    .tag(3)
                }
                .tabViewStyle(PageTabViewStyle(indexDisplayMode: .never))
                .animation(.easeInOut(duration: 0.5), value: currentStep)
            }
            .navigationBarHidden(true)
        }
    }
    
    private func moveToNextStep() {
        withAnimation(.easeInOut(duration: 0.5)) {
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
