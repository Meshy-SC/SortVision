// LevelsGridView.swift
#if os(visionOS)
// Grid view for level selection with progress gauges.

import SwiftUI

// MARK: - LevelsGridView

/// Displays a grid of level selection buttons for a specific world.
/// Includes progress gauges at the top showing overall progress, score, and credits.
struct LevelsGridView: View {
    
    // MARK: - Environment

    @Environment(AppModel.self) private var appModel
    
    // MARK: - Properties
    
    /// The world to display levels for.
    var world: World
    
    /// Loaded level data for this world.
    @State private var levels: [[String]] = []
    
    /// Whether the initial level load has completed.
    @State private var hasLoaded = false
    
    /// Grid layout configuration.
    private let columns = [GridItem(.adaptive(minimum: 72))]
    
    // MARK: - Body
    
    var body: some View {
        Group {
            if !hasLoaded {
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if levels.isEmpty {
                ContentUnavailableView(
                    "No Levels",
                    systemImage: "square.grid.3x3.slash",
                    description: Text("Levels for \(world.title) could not be loaded.")
                )
            } else {
                ScrollView {
                    VStack(spacing: 12) {
                        gaugesSection
                        levelsGridSection
                    }
                    .padding(.horizontal)
                    .padding(.bottom, 20)
                }
            }
        }
        .navigationTitle(world.title)
        .task(id: world.id) {
            await loadLevels()
        }
    }
    
    // MARK: - Gauges Section
    
    private var gaugesSection: some View {
        HStack(spacing: 30) {
            let completed = appModel.progressService.completedCount(for: world.worldName)
            let total = appModel.worldTotalLevels[world.worldName] ?? 0
            CircularStatGauge(
                title: "Progress",
                value: total > 0 ? Double(completed) / Double(total) * 100 : 0,
                maxValue: 100,
                tintColor: .green
            )
            CircularStatGauge(
                title: "Score",
                value: Double(appModel.progressService.worldScore(for: world.worldName)),
                maxValue: Double(appModel.progressService.maximumWorldScore(for: world.worldName)),
                tintColor: .orange
            )
            CircularStatGauge(
                title: "Credits",
                value: Double(appModel.inAppPurchaseService.solutionCredits),
                maxValue: Double(appModel.inAppPurchaseService.maximumSolutionCredits),
                tintColor: .blue
            )
        }
    }
    
    // MARK: - Levels Grid Section
    
    private var levelsGridSection: some View {
        LazyVGrid(columns: columns, spacing: 16) {
            ForEach(Array(levels.enumerated()), id: \.offset) { index, _ in
                LevelButtonView(
                    levelIndex: index,
                    isActive: isLevelActive(index),
                    isCompleted: isLevelCompleted(index),
                    starRating: starRating(for: index),
                    hasSolutionUnlocked: appModel.inAppPurchaseService.hasUnlockedSolution(world: world, level: index),
                    isUnlocked: isLevelUnlocked(index),
                    lockMessage: appModel.progressService.unlockRequirement(forLevel: index, in: world),
                    onSelect: { selectLevel(index) }
                )
                .id("level-\(index)")
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
    
    // MARK: - Helper Methods
    
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
    
    private func selectLevel(_ index: Int) {
        // If the user taps the already-active level, dismiss the UI so they can resume playing
        if appModel.activeWorld?.id == world.id && appModel.selectedLevelIndex == index {
            appModel.isControlPanelOpen = false
            return
        }

        if appModel.hasSessionAnchor {
            // Session anchor exists — skip placement and reuse anchor position
            appModel.activateLevelAtSessionAnchor(world: world, levelIndex: index)
            appModel.isControlPanelOpen = false
        } else {
            // No session anchor — enter placement flow
            appModel.startLevelPlacement(world: world, levelIndex: index)
            appModel.isControlPanelOpen = false
        }
    }
    
    private func loadLevels() async {
        hasLoaded = false
        levels = []
        levels = await LevelGridQueries.loadLevels(for: world, appModel: appModel)
        hasLoaded = true
    }
}
#endif
