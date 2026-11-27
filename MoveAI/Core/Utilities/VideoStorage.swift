//
//  VideoStorage.swift
//  MoveAI
//
//  Owns the on-disk lifecycle of session videos. Videos live in the app's
//  Documents directory; sessions persist only the file name because the app
//  container path changes across app updates and device restores.
//

import Foundation

enum VideoStorage {

    /// Canonical directory for session videos (camera recordings already land here).
    static var videosDirectory: URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
    }

    /// Resolve a persisted file name against the current container.
    static func videoURL(forFileName fileName: String) -> URL {
        videosDirectory.appendingPathComponent(fileName)
    }

    /// Whether a URL points inside the canonical videos directory (i.e. a file
    /// this app owns and may delete). Bundle resources and placeholder URLs are not owned.
    static func isOwned(_ url: URL) -> Bool {
        url.standardizedFileURL.path.hasPrefix(videosDirectory.standardizedFileURL.path + "/")
    }

    /// Move a video (typically from the temporary directory, where the system
    /// may purge it at any time) into permanent storage under a unique name.
    static func importToPermanentStorage(_ sourceURL: URL) throws -> URL {
        let fileExtension = sourceURL.pathExtension.isEmpty ? "mov" : sourceURL.pathExtension.lowercased()
        let destinationURL = videosDirectory
            .appendingPathComponent("imported_\(UUID().uuidString)")
            .appendingPathExtension(fileExtension)
        try FileManager.default.moveItem(at: sourceURL, to: destinationURL)
        return destinationURL
    }

    /// Delete a session video, but only if it lives in the canonical directory.
    static func deleteIfOwned(_ url: URL) {
        guard isOwned(url) else { return }
        do {
            if FileManager.default.fileExists(atPath: url.path) {
                try FileManager.default.removeItem(at: url)
            }
        } catch {
            Log.storage.error("VideoStorage: Failed to delete video \(url.lastPathComponent): \(error.localizedDescription)")
        }
    }

    /// Resolve a URL that was persisted by an older build as an absolute path.
    /// Container paths change across updates/restores, so if the stored path is
    /// dead, fall back to the same file name in the current videos directory.
    static func resolveStoredURL(_ storedURL: URL) -> URL {
        if FileManager.default.fileExists(atPath: storedURL.path) {
            return storedURL
        }
        return videoURL(forFileName: storedURL.lastPathComponent)
    }
}
