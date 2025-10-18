//
//  TrendsView.swift
//  MoveAI
//
//  Created by Dave Mathew on 10/18/25.
//

import SwiftUI

struct TrendsView: View {
    @EnvironmentObject var sessionManager: SessionManager
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 24) {
                    // Header
                    VStack(spacing: 8) {
                        Image(systemName: "chart.line.uptrend.xyaxis")
                            .font(.system(size: 60))
                            .foregroundColor(.blue)
                        
                        Text("Your Progress")
                            .font(.title2)
                            .fontWeight(.semibold)
                    }
                    .padding(.top)
                    
                    // Weekly Activity Chart
                    VStack(alignment: .leading, spacing: 16) {
                        HStack {
                            Image(systemName: "calendar")
                                .foregroundColor(.blue)
                            Text("This Week's Activity")
                                .font(.headline)
                                .fontWeight(.semibold)
                        }
                        
                        WeeklyActivityChart(sessions: sessionManager.sessions)
                    }
                    .padding()
                    .background(Color(.systemGray6))
                    .cornerRadius(12)
                    
                    // Movement Breakdown
                    VStack(alignment: .leading, spacing: 16) {
                        HStack {
                            Image(systemName: "chart.pie")
                                .foregroundColor(.green)
                            Text("Movement Breakdown")
                                .font(.headline)
                                .fontWeight(.semibold)
                        }
                        
                        MovementBreakdownView(sessions: sessionManager.sessions)
                    }
                    .padding()
                    .background(Color(.systemGray6))
                    .cornerRadius(12)
                    
                    // Recent Achievements
                    VStack(alignment: .leading, spacing: 16) {
                        HStack {
                            Image(systemName: "trophy.fill")
                                .foregroundColor(.orange)
                            Text("Recent Achievements")
                                .font(.headline)
                                .fontWeight(.semibold)
                        }
                        
                        AchievementsView(sessions: sessionManager.sessions)
                    }
                    .padding()
                    .background(Color(.systemGray6))
                    .cornerRadius(12)
                    
                    // Insights
                    VStack(alignment: .leading, spacing: 16) {
                        HStack {
                            Image(systemName: "lightbulb.fill")
                                .foregroundColor(.yellow)
                            Text("Insights")
                                .font(.headline)
                                .fontWeight(.semibold)
                        }
                        
                        InsightsView(sessions: sessionManager.sessions)
                    }
                    .padding()
                    .background(Color(.systemGray6))
                    .cornerRadius(12)
                    
                    Spacer(minLength: 20)
                }
                .padding()
            }
            .navigationTitle("Trends")
            .navigationBarTitleDisplayMode(.large)
        }
    }
}

struct WeeklyActivityChart: View {
    let sessions: [Session]
    
    var body: some View {
        VStack(spacing: 12) {
            HStack(alignment: .bottom, spacing: 8) {
                ForEach(0..<7) { day in
                    VStack(spacing: 4) {
                        let daySessions = sessionsForDay(day)
                        let height = CGFloat(daySessions.count) * 8 + 4
                        
                        RoundedRectangle(cornerRadius: 4)
                            .fill(daySessions.isEmpty ? Color.gray.opacity(0.3) : Color.blue)
                            .frame(width: 30, height: max(height, 4))
                        
                        Text(dayName(day))
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                }
            }
            
            Text("Sessions per day this week")
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }
    
    private func sessionsForDay(_ dayOffset: Int) -> [Session] {
        let calendar = Calendar.current
        let today = Date()
        let targetDate = calendar.date(byAdding: .day, value: -dayOffset, to: today) ?? today
        
        return sessions.filter { session in
            calendar.isDate(session.timestamp, inSameDayAs: targetDate)
        }
    }
    
    private func dayName(_ dayOffset: Int) -> String {
        let calendar = Calendar.current
        let today = Date()
        let targetDate = calendar.date(byAdding: .day, value: -dayOffset, to: today) ?? today
        
        let formatter = DateFormatter()
        formatter.dateFormat = "E"
        return formatter.string(from: targetDate)
    }
}

struct MovementBreakdownView: View {
    let sessions: [Session]
    
    var body: some View {
        VStack(spacing: 12) {
            let movementCounts = Dictionary(grouping: sessions, by: { $0.movementType })
                .mapValues { $0.count }
                .sorted { $0.value > $1.value }
            
            ForEach(movementCounts, id: \.key) { movement, count in
                HStack {
                    Text(movement.rawValue.capitalized)
                        .font(.subheadline)
                    
                    Spacer()
                    
                    Text("\(count)")
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(.blue)
                }
            }
            
            if movementCounts.isEmpty {
                Text("No sessions recorded yet")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
        }
    }
}

struct AchievementsView: View {
    let sessions: [Session]
    
    var body: some View {
        VStack(spacing: 12) {
            AchievementRow(
                icon: "video.fill",
                title: "First Session",
                description: "Recorded your first workout",
                isUnlocked: !sessions.isEmpty
            )
            
            AchievementRow(
                icon: "calendar",
                title: "Weekly Warrior",
                description: "Complete 3 sessions this week",
                isUnlocked: sessionsThisWeek() >= 3
            )
            
            AchievementRow(
                icon: "trophy.fill",
                title: "Consistency King",
                description: "Record 10 total sessions",
                isUnlocked: sessions.count >= 10
            )
        }
    }
    
    private func sessionsThisWeek() -> Int {
        let calendar = Calendar.current
        let now = Date()
        let weekAgo = calendar.date(byAdding: .day, value: -7, to: now) ?? now
        
        return sessions.filter { session in
            session.timestamp >= weekAgo
        }.count
    }
}

struct AchievementRow: View {
    let icon: String
    let title: String
    let description: String
    let isUnlocked: Bool
    
    var body: some View {
        HStack {
            Image(systemName: icon)
                .foregroundColor(isUnlocked ? .orange : .gray)
                .frame(width: 20)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(isUnlocked ? .primary : .secondary)
                
                Text(description)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            if isUnlocked {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(.green)
            }
        }
    }
}

struct InsightsView: View {
    let sessions: [Session]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            if sessions.isEmpty {
                Text("Start recording sessions to see insights!")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            } else {
                InsightRow(
                    icon: "clock.fill",
                    text: "You've recorded \(sessions.count) session\(sessions.count == 1 ? "" : "s")"
                )
                
                if sessions.count >= 3 {
                    InsightRow(
                        icon: "chart.line.uptrend.xyaxis",
                        text: "You're building a great habit!"
                    )
                }
                
                if let mostRecent = sessions.max(by: { $0.timestamp < $1.timestamp }) {
                    let daysSince = Calendar.current.dateComponents([.day], from: mostRecent.timestamp, to: Date()).day ?? 0
                    if daysSince > 0 {
                        InsightRow(
                            icon: "calendar.badge.clock",
                            text: "Last session was \(daysSince) day\(daysSince == 1 ? "" : "s") ago"
                        )
                    }
                }
            }
        }
    }
}

struct InsightRow: View {
    let icon: String
    let text: String
    
    var body: some View {
        HStack {
            Image(systemName: icon)
                .foregroundColor(.blue)
                .frame(width: 20)
            
            Text(text)
                .font(.subheadline)
            
            Spacer()
        }
    }
}

#Preview {
    TrendsView()
        .environmentObject(SessionManager())
}
