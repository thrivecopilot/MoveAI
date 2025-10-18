//
//  MainTabView.swift
//  MoveAI
//
//  Created by Dave Mathew on 10/18/25.
//

import SwiftUI

struct MainTabView: View {
    @StateObject private var sessionManager = SessionManager()
    @StateObject private var cameraService = CameraService()
    
    var body: some View {
        TabView {
            // Home Tab
            MovementMasteryHomeView()
                .environmentObject(sessionManager)
                .environmentObject(cameraService)
                .tabItem {
                    Image(systemName: "house.fill")
                    Text("Home")
                }
            
            // Profile Tab
            ProfileView()
                .environmentObject(sessionManager)
                .tabItem {
                    Image(systemName: "person.fill")
                    Text("Profile")
                }
            
            // Trends Tab
            TrendsView()
                .environmentObject(sessionManager)
                .tabItem {
                    Image(systemName: "chart.line.uptrend.xyaxis")
                    Text("Trends")
                }
        }
        .accentColor(.blue)
    }
}

#Preview {
    MainTabView()
}
