// tvOSMainView.swift
// Root view for tvOS — handles navigation between control panel and game scene.

#if os(tvOS)
import SwiftUI

/// Root navigation view for the tvOS version of PushBox.
/// Uses a NavigationStack with world/level selection that presents
/// the 3D game scene as a full-screen cover.
struct tvOSMainView: View {
    
    @Environment(AppModel.self) private var appModel
    
    /// Whether the game scene is currently presented.
    @State private var isGamePresented = false
    
    /// Whether audio settings sheet is shown.
    @State private var isAudioSettingsPresented = false
    
    /// Whether the Game Center leaderboard sheet is shown.
    @State private var isLeaderboardPresented = false
    
    var body: some View {
        NavigationStack {
            iOSControlPanel(
                onLevelSelected: { world, levelIndex in
                    appModel.selectedWorld = world
                    appModel.activeWorld = world
                    appModel.selectedLevelIndex = levelIndex
                    appModel.progressService.currentLevelPushes = 0
                    isGamePresented = true
                }
            )
            .navigationTitle("Push Box")
            .toolbar {
                ToolbarItem(placement: .automatic) {
                    HStack(spacing: 12) {
                        Button {
                            isLeaderboardPresented = true
                        } label: {
                            Image(systemName: "trophy")
                                .frame(width: 36, height: 36)
                                .contentShape(Rectangle())
                        }
                        .accessibilityLabel("Leaderboard")
                        .disabled(!appModel.gameCenterService.isAuthenticated)

                        Button {
                            isAudioSettingsPresented = true
                        } label: {
                            Image(systemName: "gearshape")
                                .frame(width: 36, height: 36)
                                .contentShape(Rectangle())
                        }
                        .accessibilityLabel("Settings")
                    }
                }
            }
        }
        .fullScreenCover(isPresented: $isGamePresented) {
            iOSGameSceneView(
                onDismiss: {
                    appModel.audioService.stopPuzzleAudio()
                    isGamePresented = false
                }
            )
            .environment(appModel)
        }
        .sheet(isPresented: $isLeaderboardPresented) {
            NavigationStack {
                LeaderboardView()
                    .environment(appModel)
                    .navigationTitle("Leaderboard")
                    .toolbar {
                        ToolbarItem(placement: .automatic) {
                            Button("Done") {
                                isLeaderboardPresented = false
                            }
                        }
                    }
            }
        }
        .sheet(isPresented: $isAudioSettingsPresented) {
            SettingsView()
                .environment(appModel)
        }
    }
}
#endif
