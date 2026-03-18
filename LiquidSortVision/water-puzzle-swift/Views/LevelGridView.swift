import SwiftUI

/// Level selection grid with a world header card.
///
/// Displays a prominent world header with progress gauge, followed
/// by a `LazyVGrid` of level tiles. Matches the Pushbox visual style.
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
                    .controlSize(.large)
                }
            } else {
                ScrollView {
                    VStack(spacing: 16) {
                        // World header card
                        let levels = gameManager.levels(for: stage)
                        let completedInStage = gameManager.completedCountInStage(stage)

                        WorldHeaderView(
                            stage: stage,
                            completed: completedInStage,
                            total: levels.count,
                            totalStars: totalStarsInStage,
                            maxStars: levels.count * 3
                        )

                        // Level grid
                        LazyVGrid(columns: columns, spacing: 12) {
                            ForEach(levels) { level in
                                let displayNumber = Stage.localLevelNumber(for: level.number)
                                LevelTileView(
                                    levelNumber: displayNumber,
                                    isLocked: gameManager.isLevelLocked(level.number),
                                    isCompleted: level.number <= gameManager.completedLevel,
                                    starRating: gameManager.starRating(for: level.number),
                                    themeColor: stage.themeColor
                                ) {
                                    path.append(AppScreen.gameplay(stage, level))
                                }
                            }
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                }
                .background(.background.secondary)
            }
        }
        .navigationTitle(stage.displayName)
        #if os(iOS)
        .navigationBarTitleDisplayMode(.large)
        #endif
    }

    // MARK: - Computed

    /// Total stars earned across all levels in this stage.
    private var totalStarsInStage: Int {
        gameManager.levels(for: stage).reduce(0) { sum, level in
            sum + gameManager.starRating(for: level.number)
        }
    }
}
