import SwiftUI

/// Level selection grid with progress gauges and group-based unlocking.
///
/// Displays circular stat gauges (Progress + Stars) at the top
/// followed by a scrollable grid of level cells.
/// Mirrors ParkVision's `GameModeLevelsView` pattern.
struct LevelGridView: View {
    @Environment(GameManager.self) private var gameManager
    @Binding var path: NavigationPath
    let stage: Stage

    private let columns = [GridItem(.adaptive(minimum: 72), spacing: 14)]

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
                    VStack(spacing: 20) {
                        // Per-world gauges
                        gaugesSection

                        // Levels grid
                        levelsGrid
                    }
                    .padding()
                }
            }
        }
        .navigationTitle(stage.displayName)
        #if os(iOS)
        .navigationBarTitleDisplayMode(.large)
        #endif
    }

    // MARK: - Gauges Section

    private var gaugesSection: some View {
        let total = gameManager.levels(for: stage).count
        let completedInStage = gameManager.completedCountInStage(stage)

        return HStack(spacing: 30) {
            CircularStatGauge(
                title: "Progress",
                value: total > 0 ? Double(completedInStage) / Double(total) * 100 : 0,
                maxValue: 100,
                tintColor: .green
            )
            CircularStatGauge(
                title: "Stars",
                value: Double(totalStarsInStage),
                maxValue: Double(total * 3),
                tintColor: .yellow
            )
        }
    }

    // MARK: - Levels Grid

    private var levelsGrid: some View {
        let levels = gameManager.levels(for: stage)

        return LazyVGrid(columns: columns, spacing: 14) {
            ForEach(levels) { level in
                let displayNumber = Stage.localLevelNumber(for: level.number)
                let star = gameManager.starRating(for: level.number)
                let isLocked = gameManager.isLevelLocked(level.number)

                LevelTileView(
                    levelNumber: displayNumber,
                    isLocked: isLocked,
                    starRating: star,
                    themeColor: stage.themeColor,
                    lockMessage: "Complete more levels to unlock this level."
                ) {
                    guard !isLocked else { return }
                    path.append(AppScreen.gameplay(stage, level))
                }
                .id("level-\(level.id)")
            }
        }
        .accessibilityRotor("Incomplete Levels") {
            ForEach(levels) { level in
                let star = gameManager.starRating(for: level.number)
                if star == 0 {
                    let displayNumber = Stage.localLevelNumber(for: level.number)
                    AccessibilityRotorEntry(
                        "Level \(displayNumber)",
                        id: "level-\(level.id)"
                    )
                }
            }
        }
    }

    // MARK: - Computed

    /// Total stars earned across all levels in this stage.
    private var totalStarsInStage: Int {
        gameManager.levels(for: stage).reduce(0) { sum, level in
            sum + gameManager.starRating(for: level.number)
        }
    }
}
