import SwiftUI

/// Gameplay screen — native toolbar-based HUD with system background.
///
/// Uses a standard `toolbar` for Home/Restart controls. The game
/// scene fills the available space.
struct GameplayView: View {
    let stage: Stage
    let level: Level
    @Binding var path: NavigationPath
    @Environment(GameManager.self) private var gameManager
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var engine: GameEngine?
    @State private var showLevelComplete = false

    private var localNumber: Int {
        Stage.localLevelNumber(for: level.number)
    }

    var body: some View {
        ZStack {
            // Game scene
            if let engine {
                GameSceneView(engine: engine)
                    .padding()
                    .accessibilityLabel("Water sort puzzle, \(stage.displayName) level \(localNumber)")
                    .accessibilityHint("Tap tubes to select and pour water between them")
            } else {
                ProgressView("Loading…")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }

            // Level complete overlay
            if showLevelComplete {
                LevelCompletionOverlay(
                    stage: stage,
                    level: level,
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
        .navigationTitle("\(stage.displayName) • Level \(localNumber)")
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
        gameEngine.reduceMotion = reduceMotion

        gameEngine.onLevelComplete = {
            showLevelComplete = true
        }
        gameEngine.onSaveProgress = { levelNumber in
            gameManager.completeLevel(number: levelNumber)
        }

        gameEngine.setup()
        engine = gameEngine
    }
}
