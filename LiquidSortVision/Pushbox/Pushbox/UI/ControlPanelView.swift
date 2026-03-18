// ControlPanelView.swift
#if os(visionOS)
// Main control panel with world selection sidebar and levels grid.
// Displayed as an ornament within the main Volumetric window.

import SwiftUI

// MARK: - ControlPanelView

/// The main control panel view displayed as an ornament within the volumetric window.
/// Contains a sidebar for world selection and a detail view for level selection.
struct ControlPanelView: View {
    
    // MARK: - Environment

    @Environment(AppModel.self) private var appModel

    /// Whether the Game Center leaderboard sheet is presented.
    @State private var isLeaderboardPresented = false

    /// Whether the audio settings sheet is presented.
    @State private var isAudioSettingsPresented = false

    /// The message to display in the locked-world alert.
    @State private var lockedWorldAlertMessage: String?

    // MARK: - Body

    var body: some View {
        NavigationSplitView {
            sidebarContent
                .toolbar {
                    ToolbarItem(placement: .bottomBar) {
                        HStack {
                            Button {
                                isLeaderboardPresented = true
                            } label: {
                                Label("Leaderboard", systemImage: "trophy")
                            }
                            .disabled(!appModel.gameCenterService.isAuthenticated)

                            Button {
                                isAudioSettingsPresented = true
                            } label: {
                                Label("Settings", systemImage: "gearshape")
                            }
                            .accessibilityLabel("Settings")
                        }
                    }
                }
        } detail: {
            detailContent
        }
        .sheet(isPresented: $isLeaderboardPresented) {
            LeaderboardView()
                .environment(appModel)
        }
        .sheet(isPresented: $isAudioSettingsPresented) {
            NavigationStack {
                SettingsView()
                    .environment(appModel)
                    .toolbar {
                        ToolbarItem(placement: .confirmationAction) {
                            Button("Done") { isAudioSettingsPresented = false }
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
    
    private var sidebarContent: some View {
        List(selection: Binding(
            get: { appModel.selectedWorld },
            set: { newWorld in
                guard let newWorld else { return }
                // Prevent selecting locked worlds — show unlock info instead
                guard appModel.progressService.isWorldUnlocked(newWorld) else {
                    lockedWorldAlertMessage = appModel.progressService.unlockRequirement(forWorld: newWorld)
                        ?? "Complete more levels in the previous world to unlock."
                    return
                }
                appModel.selectedWorld = newWorld
            }
        )) {
            ForEach(World.allWorlds) { world in
                WorldRowView(
                    world: world,
                    completedCount: appModel.progressService.completedCount(for: world.worldName),
                    totalLevels: appModel.worldTotalLevels[world.worldName] ?? 0,
                    isUnlocked: appModel.progressService.isWorldUnlocked(world)
                )
                .tag(world)
            }
        }
        .listStyle(.sidebar)
        .navigationTitle("Push Box")
    }
    
    // MARK: - Detail
    
    @ViewBuilder
    private var detailContent: some View {
        if let world = appModel.selectedWorld {
            LevelsGridView(world: world)
        } else {
            Text("Select a world")
                .accessibilityLabel("Please select a world")
        }
    }
}
#endif
