import SwiftUI

/// Level selection grid — native Apple layout.
///
/// Uses a `LazyVGrid` inside a `ScrollView` with system background
/// and a prominent navigation title. Level tiles use native button styles.
struct LevelGridView: View {
    @Environment(GameManager.self) private var gameManager
    @Binding var path: NavigationPath
    let stage: Stage

    private let columns = Array(repeating: GridItem(.flexible(), spacing: 12), count: 5)

    var body: some View {
        Group {
            if let error = gameManager.levelLoadingErrors[stage] {
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
                        let levels = gameManager.levels(for: stage)
                        ForEach(levels) { level in
                            let displayNumber = Stage.localLevelNumber(for: level.number)
                            LevelTileView(
                                levelNumber: displayNumber,
                                isLocked: gameManager.isLevelLocked(level.number),
                                isCompleted: level.number <= gameManager.completedLevel
                            ) {
                                path.append(AppScreen.gameplay(stage, level))
                            }
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                }
            }
        }
        .navigationTitle(stage.displayName)
        #if os(iOS)
        .navigationBarTitleDisplayMode(.large)
        #endif
    }
}

