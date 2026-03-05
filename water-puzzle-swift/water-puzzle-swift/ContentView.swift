import SwiftUI

/// Navigation route identifiers for the app flow:
/// MainMenu → DifficultySelect → LevelGrid → Gameplay
enum AppScreen: Hashable {
    case mainMenu
    case difficultySelect
    case levelGrid(GameMode)
    case gameplay(GameMode, Level)
}

/// Level needs Hashable conformance for NavigationPath.
/// Two levels are considered equal if they have the same level number.
extension Level: Hashable {
    nonisolated static func == (lhs: Level, rhs: Level) -> Bool {
        lhs.no == rhs.no
    }

    nonisolated func hash(into hasher: inout Hasher) {
        hasher.combine(no)
    }
}

/// Root content view with NavigationStack-based routing.
/// Mirrors the Unity scene flow: Loading → MainMenu → Main (game).
struct ContentView: View {
    @State private var path = NavigationPath()
    @State private var gameManager = GameManager.shared

    var body: some View {
        NavigationStack(path: $path) {
            MainMenuView(path: $path)
                .navigationDestination(for: AppScreen.self) { screen in
                    switch screen {
                    case .mainMenu:
                        MainMenuView(path: $path)
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
