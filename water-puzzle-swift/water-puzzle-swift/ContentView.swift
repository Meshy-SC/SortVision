import SwiftUI

/// Root content view with `NavigationStack`-based routing.
///
/// Manages the app's navigation stack and provides `GameManager`
/// to the entire view hierarchy via `@Environment`.
///
/// ## Navigation Flow
/// ```
/// MainMenu → DifficultySelect → LevelGrid → Gameplay
/// ```
///
/// Route definitions live in `Navigation/AppScreen.swift`.
struct ContentView: View {
    @State private var path = NavigationPath()
    @State private var gameManager = GameManager.shared

    var body: some View {
        NavigationStack(path: $path) {
            MainMenuView(path: $path)
                .navigationDestination(for: AppScreen.self) { screen in
                    switch screen {
                    case .difficultySelect:
                        DifficultySelectView(path: $path)
                    case .levelGrid(let mode):
                        LevelGridView(path: $path, gameMode: mode)
                    case .gameplay(let mode, let level):
                        GameplayView(gameMode: mode, level: level, path: $path)
                    }
                }
        }
        .environment(gameManager)
    }
}
