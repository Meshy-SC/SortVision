// LevelGridQueries.swift
// Shared queries for level grid views across platforms.
// Eliminates duplication between LevelsGridView (visionOS) and iOSLevelsGridView (iOS/macOS).

import Foundation

// MARK: - LevelGridQueries

/// Read-only queries for level state used by grid selection views.
///
/// Provides a single source of truth shared between the visionOS
/// `LevelsGridView` and iOS `iOSLevelsGridView`, preventing
/// duplicated completion/rating lookups.
@MainActor
enum LevelGridQueries {
    
    /// Whether the given level is the currently active (playing) level.
    /// - Parameters:
    ///   - index: The level index within the world.
    ///   - world: The world being displayed.
    ///   - appModel: The app model to query.
    /// - Returns: `true` if this level is currently being played.
    static func isLevelActive(_ index: Int, in world: World, appModel: AppModel) -> Bool {
        appModel.activeWorld?.id == world.id && appModel.selectedLevelIndex == index
    }
    
    /// Whether the given level has been completed at least once.
    /// - Parameters:
    ///   - index: The level index within the world.
    ///   - world: The world being displayed.
    ///   - appModel: The app model to query.
    /// - Returns: `true` if the level is marked as completed.
    static func isLevelCompleted(_ index: Int, in world: World, appModel: AppModel) -> Bool {
        appModel.progressService.isLevelCompleted(worldName: world.worldName, levelIndex: index)
    }
    
    /// The star rating (0–3) for the given level.
    /// - Parameters:
    ///   - index: The level index within the world.
    ///   - world: The world being displayed.
    ///   - appModel: The app model to query.
    /// - Returns: The star rating achieved, or `0` if not completed.
    static func starRating(for index: Int, in world: World, appModel: AppModel) -> Int {
        appModel.progressService.starRating(worldName: world.worldName, levelIndex: index)
    }
    
    /// Whether the given level is unlocked (playable) based on progression rules.
    /// - Parameters:
    ///   - index: The level index within the world.
    ///   - world: The world being displayed.
    ///   - appModel: The app model to query.
    /// - Returns: `true` if the level is unlocked and can be played.
    static func isLevelUnlocked(_ index: Int, in world: World, appModel: AppModel) -> Bool {
        appModel.progressService.isLevelUnlocked(index, in: world)
    }
    
    /// Whether the given world is unlocked based on progression rules.
    /// - Parameters:
    ///   - world: The world to check.
    ///   - appModel: The app model to query.
    /// - Returns: `true` if the world is accessible.
    static func isWorldUnlocked(_ world: World, appModel: AppModel) -> Bool {
        appModel.progressService.isWorldUnlocked(world)
    }
    
    /// Loads levels for the given world using the app model's level loader.
    /// - Parameters:
    ///   - world: The world to load levels for.
    ///   - appModel: The app model whose level loader to use.
    /// - Returns: An array of levels (each level is an array of row strings).
    static func loadLevels(for world: World, appModel: AppModel) async -> [[String]] {
        do {
            return try await appModel.levelLoader.loadLevels(for: world.worldName)
        } catch {
            AppLogger.levels.error("Error loading levels for \(world.worldName): \(error.localizedDescription)")
            return []
        }
    }
}
