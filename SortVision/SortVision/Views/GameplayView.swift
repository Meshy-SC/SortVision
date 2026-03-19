import SwiftUI

/// Gameplay screen with bottom toolbar and in-game gauges.
///
/// Uses the world's theme color in the navigation bar and displays
/// World/Level/Moves gauges. Bottom toolbar provides Previous, Undo,
/// Restart, and Next level buttons in a translucent capsule.
/// Mirrors ParkVision's GameView toolbar pattern.
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
        VStack(spacing: 0) {
            // Game scene
            ZStack {
                if let engine {
                    GameSceneView(engine: engine)
                        .padding()
                        .accessibilityLabel("SortVision puzzle, \(stage.displayName) level \(localNumber)")
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
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            // Bottom toolbar
            if let engine, !showLevelComplete {
                GameToolbar(
                    canGoToPreviousLevel: hasPreviousLevel,
                    canGoToNextLevel: gameManager.hasNextLevel(after: level.number),
                    canUndo: engine.canUndo,
                    onPrevious: { navigateToPreviousLevel() },
                    onRestart: {
                        showLevelComplete = false
                        engine.restart()
                    },
                    onUndo: { engine.undo() },
                    onNext: { navigateToNextLevel() }
                )
                .padding(.horizontal, 20)
                .padding(.bottom, 8)
                .transition(.move(edge: .bottom).combined(with: .opacity))
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

            // Game gauges in center
            ToolbarItem(placement: .principal) {
                if let engine, engine.gameState == .playing {
                    HStack(spacing: 12) {
                        GameGauges(
                            worldNumber: stage.worldNumber,
                            totalWorlds: Stage.allCases.count,
                            levelNumber: localNumber,
                            totalLevels: Stage.levelsPerStage,
                            moveCount: engine.moveCount,
                            optimalMoveCount: gameManager.optimalMoveCount(for: level.number)
                        )
                    }
                }
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

    // MARK: - Engine

    private func createEngine() {
        let gameEngine = GameEngine()
        gameEngine.level = level

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

    // MARK: - Navigation

    private var hasPreviousLevel: Bool {
        level.number > 1
    }

    private func navigateToPreviousLevel() {
        let prevGlobalNumber = level.number - 1
        guard let prevLevel = gameManager.level(globalNumber: prevGlobalNumber),
              let prevStage = Stage.stage(for: prevGlobalNumber)
        else { return }

        showLevelComplete = false
        if prevStage == stage {
            path.removeLast()
            path.append(AppScreen.gameplay(stage, prevLevel))
        } else {
            path.removeLast(path.count)
            Task {
                try? await Task.sleep(for: .milliseconds(100))
                path.append(AppScreen.levelGrid(prevStage))
                path.append(AppScreen.gameplay(prevStage, prevLevel))
            }
        }
    }

    private func navigateToNextLevel() {
        let nextGlobalNumber = level.number + 1
        guard let nextLevel = gameManager.level(globalNumber: nextGlobalNumber),
              let nextStage = Stage.stage(for: nextGlobalNumber)
        else { return }

        showLevelComplete = false
        if nextStage == stage {
            path.removeLast()
            path.append(AppScreen.gameplay(stage, nextLevel))
        } else {
            path.removeLast(path.count)
            Task {
                try? await Task.sleep(for: .milliseconds(100))
                path.append(AppScreen.levelGrid(nextStage))
                path.append(AppScreen.gameplay(nextStage, nextLevel))
            }
        }
    }
}
