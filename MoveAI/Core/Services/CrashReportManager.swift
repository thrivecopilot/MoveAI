//
//  CrashReportManager.swift
//  MoveAI
//
//  Zero-dependency crash and hang diagnostics via MetricKit. The system
//  delivers diagnostic payloads on the launch after an incident; they are
//  persisted locally (Application Support/Diagnostics) so they can be pulled
//  from a device for inspection until a remote reporting backend exists.
//

import Foundation
import MetricKit
import os

final class CrashReportManager: NSObject, MXMetricManagerSubscriber {
    static let shared = CrashReportManager()

    private let logger = Logger(subsystem: "com.thrivecopilot.MoveAI", category: "Diagnostics")
    private let maxStoredPayloads = 20

    private var diagnosticsDirectory: URL? {
        guard let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first else {
            return nil
        }
        return base.appendingPathComponent("Diagnostics", isDirectory: true)
    }

    func start() {
        MXMetricManager.shared.add(self)
    }

    // MARK: - MXMetricManagerSubscriber

    func didReceive(_ payloads: [MXDiagnosticPayload]) {
        logger.error("Received \(payloads.count) diagnostic payload(s) — crash/hang occurred on a previous launch")
        for payload in payloads {
            persist(payload.jsonRepresentation())
        }
    }

    // MARK: - Storage

    private func persist(_ data: Data) {
        guard let directory = diagnosticsDirectory else { return }
        do {
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            let timestamp = ISO8601DateFormatter().string(from: Date())
                .replacingOccurrences(of: ":", with: "-")
            let fileURL = directory.appendingPathComponent("diagnostic_\(timestamp)_\(UUID().uuidString.prefix(8)).json")
            try data.write(to: fileURL, options: [.atomic])
            pruneOldPayloads(in: directory)
        } catch {
            logger.error("Failed to persist diagnostic payload: \(error.localizedDescription)")
        }
    }

    private func pruneOldPayloads(in directory: URL) {
        guard let files = try? FileManager.default.contentsOfDirectory(
            at: directory,
            includingPropertiesForKeys: [.contentModificationDateKey]
        ) else { return }
        guard files.count > maxStoredPayloads else { return }

        let sorted = files.sorted { lhs, rhs in
            let lhsDate = (try? lhs.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate) ?? .distantPast
            let rhsDate = (try? rhs.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate) ?? .distantPast
            return lhsDate < rhsDate
        }
        for file in sorted.prefix(files.count - maxStoredPayloads) {
            try? FileManager.default.removeItem(at: file)
        }
    }
}
