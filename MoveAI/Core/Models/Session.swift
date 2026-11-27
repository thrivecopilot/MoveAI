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
    let technique: MuayThaiTechnique?
    let fightStance: FightStance?
    let videoURL: URL
    let timestamp: Date
    let analysisResult: AnalysisResult?
    let poseData: [PoseDetectionResult]?
    let notes: String?
    let isRecordedLive: Bool  // true for camera recordings, false for uploaded videos
    
    init(
        id: UUID = UUID(),
        movementType: MovementType,
        technique: MuayThaiTechnique? = nil,
        fightStance: FightStance? = nil,
        videoURL: URL,
        timestamp: Date = Date(),
        analysisResult: AnalysisResult? = nil,
        poseData: [PoseDetectionResult]? = nil,
        notes: String? = nil,
        isRecordedLive: Bool = false  // Default to false for backward compatibility
    ) {
        self.id = id
        self.movementType = movementType
        self.technique = technique
        self.fightStance = fightStance
        self.videoURL = videoURL
        self.timestamp = timestamp
        self.analysisResult = analysisResult
        self.poseData = poseData
        self.notes = notes
        self.isRecordedLive = isRecordedLive
    }
    
    var displayName: String {
        if movementType == .muayThai {
            if let technique {
                return "\(movementType.displayName) - \(technique.displayName)"
            }

            if let detected = analysisResult?.detectedTechnique {
                return "\(movementType.displayName) - \(detected.displayName)"
            }
        }
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

// MARK: - Codable (video path portability)
//
// The app container path changes on every app update and device restore, so
// sessions must not persist absolute video URLs. Videos the app owns are
// stored by file name and resolved against the current container on decode.
// Non-owned URLs (bundle fixtures, previews) are stored as-is.
extension Session {
    private enum CodingKeys: String, CodingKey {
        case id, movementType, technique, fightStance, timestamp
        case analysisResult, poseData, notes, isRecordedLive
        case videoFileName
        case videoURL // legacy: absolute URL written by older builds
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.id = try container.decode(UUID.self, forKey: .id)
        self.movementType = try container.decode(MovementType.self, forKey: .movementType)
        self.technique = try container.decodeIfPresent(MuayThaiTechnique.self, forKey: .technique)
        self.fightStance = try container.decodeIfPresent(FightStance.self, forKey: .fightStance)
        self.timestamp = try container.decode(Date.self, forKey: .timestamp)
        self.analysisResult = try container.decodeIfPresent(AnalysisResult.self, forKey: .analysisResult)
        self.poseData = try container.decodeIfPresent([PoseDetectionResult].self, forKey: .poseData)
        self.notes = try container.decodeIfPresent(String.self, forKey: .notes)
        self.isRecordedLive = try container.decodeIfPresent(Bool.self, forKey: .isRecordedLive) ?? false
        self.videoURL = try Self.decodeVideoURL(from: container)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(movementType, forKey: .movementType)
        try container.encodeIfPresent(technique, forKey: .technique)
        try container.encodeIfPresent(fightStance, forKey: .fightStance)
        try container.encode(timestamp, forKey: .timestamp)
        try container.encodeIfPresent(analysisResult, forKey: .analysisResult)
        try container.encodeIfPresent(poseData, forKey: .poseData)
        try container.encodeIfPresent(notes, forKey: .notes)
        try container.encode(isRecordedLive, forKey: .isRecordedLive)
        if VideoStorage.isOwned(videoURL) {
            try container.encode(videoURL.lastPathComponent, forKey: .videoFileName)
        } else {
            try container.encode(videoURL, forKey: .videoURL)
        }
    }

    private static func decodeVideoURL(from container: KeyedDecodingContainer<CodingKeys>) throws -> URL {
        if let fileName = try container.decodeIfPresent(String.self, forKey: .videoFileName) {
            return VideoStorage.videoURL(forFileName: fileName)
        }
        let legacyURL = try container.decode(URL.self, forKey: .videoURL)
        return VideoStorage.resolveStoredURL(legacyURL)
    }
}

// MARK: - Session Metadata (for index file)

struct SessionMetadata: Codable {
    let id: UUID
    let movementType: MovementType
    let technique: MuayThaiTechnique?
    let fightStance: FightStance?
    let timestamp: Date
    let videoURL: URL
    let hasAnalysis: Bool
    let score: Double?

    init(from session: Session) {
        self.id = session.id
        self.movementType = session.movementType
        self.technique = session.technique
        self.fightStance = session.fightStance
        self.timestamp = session.timestamp
        self.videoURL = session.videoURL
        self.hasAnalysis = session.hasAnalysis
        self.score = session.score
    }

    // Same video-path portability rules as Session (see extension below).
    private enum CodingKeys: String, CodingKey {
        case id, movementType, technique, fightStance, timestamp, hasAnalysis, score
        case videoFileName
        case videoURL // legacy: absolute URL written by older builds
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.id = try container.decode(UUID.self, forKey: .id)
        self.movementType = try container.decode(MovementType.self, forKey: .movementType)
        self.technique = try container.decodeIfPresent(MuayThaiTechnique.self, forKey: .technique)
        self.fightStance = try container.decodeIfPresent(FightStance.self, forKey: .fightStance)
        self.timestamp = try container.decode(Date.self, forKey: .timestamp)
        self.hasAnalysis = try container.decode(Bool.self, forKey: .hasAnalysis)
        self.score = try container.decodeIfPresent(Double.self, forKey: .score)
        if let fileName = try container.decodeIfPresent(String.self, forKey: .videoFileName) {
            self.videoURL = VideoStorage.videoURL(forFileName: fileName)
        } else {
            self.videoURL = VideoStorage.resolveStoredURL(try container.decode(URL.self, forKey: .videoURL))
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(movementType, forKey: .movementType)
        try container.encodeIfPresent(technique, forKey: .technique)
        try container.encodeIfPresent(fightStance, forKey: .fightStance)
        try container.encode(timestamp, forKey: .timestamp)
        try container.encode(hasAnalysis, forKey: .hasAnalysis)
        try container.encodeIfPresent(score, forKey: .score)
        if VideoStorage.isOwned(videoURL) {
            try container.encode(videoURL.lastPathComponent, forKey: .videoFileName)
        } else {
            try container.encode(videoURL, forKey: .videoURL)
        }
    }
}

// MARK: - Session Manager

@MainActor
class SessionManager: ObservableObject {
    @Published var sessions: [Session] = []
    /// User-visible description of the most recent storage failure. Saves and
    /// deletes previously failed silently; the sessions UI presents this.
    @Published var lastStorageError: String?

    private let userDefaults = UserDefaults.standard
    private let sessionsKey = "saved_sessions"
    private let migrationKey = "sessions_migrated_to_files"

    /// Pose sidecars hydrated on demand, keyed by session id. Intentionally not
    /// @Published: hydration happens during view body evaluation.
    private var poseDataCache: [UUID: [PoseDetectionResult]] = [:]

    private var sessionsDirectory: URL {
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        return documentsPath.appendingPathComponent("Sessions", isDirectory: true)
    }

    /// Pose data sidecars. Kept out of session files so launch stays fast, and
    /// excluded from backup because poses are regenerable from the video.
    private var posesDirectory: URL {
        sessionsDirectory.appendingPathComponent("Poses", isDirectory: true)
    }

    private var sessionsIndexURL: URL {
        return sessionsDirectory.appendingPathComponent("sessions_index.json")
    }

    private func sessionFileURL(for sessionId: UUID) -> URL {
        return sessionsDirectory.appendingPathComponent("\(sessionId.uuidString).json")
    }

    private func poseFileURL(for sessionId: UUID) -> URL {
        return posesDirectory.appendingPathComponent("\(sessionId.uuidString).json")
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
        deletePoseFile(session.id)
        // Reclaim the video unless another session still references the same file.
        let videoStillReferenced = sessions.contains { $0.videoURL == session.videoURL }
        if !videoStillReferenced {
            VideoStorage.deleteIfOwned(session.videoURL)
        }
        updateSessionsIndex()
    }

    /// Returns the session with pose data attached, loading the sidecar on first access.
    func hydratedSession(_ session: Session) -> Session {
        if let poseData = session.poseData, !poseData.isEmpty {
            return session
        }
        if let cached = poseDataCache[session.id] {
            return sessionByReplacingPoseData(session, poseData: cached)
        }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        guard let data = try? Data(contentsOf: poseFileURL(for: session.id)),
              let poseData = try? decoder.decode([PoseDetectionResult].self, from: data),
              !poseData.isEmpty else {
            return session
        }
        if poseDataCache.count > 4 {
            poseDataCache.removeAll() // bound memory; sidecars reload cheaply
        }
        poseDataCache[session.id] = poseData
        return sessionByReplacingPoseData(session, poseData: poseData)
    }

    /// Live copy of the session (by id) with pose data attached.
    func currentSession(for session: Session) -> Session {
        hydratedSession(sessions.first { $0.id == session.id } ?? session)
    }

    private func sessionByReplacingPoseData(_ session: Session, poseData: [PoseDetectionResult]?) -> Session {
        Session(
            id: session.id,
            movementType: session.movementType,
            technique: session.technique,
            fightStance: session.fightStance,
            videoURL: session.videoURL,
            timestamp: session.timestamp,
            analysisResult: session.analysisResult,
            poseData: poseData,
            notes: session.notes,
            isRecordedLive: session.isRecordedLive
        )
    }
    
    /// Remove every session, its owned video, and the index (account deletion).
    func deleteAllData() {
        for session in sessions {
            deleteSessionFile(session.id)
            deletePoseFile(session.id)
            VideoStorage.deleteIfOwned(session.videoURL)
        }
        sessions = []
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
            var posesURL = posesDirectory
            try fileManager.createDirectory(at: posesURL, withIntermediateDirectories: true, attributes: nil)
            var resourceValues = URLResourceValues()
            resourceValues.isExcludedFromBackup = true
            try posesURL.setResourceValues(resourceValues)
        } catch {
            Log.storage.error("SessionManager: Failed to create sessions directory: \(error.localizedDescription)")
        }
    }

    private func saveSession(_ session: Session) {
        do {
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            // Pose data goes to a sidecar so the session file stays small enough
            // to load eagerly at launch; sidecars are hydrated on demand.
            let data = try encoder.encode(sessionByReplacingPoseData(session, poseData: nil))
            try data.write(to: sessionFileURL(for: session.id), options: [.atomic])
            if let poseData = session.poseData, !poseData.isEmpty {
                let poseBytes = try encoder.encode(poseData)
                try poseBytes.write(to: poseFileURL(for: session.id), options: [.atomic])
                poseDataCache[session.id] = poseData
            }
        } catch {
            Log.storage.error("SessionManager: Failed to save session \(session.id): \(error.localizedDescription)")
            lastStorageError = "Your session couldn't be saved (\(error.localizedDescription)). Free up storage and try again."
        }
    }

    private func loadSession(from fileURL: URL) -> Session? {
        do {
            let data = try Data(contentsOf: fileURL)
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            let session = try decoder.decode(Session.self, from: data)
            if let poseData = session.poseData, !poseData.isEmpty {
                // Legacy file with inline pose data: split it so future launches
                // don't pay the multi-MB decode, and keep memory lean now.
                saveSession(session)
                return sessionByReplacingPoseData(session, poseData: nil)
            }
            return session
        } catch {
            Log.storage.error("SessionManager: Failed to load session from \(fileURL.lastPathComponent): \(error.localizedDescription)")
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
            Log.storage.error("SessionManager: Failed to delete session file \(sessionId): \(error.localizedDescription)")
        }
    }

    private func deletePoseFile(_ sessionId: UUID) {
        poseDataCache[sessionId] = nil
        let fileURL = poseFileURL(for: sessionId)
        if FileManager.default.fileExists(atPath: fileURL.path) {
            try? FileManager.default.removeItem(at: fileURL)
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
            Log.storage.error("SessionManager: Failed to update sessions index: \(error.localizedDescription)")
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
                    Log.storage.warning("SessionManager: Session file missing for \(meta.id), skipping")
                }
            }
            
            sessions = loadedSessions
        } catch {
            Log.storage.error("SessionManager: Failed to load sessions index: \(error.localizedDescription)")
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
            if fileURL.hasDirectoryPath {
                continue // Poses/ sidecar directory
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
            
            Log.storage.info("SessionManager: Migrating \(oldSessions.count) sessions from UserDefaults to file storage")
            
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
            
            Log.storage.info("SessionManager: Migration completed successfully")
        } catch {
            Log.storage.error("SessionManager: Failed to migrate sessions from UserDefaults: \(error.localizedDescription)")
            // Mark as migrated anyway to avoid retrying on every launch
            userDefaults.set(true, forKey: migrationKey)
        }
    }
}
