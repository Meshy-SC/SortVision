// iOSLevelsGridView.swift
// iOS-adapted levels grid that directly selects levels without immersive placement.

#if os(iOS) || os(macOS) || os(tvOS)
import SwiftUI

/// Displays a grid of level buttons for a specific world on iOS.
/// When a level is selected, it directly triggers the game scene (no placement flow).
struct iOSLevelsGridView: View {
    
    @Environment(AppModel.self) private var appModel
    
    /// The world to display levels for.
    let world: World
    
    /// Callback when a level is selected.
    let onLevelSelected: (Int) -> Void
    
    /// Loaded level data.
    @State private var levels: [[String]] = []
    
    /// Whether the initial level load has completed.
    @State private var hasLoaded = false
    
    /// Grid layout – adapts to orientation via vertical size class.
    #if os(tvOS)
    private var columns: [GridItem] { [GridItem(.adaptive(minimum: 140), spacing: 48)] }
    private var gridSpacing: CGFloat { 48 }
    #elseif os(iOS)
    private var columns: [GridItem] {
        [GridItem(.adaptive(minimum: 72), spacing: 16)]
    }
    private var gridSpacing: CGFloat { 16 }
    #else
    private var columns: [GridItem] { [GridItem(.adaptive(minimum: 80), spacing: 14)] }
    private var gridSpacing: CGFloat { 14 }
    #endif
    
    var body: some View {
        Group {
            if !hasLoaded {
                ProgressView()
                    .frame(maxWidth: .infinity, minHeight: 100)
            } else if levels.isEmpty {
                ContentUnavailableView(
                    "No Levels",
                    systemImage: "square.grid.3x3.slash",
                    description: Text("Levels for \(world.title) could not be loaded.")
                )
            } else {
                LazyVGrid(columns: columns, spacing: gridSpacing) {
                    ForEach(Array(levels.enumerated()), id: \.offset) { index, _ in
                        LevelButtonView(
                            levelIndex: index,
                            isActive: isLevelActive(index),
                            isCompleted: isLevelCompleted(index),
                            starRating: starRating(for: index),
                            hasSolutionUnlocked: appModel.inAppPurchaseService.hasUnlockedSolution(world: world, level: index),
                            isUnlocked: isLevelUnlocked(index),
                            lockMessage: appModel.progressService.unlockRequirement(forLevel: index, in: world),
                            onSelect: { onLevelSelected(index) }
                        )
                        .id("level-\(index)")
                        #if os(tvOS)
                        .padding(8)
                        #endif
                    }
                }
                .accessibilityRotor("Incomplete Levels") {
                    ForEach(Array(levels.enumerated()), id: \.offset) { index, _ in
                        if !isLevelCompleted(index) {
                            AccessibilityRotorEntry(
                                "Level \(index + 1)",
                                id: "level-\(index)"
                            )
                        }
                    }
                }
            }
        }
        .task(id: world.id) { await loadLevels() }
    }
    
    // MARK: - Helpers
    
    private func isLevelActive(_ index: Int) -> Bool {
        LevelGridQueries.isLevelActive(index, in: world, appModel: appModel)
    }
    
    private func isLevelCompleted(_ index: Int) -> Bool {
        LevelGridQueries.isLevelCompleted(index, in: world, appModel: appModel)
    }
    
    private func starRating(for index: Int) -> Int {
        LevelGridQueries.starRating(for: index, in: world, appModel: appModel)
    }
    
    private func isLevelUnlocked(_ index: Int) -> Bool {
        LevelGridQueries.isLevelUnlocked(index, in: world, appModel: appModel)
    }
    
    private func loadLevels() async {
        hasLoaded = false
        levels = []
        levels = await LevelGridQueries.loadLevels(for: world, appModel: appModel)
        hasLoaded = true
    }
}
#endif
