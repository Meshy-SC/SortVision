import Foundation

/// Shared data access layer for the Widget extension.
///
/// Since widgets run in a separate process and cannot access `GameManager` directly,
/// this helper reads level completion data from the shared `UserDefaults`
/// (using the same keys as `GameManager`).
///
/// ## Usage
/// Used by `WaterPuzzleWidget` to display the next playable level and current stage.
///
/// ## Note
/// If you later adopt App Groups for cross-process data sharing,
/// update the `UserDefaults` suite here and in `GameManager`.
enum WidgetDataProvider {

    /// Returns the highest completed global level number.
    /// Reads from the same UserDefaults key used by `GameManager`.
    static func completedLevel() -> Int {
        UserDefaults.standard.integer(forKey: GameManager.completionKey)
    }

    /// Returns the next playable global level number (completed + 1).
    static func nextLevelNumber() -> Int {
        completedLevel() + 1
    }

    /// Returns the stage the player is currently in.
    static func currentStage() -> Stage {
        let completed = completedLevel()
        if completed == 0 { return .iron }
        return Stage.stage(for: completed) ?? .iron
    }

    /// Summary data for the player's overall game progress, used by the widget.
    struct GameProgress: Sendable {
        let completedCount: Int
        let currentStage: Stage
        let nextLevel: Int

        /// Whether all currently available levels are completed.
        var isAllComplete: Bool {
            let totalAvailable = Stage.allCases
                .filter(\.isAvailable)
                .count * Stage.levelsPerStage
            return completedCount >= totalAvailable
        }

        /// Number of completed levels within the current stage.
        var stageCompletedCount: Int {
            let range = currentStage.levelRange
            if completedCount < range.lowerBound { return 0 }
            return min(completedCount - range.lowerBound + 1, Stage.levelsPerStage)
        }

        /// Progress within the current stage from 0.0 to 1.0.
        var stageProgress: Double {
            Double(stageCompletedCount) / Double(Stage.levelsPerStage)
        }
    }

    /// Returns progress data for the player's current game state.
    static func progress() -> GameProgress {
        let completed = completedLevel()
        return GameProgress(
            completedCount: completed,
            currentStage: currentStage(),
            nextLevel: completed + 1
        )
    }
}
