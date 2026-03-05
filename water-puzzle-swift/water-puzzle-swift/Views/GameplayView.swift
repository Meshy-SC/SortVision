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

            // HUD overlay — mirrors Unity Game/UIManager buttons
            VStack {
                HStack(spacing: 16) {
                    // Menu/Home button — mirrors Unity ic_menu
                    Button {
                        path.removeLast(path.count)
                    } label: {
                        Image(systemName: "house.fill")
                            .font(.title3)
                            .foregroundStyle(.white.opacity(0.85))
                            .frame(width: 44, height: 44)
                            .background(Circle().fill(.white.opacity(0.1)))
                    }

                    Spacer()

                    // Level number text — mirrors Unity UIManager level text
                    Text("Level \(level.no)")
                        .font(.system(size: 20, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)

                    Spacer()

                    // Restart button — mirrors Unity ic_replay
                    Button {
                        showLevelComplete = false
                        scene?.restart()
                    } label: {
                        Image(systemName: "arrow.counterclockwise")
                            .font(.title3)
                            .foregroundStyle(.white.opacity(0.85))
                            .frame(width: 44, height: 44)
                            .background(Circle().fill(.white.opacity(0.1)))
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 12)

                Spacer()
            }

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
        gameScene.onLevelComplete = {
            showLevelComplete = true
        }
        scene = gameScene
    }
}
