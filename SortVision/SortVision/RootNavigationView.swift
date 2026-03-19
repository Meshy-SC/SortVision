import SwiftUI

/// Root navigation view with `NavigationStack`-based routing.
///
/// Manages the app's navigation stack and provides `GameManager`
/// to the entire view hierarchy via `@Environment`.
///
/// ## Navigation Flow
/// ```
/// StageSelection (root) → LevelGrid → Gameplay
/// ```
///
/// Route definitions live in `Navigation/AppScreen.swift`.
///
/// ## Deep Link Support
/// Handles navigation requests from App Intents, Shortcuts, and Widgets
/// via `DeepLinkManager.shared.pendingLevel`. Also handles `flowvision://` URLs.
struct RootNavigationView: View {
    @State private var path = NavigationPath()
    @State private var gameManager = GameManager.shared
    @State private var deepLinkManager = DeepLinkManager.shared

    var body: some View {
        NavigationStack(path: $path) {
            StageSelectionView()
                .navigationDestination(for: AppScreen.self) { screen in
                    switch screen {
                    case .levelGrid(let stage):
                        LevelGridView(path: $path, stage: stage)
                    case .gameplay(let stage, let level):
                        GameplayView(stage: stage, level: level, path: $path)
                    }
                }
        }
        .environment(gameManager)
        .onOpenURL { url in
            handleDeepLink(url)
        }
        .onChange(of: deepLinkManager.pendingLevel) { _, _ in
            handlePendingDeepLink()
        }
        .onAppear {
            handlePendingDeepLink()
        }
    }

    // MARK: - Deep Link Handling

    /// Handles `flowvision://play?level=5` URLs from widgets.
    private func handleDeepLink(_ url: URL) {
        guard url.scheme == "flowvision",
              url.host == "play",
              let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
              let levelStr = components.queryItems?.first(where: { $0.name == "level" })?.value,
              let levelNum = Int(levelStr),
              let stage = Stage.stage(for: levelNum),
              let level = gameManager.level(globalNumber: levelNum),
              !gameManager.isLevelLocked(levelNum)
        else { return }

        navigateToLevel(stage: stage, level: level)
    }

    /// Handles navigation requests from App Intents via `DeepLinkManager`.
    private func handlePendingDeepLink() {
        guard let globalNumber = deepLinkManager.pendingLevel else { return }
        deepLinkManager.pendingLevel = nil

        guard let stage = Stage.stage(for: globalNumber),
              let level = gameManager.level(globalNumber: globalNumber),
              !gameManager.isLevelLocked(globalNumber)
        else { return }

        navigateToLevel(stage: stage, level: level)
    }

    /// Navigates the stack to a specific gameplay level.
    private func navigateToLevel(stage: Stage, level: Level) {
        // Clear existing stack and push the full navigation path
        path = NavigationPath()
        Task {
            try? await Task.sleep(for: .milliseconds(100))
            path.append(AppScreen.levelGrid(stage))
            path.append(AppScreen.gameplay(stage, level))
        }
    }
}
