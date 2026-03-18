// Logger.swift
// Centralized logging utility using OSLog for proper production logging.

import Foundation
import os

// MARK: - App Logger

/// Centralized logging utility for PushBox.
/// Uses OSLog for proper log levels and filtering in production.
/// Debug logs are only visible when attached to debugger or Console.app.
enum AppLogger {
    
    /// Shared subsystem identifier for all loggers.
    private static let subsystem = "fr.meshy.pushbox"
    
    /// Logger for general app events.
    static let general = Logger(subsystem: subsystem, category: "general")
    
    /// Logger for audio-related events.
    static let audio = Logger(subsystem: subsystem, category: "audio")
    
    /// Logger for animation-related events.
    static let animation = Logger(subsystem: subsystem, category: "animation")
    
    /// Logger for In-App Purchase events.
    static let iap = Logger(subsystem: subsystem, category: "iap")
    
    /// Logger for progress/persistence events.
    static let progress = Logger(subsystem: subsystem, category: "progress")
    
    /// Logger for level loading events.
    static let levels = Logger(subsystem: subsystem, category: "levels")
    
    /// Logger for UI/view events.
    static let ui = Logger(subsystem: subsystem, category: "ui")
    
    /// Logger for Game Center events.
    static let gameCenter = Logger(subsystem: subsystem, category: "gameCenter")

    /// Logger for CloudKit sync lifecycle events.
    static let cloudKit = Logger(subsystem: subsystem, category: "cloudKit")
}
