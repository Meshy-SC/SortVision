import SpriteKit
import SwiftUI

/// Gameplay screen wrapping the SpriteKit GameScene with a HUD overlay.
/// Mirrors Unity's Game scene with UIManager HUD buttons.
struct GameplayView: View {
    let gameMode: GameMode
    let level: Level
    @Binding var path: NavigationPath
    @Environment(GameManager.self) private var gameManager
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var scene: GameScene?
    @State private var showLevelComplete = false

    var body: some View {
        ZStack {
            // SpriteKit game scene
            if let scene {
                SpriteView(scene: scene)
                    .ignoresSafeArea()
                    .accessibilityLabel("Water sort puzzle, level \(level.number)")
                    .accessibilityHint("Tap tubes to select and pour water between them")
            } else {
                Color(red: 0.12, green: 0.15, blue: 0.22)
                    .ignoresSafeArea()
            }

            // HUD overlay — extracted to GameHUDView for single responsibility
            GameHUDView(
                levelNumber: level.number,
                onHome: {
                    path.removeLast(path.count)
                },
                onRestart: {
                    showLevelComplete = false
                    scene?.restart()
                }
            )

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
                        : .opacity.combined(with: .scale(scale: 0.9))
                )
            }
        }
        .animation(
            reduceMotion ? .none : .easeInOut(duration: 0.3),
            value: showLevelComplete
        )
        .navigationBarBackButtonHidden(true)
        #if os(iOS)
        .sensoryFeedback(.success, trigger: showLevelComplete)
        #endif
        .onAppear {
            if scene == nil {
                createScene()
            }
        }
    }

    private func createScene() {
        let gameScene = GameScene(size: CGSize(width: 750, height: 1334))
        gameScene.scaleMode = .aspectFill
        gameScene.level = level
        gameScene.gameMode = gameMode
        gameScene.reduceMotion = reduceMotion

        // Bridge SpriteKit callbacks to SwiftUI layer
        gameScene.onLevelComplete = {
            showLevelComplete = true
        }
        gameScene.onSaveProgress = { mode, number in
            gameManager.completeLevel(mode: mode, number: number)
        }

        scene = gameScene
    }
}
