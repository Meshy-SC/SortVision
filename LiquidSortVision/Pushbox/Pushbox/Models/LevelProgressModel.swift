// LevelProgressModel.swift
// SwiftData model for persisting level progress with CloudKit sync.

import Foundation
import SwiftData

// MARK: - LevelProgressModel

/// SwiftData model for storing the best performance for each level.
/// Replaces UserDefaults-based persistence to enable CloudKit synchronization.
///
/// Indexed on `(worldName, levelIndex)` for efficient per-level lookups
/// used by `ProgressService` on every level load and completion.
@Model
final class LevelProgressModel {
    
    #Index<LevelProgressModel>([\.worldName, \.levelIndex])
    
    /// The name of the world containing this level.
    /// Default value required for CloudKit compatibility.
    var worldName: String = ""
    
    /// The index of the level within the world.
    /// Default value required for CloudKit compatibility.
    var levelIndex: Int = 0
    
    /// Whether the level has been completed at least once.
    /// Default value required for CloudKit compatibility.
    var isCompleted: Bool = false
    
    /// The number of box pushes used to complete the level (best score).
    /// Default value required for CloudKit compatibility.
    var boxPushes: Int = 0
    
    /// The star rating achieved (1-3). Higher is better.
    /// Default value required for CloudKit compatibility.
    var starRating: Int = 0
    
    // MARK: - Initialization
    
    init(
        worldName: String,
        levelIndex: Int,
        isCompleted: Bool = false,
        boxPushes: Int = 0,
        starRating: Int = 0
    ) {
        self.worldName = worldName
        self.levelIndex = levelIndex
        self.isCompleted = isCompleted
        self.boxPushes = boxPushes
        self.starRating = max(0, min(3, starRating))
    }
    
    // MARK: - Conversion
    
    /// Lightweight value-type snapshot of this model's progress data,
    /// suitable for in-memory use and SwiftUI diffing.
    var levelProgress: LevelProgress {
        LevelProgress(
            isCompleted: isCompleted,
            boxPushes: boxPushes,
            starRating: starRating
        )
    }
}
