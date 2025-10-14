//
//  ContentView.swift
//  MoveAI
//
//  Created by Dave Mathew on 10/11/25.
//

import SwiftUI

struct ContentView: View {
    // Track onboarding completion using @AppStorage for persistence
    @AppStorage("isSignedIn") private var isSignedIn = false
    @AppStorage("hasHealthPermissions") private var hasHealthPermissions = false
    
    var body: some View {
               Group {
                   if isSignedIn && hasHealthPermissions {
                       // User completed onboarding - show movement mastery home
                       MovementMasteryHomeView()
                   } else {
                       // User needs to complete onboarding
                       OnboardingFlowView(
                           isSignedIn: $isSignedIn,
                           hasHealthPermissions: $hasHealthPermissions
                       )
                   }
               }
        .animation(.easeInOut(duration: 0.3), value: isSignedIn)
        .animation(.easeInOut(duration: 0.3), value: hasHealthPermissions)
    }
}

#Preview {
    ContentView()
}