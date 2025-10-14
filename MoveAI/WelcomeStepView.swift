//
//  WelcomeStepView.swift
//  MoveAI
//
//  Created by Dave Mathew on 10/11/25.
//

import SwiftUI

struct WelcomeStepView: View {
    var body: some View {
        VStack(spacing: 32) {
            Spacer()
            
            // App icon and branding
            VStack(spacing: 24) {
                Image(systemName: "dumbbell.fill")
                    .font(.system(size: 80))
                    .foregroundColor(.accentColor)
                
                VStack(spacing: 16) {
                    Text("Welcome to MoveAI")
                        .font(.largeTitle)
                        .fontWeight(.bold)
                    
                    Text("Master your movements with AI-powered form analysis")
                        .font(.title3)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                }
            }
            
            Spacer()
            
            // Feature highlights
            VStack(spacing: 16) {
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
            .padding(.horizontal)
            
            Spacer()
        }
        .padding()
    }
}

struct FeatureRow: View {
    let icon: String
    let title: String
    let description: String
    
    var body: some View {
        HStack(spacing: 16) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(.accentColor)
                .frame(width: 30)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.headline)
                Text(description)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
        }
    }
}

#Preview {
    WelcomeStepView()
}

