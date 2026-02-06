//
//  MainTabView.swift
//  MoveAI
//
//  Created by Dave Mathew on 10/18/25.
//

import SwiftUI

fileprivate enum MainTab: String, CaseIterable {
    case home
    case profile
    case trends
    
    var iconName: String {
        switch self {
        case .home: return "house.fill"
        case .profile: return "person.fill"
        case .trends: return "chart.line.uptrend.xyaxis"
        }
    }
}

struct MainTabView: View {
    
    @StateObject private var sessionManager = SessionManager()
    @StateObject private var cameraService = CameraService()
    @State private var selectedTab: MainTab = .home
    @StateObject private var tabBarVisibility = TabBarVisibility()
    
    var body: some View {
        TabView(selection: $selectedTab) {
            // Home Tab
            MovementMasteryHomeView()
                .environmentObject(sessionManager)
                .environmentObject(cameraService)
                .environmentObject(tabBarVisibility)
                .tag(MainTab.home)
            
            // Profile Tab
            ProfileView()
                .environmentObject(sessionManager)
                .environmentObject(tabBarVisibility)
                .tag(MainTab.profile)
            
            // Trends Tab
            TrendsView()
                .environmentObject(sessionManager)
                .environmentObject(tabBarVisibility)
                .tag(MainTab.trends)
        }
        .toolbar(.hidden, for: .tabBar)
        .safeAreaInset(edge: .bottom) {
            if !tabBarVisibility.isHidden {
                CustomTabBar(selectedTab: $selectedTab)
            }
        }
    }
}

final class TabBarVisibility: ObservableObject {
    @Published var isHidden: Bool = false
}

private struct CustomTabBar: View {
    @Binding var selectedTab: MainTab
    
    private let barBackground = Color.black
    private let activeColor = Color.white
    private let inactiveColor = Color.white.opacity(0.45)
    private let indicatorColor = Color(red: 0.24, green: 0.86, blue: 1.0)
    
    var body: some View {
        HStack(spacing: 0) {
            ForEach(MainTab.allCases, id: \.self) { tab in
                Button(action: { selectedTab = tab }) {
                    VStack(spacing: 6) {
                        Circle()
                            .fill(indicatorColor)
                            .frame(width: 6, height: 6)
                            .opacity(selectedTab == tab ? 1 : 0)
                        
                        Image(systemName: tab.iconName)
                            .font(.system(size: 22, weight: .semibold))
                            .foregroundColor(selectedTab == tab ? activeColor : inactiveColor)
                            .frame(maxWidth: .infinity)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.top, 6)
                    .padding(.bottom, 8)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 12)
        .background(barBackground)
        .overlay(
            Rectangle()
                .fill(Color.white.opacity(0.08))
                .frame(height: 1),
            alignment: .top
        )
    }
}

#Preview {
    MainTabView()
}
