import SwiftUI

/// Root navigation view with `NavigationStack`-based routing.
///
/// Manages the app's navigation stack and provides `GameManager`
/// to the entire view hierarchy via `@Environment`.
///
/// ## Navigation Flow
/// ```
/// MainMenu → DifficultySelection → LevelGrid → Gameplay
/// ```
///
/// Route definitions live in `Navigation/AppScreen.swift`.
///
/// ## Deep Link Support
/// Handles navigation requests from App Intents, Shortcuts, and Widgets
/// via `DeepLinkManager.shared.pendingLevel`. Also handles `waterpuzzle://` URLs.
struct RootNavigationView: View {
    @State private var path = NavigationPath()
    @State private var gameManager = GameManager.shared
    @State private var deepLinkManager = DeepLinkManager.shared

    var body: some View {
        NavigationStack(path: $path) {
            MainMenuView(path: $path)
                .navigationDestination(for: AppScreen.self) { screen in
                    switch screen {
                    case .difficultySelect:
                        DifficultySelectionView(path: $path)
                    case .levelGrid(let mode):
                        LevelGridView(path: $path, gameMode: mode)
                    case .gameplay(let mode, let level):
                        GameplayView(gameMode: mode, level: level, path: $path)
                    }
                }
        }
        .environment(gameManager)
        .onOpenURL { url in
            handleDeepLink(url)
        }
        .onChange(of: deepLinkManager.pendingLevel?.number) { _, _ in
            handlePendingDeepLink()
        }
        .onAppear {
            handlePendingDeepLink()
        }
    }

    // MARK: - Deep Link Handling

    /// Handles `waterpuzzle://play?mode=0&level=5` URLs from widgets.
    private func handleDeepLink(_ url: URL) {
        guard url.scheme == "waterpuzzle",
              url.host == "play",
              let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
              let modeStr = components.queryItems?.first(where: { $0.name == "mode" })?.value,
              let modeRaw = Int(modeStr),
              let mode = GameMode(rawValue: modeRaw),
              let levelStr = components.queryItems?.first(where: { $0.name == "level" })?.value,
              let levelNum = Int(levelStr),
              let level = gameManager.level(for: mode, number: levelNum),
              !gameManager.isLevelLocked(mode: mode, number: levelNum)
        else { return }

        navigateToLevel(mode: mode, level: level)
    }

    /// Handles navigation requests from App Intents via `DeepLinkManager`.
    private func handlePendingDeepLink() {
        guard let pending = deepLinkManager.pendingLevel,
              let level = gameManager.level(for: pending.mode, number: pending.number)
        else { return }

        deepLinkManager.pendingLevel = nil
        navigateToLevel(mode: pending.mode, level: level)
    }

    /// Navigates the stack to a specific gameplay level.
    private func navigateToLevel(mode: GameMode, level: Level) {
        // Clear existing stack and push the full navigation path
        path = NavigationPath()
        Task {
            try? await Task.sleep(for: .milliseconds(100))
            path.append(AppScreen.difficultySelect)
            path.append(AppScreen.levelGrid(mode))
            path.append(AppScreen.gameplay(mode, level))
        }
    }
}
