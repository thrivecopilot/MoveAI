//
//  Session.swift
//  MoveAI
//
//  Created by Dave Mathew on 10/11/25.
//

import Foundation

struct Session: Identifiable, Codable {
    let id: UUID
    let movementType: MovementType
    let videoURL: URL
    let timestamp: Date
    let analysisResult: AnalysisResult?
    let notes: String?
    
    init(
        id: UUID = UUID(),
        movementType: MovementType,
        videoURL: URL,
        timestamp: Date = Date(),
        analysisResult: AnalysisResult? = nil,
        notes: String? = nil
    ) {
        self.id = id
        self.movementType = movementType
        self.videoURL = videoURL
        self.timestamp = timestamp
        self.analysisResult = analysisResult
        self.notes = notes
    }
    
    var displayName: String {
        return movementType.displayName
    }
    
    var formattedDate: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: timestamp)
    }
    
    var score: Double? {
        return analysisResult?.score
    }
    
    var hasAnalysis: Bool {
        return analysisResult != nil
    }
}

// MARK: - Session Manager

@MainActor
class SessionManager: ObservableObject {
    @Published var sessions: [Session] = []
    
    private let userDefaults = UserDefaults.standard
    private let sessionsKey = "saved_sessions"
    
    init() {
        loadSessions()
    }
    
    func addSession(_ session: Session) {
        sessions.append(session)
        saveSessions()
    }
    
    func updateSession(_ session: Session) {
        if let index = sessions.firstIndex(where: { $0.id == session.id }) {
            sessions[index] = session
            saveSessions()
        }
    }
    
    func deleteSession(_ session: Session) {
        sessions.removeAll { $0.id == session.id }
        saveSessions()
    }
    
    func sessionsForMovement(_ movementType: MovementType) -> [Session] {
        return sessions.filter { $0.movementType == movementType }
    }
    
    func recentSessions(limit: Int = 5) -> [Session] {
        return Array(sessions.sorted { $0.timestamp > $1.timestamp }.prefix(limit))
    }
    
    private func saveSessions() {
        do {
            let data = try JSONEncoder().encode(sessions)
            userDefaults.set(data, forKey: sessionsKey)
        } catch {
            print("Failed to save sessions: \(error)")
        }
    }
    
    private func loadSessions() {
        guard let data = userDefaults.data(forKey: sessionsKey) else { return }
        
        do {
            sessions = try JSONDecoder().decode([Session].self, from: data)
        } catch {
            print("Failed to load sessions: \(error)")
        }
    }
}
