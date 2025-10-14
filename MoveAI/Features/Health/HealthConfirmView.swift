//
//  HealthConfirmView.swift
//  MoveAI
//
//  Created by Dave Mathew on 10/11/25.
//

import SwiftUI

struct HealthConfirmView: View {
    let profile: HealthProfile
    let onAction: (HealthAction) -> Void
    
    var body: some View {
        VStack(spacing: 32) {
            Spacer()
            
            VStack(spacing: 24) {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 60))
                    .foregroundColor(.green)
                
                VStack(spacing: 16) {
                    Text("Health Data Retrieved")
                        .font(.title2)
                        .fontWeight(.semibold)
                    
                    Text("Please confirm your information below")
                        .font(.body)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
            }
            
            Spacer()
            
            VStack(spacing: 20) {
                HealthDataRow(
                    icon: "ruler",
                    title: "Height",
                    value: profile.displayHeight
                )
                
                HealthDataRow(
                    icon: "scalemass",
                    title: "Weight",
                    value: profile.displayWeight
                )
                
                HealthDataRow(
                    icon: "calendar",
                    title: "Age",
                    value: profile.displayAge
                )
            }
            .padding()
            .background(Color(.systemGray6))
            .cornerRadius(12)
            .padding(.horizontal)
            
            Spacer()
            
            Button(action: {
                onAction(.healthProfileConfirmed)
            }) {
                Text("Confirm & Continue")
                    .font(.headline)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 50)
                    .background(Color.accentColor)
                    .cornerRadius(8)
            }
            .padding(.horizontal)
            
            Spacer()
        }
        .padding()
    }
}

struct HealthDataRow: View {
    let icon: String
    let title: String
    let value: String
    
    var body: some View {
        HStack {
            Image(systemName: icon)
                .foregroundColor(.blue)
                .frame(width: 24)
            
            Text(title)
                .font(.headline)
            
            Spacer()
            
            Text(value)
                .font(.body)
                .foregroundColor(.secondary)
        }
    }
}

#Preview {
    HealthConfirmView(
        profile: HealthProfile.demo,
        onAction: { _ in }
    )
}

