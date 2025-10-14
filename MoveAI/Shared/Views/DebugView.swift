//
//  DebugView.swift
//  MoveAI
//
//  Created by Dave Mathew on 10/11/25.
//

import SwiftUI

struct DebugView: View {
    @StateObject private var debugManager = DebugManager.shared
    @State private var selectedTab = 0
    
    var body: some View {
        NavigationView {
            VStack {
                Picker("Debug Tab", selection: $selectedTab) {
                    Text("Logs").tag(0)
                    Text("Performance").tag(1)
                    Text("State").tag(2)
                }
                .pickerStyle(SegmentedPickerStyle())
                .padding()
                
                TabView(selection: $selectedTab) {
                    LogsView()
                        .tag(0)
                    
                    PerformanceView()
                        .tag(1)
                    
                    StateView()
                        .tag(2)
                }
                .tabViewStyle(PageTabViewStyle(indexDisplayMode: .never))
            }
            .navigationTitle("Debug Console")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItemGroup(placement: .navigationBarTrailing) {
                    Button("Clear") {
                        if selectedTab == 0 {
                            debugManager.clearLogs()
                        } else if selectedTab == 1 {
                            debugManager.clearPerformanceMetrics()
                        }
                    }
                    
                    Button("Export") {
                        exportLogs()
                    }
                }
            }
        }
        .debugOnAppear("DebugView")
    }
    
    private func exportLogs() {
        let logs = debugManager.exportLogs()
        let activityVC = UIActivityViewController(activityItems: [logs], applicationActivities: nil)
        
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let window = windowScene.windows.first {
            window.rootViewController?.present(activityVC, animated: true)
        }
    }
}

struct LogsView: View {
    @StateObject private var debugManager = DebugManager.shared
    @State private var selectedLevel: LogLevel? = nil
    
    var filteredLogs: [LogEntry] {
        if let level = selectedLevel {
            return debugManager.logEntries.filter { $0.level == level }
        }
        return debugManager.logEntries
    }
    
    var body: some View {
        VStack {
            // Filter controls
            ScrollView(.horizontal, showsIndicators: false) {
                HStack {
                    Button("All") {
                        selectedLevel = nil
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(selectedLevel == nil ? Color.blue : Color.gray.opacity(0.2))
                    .foregroundColor(selectedLevel == nil ? .white : .primary)
                    .cornerRadius(8)
                    
                    ForEach(LogLevel.allCases, id: \.self) { level in
                        Button(level.rawValue.capitalized) {
                            selectedLevel = level
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(selectedLevel == level ? level.color : Color.gray.opacity(0.2))
                        .foregroundColor(selectedLevel == level ? .white : .primary)
                        .cornerRadius(8)
                    }
                }
                .padding(.horizontal)
            }
            
            // Logs list
            List(filteredLogs.reversed()) { entry in
                LogEntryView(entry: entry)
            }
            .listStyle(PlainListStyle())
        }
        .debugOnAppear("LogsView")
    }
}

struct LogEntryView: View {
    let entry: LogEntry
    
    private var timeFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss"
        return formatter
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(timeFormatter.string(from: entry.timestamp))
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Spacer()
                
                Text(entry.category)
                    .font(.caption)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Color.gray.opacity(0.2))
                    .cornerRadius(4)
            }
            
            Text(entry.message)
                .font(.system(.body, design: .monospaced))
                .foregroundColor(entry.level.color)
        }
        .padding(.vertical, 2)
    }
}

struct PerformanceView: View {
    @StateObject private var debugManager = DebugManager.shared
    
    var body: some View {
        List(debugManager.performanceMetrics.reversed()) { metric in
            PerformanceMetricView(metric: metric)
        }
        .listStyle(PlainListStyle())
        .debugOnAppear("PerformanceView")
    }
}

struct PerformanceMetricView: View {
    let metric: PerformanceMetric
    
    private var timeFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss"
        return formatter
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(metric.operation)
                    .font(.headline)
                
                Spacer()
                
                Text(String(format: "%.3fs", metric.duration))
                    .font(.caption)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(durationColor.opacity(0.2))
                    .foregroundColor(durationColor)
                    .cornerRadius(4)
            }
            
            HStack {
                Text(timeFormatter.string(from: metric.timestamp))
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Spacer()
                
                Text(metric.category)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding(.vertical, 2)
    }
    
    private var durationColor: Color {
        if metric.duration > 1.0 {
            return .red
        } else if metric.duration > 0.5 {
            return .orange
        } else if metric.duration > 0.1 {
            return .yellow
        } else {
            return .green
        }
    }
}

struct StateView: View {
    @EnvironmentObject var appState: AppStateManager
    @EnvironmentObject var movementManager: MovementManager
    
    var body: some View {
        List {
            Section("App State") {
                StateRow(label: "Onboarding Completed", value: appState.isOnboardingCompleted ? "Yes" : "No")
                StateRow(label: "Current Tab", value: appState.selectedTab.rawValue)
                StateRow(label: "Is Premium", value: appState.isPremiumUser ? "Yes" : "No")
                StateRow(label: "Show Ads", value: appState.showAds ? "Yes" : "No")
            }
            
            Section("Movement Manager") {
                StateRow(label: "Movements Count", value: "\(movementManager.movements.count)")
                StateRow(label: "User Goals Count", value: "\(movementManager.userGoals.count)")
                StateRow(label: "Is Loading", value: movementManager.isLoading ? "Yes" : "No")
            }
            
            Section("User Profile") {
                if let user = appState.currentUser {
                    StateRow(label: "User ID", value: user.id.uuidString.prefix(8) + "...")
                    StateRow(label: "Height", value: "\(user.height) cm")
                    StateRow(label: "Weight", value: "\(user.weight) kg")
                    StateRow(label: "Age", value: "\(user.age)")
                    StateRow(label: "Experience", value: user.experienceLevel.rawValue)
                } else {
                    StateRow(label: "User Profile", value: "Not Set")
                }
            }
        }
        .debugOnAppear("StateView")
    }
}

struct StateRow: View {
    let label: String
    let value: String
    
    var body: some View {
        HStack {
            Text(label)
                .foregroundColor(.primary)
            
            Spacer()
            
            Text(value)
                .foregroundColor(.secondary)
                .font(.system(.body, design: .monospaced))
        }
    }
}

#Preview {
    DebugView()
        .environmentObject(AppStateManager())
        .environmentObject(MovementManager())
}

