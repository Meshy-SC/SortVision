import Foundation
import Observation
import WidgetKit

/// Central game state manager responsible for level data and progress tracking.
///
/// ## Responsibilities
/// - Loads and caches level JSON data for all game modes (Easy, Normal, Hard, Expert)
/// - Tracks per-mode level completion progress via `UserDefaults`
/// - Manages the sound-enabled preference
///
/// ## Architecture Notes
/// - Uses the Observation framework (`@Observable`) for SwiftUI integration
/// - Injected into the SwiftUI view hierarchy via `@Environment`
/// - Singleton `shared` instance maintained for backward compatibility with SpriteKit layer
///
/// ## Unity Equivalent
/// Mirrors Unity's `ResourceManager` (level loading) + `GameManager` (progress tracking).
@MainActor @Observable
final class GameManager {

    // MARK: - Singleton

    static let shared = GameManager()

    // MARK: - Constants

    /// UserDefaults key for the sound-enabled preference.
    /// Both `GameManager` and `SoundManager` independently use this key,
    /// keeping the UI toggle and audio playback in sync without coupling.
    static let soundEnabledKey = "soundEnabled"

    // MARK: - Level Cache

    /// Cached level data indexed by game mode, loaded once at initialization.
    private var levelCache: [GameMode: [Level]] = [:]

    /// Stores any errors encountered during level loading for diagnostics.
    private(set) var levelLoadingErrors: [GameMode: Error] = [:]

    // MARK: - Observable State

    /// Tracks the highest completed level number per game mode.
    /// Dictionary mutation triggers SwiftUI view updates via Observation.
    private(set) var completedLevels: [GameMode: Int] = [:]

    /// Sound on/off toggle, persisted to UserDefaults.
    ///
    /// `SoundManager` reads the same UserDefaults key directly, so changes
    /// here are immediately reflected in audio playback without direct coupling.
    var soundEnabled: Bool = true {
        didSet {
            UserDefaults.standard.set(soundEnabled, forKey: Self.soundEnabledKey)
        }
    }

    // MARK: - Initialization

    private init() {
        // Load sound preference (default to true on first launch)
        if UserDefaults.standard.object(forKey: Self.soundEnabledKey) == nil {
            UserDefaults.standard.set(true, forKey: Self.soundEnabledKey)
        }
        soundEnabled = UserDefaults.standard.bool(forKey: Self.soundEnabledKey)

        loadAllLevels()
        loadCompletedLevels()
    }

    // MARK: - Level Loading

    /// Loads level JSON files for all game modes from the app bundle.
    ///
    /// Each mode maps to a JSON resource file (e.g., `.easy` → `levels.json`).
    /// Loading errors are captured per-mode in `levelLoadingErrors` for diagnostics
    /// rather than crashing the app.
    private func loadAllLevels() {
        for mode in GameMode.allCases {
            do {
                let levels = try loadLevels(for: mode)
                levelCache[mode] = levels
            } catch {
                levelLoadingErrors[mode] = error
                levelCache[mode] = []
            }
        }
    }

    /// Loads and decodes levels for a single game mode.
    ///
    /// - Parameter mode: The game mode whose levels to load.
    /// - Returns: Array of decoded `Level` objects.
    /// - Throws: `LevelLoadingError` if the resource is missing or malformed.
    private func loadLevels(for mode: GameMode) throws -> [Level] {
        guard let url = Bundle.main.url(forResource: mode.levelResourceName, withExtension: "json") else {
            throw LevelLoadingError.resourceNotFound(mode.levelResourceName)
        }

        let data: Data
        do {
            data = try Data(contentsOf: url)
        } catch {
            throw LevelLoadingError.fileReadFailed(mode.levelResourceName, error.localizedDescription)
        }

        do {
            let group = try JSONDecoder().decode(LevelGroup.self, from: data)
            return group.levels
        } catch {
            throw LevelLoadingError.decodingFailed(mode.levelResourceName, error.localizedDescription)
        }
    }

    /// Restores completed level progress from UserDefaults for all modes.
    private func loadCompletedLevels() {
        for mode in GameMode.allCases {
            completedLevels[mode] = UserDefaults.standard.integer(forKey: mode.completionKey)
        }
    }

    // MARK: - Level Queries

    /// Returns all levels for the given game mode.
    func levels(for mode: GameMode) -> [Level] {
        levelCache[mode] ?? []
    }

    /// Returns a specific level by its 1-based number within a game mode.
    ///
    /// - Parameters:
    ///   - mode: The game mode.
    ///   - number: The 1-based level number.
    /// - Returns: The level if found, `nil` otherwise.
    func level(for mode: GameMode, number: Int) -> Level? {
        let allLevels = levels(for: mode)
        guard number >= 1, number <= allLevels.count else { return nil }
        return allLevels[number - 1]
    }

    /// Returns the highest completed level number for the given mode (0 if none).
    func completedLevel(for mode: GameMode) -> Int {
        completedLevels[mode] ?? 0
    }

    /// Checks whether a level is locked (not yet reachable by the player).
    ///
    /// A level is locked if its number exceeds the next playable level
    /// (i.e., `number > completedLevel + 1`).
    func isLevelLocked(mode: GameMode, number: Int) -> Bool {
        number > completedLevel(for: mode) + 1
    }

    /// Checks whether a next level exists after the given level number.
    func hasNextLevel(mode: GameMode, after number: Int) -> Bool {
        levels(for: mode).count > number
    }

    // MARK: - Level Completion

    /// Records a level as completed, advancing progress if it's the furthest level beaten.
    ///
    /// Only updates if `number` exceeds the current highest completed level,
    /// preventing regression of progress.
    ///
    /// - Parameters:
    ///   - mode: The game mode the level belongs to.
    ///   - number: The 1-based level number that was completed.
    func completeLevel(mode: GameMode, number: Int) {
        let current = completedLevel(for: mode)
        if number > current {
            completedLevels[mode] = number
            UserDefaults.standard.set(number, forKey: mode.completionKey)

            // Update Home Screen widget with latest progress
            WidgetCenter.shared.reloadAllTimelines()
        }
    }
}

// MARK: - Error Types

/// Errors that can occur during level data loading.
///
/// Captured per-mode in `GameManager.levelLoadingErrors` for diagnostics
/// without crashing the app when a single mode's data is unavailable.
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
