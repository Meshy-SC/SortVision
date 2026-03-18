// LevelProgress.swift
// Represents the progress state for a single game level.

import Foundation

// MARK: - LevelProgress

/// Represents the progress state for a single game level.
/// This is a Codable struct used for persistence to UserDefaults.
///
/// Star ratings are calculated based on push count relative to optimal:
/// - **3 stars**: At or below optimal push count
/// - **2 stars**: Within 20% above optimal push count
/// - **1 star**: More than 20% above optimal push count
struct LevelProgress: Codable, Equatable, Hashable, Sendable {
    
    /// Whether the level has been completed at least once.
    let isCompleted: Bool
    
    /// The number of box pushes used to complete the level.
    let boxPushes: Int
    
    /// The star rating achieved (1-3).
    /// Higher is better, based on proximity to optimal push count.
    let starRating: Int
    
    // MARK: - Coding Keys
    
    /// Maps property names to JSON keys for backward compatibility.
    private enum CodingKeys: String, CodingKey {
        case isCompleted = "completed"
        case boxPushes
        case starRating
    }
    
    // MARK: - Initialization
    
    /// Creates a new level progress record.
    /// - Parameters:
    ///   - isCompleted: Whether the level has been completed.
    ///   - boxPushes: The number of pushes used.
    ///   - starRating: The star rating achieved (1-3).
    init(isCompleted: Bool, boxPushes: Int, starRating: Int) {
        self.isCompleted = isCompleted
        self.boxPushes = boxPushes
        self.starRating = max(0, min(3, starRating)) // Clamp to 0-3
    }
}
