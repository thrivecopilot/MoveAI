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
    let poseData: [PoseDetectionResult]?
    let notes: String?
    let isRecordedLive: Bool  // true for camera recordings, false for uploaded videos
    
    init(
        id: UUID = UUID(),
        movementType: MovementType,
        videoURL: URL,
        timestamp: Date = Date(),
        analysisResult: AnalysisResult? = nil,
        poseData: [PoseDetectionResult]? = nil,
        notes: String? = nil,
        isRecordedLive: Bool = false  // Default to false for backward compatibility
    ) {
        self.id = id
        self.movementType = movementType
        self.videoURL = videoURL
        self.timestamp = timestamp
        self.analysisResult = analysisResult
        self.poseData = poseData
        self.notes = notes
        self.isRecordedLive = isRecordedLive
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

// MARK: - Session Metadata (for index file)

struct SessionMetadata: Codable {
    let id: UUID
    let movementType: MovementType
    let timestamp: Date
    let videoURL: URL
    let hasAnalysis: Bool
    let score: Double?
    
    init(from session: Session) {
        self.id = session.id
        self.movementType = session.movementType
        self.timestamp = session.timestamp
        self.videoURL = session.videoURL
        self.hasAnalysis = session.hasAnalysis
        self.score = session.score
    }
}

// MARK: - Session Manager

@MainActor
class SessionManager: ObservableObject {
    @Published var sessions: [Session] = []
    
    private let userDefaults = UserDefaults.standard
    private let sessionsKey = "saved_sessions"
    private let migrationKey = "sessions_migrated_to_files"
    
    private var sessionsDirectory: URL {
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        return documentsPath.appendingPathComponent("Sessions", isDirectory: true)
    }
    
    private var sessionsIndexURL: URL {
        return sessionsDirectory.appendingPathComponent("sessions_index.json")
    }
    
    private func sessionFileURL(for sessionId: UUID) -> URL {
        return sessionsDirectory.appendingPathComponent("\(sessionId.uuidString).json")
    }
    
    init() {
        setupSessionsDirectory()
        migrateFromUserDefaultsIfNeeded()
        loadSessions()
    }
    
    func addSession(_ session: Session) {
        sessions.append(session)
        saveSession(session)
        updateSessionsIndex()
    }
    
    func updateSession(_ session: Session) {
        if let index = sessions.firstIndex(where: { $0.id == session.id }) {
            sessions[index] = session
            saveSession(session)
            updateSessionsIndex()
        }
    }
    
    func deleteSession(_ session: Session) {
        sessions.removeAll { $0.id == session.id }
        deleteSessionFile(session.id)
        updateSessionsIndex()
    }
    
    func sessionsForMovement(_ movementType: MovementType) -> [Session] {
        return sessions.filter { $0.movementType == movementType }
    }
    
    func recentSessions(limit: Int = 5) -> [Session] {
        return Array(sessions.sorted { $0.timestamp > $1.timestamp }.prefix(limit))
    }
    
    // MARK: - File System Operations
    
    private func setupSessionsDirectory() {
        let fileManager = FileManager.default
        do {
            try fileManager.createDirectory(at: sessionsDirectory, withIntermediateDirectories: true, attributes: nil)
        } catch {
            print("❌ SessionManager: Failed to create sessions directory: \(error.localizedDescription)")
        }
    }
    
    private func saveSession(_ session: Session) {
        let fileURL = sessionFileURL(for: session.id)
        do {
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            let data = try encoder.encode(session)
            try data.write(to: fileURL, options: [.atomic])
        } catch {
            print("❌ SessionManager: Failed to save session \(session.id): \(error.localizedDescription)")
        }
    }
    
    private func loadSession(from fileURL: URL) -> Session? {
        do {
            let data = try Data(contentsOf: fileURL)
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            return try decoder.decode(Session.self, from: data)
        } catch {
            print("❌ SessionManager: Failed to load session from \(fileURL.lastPathComponent): \(error.localizedDescription)")
            return nil
        }
    }
    
    private func deleteSessionFile(_ sessionId: UUID) {
        let fileURL = sessionFileURL(for: sessionId)
        let fileManager = FileManager.default
        do {
            if fileManager.fileExists(atPath: fileURL.path) {
                try fileManager.removeItem(at: fileURL)
            }
        } catch {
            print("❌ SessionManager: Failed to delete session file \(sessionId): \(error.localizedDescription)")
        }
    }
    
    private func updateSessionsIndex() {
        let metadata = sessions.map { SessionMetadata(from: $0) }
        do {
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            let data = try encoder.encode(metadata)
            try data.write(to: sessionsIndexURL, options: [.atomic])
        } catch {
            print("❌ SessionManager: Failed to update sessions index: \(error.localizedDescription)")
        }
    }
    
    private func loadSessions() {
        // First, try to load from index and then load full session data
        guard let indexData = try? Data(contentsOf: sessionsIndexURL) else {
            // No index file exists yet, try to load from individual files
            loadSessionsFromFiles()
            return
        }
        
        do {
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            let metadata = try decoder.decode([SessionMetadata].self, from: indexData)
            
            // Load full session data for each metadata entry
            var loadedSessions: [Session] = []
            for meta in metadata {
                let fileURL = sessionFileURL(for: meta.id)
                if let session = loadSession(from: fileURL) {
                    loadedSessions.append(session)
                } else {
                    print("⚠️ SessionManager: Session file missing for \(meta.id), skipping")
                }
            }
            
            sessions = loadedSessions
        } catch {
            print("❌ SessionManager: Failed to load sessions index: \(error.localizedDescription)")
            // Fallback: try loading from individual files
            loadSessionsFromFiles()
        }
    }
    
    private func loadSessionsFromFiles() {
        let fileManager = FileManager.default
        guard let files = try? fileManager.contentsOfDirectory(at: sessionsDirectory, includingPropertiesForKeys: nil) else {
            return
        }
        
        var loadedSessions: [Session] = []
        for fileURL in files {
            if fileURL.lastPathComponent == "sessions_index.json" {
                continue
            }
            if let session = loadSession(from: fileURL) {
                loadedSessions.append(session)
            }
        }
        
        sessions = loadedSessions.sorted { $0.timestamp > $1.timestamp }
        // Update index with loaded sessions
        updateSessionsIndex()
    }
    
    // MARK: - Migration
    
    private func migrateFromUserDefaultsIfNeeded() {
        // Check if migration has already been performed
        if userDefaults.bool(forKey: migrationKey) {
            return
        }
        
        // Check if there's data in UserDefaults to migrate
        guard let data = userDefaults.data(forKey: sessionsKey) else {
            // No data to migrate, mark as migrated
            userDefaults.set(true, forKey: migrationKey)
            return
        }
        
        do {
            let decoder = JSONDecoder()
            // Try to decode with iso8601 first, fallback to default if needed
            decoder.dateDecodingStrategy = .iso8601
            var oldSessions: [Session]
            do {
                oldSessions = try decoder.decode([Session].self, from: data)
            } catch {
                // Fallback: try with default date decoding strategy (for old data format)
                decoder.dateDecodingStrategy = .deferredToDate
                oldSessions = try decoder.decode([Session].self, from: data)
            }
            
            print("🔄 SessionManager: Migrating \(oldSessions.count) sessions from UserDefaults to file storage")
            
            // Save each session to file
            for session in oldSessions {
                saveSession(session)
            }
            
            // Populate sessions array and update index
            sessions = oldSessions
            updateSessionsIndex()
            
            // Remove from UserDefaults
            userDefaults.removeObject(forKey: sessionsKey)
            
            // Mark migration as complete
            userDefaults.set(true, forKey: migrationKey)
            
            print("✅ SessionManager: Migration completed successfully")
        } catch {
            print("❌ SessionManager: Failed to migrate sessions from UserDefaults: \(error.localizedDescription)")
            // Mark as migrated anyway to avoid retrying on every launch
            userDefaults.set(true, forKey: migrationKey)
        }
    }
}
