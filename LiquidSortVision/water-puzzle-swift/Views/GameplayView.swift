import SwiftUI

/// Gameplay screen with world-themed toolbar and HUD.
///
/// Uses the world's theme color in the navigation bar and displays
/// the world/level context prominently. Toolbar buttons use the same
/// visual language as the rest of the UI.
struct GameplayView: View {
    let stage: Stage
    let level: Level
    @Binding var path: NavigationPath
    @Environment(GameManager.self) private var gameManager
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var engine: GameEngine?
    @State private var showLevelComplete = false
    @State private var completionMoves: Int = 0

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
                    moveCount: completionMoves,
                    parMoves: gameManager.optimalMoveCount(for: level.number),
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
                    Label("Home", systemImage: "house.fill")
                }
                .accessibilityHint("Returns to main menu")
                .keyboardShortcut("h", modifiers: .command)
            }

            // Move counter in center
            ToolbarItem(placement: .principal) {
                if let engine, engine.gameState == .playing {
                    HStack(spacing: 6) {
                        Image(systemName: "arrow.left.arrow.right")
                            .font(.caption)
                            .foregroundStyle(stage.themeColor)
                        Text("\(engine.moveCount)")
                            .font(.system(.body, design: .rounded, weight: .bold))
                            .monospacedDigit()
                            .contentTransition(.numericText())
                        Text("moves")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
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
            completionMoves = gameEngine.moveCount
            showLevelComplete = true
        }
        gameEngine.onSaveProgress = { levelNumber, moves in
            gameManager.completeLevel(number: levelNumber, moves: moves)
        }

        gameEngine.setup()
        engine = gameEngine
    }
}
