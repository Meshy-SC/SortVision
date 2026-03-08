import SwiftUI

/// Level selection grid — native Apple layout.
///
/// Uses a `LazyVGrid` inside a `ScrollView` with system background
/// and a prominent navigation title. Level tiles use native button styles.
struct LevelGridView: View {
    @Environment(GameManager.self) private var gameManager
    @Binding var path: NavigationPath
    let gameMode: GameMode

    private let columns = Array(repeating: GridItem(.flexible(), spacing: 12), count: 5)

    var body: some View {
        Group {
            if let error = gameManager.levelLoadingErrors[gameMode] {
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
                ScrollView {
                    LazyVGrid(columns: columns, spacing: 12) {
                        let levels = gameManager.levels(for: gameMode)
                        ForEach(levels) { level in
                            LevelTileView(
                                levelNumber: level.number,
                                isLocked: gameManager.isLevelLocked(
                                    mode: gameMode, number: level.number),
                                isCompleted: level.number <= gameManager.completedLevel(
                                    for: gameMode)
                            ) {
                                path.append(AppScreen.gameplay(gameMode, level))
                            }
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                }
            }
        }
        .navigationTitle("\(gameMode.displayName)")
        #if os(iOS)
        .navigationBarTitleDisplayMode(.large)
        #endif
    }
}

