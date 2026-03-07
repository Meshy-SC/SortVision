import SwiftUI

/// Navigation route identifiers for the app flow:
/// MainMenu → DifficultySelect → LevelGrid → Gameplay
enum AppScreen: Hashable {
    case difficultySelect
    case levelGrid(GameMode)
    case gameplay(GameMode, Level)
}

/// Level needs Hashable conformance for NavigationPath.
/// Two levels are equal if they have the same number AND the same map data.
extension Level: Hashable {
    nonisolated static func == (lhs: Level, rhs: Level) -> Bool {
        lhs.no == rhs.no && lhs.map == rhs.map
    }

    nonisolated func hash(into hasher: inout Hasher) {
        hasher.combine(no)
        hasher.combine(map)
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
