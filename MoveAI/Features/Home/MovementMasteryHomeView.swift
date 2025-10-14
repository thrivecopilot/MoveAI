//
//  MovementMasteryHomeView.swift
//  MoveAI
//
//  Created by Dave Mathew on 10/11/25.
//

import SwiftUI

struct MovementMasteryHomeView: View {
    @AppStorage("isSignedIn") private var isSignedIn = false
    @AppStorage("hasHealthPermissions") private var hasHealthPermissions = false
    @AppStorage("userHeight") private var userHeight: Double = 0
    @AppStorage("userWeight") private var userWeight: Double = 0
    @AppStorage("userAge") private var userAge: Int = 0
    
    @State private var selectedMovement: MovementType?
    @State private var showingCamera = false
    @StateObject private var sessionManager = SessionManager()
    @StateObject private var cameraService = CameraService()
    @State private var showingSessionHistory = false
    @State private var cameraView: CameraCaptureView?
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    // Welcome Header
                    welcomeHeader
                    
                    // Movement Categories
                    movementCategoriesSection
                    
                    // Quick Stats (if we have health data)
                    if userHeight > 0 || userWeight > 0 || userAge > 0 {
                        quickStatsSection
                    }
                    
                    // Recent Activity
                    recentActivitySection
                }
                .padding()
            }
            .navigationTitle("MoveAI")
            .navigationBarTitleDisplayMode(.large)
        }
        .sheet(isPresented: $showingCamera) {
            if let cameraView = cameraView {
                cameraView
            }
        }
        .onChange(of: showingCamera) { isShowing in
            print("🏠 MovementMasteryHomeView: showingCamera changed to: \(isShowing)")
            if !isShowing {
                print("🏠 MovementMasteryHomeView: Camera sheet dismissed, resetting selectedMovement")
                selectedMovement = nil
                cameraView = nil
            }
        }
    }
    
    private var welcomeHeader: some View {
        VStack(spacing: 16) {
            HStack {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Master Your Movements")
                        .font(.title2)
                        .fontWeight(.bold)
                    
                    Text("Choose a movement to analyze and improve your form")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                Image(systemName: "dumbbell.fill")
                    .font(.system(size: 40))
                    .foregroundColor(.accentColor)
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(16)
    }
    
    private var movementCategoriesSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Movement Categories")
                .font(.headline)
                .padding(.horizontal, 4)
            
            // Powerlifting Category
            MovementCategoryCard(
                title: "Powerlifting",
                description: "Master the fundamental compound movements",
                icon: "figure.strengthtraining.traditional",
                color: .blue,
                movements: [
                    MovementOption(
                        type: .squat,
                        title: "Squat",
                        description: "Lower body compound movement",
                        difficulty: .intermediate
                    ),
                    MovementOption(
                        type: .deadlift,
                        title: "Deadlift",
                        description: "Full body compound movement",
                        difficulty: .intermediate
                    ),
                    MovementOption(
                        type: .benchPress,
                        title: "Bench Press",
                        description: "Upper body compound movement",
                        difficulty: .beginner
                    )
                ],
                onMovementSelected: { movementType in
                    print("🏠 MovementMasteryHomeView: Movement selected: \(movementType.displayName)")
                    selectedMovement = movementType
                    
                    // Create camera view
                    cameraView = CameraCaptureView(
                        movementType: movementType,
                        cameraService: cameraService
                    ) { recordedMovement in
                        // Create a session from the recorded movement
                        let session = Session(
                            movementType: recordedMovement.movementType,
                            videoURL: recordedMovement.videoURL,
                            timestamp: recordedMovement.timestamp
                        )
                        
                        // Add to session manager
                        sessionManager.addSession(session)
                    }
                    
                    showingCamera = true
                }
            )
            
            // Coming Soon Categories
            VStack(spacing: 12) {
                ComingSoonCategoryCard(
                    title: "Olympic Lifting",
                    description: "Snatch, Clean & Jerk",
                    icon: "figure.strengthtraining.traditional",
                    color: .orange
                )
                
                ComingSoonCategoryCard(
                    title: "Bodyweight",
                    description: "Push-ups, Pull-ups, Dips",
                    icon: "figure.strengthtraining.traditional",
                    color: .green
                )
            }
        }
    }
    
    private var quickStatsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Your Profile")
                .font(.headline)
                .padding(.horizontal, 4)
            
            HStack(spacing: 16) {
                if userHeight > 0 {
                    StatCard(
                        icon: "ruler",
                        title: "Height",
                        value: formatHeight(userHeight),
                        color: .blue
                    )
                }
                
                if userWeight > 0 {
                    StatCard(
                        icon: "scalemass",
                        title: "Weight",
                        value: formatWeight(userWeight),
                        color: .green
                    )
                }
                
                if userAge > 0 {
                    StatCard(
                        icon: "calendar",
                        title: "Age",
                        value: "\(userAge) years",
                        color: .orange
                    )
                }
            }
        }
    }
    
    private var recentActivitySection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Recent Sessions")
                    .font(.headline)
                    .padding(.horizontal, 4)
                
                Spacer()
                
                NavigationLink(destination: SessionHistoryView(sessionManager: sessionManager)) {
                    Text("View All")
                        .font(.subheadline)
                        .foregroundColor(.accentColor)
                }
            }
            
            if sessionManager.sessions.isEmpty {
                EmptyStateCard(
                    icon: "video.fill",
                    title: "No sessions yet",
                    description: "Start by recording your first movement to see your progress here"
                )
            } else {
                VStack(spacing: 8) {
                    ForEach(sessionManager.recentSessions(limit: 3)) { session in
                        RecentSessionCard(session: session)
                    }
                }
            }
        }
    }
    
    private func formatHeight(_ heightInCm: Double) -> String {
        let totalInches = heightInCm / 2.54
        let feet = Int(totalInches / 12)
        let inches = Int(totalInches.truncatingRemainder(dividingBy: 12))
        return "\(feet)'\(inches)\""
    }
    
    private func formatWeight(_ weightInKg: Double) -> String {
        let pounds = weightInKg * 2.20462
        return "\(Int(pounds)) lbs"
    }
}

struct MovementCategoryCard: View {
    let title: String
    let description: String
    let icon: String
    let color: Color
    let movements: [MovementOption]
    let onMovementSelected: (MovementType) -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Category Header
            HStack {
                Image(systemName: icon)
                    .font(.title2)
                    .foregroundColor(color)
                    .frame(width: 30)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.headline)
                        .fontWeight(.semibold)
                    
                    Text(description)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
            }
            
            // Movement Options
            VStack(spacing: 8) {
                ForEach(movements, id: \.type) { movement in
                    MovementOptionRow(
                        movement: movement,
                        onTap: {
                            onMovementSelected(movement.type)
                        }
                    )
                }
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(16)
    }
}

struct MovementOption {
    let type: MovementType
    let title: String
    let description: String
    let difficulty: DifficultyLevel
}


struct MovementOptionRow: View {
    let movement: MovementOption
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 12) {
                Image(systemName: movement.type.icon)
                    .font(.title3)
                    .foregroundColor(.accentColor)
                    .frame(width: 24)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(movement.title)
                        .font(.subheadline)
                        .fontWeight(.medium)
                    
                    Text(movement.description)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                // Difficulty Badge
                Text(movement.difficulty.rawValue)
                    .font(.caption2)
                    .fontWeight(.medium)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color(movement.difficulty.color).opacity(0.2))
                    .foregroundColor(Color(movement.difficulty.color))
                    .cornerRadius(6)
                
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding(.vertical, 8)
            .padding(.horizontal, 12)
            .background(Color(.systemBackground))
            .cornerRadius(12)
        }
        .buttonStyle(.plain)
    }
}

struct ComingSoonCategoryCard: View {
    let title: String
    let description: String
    let icon: String
    let color: Color
    
    var body: some View {
        HStack {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(color.opacity(0.6))
                .frame(width: 30)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.headline)
                    .fontWeight(.semibold)
                    .foregroundColor(.secondary)
                
                Text(description)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            Text("Coming Soon")
                .font(.caption2)
                .fontWeight(.medium)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Color.gray.opacity(0.2))
                .foregroundColor(.secondary)
                .cornerRadius(6)
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(16)
        .opacity(0.7)
    }
}

struct StatCard: View {
    let icon: String
    let title: String
    let value: String
    let color: Color
    
    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundColor(color)
            
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
            
            Text(value)
                .font(.subheadline)
                .fontWeight(.semibold)
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
}

struct EmptyStateCard: View {
    let icon: String
    let title: String
    let description: String
    
    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 40))
                .foregroundColor(.secondary)
            
            Text(title)
                .font(.headline)
                .foregroundColor(.secondary)
            
            Text(description)
                .font(.caption)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(16)
    }
}

struct RecentSessionCard: View {
    let session: Session
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: session.movementType.icon)
                .font(.title3)
                .foregroundColor(.accentColor)
                .frame(width: 24)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(session.displayName)
                    .font(.subheadline)
                    .fontWeight(.medium)
                
                Text(session.formattedDate)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            if let score = session.score {
                Text("\(Int(score))")
                    .font(.headline)
                    .fontWeight(.bold)
                    .foregroundColor(scoreColor(Int(score)))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color(.systemGray6))
                    .cornerRadius(6)
            } else {
                Image(systemName: "clock")
                    .font(.caption)
                    .foregroundColor(.orange)
            }
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 12)
        .background(Color(.systemBackground))
        .cornerRadius(12)
    }
    
    private func scoreColor(_ score: Int) -> Color {
        if score >= 80 {
            return .green
        } else if score >= 60 {
            return .orange
        } else {
            return .red
        }
    }
}

#Preview {
    MovementMasteryHomeView()
}
