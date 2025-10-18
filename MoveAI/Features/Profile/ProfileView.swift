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
                VStack(spacing: 24) {
                    // Header
                    VStack(spacing: 8) {
                        Image(systemName: "person.circle.fill")
                            .font(.system(size: 80))
                            .foregroundColor(.blue)
                        
                        Text("Your Profile")
                            .font(.title2)
                            .fontWeight(.semibold)
                    }
                    .padding(.top)
                    
                    // Health Information Card
                    VStack(alignment: .leading, spacing: 16) {
                        HStack {
                            Image(systemName: "heart.fill")
                                .foregroundColor(.red)
                            Text("Health Information")
                                .font(.headline)
                                .fontWeight(.semibold)
                        }
                        
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
                    .padding()
                    .background(Color(.systemGray6))
                    .cornerRadius(12)
                    
                    // Quick Stats Card
                    VStack(alignment: .leading, spacing: 16) {
                        HStack {
                            Image(systemName: "chart.bar.fill")
                                .foregroundColor(.green)
                            Text("Quick Stats")
                                .font(.headline)
                                .fontWeight(.semibold)
                        }
                        
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
                    .padding()
                    .background(Color(.systemGray6))
                    .cornerRadius(12)
                    
                    // Settings Section
                    VStack(alignment: .leading, spacing: 16) {
                        HStack {
                            Image(systemName: "gearshape.fill")
                                .foregroundColor(.gray)
                            Text("Settings")
                                .font(.headline)
                                .fontWeight(.semibold)
                        }
                        
                        VStack(spacing: 0) {
                            SettingsRow(
                                icon: "pencil",
                                title: "Edit Profile",
                                action: { /* TODO: Edit profile */ }
                            )
                            
                            Divider()
                            
                            SettingsRow(
                                icon: "bell",
                                title: "Notifications",
                                action: { /* TODO: Notifications */ }
                            )
                            
                            Divider()
                            
                            SettingsRow(
                                icon: "questionmark.circle",
                                title: "Help & Support",
                                action: { /* TODO: Help */ }
                            )
                        }
                    }
                    .padding()
                    .background(Color(.systemGray6))
                    .cornerRadius(12)
                    
                    Spacer(minLength: 20)
                }
                .padding()
            }
            .navigationTitle("Profile")
            .navigationBarTitleDisplayMode(.large)
        }
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
                .foregroundColor(.blue)
                .frame(width: 20)
            
            Text(title)
                .font(.subheadline)
                .foregroundColor(.secondary)
            
            Spacer()
            
            Text(value)
                .font(.subheadline)
                .fontWeight(.medium)
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
                    .foregroundColor(.blue)
                    .frame(width: 20)
                
                Text(title)
                    .font(.subheadline)
                    .foregroundColor(.primary)
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding(.vertical, 8)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

#Preview {
    ProfileView()
        .environmentObject(SessionManager())
}
