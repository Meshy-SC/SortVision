import Foundation

/// Shared data access layer for the Widget extension.
///
/// Since widgets run in a separate process and cannot access `GameManager` directly,
/// this helper reads level completion data from the shared `UserDefaults`
/// (using the same keys as `GameManager`).
///
/// ## Usage
/// Used by `WaterPuzzleWidget` to display the next playable level per difficulty.
///
/// ## Note
/// If you later adopt App Groups for cross-process data sharing,
/// update the `UserDefaults` suite here and in `GameManager`.
enum WidgetDataProvider {
    /// Returns the highest completed level number for the given mode.
    /// Reads from the same UserDefaults keys used by `GameManager`.
    static func completedLevel(for mode: GameMode) -> Int {
        UserDefaults.standard.integer(forKey: mode.completionKey)
    }

    /// Returns the next playable level number (completed + 1).
    static func nextLevelNumber(for mode: GameMode) -> Int {
        completedLevel(for: mode) + 1
    }

    /// Summary data for a single difficulty, used by the widget.
    struct DifficultyProgress: Sendable {
        let mode: GameMode
        let completedCount: Int
        let nextLevel: Int
        let totalLevels: Int

        var isAllComplete: Bool { completedCount >= totalLevels }

        /// Progress ratio from 0.0 to 1.0.
        var progress: Double {
            guard totalLevels > 0 else { return 0 }
            return Double(completedCount) / Double(totalLevels)
        }
    }

    /// Returns progress data for a given mode.
    ///
    /// `totalLevels` is provided as a parameter since the widget cannot
    /// decode the level JSON files from the main bundle easily.
    static func progress(for mode: GameMode, totalLevels: Int) -> DifficultyProgress {
        let completed = completedLevel(for: mode)
        return DifficultyProgress(
            mode: mode,
            completedCount: completed,
            nextLevel: completed + 1,
            totalLevels: totalLevels
        )
    }
}
