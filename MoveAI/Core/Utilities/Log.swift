//
//  Log.swift
//  MoveAI
//
//  Centralized os.Logger instances. Use these instead of print() in
//  production code paths so failures show up in Console / sysdiagnose.
//

import Foundation
import os

enum Log {
    private static let subsystem = Bundle.main.bundleIdentifier ?? "com.thrivecopilot.MoveAI"

    static let storage = Logger(subsystem: subsystem, category: "Storage")
    static let video = Logger(subsystem: subsystem, category: "Video")
    static let analysis = Logger(subsystem: subsystem, category: "Analysis")
    static let auth = Logger(subsystem: subsystem, category: "Auth")
}
