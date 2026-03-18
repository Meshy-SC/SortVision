// iOSControlPanel.swift
// iOS-adapted control panel with world selection and drill-down level grid.

#if os(iOS) || os(macOS) || os(tvOS)
import SwiftUI

/// iOS control panel using a NavigationStack drill-down pattern.
///
/// Shows a list of worlds first. Tapping a world pushes to a detail view
/// displaying only that world's level grid — avoiding the previous design
/// that loaded every world's levels into a single scrolling list.
///
/// Both call sites (`iOSMainView` and `GameSheets`) already provide
/// a `NavigationStack`, so `NavigationLink` works out of the box.
struct iOSControlPanel: View {
    
    @Environment(AppModel.self) private var appModel
    
    /// Callback when a level is selected — triggers game scene presentation.
    let onLevelSelected: (World, Int) -> Void
    
    /// The message to display in the locked-world alert.
    @State private var lockedWorldAlertMessage: String?
    
    var body: some View {
        List {
            // MARK: Stats
            Section {
                HStack(spacing: 30) {
                    CircularStatGauge(
                        title: "Progress",
                        value: appModel.progressService.overallProgress,
                        maxValue: 100,
                        tintColor: .green
                    )
                    CircularStatGauge(
                        title: "Score",
                        value: Double(appModel.progressService.globalScore),
                        maxValue: Double(appModel.progressService.maximumGlobalScore),
                        tintColor: .orange
                    )
                    CircularStatGauge(
                        title: "Credits",
                        value: Double(appModel.inAppPurchaseService.solutionCredits),
                        maxValue: Double(appModel.inAppPurchaseService.maximumSolutionCredits),
                        tintColor: .blue
                    )
                }
                .frame(maxWidth: .infinity, alignment: .center)
            }
            .listRowBackground(Color.clear)

            // MARK: Worlds
            Section {
                ForEach(World.allWorlds, id: \.id) { world in
                    let worldUnlocked = appModel.progressService.isWorldUnlocked(world)
                    if worldUnlocked {
                        NavigationLink {
                            iOSWorldLevelsView(
                                world: world,
                                onLevelSelected: { levelIndex in
                                    onLevelSelected(world, levelIndex)
                                }
                            )
                            .environment(appModel)
                        } label: {
                            worldRow(world, isUnlocked: true)
                        }
                        .accessibilityLabel(worldAccessibilityLabel(world))
                    } else {
                        Button {
                            lockedWorldAlertMessage = appModel.progressService.unlockRequirement(forWorld: world)
                                ?? "Complete more levels in the previous world to unlock."
                        } label: {
                            worldRow(world, isUnlocked: false)
                        }
                        .accessibilityLabel(lockedWorldAccessibilityLabel(world))
                    }
                }
            } header: {
                Text("Worlds")
            }
        }
        #if os(iOS)
        .listStyle(.insetGrouped)
        #elseif os(macOS)
        .listStyle(.sidebar)
        #endif
        .alert("World Locked", isPresented: Binding(
            get: { lockedWorldAlertMessage != nil },
            set: { if !$0 { lockedWorldAlertMessage = nil } }
        )) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(lockedWorldAlertMessage ?? "")
        }
    }
    
    // MARK: - World Row
    
    private func worldRow(_ world: World, isUnlocked: Bool) -> some View {
        HStack {
            Image(systemName: isUnlocked ? "cube.box" : "lock.fill")
                .font(.title2)
                .foregroundStyle(isUnlocked ? .blue : .secondary)
                .frame(width: 36, height: 36)
                .glassEffect(.regular, in: .circle)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(world.title)
                    .font(.headline)
                Text(world.subtitle)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            
            Spacer()
            
            HStack(spacing: 4) {
                if !isUnlocked {
                    Image(systemName: "lock.fill")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                let completedCount = appModel.progressService.completedCount(for: world.worldName)
                let totalLevels = appModel.worldTotalLevels[world.worldName] ?? 0
                Text("\(completedCount)/\(totalLevels)")
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .glassEffect(in: .capsule)
        }
        .opacity(isUnlocked ? 1.0 : 0.6)
    }
    
    private func worldAccessibilityLabel(_ world: World) -> String {
        let completed = appModel.progressService.completedCount(for: world.worldName)
        let total = appModel.worldTotalLevels[world.worldName] ?? 0
        return "\(world.title), \(completed) of \(total) levels completed"
    }
    
    private func lockedWorldAccessibilityLabel(_ world: World) -> String {
        let total = appModel.worldTotalLevels[world.worldName] ?? 0
        return "\(world.title), locked, \(total) levels. Complete more levels in the previous world to unlock."
    }
}

// MARK: - World Levels Detail View

/// Detail view pushed when the user taps a world in the control panel.
/// Displays a scrollable grid of level buttons for that world only.
private struct iOSWorldLevelsView: View {
    
    @Environment(AppModel.self) private var appModel
    
    /// The world to display levels for.
    let world: World
    
    /// Callback when a level is selected.
    let onLevelSelected: (Int) -> Void
    
    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Per-world progress summary
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
                
                iOSLevelsGridView(
                    world: world,
                    onLevelSelected: onLevelSelected
                )
            }
            .padding()
        }
        .navigationTitle(world.title)
        #if os(iOS)
        .navigationBarTitleDisplayMode(.large)
        #endif
    }
}
#endif
