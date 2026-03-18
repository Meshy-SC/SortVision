// ProgressService.swift
// Manages game progress persistence using SwiftData with CloudKit sync.

import Foundation
import SwiftData
import Combine
import CoreData

// MARK: - ProgressService

/// Service responsible for tracking and persisting game progress.
/// Handles level completion, star ratings, and overall game statistics.
/// Uses SwiftData for CloudKit-synced persistence.
@MainActor
@Observable
final class ProgressService {

    // MARK: - Observable Properties

    /// Progress dictionary: [WorldName: [LevelIndex: LevelProgress]]
    var progress: [String: [Int: LevelProgress]] = [:]

    /// Current level push count (resets on level load).
    var currentLevelPushes: Int = 0

    // MARK: - Private Properties

    /// Legacy UserDefaults keys for migration.
    private enum LegacyKeys {
        static let progress = "PushboxProgress"
        static let migrationComplete = "progressMigrationComplete"
    }

    /// Reference to world total levels — delegates to the shared static on `World`.
    @ObservationIgnored
    private var worldTotalLevels: [String: Int] { World.totalLevelsPerWorld }

    /// SwiftData model context for persistence.
    @ObservationIgnored
    private let modelContext: ModelContext
    
    /// Cancellable for CloudKit remote-change notification subscription.
    @ObservationIgnored
    private var remoteChangeCancellable: AnyCancellable?

    // MARK: - Initialization

    init(modelContext: ModelContext) {
        self.modelContext = modelContext

        migrateFromUserDefaultsIfNeeded()
        loadProgress()
        
        // Listen for CloudKit remote changes to sync progress across devices
        remoteChangeCancellable = NotificationCenter.default
            .publisher(for: .NSPersistentStoreRemoteChange)
            .debounce(for: .milliseconds(500), scheduler: RunLoop.main)
            .sink { [weak self] _ in
                self?.loadProgress()
                AppLogger.progress.info("Refreshed progress after CloudKit remote change")
            }
    }

    // MARK: - Push Count Management
    
    /// Increments the current level push count.
    func incrementPushCount() {
        currentLevelPushes += 1
    }
    
    /// Decrements the current level push count (for undo operations).
    func decrementPushCount() {
        currentLevelPushes = max(0, currentLevelPushes - 1)
    }
    
    /// Resets the current level push count.
    func resetPushCount() {
        currentLevelPushes = 0
    }
    
    // MARK: - Level Completion
    
    /// Marks a level as completed and calculates the star rating.
    /// Star rating is based on push count relative to optimal:
    /// - 3 stars: At or below optimal
    /// - 2 stars: Within 20% above optimal
    /// - 1 star: More than 20% above optimal
    ///
    /// - Parameters:
    ///   - world: The world containing the completed level.
    ///   - levelIndex: The index of the completed level.
    func completeLevel(for world: World, levelIndex: Int) {
        let worldName = world.worldName
        var worldProgress = progress[worldName] ?? [:]
        let playerPushes = currentLevelPushes
        
        // Calculate star rating based on optimal push count
        var newStarRating = 1
        if world.optimalPushCounts.indices.contains(levelIndex) {
            let minPush = world.optimalPushCounts[levelIndex]
            let twoStarThreshold = Int(ceil(Double(minPush) * 1.2))
            
            if playerPushes <= minPush {
                newStarRating = 3
            } else if playerPushes <= twoStarThreshold {
                newStarRating = 2
            }
        }
        
        // Always save the latest result — the most recent play is the one that counts.
        let newProgress = LevelProgress(
            isCompleted: true,
            boxPushes: playerPushes,
            starRating: newStarRating
        )
        worldProgress[levelIndex] = newProgress
        updateSwiftDataModel(worldName: worldName, levelIndex: levelIndex, progress: newProgress)
        
        progress[worldName] = worldProgress
        updateCachedStatistics()
    }
    
    // MARK: - SwiftData Persistence
    
    /// Updates or creates a SwiftData model for the given progress.
    private func updateSwiftDataModel(worldName: String, levelIndex: Int, progress: LevelProgress) {
        // Check if model already exists
        let predicate = #Predicate<LevelProgressModel> { model in
            model.worldName == worldName && model.levelIndex == levelIndex
        }
        let descriptor = FetchDescriptor<LevelProgressModel>(predicate: predicate)
        
        do {
            let existing = try modelContext.fetch(descriptor)
            if let model = existing.first {
                // Update existing
                model.isCompleted = progress.isCompleted
                model.boxPushes = progress.boxPushes
                model.starRating = progress.starRating
            } else {
                // Create new
                let model = LevelProgressModel(
                    worldName: worldName,
                    levelIndex: levelIndex,
                    isCompleted: progress.isCompleted,
                    boxPushes: progress.boxPushes,
                    starRating: progress.starRating
                )
                modelContext.insert(model)
            }
            try modelContext.save()
        } catch {
            AppLogger.progress.error("Failed to save progress: \(error.localizedDescription)")
        }
    }
    
    /// Flushes any pending SwiftData changes to the persistent store.
    /// Individual level completions are already persisted by `completeLevel()`,
    /// so this only needs to commit any uncommitted auto-save buffer.
    func saveProgress() {
        do {
            try modelContext.save()
        } catch {
            AppLogger.progress.error("Failed to flush progress: \(error.localizedDescription)")
        }
    }
    
    /// Loads progress from SwiftData.
    func loadProgress() {
        let descriptor = FetchDescriptor<LevelProgressModel>()
        
        do {
            let models = try modelContext.fetch(descriptor)
            var loaded: [String: [Int: LevelProgress]] = [:]
            
            for model in models {
                loaded[model.worldName, default: [:]][model.levelIndex] = model.levelProgress
            }
            
            progress = loaded
            updateCachedStatistics()
        } catch {
            AppLogger.progress.error("Failed to load progress: \(error.localizedDescription)")
        }
    }
    
    /// Deletes all saved progress from SwiftData and clears the in-memory cache.
    ///
    /// This operation:
    /// 1. Batch-deletes every `LevelProgressModel` from the persistent store
    /// 2. Clears the in-memory progress dictionary
    /// 3. Resets the current push counter
    ///
    /// The deletion propagates to other devices via CloudKit sync.
    func resetAllProgress() {
        do {
            try modelContext.delete(model: LevelProgressModel.self)
            try modelContext.save()
            progress = [:]
            currentLevelPushes = 0
            updateCachedStatistics()
            AppLogger.progress.info("All progress has been reset")
        } catch {
            AppLogger.progress.error("Failed to reset progress: \(error.localizedDescription)")
        }
    }
    
    // MARK: - Migration
    
    /// Migrates legacy UserDefaults data to SwiftData.
    private func migrateFromUserDefaultsIfNeeded() {
        guard !UserDefaults.standard.bool(forKey: LegacyKeys.migrationComplete) else { return }
        
        guard let data = UserDefaults.standard.data(forKey: LegacyKeys.progress),
              let decoded = try? JSONDecoder().decode([String: [Int: LevelProgress]].self, from: data) else {
            UserDefaults.standard.set(true, forKey: LegacyKeys.migrationComplete)
            return
        }
        
        for (worldName, worldProgress) in decoded {
            for (levelIndex, levelProgress) in worldProgress {
                let model = LevelProgressModel(
                    worldName: worldName,
                    levelIndex: levelIndex,
                    isCompleted: levelProgress.isCompleted,
                    boxPushes: levelProgress.boxPushes,
                    starRating: levelProgress.starRating
                )
                modelContext.insert(model)
            }
        }
        
        do {
            try modelContext.save()
            UserDefaults.standard.removeObject(forKey: LegacyKeys.progress)
            UserDefaults.standard.set(true, forKey: LegacyKeys.migrationComplete)
            AppLogger.progress.info("Successfully migrated progress from UserDefaults to SwiftData")
        } catch {
            AppLogger.progress.error("Failed to migrate progress: \(error.localizedDescription)")
        }
    }
    
    // MARK: - Statistics (In-Memory Cache)

    /// Overall completion percentage across all worlds.
    /// Cached and updated only when progress changes (level complete, load, reset).
    var overallProgress: Double = 0

    /// Total score across all completed levels.
    /// Scoring: 3 stars = 10 points, 2 stars = 7 points, 1 star = 5 points.
    /// Cached and updated only when progress changes.
    var globalScore: Int = 0

    /// Maximum possible score if all levels completed with 3 stars.
    var maximumGlobalScore: Int {
        worldTotalLevels.values.reduce(0) { $0 + $1 * 10 }
    }
    
    /// Score for a single world (sum of star-based points for its completed levels).
    /// Scoring: 3 stars = 10 pts, 2 stars = 7 pts, 1 star = 5 pts.
    func worldScore(for worldName: String) -> Int {
        progress[worldName]?.values.filter(\.isCompleted).reduce(0) { score, lp in
            switch lp.starRating {
            case 3: return score + 10
            case 2: return score + 7
            default: return score + 5
            }
        } ?? 0
    }

    /// Maximum possible score for a single world (all levels × 10 pts).
    func maximumWorldScore(for worldName: String) -> Int {
        (worldTotalLevels[worldName] ?? 0) * 10
    }

    /// Gets the completed level count for a specific world using in-memory cache.
    func completedCount(for worldName: String) -> Int {
        progress[worldName]?.values.filter(\.isCompleted).count ?? 0
    }
    
    /// Whether a specific level has been completed, using in-memory cache.
    func isLevelCompleted(worldName: String, levelIndex: Int) -> Bool {
        progress[worldName]?[levelIndex]?.isCompleted ?? false
    }
    
    /// Star rating for a specific level, using in-memory cache.
    func starRating(worldName: String, levelIndex: Int) -> Int {
        progress[worldName]?[levelIndex]?.starRating ?? 0
    }
    
    /// Recalculates cached statistics from the in-memory progress dictionary.
    /// Called after any mutation: loadProgress(), completeLevel(), resetAllProgress().
    private func updateCachedStatistics() {
        let totalLevels = worldTotalLevels.values.reduce(0, +)
        let completedLevels = progress.values.flatMap(\.values).filter(\.isCompleted)
        if totalLevels > 0 {
            overallProgress = (Double(completedLevels.count) / Double(totalLevels)) * 100.0
        } else {
            overallProgress = 0
        }
        globalScore = completedLevels.reduce(0) { score, lp in
            switch lp.starRating {
            case 3: return score + 10
            case 2: return score + 7
            default: return score + 5
            }
        }
    }
    
    /// Gets the optimal push count for a specific level.
    /// - Parameters:
    ///   - world: The world containing the level.
    ///   - levelIndex: The level index.
    /// - Returns: The optimal push count, or nil if not available.
    func optimalPushes(for world: World?, levelIndex: Int?) -> Int? {
        guard let world = world,
              let index = levelIndex,
              world.optimalPushCounts.indices.contains(index) else { return nil }
        return world.optimalPushCounts[index]
    }
    
    // MARK: - Level Progression & Unlocking
    //
    // Progression model (industry-standard threshold gating):
    //
    // • World 1 is always open.
    // • Subsequent worlds unlock when the player completes ≥ 50% of the previous world.
    // • Within each unlocked world, levels are gated in groups of 10:
    //   – The first group (levels 0–9) is open when the world is unlocked.
    //   – Each subsequent group requires ≥ 60% (6 of 10) completions in the prior group.
    //
    // This prevents hard-stop frustration while maintaining a sense of progression.
    
    /// Number of levels per unlock group within a world.
    static let levelsPerGroup: Int = 10
    
    /// Fraction of previous group that must be completed to unlock the next group (60%).
    static let groupUnlockThreshold: Double = 0.6
    
    /// Fraction of a world that must be completed to unlock the next world (50%).
    static let worldUnlockThreshold: Double = 0.5
    
    /// Whether a world is unlocked for the player.
    ///
    /// - The first world in `World.allWorlds` is always unlocked.
    /// - Subsequent worlds require ≥ 50% completion of the immediately preceding world.
    ///
    /// - Parameter world: The world to check.
    /// - Returns: `true` if the player can access this world.
    func isWorldUnlocked(_ world: World) -> Bool {
        let allWorlds = World.allWorlds
        guard let worldIndex = allWorlds.firstIndex(where: { $0.id == world.id }) else {
            return false
        }
        
        // First world is always open
        if worldIndex == 0 { return true }
        
        // Check if the previous world meets the unlock threshold
        let previousWorld = allWorlds[worldIndex - 1]
        let completed = completedCount(for: previousWorld.worldName)
        let total = worldTotalLevels[previousWorld.worldName] ?? 0
        guard total > 0 else { return false }
        
        let requiredCompletions = Int(ceil(Double(total) * Self.worldUnlockThreshold))
        return completed >= requiredCompletions
    }
    
    /// Whether a specific level within a world is unlocked for the player.
    ///
    /// - The first group (levels 0–9) is open as soon as the world is unlocked.
    /// - Each subsequent group of 10 requires ≥ 60% completions in the prior group.
    ///
    /// - Parameters:
    ///   - levelIndex: The 0-based level index.
    ///   - world: The world containing the level.
    /// - Returns: `true` if the player can access this level.
    func isLevelUnlocked(_ levelIndex: Int, in world: World) -> Bool {
        // World must be unlocked first
        guard isWorldUnlocked(world) else { return false }
        
        let groupSize = Self.levelsPerGroup
        let groupIndex = levelIndex / groupSize
        
        // First group is always open when the world is unlocked
        if groupIndex == 0 { return true }
        
        // Check if the previous group meets the unlock threshold
        let previousGroupStart = (groupIndex - 1) * groupSize
        let previousGroupEnd = min(previousGroupStart + groupSize, world.levelCount)
        let previousGroupSize = previousGroupEnd - previousGroupStart
        
        var completedInPreviousGroup = 0
        for i in previousGroupStart..<previousGroupEnd {
            if isLevelCompleted(worldName: world.worldName, levelIndex: i) {
                completedInPreviousGroup += 1
            }
        }
        
        let requiredCompletions = Int(ceil(Double(previousGroupSize) * Self.groupUnlockThreshold))
        return completedInPreviousGroup >= requiredCompletions
    }
    
    /// The number of completed levels required to unlock the next world after this one.
    ///
    /// - Parameter worldName: The world whose unlock requirement to calculate.
    /// - Returns: The number of completions needed, or `nil` if this is the last world.
    func completionsNeededForNextWorld(after worldName: String) -> Int? {
        let total = worldTotalLevels[worldName] ?? 0
        guard total > 0 else { return nil }
        return Int(ceil(Double(total) * Self.worldUnlockThreshold))
    }
    
    /// The number of completed levels in a group required to unlock the next group.
    ///
    /// - Parameter groupSize: The number of levels in the group (may be < 10 for the last group).
    /// - Returns: The number of completions needed.
    func completionsNeededForNextGroup(groupSize: Int) -> Int {
        Int(ceil(Double(groupSize) * Self.groupUnlockThreshold))
    }
    
    /// Returns the index of the first locked level in a world, or `nil` if all levels are unlocked.
    /// Useful for scrolling the grid to the player's frontier.
    ///
    /// - Parameter world: The world to check.
    /// - Returns: The first locked level index, or `nil`.
    func firstLockedLevelIndex(in world: World) -> Int? {
        for i in 0..<world.levelCount {
            if !isLevelUnlocked(i, in: world) {
                return i
            }
        }
        return nil
    }
    
    /// Returns the index of the next playable (unlocked & incomplete) level, or `nil`.
    /// Useful for "continue" / auto-advance functionality.
    ///
    /// - Parameter world: The world to search in.
    /// - Returns: The next playable level index, or `nil` if all unlocked levels are completed.
    func nextPlayableLevel(in world: World) -> Int? {
        for i in 0..<world.levelCount {
            guard isLevelUnlocked(i, in: world) else { return nil }
            if !isLevelCompleted(worldName: world.worldName, levelIndex: i) {
                return i
            }
        }
        return nil
    }
    
    // MARK: - Unlock Requirement Messages
    
    /// Returns a human-readable message explaining what the player needs to do
    /// to unlock a given world, or `nil` if the world is already unlocked.
    ///
    /// - Parameter world: The world to check.
    /// - Returns: A localised requirement string, or `nil`.
    func unlockRequirement(forWorld world: World) -> String? {
        guard !isWorldUnlocked(world) else { return nil }
        let allWorlds = World.allWorlds
        guard let worldIndex = allWorlds.firstIndex(where: { $0.id == world.id }),
              worldIndex > 0 else { return nil }
        
        let previousWorld = allWorlds[worldIndex - 1]
        let completed = completedCount(for: previousWorld.worldName)
        let total = worldTotalLevels[previousWorld.worldName] ?? 0
        let required = Int(ceil(Double(total) * Self.worldUnlockThreshold))
        let remaining = max(0, required - completed)
        
        return "Complete \(remaining) more level\(remaining == 1 ? "" : "s") in the \(previousWorld.title) world to unlock. (\(completed)/\(total) completed)"
    }
    
    /// Returns a human-readable message explaining what the player needs to do
    /// to unlock a given level, or `nil` if the level is already unlocked.
    ///
    /// If the world itself is locked the world-level message is returned instead.
    ///
    /// - Parameters:
    ///   - levelIndex: The 0-based level index.
    ///   - world: The world containing the level.
    /// - Returns: A localised requirement string, or `nil`.
    func unlockRequirement(forLevel levelIndex: Int, in world: World) -> String? {
        guard !isLevelUnlocked(levelIndex, in: world) else { return nil }
        
        // If the world itself is locked, surface that requirement instead
        if !isWorldUnlocked(world) {
            return unlockRequirement(forWorld: world)
        }
        
        let groupSize = Self.levelsPerGroup
        let groupIndex = levelIndex / groupSize
        guard groupIndex > 0 else { return nil }
        
        let previousGroupStart = (groupIndex - 1) * groupSize
        let previousGroupEnd = min(previousGroupStart + groupSize, world.levelCount)
        
        var completedInPreviousGroup = 0
        for i in previousGroupStart..<previousGroupEnd {
            if isLevelCompleted(worldName: world.worldName, levelIndex: i) {
                completedInPreviousGroup += 1
            }
        }
        
        let previousGroupSize = previousGroupEnd - previousGroupStart
        let required = Int(ceil(Double(previousGroupSize) * Self.groupUnlockThreshold))
        let remaining = max(0, required - completedInPreviousGroup)
        
        return "Complete \(remaining) more level\(remaining == 1 ? "" : "s") from levels \(previousGroupStart + 1)–\(previousGroupEnd) to unlock. (\(completedInPreviousGroup)/\(previousGroupSize) completed)"
    }
    
}
