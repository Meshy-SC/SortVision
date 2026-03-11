import SwiftUI

/// Gameplay screen — native toolbar-based HUD with system background.
///
/// Uses a standard `toolbar` for Home/Restart controls. The game
/// scene fills the available space.
struct GameplayView: View {
    let gameMode: GameMode
    let level: Level
    @Binding var path: NavigationPath
    @Environment(GameManager.self) private var gameManager
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var engine: GameEngine?
    @State private var showLevelComplete = false

    var body: some View {
        ZStack {
            // Game scene
            if let engine {
                GameSceneView(engine: engine)
                    .padding()
                    .accessibilityLabel("Water sort puzzle, level \(level.number)")
                    .accessibilityHint("Tap tubes to select and pour water between them")
            } else {
                ProgressView("Loading…")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }

            // Level complete overlay
            if showLevelComplete {
                LevelCompletionOverlay(
                    gameMode: gameMode,
                    levelNumber: level.number,
                    path: $path
                )
                .transition(
                    reduceMotion
                        ? .opacity
                        : .opacity.combined(with: .scale(scale: 0.92))
                )
            }
        }
        .animation(
            reduceMotion ? .none : .spring(.bouncy),
            value: showLevelComplete
        )
        .navigationTitle("Level \(level.number)")
        .navigationBarBackButtonHidden(true)
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button {
                    path.removeLast(path.count)
                } label: {
                    Label("Home", systemImage: "house")
                }
                .accessibilityHint("Returns to main menu")
                .keyboardShortcut("h", modifiers: .command)
            }

            ToolbarItem(placement: .primaryAction) {
                Button {
                    showLevelComplete = false
                    engine?.restart()
                } label: {
                    Label("Restart", systemImage: "arrow.counterclockwise")
                }
                .accessibilityHint("Resets the current puzzle")
                .keyboardShortcut("r", modifiers: .command)
            }
        }
        #if os(iOS)
        .sensoryFeedback(.success, trigger: showLevelComplete)
        #endif
        .onAppear {
            if engine == nil {
                createEngine()
            }
        }
    }

    private func createEngine() {
        let gameEngine = GameEngine()
        gameEngine.level = level
        gameEngine.gameMode = gameMode
        gameEngine.reduceMotion = reduceMotion

        gameEngine.onLevelComplete = {
            showLevelComplete = true
        }
        gameEngine.onSaveProgress = { mode, number in
            gameManager.completeLevel(mode: mode, number: number)
        }

        gameEngine.setup()
        engine = gameEngine
    }
}
