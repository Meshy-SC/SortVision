import SwiftUI

/// Level selection grid. Mirrors Unity's LevelsPanel with LevelTile buttons.
/// Shows level number, lock state (locked/available/completed) per tile.
struct LevelGridView: View {
    @Environment(GameManager.self) private var gameManager
    @Binding var path: NavigationPath
    let gameMode: GameMode

    private let columns = Array(repeating: GridItem(.flexible(), spacing: 12), count: 5)

    var body: some View {
        ZStack {
            Color.clear
                .gameBackground()

            if let error = gameManager.levelLoadingErrors[gameMode] {
                // User-facing error state when level data fails to load
                ContentUnavailableView {
                    Label("Levels Unavailable", systemImage: "exclamationmark.triangle.fill")
                } description: {
                    Text(error.localizedDescription)
                } actions: {
                    Button("Go Back") {
                        path.removeLast()
                    }
                    .buttonStyle(.borderedProminent)
                }
            } else {
                VStack(spacing: 16) {
                    Text("\(gameMode.displayName) Levels")
                        .font(.system(.title2, design: .rounded, weight: .bold))
                        .foregroundStyle(.white)
                        .padding(.top, 20)
                        .accessibilityAddTraits(.isHeader)

                    ScrollView {
                        LazyVGrid(columns: columns, spacing: 12) {
                            let levels = gameManager.levels(for: gameMode)
                            ForEach(levels) { level in
                                LevelTileView(
                                    levelNumber: level.number,
                                    isLocked: gameManager.isLevelLocked(
                                        mode: gameMode, number: level.number),
                                    isCompleted: level.number <= gameManager.completedLevel(for: gameMode)
                                ) {
                                    path.append(AppScreen.gameplay(gameMode, level))
                                }
                            }
                        }
                        .padding(.horizontal, 16)
                        .padding(.bottom, 20)
                    }
                }
            }
        }
        .navigationTitle("\(gameMode.displayName) Levels")
        #if os(iOS)
        .toolbarVisibility(.hidden, for: .navigationBar)
        #endif
    }
}

