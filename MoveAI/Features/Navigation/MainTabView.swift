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

    var accessibilityLabel: String {
        rawValue.capitalized
    }
}

struct MainTabView: View {

    @StateObject private var sessionManager = SessionManager()
    @StateObject private var cameraService = CameraService()
    @State private var selectedTab: MainTab = .home
    @StateObject private var tabBarVisibility = TabBarVisibility()

    var body: some View {
        TabView(selection: $selectedTab) {
            MovementMasteryHomeView()
                .environmentObject(sessionManager)
                .environmentObject(cameraService)
                .environmentObject(tabBarVisibility)
                .tag(MainTab.home)

            ProfileView()
                .environmentObject(sessionManager)
                .environmentObject(tabBarVisibility)
                .tag(MainTab.profile)

            TrendsView()
                .environmentObject(sessionManager)
                .environmentObject(tabBarVisibility)
                .tag(MainTab.trends)
        }
        .toolbar(.hidden, for: .tabBar)
        .safeAreaInset(edge: .bottom, spacing: 0) {
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
    @Environment(\.colorScheme) private var colorScheme
    @Binding var selectedTab: MainTab

    private let activeColor = Color.white
    private let inactiveColor = Color.white.opacity(0.48)

    var body: some View {
        VStack(spacing: 0) {
            Rectangle()
                .fill(CoachTheme.Palette.stroke(for: colorScheme))
                .frame(height: 1)

            HStack(spacing: 0) {
                ForEach(MainTab.allCases, id: \.self) { tab in
                    Button(action: {
                        withAnimation(CoachTheme.Motion.quick) {
                            selectedTab = tab
                        }
                    }) {
                        VStack(spacing: 6) {
                            Circle()
                                .fill(CoachTheme.Palette.accent)
                                .frame(width: 7, height: 7)
                                .opacity(selectedTab == tab ? 1 : 0)
                                .accessibilityHidden(true)

                            Image(systemName: tab.iconName)
                                .font(.system(size: 22, weight: .semibold))
                                .foregroundColor(selectedTab == tab ? activeColor : inactiveColor)
                                .frame(maxWidth: .infinity)
                                .accessibilityLabel(tab.accessibilityLabel)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.top, 6)
                        .padding(.bottom, 8)
                    }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier("\(AccessibilityID.MainTabBar.button).\(tab.rawValue)")
                    .accessibilityLabel(tab.accessibilityLabel)
                }
            }
            .padding(.horizontal, 12)
            .background(
                CoachTheme.Palette.chromeBackground(for: colorScheme)
                    .overlay(
                        LinearGradient(
                            colors: [
                                Color.black.opacity(colorScheme == .dark ? 0.20 : 0.06),
                                Color.clear,
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
            )
        }
        .background(CoachTheme.Palette.chromeBackground(for: colorScheme))
        .accessibilityIdentifier(AccessibilityID.MainTabBar.root)
        .accessibilityElement(children: .contain)
    }
}

#Preview {
    MainTabView()
}
