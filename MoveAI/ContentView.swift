//
//  ContentView.swift
//  MoveAI
//
//  Created by Dave Mathew on 10/11/25.
//

import SwiftUI
import AuthenticationServices

struct ContentView: View {
    // Track onboarding completion using @AppStorage for persistence
    @AppStorage("isSignedIn") private var isSignedIn = false
    @AppStorage("hasHealthPermissions") private var hasHealthPermissions = false

    @StateObject private var appleAuthManager = AppleAuthManager()

    var body: some View {
               Group {
                   if isSignedIn && hasHealthPermissions {
                       // User completed onboarding - show main app with tabs
                       MainTabView()
                   } else {
                       // User needs to complete onboarding
                       OnboardingFlowView(
                           isSignedIn: $isSignedIn,
                           hasHealthPermissions: $hasHealthPermissions
                       )
                   }
               }
        .environmentObject(appleAuthManager)
        .animation(.easeInOut(duration: 0.3), value: isSignedIn)
        .animation(.easeInOut(duration: 0.3), value: hasHealthPermissions)
        .task {
            // Apple requires handling credential revocation; only meaningful when
            // a real credential is stored (validateCredentialState no-ops otherwise).
            await appleAuthManager.validateCredentialState()
        }
        .onReceive(NotificationCenter.default.publisher(
            for: ASAuthorizationAppleIDProvider.credentialRevokedNotification
        )) { _ in
            appleAuthManager.signOut()
        }
        .onChange(of: appleAuthManager.isSignedIn) { signedIn in
            // Keep the onboarding gate in sync when the credential goes away
            // (revocation, sign out, account deletion).
            if !signedIn {
                isSignedIn = false
            }
        }
    }
}

#Preview {
    ContentView()
}
