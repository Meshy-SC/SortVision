// iOSMainView.swift
// Root view for iOS — handles navigation between control panel and game scene.

#if os(iOS) || os(macOS) || os(tvOS)
import SwiftUI

/// Root navigation view for the iOS version of PushBox.
/// Uses a NavigationStack with world/level selection that presents
/// the 3D game scene as a full-screen cover.
struct iOSMainView: View {
    
    @Environment(AppModel.self) private var appModel
    
    /// Whether the game scene is currently presented.
    @State private var isGamePresented = false
    
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
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
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

                        NavigationLink {
                            SettingsView()
                                .environment(appModel)
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
        #if os(iOS) || os(tvOS)
        .fullScreenCover(isPresented: $isGamePresented) {
            iOSGameSceneView(
                onDismiss: {
                    appModel.audioService.stopPuzzleAudio()
                    isGamePresented = false
                }
            )
            .environment(appModel)
        }
        #else
        .sheet(isPresented: $isGamePresented) {
            iOSGameSceneView(
                onDismiss: {
                    appModel.audioService.stopPuzzleAudio()
                    isGamePresented = false
                }
            )
            .environment(appModel)
            .frame(minWidth: 900, minHeight: 600)
        }
        #endif
        .sheet(isPresented: $isLeaderboardPresented) {
            NavigationStack {
                LeaderboardView()
                    .environment(appModel)
                    .navigationTitle("Leaderboard")
                    #if os(iOS)
                    .navigationBarTitleDisplayMode(.inline)
                    #endif
                    .toolbar {
                        ToolbarItem(placement: .automatic) {
                            Button("Done") {
                                isLeaderboardPresented = false
                            }
                        }
                    }
            }
        }
    }
}
#endif
