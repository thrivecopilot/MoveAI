//
//  HomeView.swift
//  MoveAI
//
//  Created by Dave Mathew on 10/11/25.
//

import SwiftUI

struct HomeView: View {
    @AppStorage("isSignedIn") private var isSignedIn = false
    @AppStorage("hasHealthPermissions") private var hasHealthPermissions = false
    @AppStorage("userHeight") private var userHeight: Double = 0
    @AppStorage("userWeight") private var userWeight: Double = 0
    @AppStorage("userAge") private var userAge: Int = 0
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 32) {
                Spacer()
                
                // Success confirmation
                VStack(spacing: 24) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 80))
                        .foregroundColor(.green)
                    
                    VStack(spacing: 16) {
                        Text("Welcome to MoveAI!")
                            .font(.largeTitle)
                            .fontWeight(.bold)
                        
                        Text("You're all set up and ready to start improving your movement technique")
                            .font(.body)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                    }
                }
                
                Spacer()
                
                // User profile summary
                if userHeight > 0 && userWeight > 0 && userAge > 0 {
                    VStack(spacing: 16) {
                        Text("Your Profile")
                            .font(.headline)
                        
                        VStack(spacing: 8) {
                            ProfileRow(
                                icon: "ruler",
                                title: "Height",
                                value: formatHeight(userHeight)
                            )
                            
                            ProfileRow(
                                icon: "scalemass",
                                title: "Weight",
                                value: formatWeight(userWeight)
                            )
                            
                            ProfileRow(
                                icon: "calendar",
                                title: "Age",
                                value: "\(userAge) years"
                            )
                        }
                        .padding()
                        .background(Color(.systemGray6))
                        .cornerRadius(12)
                    }
                    .padding(.horizontal)
                }
                
                // Status indicators
                VStack(spacing: 16) {
                    StatusRow(
                        icon: "applelogo",
                        title: "Apple ID",
                        isConnected: isSignedIn,
                        color: .primary
                    )
                    
                    StatusRow(
                        icon: "heart.fill",
                        title: "Apple Health",
                        isConnected: hasHealthPermissions,
                        color: .red
                    )
                }
                .padding(.horizontal)
                
                Spacer()
                
                       // Next steps placeholder
                       VStack(spacing: 16) {
                           Text("Ready to Start")
                               .font(.headline)

                           Text("Record your movements and get AI-powered form analysis")
                               .font(.caption)
                               .foregroundColor(.secondary)
                               .multilineTextAlignment(.center)
                           
                           NavigationLink(destination: MovementSelectionView()) {
                               Text("Record Movement")
                                   .font(.headline)
                                   .foregroundColor(.white)
                                   .frame(maxWidth: .infinity)
                                   .frame(height: 50)
                                   .background(Color.accentColor)
                                   .cornerRadius(8)
                           }
                       }
                       .padding()
                       .background(Color(.systemGray6))
                       .cornerRadius(12)
                       .padding(.horizontal)
                
                Spacer()
            }
            .padding()
            .navigationTitle("MoveAI")
            .navigationBarTitleDisplayMode(.large)
        }
    }
    
    private func formatHeight(_ heightInCm: Double) -> String {
        let totalInches = heightInCm / 2.54
        let feet = Int(totalInches / 12)
        let inches = Int(totalInches.truncatingRemainder(dividingBy: 12))
        return "\(feet)'\(inches)\" (\(Int(heightInCm)) cm)"
    }
    
    private func formatWeight(_ weightInKg: Double) -> String {
        let pounds = weightInKg * 2.20462
        return "\(Int(pounds)) lbs (\(Int(weightInKg)) kg)"
    }
}

struct ProfileRow: View {
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

struct StatusRow: View {
    let icon: String
    let title: String
    let isConnected: Bool
    let color: Color
    
    var body: some View {
        HStack {
            Image(systemName: icon)
                .foregroundColor(color)
                .frame(width: 24)
            
            Text(title)
                .font(.headline)
            
            Spacer()
            
            Image(systemName: isConnected ? "checkmark.circle.fill" : "xmark.circle.fill")
                .foregroundColor(isConnected ? .green : .red)
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(8)
    }
}

#Preview {
    HomeView()
}
