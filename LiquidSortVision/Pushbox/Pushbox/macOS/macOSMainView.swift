// macOSMainView.swift
// Root view for macOS — uses NavigationSplitView for native sidebar+detail pattern.
// Follows macOS HIG for master-detail interfaces with proper toolbar integration.

#if os(macOS)
import SwiftUI

/// Root navigation view for the macOS version of PushBox.
/// Uses a `NavigationSplitView` with a sidebar for world selection and a detail
/// area showing the level grid — the native macOS pattern per HIG.
struct macOSMainView: View {
    
    @Environment(AppModel.self) private var appModel
    
    /// Whether the game scene sheet is presented.
    @State private var isGamePresented = false
    
    /// Whether the leaderboard sheet is presented.
    @State private var isLeaderboardPresented = false
    
    /// The message to display in the locked-world alert.
    @State private var lockedWorldAlertMessage: String?
    
    var body: some View {
        NavigationSplitView {
            sidebar
                .navigationSplitViewColumnWidth(min: 220, ideal: 250, max: 350)
        } detail: {
            detail
        }
        .sheet(isPresented: $isGamePresented) {
            iOSGameSceneView(
                onDismiss: {
                    appModel.audioService.stopPuzzleAudio()
                    isGamePresented = false
                }
            )
            .environment(appModel)
            .frame(minWidth: 900, minHeight: 600)
            .interactiveDismissDisabled()
        }
        .sheet(isPresented: $isLeaderboardPresented) {
            NavigationStack {
                LeaderboardView()
                    .environment(appModel)
                    .navigationTitle("Leaderboard")
                    .toolbar {
                        ToolbarItem(placement: .confirmationAction) {
                            Button("Done") { isLeaderboardPresented = false }
                        }
                    }
            }
        }
        .alert("World Locked", isPresented: Binding(
            get: { lockedWorldAlertMessage != nil },
            set: { if !$0 { lockedWorldAlertMessage = nil } }
        )) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(lockedWorldAlertMessage ?? "")
        }

    }
    
    // MARK: - Sidebar
    
    private var sidebar: some View {
        List(selection: Binding<String?>(
            get: { appModel.selectedWorld?.id },
            set: { newID in
                guard let newID else { return }
                guard let world = World.allWorlds.first(where: { $0.id == newID }) else { return }
                // Prevent selecting locked worlds — show unlock info instead
                guard appModel.progressService.isWorldUnlocked(world) else {
                    lockedWorldAlertMessage = appModel.progressService.unlockRequirement(forWorld: world)
                        ?? "Complete more levels in the previous world to unlock."
                    return
                }
                appModel.selectedWorld = world
            }
        )) {
            Section("Worlds") {
                ForEach(World.allWorlds, id: \.id) { world in
                    let worldUnlocked = appModel.progressService.isWorldUnlocked(world)
                    HStack {
                        Image(systemName: worldUnlocked ? "cube.box" : "lock.fill")
                            .foregroundStyle(worldUnlocked ? .blue : .secondary)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(world.title)
                                .font(.headline)
                            Text(world.subtitle)
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        HStack(spacing: 4) {
                            if !worldUnlocked {
                                Image(systemName: "lock.fill")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            let completed = appModel.progressService.completedCount(for: world.worldName)
                            let total = appModel.worldTotalLevels[world.worldName] ?? 0
                            Text("\(completed)/\(total)")
                                .font(.subheadline.monospacedDigit())
                                .foregroundStyle(.secondary)
                        }
                    }
                    .opacity(worldUnlocked ? 1.0 : 0.6)
                    .accessibilityLabel(worldUnlocked
                        ? "\(world.title), \(appModel.progressService.completedCount(for: world.worldName)) of \(appModel.worldTotalLevels[world.worldName] ?? 0) levels completed"
                        : "\(world.title), locked, \(appModel.worldTotalLevels[world.worldName] ?? 0) levels"
                    )
                }
            }
        }
        .navigationTitle("Push Box")
        .toolbar {
            ToolbarItemGroup(placement: .automatic) {
                Button {
                    isLeaderboardPresented = true
                } label: {
                    Image(systemName: "trophy")
                }
                .disabled(!appModel.gameCenterService.isAuthenticated)
                .accessibilityLabel("Leaderboard")
            }
        }
    }
    
    // MARK: - Detail
    
    @ViewBuilder
    private var detail: some View {
        if let world = appModel.selectedWorld {
            ScrollView {
                VStack(spacing: 16) {
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
                    .padding(.top, 8)
                    
                    iOSLevelsGridView(
                        world: world,
                        onLevelSelected: { levelIndex in
                            appModel.activeWorld = world
                            appModel.selectedLevelIndex = levelIndex
                            appModel.progressService.currentLevelPushes = 0
                            isGamePresented = true
                        }
                    )
                }
                .padding()
            }
            .navigationTitle(world.title)
        } else {
            ContentUnavailableView(
                "Select a World",
                systemImage: "cube.box",
                description: Text("Choose a world from the sidebar to view its levels.")
            )
        }
    }
}
#endif
