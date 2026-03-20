import Foundation
import Observation
import WidgetKit

// MARK: - WorldData Model

/// Decoded from World{N}Data.json — extracts optimal move counts per level.
struct WorldData: Decodable, Sendable {
    let optimalMoveCounts: [Int]

    /// Maps Swift property names to JSON keys, preserving serialization compatibility.
    private enum CodingKeys: String, CodingKey {
        case optimalMoveCounts = "optimalPushCounts"
    }
}

/// Central game state manager responsible for level data and progress tracking.
///
/// ## Responsibilities
/// - Loads and caches level JSON data for all available stages
/// - Assigns global level numbers (1–400+) across stages
/// - Tracks sequential level completion progress via `UserDefaults`
/// - Migrates legacy per-difficulty progress to the new global system
/// - Manages the sound-enabled preference
///
/// ## Architecture Notes
/// - Uses the Observation framework (`@Observable`) for SwiftUI integration
/// - Injected into the SwiftUI view hierarchy via `@Environment`
/// - Singleton `shared` instance for backward compatibility
@MainActor @Observable
final class GameManager {

    // MARK: - Singleton

    static let shared = GameManager()

    // MARK: - Constants

    /// UserDefaults key for the sound-enabled preference.
    /// Forwarded from `ProgressStore` for backward compatibility.
    /// `nonisolated` because this only forwards to a constant (`static let`)
    /// and is accessed from non-isolated contexts (e.g. `WidgetDataProvider`).
    nonisolated static var soundEnabledKey: String { ProgressStore.soundEnabledKey }

    /// UserDefaults key for the highest completed global level number.
    /// Forwarded from `ProgressStore` for backward compatibility.
    /// `nonisolated` because this only forwards to a constant (`static let`)
    /// and is accessed from non-isolated contexts (e.g. `WidgetDataProvider`).
    nonisolated static var completionKey: String { ProgressStore.completionKey }

    // MARK: - Level Cache

    /// Cached level data indexed by stage, loaded once at initialization.
    /// Levels within each stage are renumbered with global numbers.
    private var stageLevels: [Stage: [Level]] = [:]

    /// Stores any errors encountered during level loading for diagnostics.
    private(set) var levelLoadingErrors: [Stage: Error] = [:]

    // MARK: - Star Rating & Optimal Moves

    /// Optimal (par) move count for each global level number.
    /// Loaded from World{N}Data.json files at init.
    private var optimalMoves: [Int: Int] = [:]

    /// Player's best (lowest) move count for each global level number.
    /// Persisted to UserDefaults.
    private var bestMoves: [Int: Int] = [:]

    /// Player's earned star rating for each global level number.
    /// Persisted to UserDefaults via `ProgressStore`.
    private var starRatings: [Int: Int] = [:]

    // MARK: - Observable State

    /// Highest completed global level number (0 if none).
    /// Drives level locking, stage accessibility, and progress display.
    private(set) var completedLevel: Int = 0

    /// Sound on/off toggle, persisted via `ProgressStore`.
    var soundEnabled: Bool = true {
        didSet {
            ProgressStore.saveSoundPreference(soundEnabled)
        }
    }

    // MARK: - Initialization

    private init() {
        soundEnabled = ProgressStore.loadSoundPreference()
        ProgressStore.migrateFromLegacyProgress()
        loadAllLevels()
        loadAllWorldData()
        loadCompletedLevel()
        loadBestMoves()
    }

    // MARK: - Level Loading

    /// Loads level JSON files for all stages from the app bundle.
    ///
    /// Each stage's `levelResourceName` maps to a JSON file. After decoding,
    /// levels are renumbered with global numbers (e.g., Iron levels 1–100 stay as-is,
    /// Bronze levels become 101–200, etc.).
    private func loadAllLevels() {
        for stage in Stage.allCases {
            let resourceName = stage.levelResourceName

            do {
                var levels = try loadLevels(resource: resourceName)
                let offset = stage.rawValue * Stage.levelsPerStage
                for i in levels.indices {
                    levels[i].number = offset + levels[i].number
                }
                stageLevels[stage] = levels
            } catch {
                levelLoadingErrors[stage] = error
                stageLevels[stage] = []
            }
        }
    }

    /// Loads World{N}Data.json for each stage to populate optimal move counts.
    private func loadAllWorldData() {
        for stage in Stage.allCases {
            let resourceName = stage.worldDataResourceName
            guard let url = Bundle.main.url(forResource: resourceName, withExtension: "json") else {
                continue
            }

            do {
                let data = try Data(contentsOf: url)
                let worldData = try JSONDecoder().decode(WorldData.self, from: data)
                let offset = stage.rawValue * Stage.levelsPerStage
                for (index, optimal) in worldData.optimalMoveCounts.enumerated() {
                    let globalNumber = offset + index + 1
                    optimalMoves[globalNumber] = optimal
                }
            } catch {
                // Non-fatal: stars just won't show for this world
            }
        }
    }

    /// Restores per-level best moves and star ratings from `ProgressStore`.
    private func loadBestMoves() {
        bestMoves = ProgressStore.loadBestMoves()
        starRatings = ProgressStore.loadStarRatings()
    }

    /// Saves best moves and star ratings via `ProgressStore`.
    private func saveBestMoves() {
        ProgressStore.saveBestMovesAndRatings(
            bestMoves: bestMoves,
            starRatings: starRatings
        )
    }

    /// Loads and decodes levels from a single JSON resource file.
    ///
    /// - Parameter resource: The JSON resource filename (without extension).
    /// - Returns: Array of decoded `Level` objects with local numbering.
    /// - Throws: `LevelLoadingError` if the resource is missing or malformed.
    private func loadLevels(resource: String) throws -> [Level] {
        guard let url = Bundle.main.url(forResource: resource, withExtension: "json") else {
            throw LevelLoadingError.resourceNotFound(resource)
        }

        let data: Data
        do {
            data = try Data(contentsOf: url)
        } catch {
            throw LevelLoadingError.fileReadFailed(resource, error.localizedDescription)
        }

        do {
            let group = try JSONDecoder().decode(LevelGroup.self, from: data)
            return group.levels
        } catch {
            throw LevelLoadingError.decodingFailed(resource, error.localizedDescription)
        }
    }

    /// Restores completed level progress from `ProgressStore`.
    func loadCompletedLevel() {
        completedLevel = ProgressStore.loadCompletedLevel()
    }

    // MARK: - Level Queries

    /// Returns all levels for the given stage.
    func levels(for stage: Stage) -> [Level] {
        stageLevels[stage] ?? []
    }

    /// Returns a specific level by its global number.
    ///
    /// - Parameter globalNumber: The 1-based global level number.
    /// - Returns: The level if found, `nil` otherwise.
    func level(globalNumber: Int) -> Level? {
        guard let stage = Stage.stage(for: globalNumber) else { return nil }
        let levels = self.levels(for: stage)
        let localIndex = globalNumber - stage.levelRange.lowerBound
        guard localIndex >= 0, localIndex < levels.count else { return nil }
        return levels[localIndex]
    }

    /// Returns the number of completed levels within a specific stage.
    func completedCountInStage(_ stage: Stage) -> Int {
        max(0, min(completedLevel - stage.levelRange.lowerBound + 1, Stage.levelsPerStage))
    }

    /// Checks whether a level is locked (not yet reachable by the player).
    ///
    /// A level is locked if its global number exceeds the next playable level
    /// (i.e., `globalNumber > completedLevel + 1`).
    func isLevelLocked(_ globalNumber: Int) -> Bool {
        globalNumber > completedLevel + 1
    }

    /// Checks whether a stage is accessible to the player.
    ///
    /// A stage is accessible if it has content and the player has reached
    /// at least its first level (i.e., completed the previous stage or it's Iron).
    func isStageAccessible(_ stage: Stage) -> Bool {
        guard stage.isAvailable else { return false }
        return completedLevel >= stage.levelRange.lowerBound - 1
    }

    /// Checks whether a next level exists after the given global level number.
    func hasNextLevel(after globalNumber: Int) -> Bool {
        level(globalNumber: globalNumber + 1) != nil
    }

    // MARK: - Star Rating Queries

    /// Returns the optimal (par) move count for a level, if known.
    func optimalMoveCount(for globalNumber: Int) -> Int? {
        optimalMoves[globalNumber]
    }

    /// Returns the player's best move count for a level, or nil if not played.
    func bestMoveCount(for globalNumber: Int) -> Int? {
        bestMoves[globalNumber]
    }

    /// Returns the player's star rating (0–3) for a level.
    func starRating(for globalNumber: Int) -> Int {
        starRatings[globalNumber] ?? 0
    }

    /// Calculates a star rating from move count vs optimal.
    /// - 3 stars: moves ≤ optimal
    /// - 2 stars: moves ≤ optimal × 1.5
    /// - 1 star:  completed
    static func calculateStars(moves: Int, optimal: Int?) -> Int {
        guard let optimal, optimal > 0 else { return 1 }
        if moves <= optimal { return 3 }
        if moves <= Int(Double(optimal) * 1.5) { return 2 }
        return 1
    }

    // MARK: - Level Completion

    /// Records a level as completed with the given move count.
    ///
    /// Updates progress, best move count, and star rating. Only advances
    /// global progress if this is the furthest level beaten.
    ///
    /// - Parameters:
    ///   - number: The global level number that was completed.
    ///   - moves: Number of moves used to complete the level.
    func completeLevel(number: Int, moves: Int) {
        // Update global progress
        if number > completedLevel {
            completedLevel = number
            ProgressStore.saveCompletedLevel(number)
            WidgetCenter.shared.reloadAllTimelines()
        }

        // Update best move count (keep lowest)
        bestMoves[number] = min(moves, bestMoves[number] ?? .max)

        // Calculate and store star rating (keep highest)
        let newStars = Self.calculateStars(moves: moves, optimal: optimalMoves[number])
        starRatings[number] = max(newStars, starRatings[number] ?? 0)

        saveBestMoves()
    }

    // MARK: - Aggregate Stats

    /// Total stars earned across all completed levels.
    var totalStars: Int {
        starRatings.values.reduce(0, +)
    }

    /// Maximum possible stars across all available levels.
    var maxStars: Int {
        Stage.allCases.reduce(0) { total, stage in total + levels(for: stage).count * 3 }
    }

    // MARK: - Reset Progress

    /// Resets all level completions, star ratings, and scores.
    func resetAllProgress() {
        completedLevel = 0
        bestMoves.removeAll()
        starRatings.removeAll()
        ProgressStore.resetAllProgress()
        WidgetCenter.shared.reloadAllTimelines()
    }
}

// MARK: - Error Types

/// Errors that can occur during level data loading.
///
/// Captured per-stage in `GameManager.levelLoadingErrors` for diagnostics
/// without crashing the app when a single stage's data is unavailable.
enum LevelLoadingError: LocalizedError, Sendable {
    /// The JSON resource file was not found in the app bundle.
    case resourceNotFound(String)

    /// The file exists but could not be read from disk.
    case fileReadFailed(String, String)

    /// The file was read but JSON decoding failed.
    case decodingFailed(String, String)

    var errorDescription: String? {
        switch self {
        case .resourceNotFound(let name):
            "Level resource '\(name).json' not found in app bundle."
        case .fileReadFailed(let name, let description):
            "Failed to read '\(name).json': \(description)"
        case .decodingFailed(let name, let description):
            "Failed to decode '\(name).json': \(description)"
        }
    }
}
