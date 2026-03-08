import RealityKit
import SwiftUI

/// Gameplay screen — native toolbar-based HUD with system background.
///
/// Uses a standard `toolbar` for Home/Restart controls instead of a
/// custom overlay. The RealityView fills the safe area.
struct GameplayView: View {
    let gameMode: GameMode
    let level: Level
    @Binding var path: NavigationPath
    @Environment(GameManager.self) private var gameManager
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var scene3D: GameScene3D?
    @State private var showLevelComplete = false

    var body: some View {
        ZStack {
            // 3D game scene
            if let scene3D {
                GameRealityView(scene: scene3D)
                    .ignoresSafeArea(edges: .bottom)
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
                        : .opacity.combined(with: .scale(scale: 0.9))
                )
            }
        }
        .animation(
            reduceMotion ? .none : .easeInOut(duration: 0.3),
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
                    scene3D?.restart()
                } label: {
                    Label("Restart", systemImage: "arrow.counterclockwise")
                }
                .accessibilityHint("Resets the current puzzle")
                .keyboardShortcut("r", modifiers: .command)
            }
        }
        #if os(visionOS)
        .ornament(attachmentAnchor: .scene(.bottom)) {
            HStack(spacing: 20) {
                Button {
                    path.removeLast(path.count)
                } label: {
                    Label("Home", systemImage: "house")
                }
                .accessibilityHint("Returns to main menu")

                Text("Level \(level.number)")
                    .font(.headline)
                    .accessibilityAddTraits(.isHeader)

                Button {
                    showLevelComplete = false
                    scene3D?.restart()
                } label: {
                    Label("Restart", systemImage: "arrow.counterclockwise")
                }
                .accessibilityHint("Resets the current puzzle")
            }
            .buttonStyle(.bordered)
            .padding(.horizontal, 24)
            .padding(.vertical, 12)
            .glassBackgroundEffect()
        }
        #endif
        #if os(iOS)
        .sensoryFeedback(.success, trigger: showLevelComplete)
        #endif
        .onAppear {
            if scene3D == nil {
                createScene()
            }
        }
    }

    private func createScene() {
        let gameScene = GameScene3D()
        gameScene.level = level
        gameScene.gameMode = gameMode
        gameScene.reduceMotion = reduceMotion

        gameScene.onLevelComplete = {
            showLevelComplete = true
        }
        gameScene.onSaveProgress = { mode, number in
            gameManager.completeLevel(mode: mode, number: number)
        }

        gameScene.setup()
        scene3D = gameScene
    }
}
