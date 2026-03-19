import SwiftUI

/// Centralised level navigation logic used by gameplay views,
/// the completion overlay, and deep link handling.
///
/// Eliminates duplicated navigation code that previously existed in
/// `GameplayView`, `LevelCompletionOverlay`, and `RootNavigationView`.
///
/// ## Usage
/// ```swift
/// let navigator = LevelNavigator(path: $path, gameManager: gameManager)
/// navigator.goToNextLevel(after: currentLevel, in: currentStage)
/// ```
@MainActor
struct LevelNavigator {

    // MARK: - Dependencies

    @Binding var path: NavigationPath
    let gameManager: GameManager

    // MARK: - Navigation Actions

    /// Navigates to the previous level relative to the given global number.
    ///
    /// Handles cross-stage transitions (e.g., from Bronze level 1 back to Iron level 100)
    /// by resetting the navigation stack and re-pushing the full path.
    ///
    /// - Parameters:
    ///   - currentLevel: The level the player is currently on.
    ///   - currentStage: The stage the player is currently in.
    func goToPreviousLevel(from currentLevel: Level, in currentStage: Stage) {
        let prevGlobalNumber = currentLevel.number - 1
        guard let prevLevel = gameManager.level(globalNumber: prevGlobalNumber),
              let prevStage = Stage.stage(for: prevGlobalNumber)
        else { return }

        navigateToLevel(prevLevel, in: prevStage, from: currentStage)
    }

    /// Navigates to the next level relative to the given global number.
    ///
    /// Handles cross-stage transitions (e.g., from Iron level 100 to Bronze level 1)
    /// by resetting the navigation stack and re-pushing the full path.
    ///
    /// - Parameters:
    ///   - currentLevel: The level the player just completed or is navigating from.
    ///   - currentStage: The stage the player is currently in.
    func goToNextLevel(after currentLevel: Level, in currentStage: Stage) {
        let nextGlobalNumber = currentLevel.number + 1
        guard let nextLevel = gameManager.level(globalNumber: nextGlobalNumber),
              let nextStage = Stage.stage(for: nextGlobalNumber)
        else { return }

        navigateToLevel(nextLevel, in: nextStage, from: currentStage)
    }

    /// Navigates directly to a specific level, used by deep link handling.
    ///
    /// Always resets the navigation stack and pushes the full path
    /// (stage grid → gameplay) to ensure a consistent back-navigation experience.
    ///
    /// - Parameters:
    ///   - level: The target level.
    ///   - stage: The stage containing the target level.
    func navigateViaDeepLink(to level: Level, in stage: Stage) {
        path = NavigationPath()
        Task {
            try? await Task.sleep(for: .milliseconds(100))
            path.append(AppScreen.levelGrid(stage))
            path.append(AppScreen.gameplay(stage, level))
        }
    }

    /// Navigates back to the root (main menu).
    func goToMainMenu() {
        path.removeLast(path.count)
    }

    // MARK: - Private Helpers

    /// Navigates to a level, handling same-stage vs. cross-stage transitions.
    ///
    /// - Same stage: Replaces the current gameplay screen on the stack.
    /// - Cross stage: Resets the stack and pushes the new stage's grid + gameplay.
    private func navigateToLevel(_ level: Level, in targetStage: Stage, from currentStage: Stage) {
        if targetStage == currentStage {
            // Same stage — swap the gameplay screen
            path.removeLast()
            path.append(AppScreen.gameplay(currentStage, level))
        } else {
            // Different stage — reset and push full path
            path.removeLast(path.count)
            Task {
                try? await Task.sleep(for: .milliseconds(100))
                path.append(AppScreen.levelGrid(targetStage))
                path.append(AppScreen.gameplay(targetStage, level))
            }
        }
    }
}
