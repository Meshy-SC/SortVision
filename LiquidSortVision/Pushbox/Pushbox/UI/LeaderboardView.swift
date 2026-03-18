// LeaderboardView.swift
// Presents the Game Center leaderboard, achievements, and challenges.

import SwiftUI
import GameKit

// MARK: - LeaderboardView

/// Provides access to Game Center features: leaderboards, achievements, and challenges.
///
/// Uses Apple's recommended `GKAccessPoint.trigger()` API to present the system-provided
/// Game Center dashboard, which displays player names, scores, ranks, and social features
/// with Apple's native UI.
struct LeaderboardView: View {

    @Environment(AppModel.self) private var appModel
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        if appModel.gameCenterService.isAuthenticated {
            gameCenterView
        } else {
            notAuthenticatedView
        }
    }

    // MARK: - Authenticated View

    private var gameCenterView: some View {
        VStack(spacing: 24) {
            Image(systemName: "trophy.fill")
                .font(.system(size: 60))
                .foregroundStyle(.yellow)

            Text("Game Center")
                .font(.largeTitle.bold())

            Text("Compete, earn achievements, and challenge friends")
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            VStack(spacing: 12) {
                // Leaderboard
                Button {
                    presentLeaderboard()
                } label: {
                    Label("View Leaderboard", systemImage: "chart.bar")
                        .font(.headline)
                        .padding()
                        .frame(maxWidth: 300)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)

                // Achievements
                Button {
                    presentAchievements()
                } label: {
                    Label("Achievements", systemImage: "medal")
                        .font(.headline)
                        .padding()
                        .frame(maxWidth: 300)
                }
                .buttonStyle(.bordered)
                .controlSize(.large)

                // Challenges
                Button {
                    appModel.gameCenterService.presentChallenges()
                } label: {
                    Label("Challenge Friends", systemImage: "person.2")
                        .font(.headline)
                        .padding()
                        .frame(maxWidth: 300)
                }
                .buttonStyle(.bordered)
                .controlSize(.large)
            }
        }
        .padding()
    }

    // MARK: - Dashboard Triggers

    /// Presents the Game Center dashboard focused on the global leaderboard.
    private func presentLeaderboard() {
        GKAccessPoint.shared.trigger(
            leaderboardID: GameCenterService.globalScoreLeaderboardID,
            playerScope: .global,
            timeScope: .allTime
        ) {
            dismiss()
        }
    }

    /// Presents the Game Center dashboard focused on achievements.
    private func presentAchievements() {
        GKAccessPoint.shared.trigger(
            state: .achievements
        ) {
            dismiss()
        }
    }

    // MARK: - Not Authenticated

    private var notAuthenticatedView: some View {
        ContentUnavailableView {
            Label("Game Center", systemImage: "gamecontroller")
        } description: {
            Text("Sign in to Game Center in Settings to view the leaderboard and compete with other players.")
        } actions: {
            Button("Open Settings") {
                #if os(iOS)
                if let url = URL(string: UIApplication.openSettingsURLString) {
                    UIApplication.shared.open(url)
                }
                #elseif os(macOS)
                if let url = URL(string: "x-apple.systempreferences:com.apple.Game-Center") {
                    NSWorkspace.shared.open(url)
                }
                #elseif os(tvOS)
                // tvOS cannot open Settings programmatically
                #endif
            }
        }
    }
}
