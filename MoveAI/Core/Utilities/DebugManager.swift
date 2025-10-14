//
//  DebugManager.swift
//  MoveAI
//
//  Created by Dave Mathew on 10/11/25.
//

import Foundation
import SwiftUI
import os.log

@MainActor
class DebugManager: ObservableObject {
    static let shared = DebugManager()
    
    @Published var isDebugMode: Bool = false
    @Published var logEntries: [LogEntry] = []
    @Published var performanceMetrics: [PerformanceMetric] = []
    
    private let logger = Logger(subsystem: "com.thrivecopilot.MoveAI", category: "Debug")
    private let maxLogEntries = 1000
    
    private init() {
        #if DEBUG
        isDebugMode = true
        #endif
    }
    
    // MARK: - Logging
    
    func log(_ message: String, level: LogLevel = .info, category: String = "General") {
        let entry = LogEntry(
            timestamp: Date(),
            level: level,
            category: category,
            message: message
        )
        
        logEntries.append(entry)
        
        // Keep only the most recent entries
        if logEntries.count > maxLogEntries {
            logEntries.removeFirst(logEntries.count - maxLogEntries)
        }
        
        // Also log to system logger
        switch level {
        case .debug:
            logger.debug("\(category): \(message)")
        case .info:
            logger.info("\(category): \(message)")
        case .warning:
            logger.warning("\(category): \(message)")
        case .error:
            logger.error("\(category): \(message)")
        }
        
        // Print to console for immediate debugging
        print("[\(level.rawValue.uppercased())] \(category): \(message)")
    }
    
    func logError(_ error: Error, category: String = "Error") {
        log("Error: \(error.localizedDescription)", level: .error, category: category)
    }
    
    func logPerformance(_ operation: String, duration: TimeInterval, category: String = "Performance") {
        let metric = PerformanceMetric(
            operation: operation,
            duration: duration,
            timestamp: Date(),
            category: category
        )
        
        performanceMetrics.append(metric)
        
        // Keep only recent performance metrics
        if performanceMetrics.count > 500 {
            performanceMetrics.removeFirst(performanceMetrics.count - 500)
        }
        
        log("Performance: \(operation) took \(String(format: "%.3f", duration))s", 
            level: .info, 
            category: category)
    }
    
    // MARK: - State Monitoring
    
    func logStateChange<T>(_ object: T, property: String, oldValue: Any, newValue: Any) {
        log("State change: \(String(describing: type(of: object))).\(property): \(oldValue) → \(newValue)", 
            level: .debug, 
            category: "State")
    }
    
    // MARK: - UI Monitoring
    
    func logViewAppeared(_ viewName: String) {
        log("View appeared: \(viewName)", level: .debug, category: "UI")
    }
    
    func logViewDisappeared(_ viewName: String) {
        log("View disappeared: \(viewName)", level: .debug, category: "UI")
    }
    
    func logUserAction(_ action: String, context: String = "") {
        log("User action: \(action)\(context.isEmpty ? "" : " (\(context))")", 
            level: .info, 
            category: "UserAction")
    }
    
    // MARK: - Clear Functions
    
    func clearLogs() {
        logEntries.removeAll()
    }
    
    func clearPerformanceMetrics() {
        performanceMetrics.removeAll()
    }
    
    func exportLogs() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        
        let logStrings = logEntries.map { entry in
            "[\(formatter.string(from: entry.timestamp))] [\(entry.level.rawValue.uppercased())] [\(entry.category)] \(entry.message)"
        }
        
        return logStrings.joined(separator: "\n")
    }
}

// MARK: - Supporting Types

struct LogEntry: Identifiable {
    let id = UUID()
    let timestamp: Date
    let level: LogLevel
    let category: String
    let message: String
}

struct PerformanceMetric: Identifiable {
    let id = UUID()
    let operation: String
    let duration: TimeInterval
    let timestamp: Date
    let category: String
}

enum LogLevel: String, CaseIterable {
    case debug = "debug"
    case info = "info"
    case warning = "warning"
    case error = "error"
    
    var color: Color {
        switch self {
        case .debug: return .gray
        case .info: return .blue
        case .warning: return .orange
        case .error: return .red
        }
    }
}

// MARK: - Performance Monitoring

@MainActor
class PerformanceMonitor {
    private var startTimes: [String: Date] = [:]
    
    func startTiming(_ operation: String) {
        startTimes[operation] = Date()
    }
    
    func endTiming(_ operation: String, category: String = "Performance") {
        guard let startTime = startTimes[operation] else {
            DebugManager.shared.log("No start time found for operation: \(operation)", level: .warning)
            return
        }
        
        let duration = Date().timeIntervalSince(startTime)
        DebugManager.shared.logPerformance(operation, duration: duration, category: category)
        startTimes.removeValue(forKey: operation)
    }
}

// MARK: - View Modifiers for Easy Debugging

extension View {
    func debugLog(_ message: String, level: LogLevel = .debug) -> some View {
        DebugManager.shared.log(message, level: level, category: "View")
        return self
    }
    
    func debugOnAppear(_ viewName: String) -> some View {
        self.onAppear {
            DebugManager.shared.logViewAppeared(viewName)
        }
    }
    
    func debugOnDisappear(_ viewName: String) -> some View {
        self.onDisappear {
            DebugManager.shared.logViewDisappeared(viewName)
        }
    }
    
    func debugUserAction(_ action: String, context: String = "") -> some View {
        self.onTapGesture {
            DebugManager.shared.logUserAction(action, context: context)
        }
    }
}
