import Foundation

/// Persistence layer for player progress data.
///
/// Encapsulates all `UserDefaults` read/write operations for:
/// - Global level completion tracking
/// - Per-level best move counts
/// - Per-level star ratings
/// - Sound preference
///
/// ## Architecture
/// Extracted from `GameManager` to follow the Single Responsibility Principle.
/// `GameManager` delegates all persistence to this store, keeping itself
/// focused on game logic, level queries, and state management.
///
/// ## Thread Safety
/// All access is `@MainActor`-isolated, matching `GameManager`'s isolation.
@MainActor
enum ProgressStore {

    // MARK: - UserDefaults Keys

    /// Key for the sound-enabled preference.
    static let soundEnabledKey = "soundEnabled"

    /// Key for the highest completed global level number.
    static let completionKey = "globalLevelCompleted"

    /// Key for per-level best move counts dictionary.
    static let bestMovesKey = "bestMoves"

    /// Key for per-level star ratings dictionary.
    static let starRatingsKey = "starRatings"

    /// Key for tracking whether legacy migration has been performed.
    static let migrationKey = "stage_progress_migrated"

    // MARK: - Sound Preference

    /// Loads the sound-enabled preference, defaulting to `true` on first launch.
    static func loadSoundPreference() -> Bool {
        if UserDefaults.standard.object(forKey: soundEnabledKey) == nil {
            UserDefaults.standard.set(true, forKey: soundEnabledKey)
        }
        return UserDefaults.standard.bool(forKey: soundEnabledKey)
    }

    /// Saves the sound-enabled preference.
    static func saveSoundPreference(_ enabled: Bool) {
        UserDefaults.standard.set(enabled, forKey: soundEnabledKey)
    }

    // MARK: - Level Completion

    /// Loads the highest completed global level number.
    static func loadCompletedLevel() -> Int {
        UserDefaults.standard.integer(forKey: completionKey)
    }

    /// Saves the highest completed global level number.
    static func saveCompletedLevel(_ level: Int) {
        UserDefaults.standard.set(level, forKey: completionKey)
    }

    // MARK: - Best Moves & Star Ratings

    /// Loads per-level best move counts from UserDefaults.
    ///
    /// - Returns: Dictionary mapping global level numbers to best move counts.
    static func loadBestMoves() -> [Int: Int] {
        loadIntDict(forKey: bestMovesKey)
    }

    /// Loads per-level star ratings from UserDefaults.
    ///
    /// - Returns: Dictionary mapping global level numbers to star ratings (0–3).
    static func loadStarRatings() -> [Int: Int] {
        loadIntDict(forKey: starRatingsKey)
    }

    /// Shared helper to load a `[String: Int]` dictionary from UserDefaults
    /// and convert it to `[Int: Int]`, discarding non-integer keys.
    private static func loadIntDict(forKey key: String) -> [Int: Int] {
        guard let dict = UserDefaults.standard.dictionary(forKey: key) as? [String: Int]
        else { return [:] }
        return dict.reduce(into: [:]) { result, pair in
            guard let intKey = Int(pair.key) else { return }
            result[intKey] = pair.value
        }
    }

    /// Saves best moves and star ratings to UserDefaults.
    ///
    /// - Parameters:
    ///   - bestMoves: Dictionary mapping global level numbers to best move counts.
    ///   - starRatings: Dictionary mapping global level numbers to star ratings.
    static func saveBestMovesAndRatings(
        bestMoves: [Int: Int],
        starRatings: [Int: Int]
    ) {
        let movesDict = Dictionary(uniqueKeysWithValues: bestMoves.map { (String($0.key), $0.value) })
        let starsDict = Dictionary(uniqueKeysWithValues: starRatings.map { (String($0.key), $0.value) })
        UserDefaults.standard.set(movesDict, forKey: bestMovesKey)
        UserDefaults.standard.set(starsDict, forKey: starRatingsKey)
    }

    // MARK: - Legacy Migration

    /// Migrates from the old per-difficulty progress system to global progression.
    ///
    /// Old keys: `"easy_Level_Complete"`, `"normal_Level_Complete"`, etc.
    /// Maps completed counts to global level numbers:
    /// Easy 1–100 → Global 1–100, Normal 1–100 → Global 101–200, etc.
    ///
    /// - Returns: `true` if migration was performed, `false` if already migrated.
    @discardableResult
    static func migrateFromLegacyProgress() -> Bool {
        guard !UserDefaults.standard.bool(forKey: migrationKey) else { return false }

        let legacyModes: [(key: String, offset: Int)] = [
            ("easy_Level_Complete", 0),
            ("normal_Level_Complete", 100),
            ("hard_Level_Complete", 200),
            ("expert_Level_Complete", 300),
        ]

        let maxGlobal = legacyModes.reduce(0) { result, mode in
            let completed = UserDefaults.standard.integer(forKey: mode.key)
            return completed > 0 ? max(result, mode.offset + completed) : result
        }

        if maxGlobal > 0 {
            UserDefaults.standard.set(maxGlobal, forKey: completionKey)
        }

        UserDefaults.standard.set(true, forKey: migrationKey)
        return true
    }

    // MARK: - Reset

    /// Clears all progress data (completion, best moves, star ratings).
    static func resetAllProgress() {
        UserDefaults.standard.set(0, forKey: completionKey)
        UserDefaults.standard.removeObject(forKey: bestMovesKey)
        UserDefaults.standard.removeObject(forKey: starRatingsKey)
    }
}
