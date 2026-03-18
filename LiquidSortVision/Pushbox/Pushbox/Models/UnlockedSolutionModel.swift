// UnlockedSolutionModel.swift
// SwiftData model for tracking unlocked level solutions with CloudKit sync.

import Foundation
import SwiftData

// MARK: - UnlockedSolutionModel

/// SwiftData model for tracking which level solutions the user has unlocked.
/// Note: Unique constraints are NOT compatible with CloudKit-backed stores.
/// Duplicate prevention must be handled at the application level.
///
/// Indexed on `levelKey` for efficient lookups during solution unlock checks
/// and fetch-before-insert duplicate prevention.
@Model
final class UnlockedSolutionModel {
    
    #Index<UnlockedSolutionModel>([\.levelKey])
    
    /// Key identifying the level. Format: "WorldName-LevelIndex".
    /// Note: Cannot use @Attribute(.unique) with CloudKit sync — duplicates
    /// must be prevented via fetch-before-insert in the service layer.
    /// Default value required for CloudKit compatibility.
    var levelKey: String = ""
    
    /// Timestamp when the solution was unlocked.
    /// Default value required for CloudKit compatibility.
    var unlockedAt: Date = Date()
    
    // MARK: - Initialization
    
    init(levelKey: String, unlockedAt: Date = .now) {
        self.levelKey = levelKey
        self.unlockedAt = unlockedAt
    }
}
