import SpriteKit
import SwiftUI

/// Gameplay screen wrapping the SpriteKit GameScene with a HUD overlay.
/// Mirrors Unity's Game scene with UIManager HUD buttons.
struct GameplayView: View {
    let gameMode: GameMode
    let level: Level
    @Binding var path: NavigationPath
    @Environment(GameManager.self) private var gameManager

    @State private var scene: GameScene?
    @State private var showLevelComplete = false

    var body: some View {
        ZStack {
            // SpriteKit game scene
            if let scene {
                SpriteView(scene: scene)
                    .ignoresSafeArea()
            } else {
                Color(red: 0.12, green: 0.15, blue: 0.22)
                    .ignoresSafeArea()
            }

            // HUD overlay — extracted to GameHUDView for single responsibility
            GameHUDView(
                levelNumber: level.no,
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
                LevelCompleteView(
                    gameMode: gameMode,
                    levelNumber: level.no,
                    path: $path
                )
                .transition(.opacity.combined(with: .scale(scale: 0.9)))
            }
        }
        .animation(.easeInOut(duration: 0.3), value: showLevelComplete)
        .navigationBarBackButtonHidden(true)
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
