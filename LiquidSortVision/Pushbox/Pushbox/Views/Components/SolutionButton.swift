// SolutionButton.swift
// Cross-platform solution button with color coding and credit badge.
// Single source of truth for both visionOS and iOS.

import SwiftUI

// MARK: - SolutionButton

/// A solution button displaying a lightbulb icon with:
/// - **Color coding**: Green (completed), Yellow (credits available), Red (no credits)
/// - **Credit badge**: Shows remaining solution credits
/// - **Pulse animation**: While solution is playing
struct SolutionButton: View {

    // MARK: - Environment

    @Environment(AppModel.self) private var appModel

    // MARK: - Properties

    /// Action to execute when tapped.
    let action: () -> Void

    /// Whether the level is fully loaded and ready for interaction.
    var isLevelReady: Bool = true

    // MARK: - Computed Properties

    /// Whether the current level has been completed.
    private var isLevelCompleted: Bool {
        guard let world = appModel.activeWorld ?? appModel.selectedWorld,
              let levelIndex = appModel.selectedLevelIndex else { return false }
        return appModel.progressService.isLevelCompleted(worldName: world.worldName, levelIndex: levelIndex)
    }

    /// Whether the button should be disabled.
    /// Disabled when:
    /// - Level isn't ready AND solution isn't playing (user can always stop a playing solution)
    /// - Solution startup is already in progress (prevents concurrent calls)
    private var isDisabled: Bool {
        if appModel.isPlayingSolution { return false }
        return !isLevelReady || appModel.isStartingSolution
    }

    /// Whether the current level's solution has been unlocked (credit already spent).
    private var isSolutionUnlocked: Bool {
        guard let world = appModel.activeWorld ?? appModel.selectedWorld,
              let levelIndex = appModel.selectedLevelIndex else { return false }
        return appModel.inAppPurchaseService.hasUnlockedSolution(world: world, level: levelIndex)
    }

    /// Color for the solution button based on level and credit status.
    /// - Green: Level already solved or solution already unlocked
    /// - Yellow: Unsolved but solution available (has credits)
    /// - Red: Unsolved and no credits available
    private var bulbColor: Color {
        if isLevelCompleted || isSolutionUnlocked { return .green }

        if appModel.isPlayingSolution || appModel.inAppPurchaseService.solutionCredits > 0 {
            return .yellow
        }

        return .red
    }

    // MARK: - Body

    var body: some View {
        Button(action: action) {
            Image(systemName: "lightbulb.fill")
                .foregroundStyle(bulbColor)
                .symbolEffect(
                    .pulse.byLayer,
                    options: .repeating,
                    isActive: appModel.isPlayingSolution
                )
                .opacity(appModel.isPlayingSolution ? 0.6 : 1)
                #if !os(visionOS)
                .font(.title3)
                .frame(minWidth: 44, minHeight: 44)
                .contentShape(Rectangle())
                #endif
        }
        #if os(visionOS)
        .buttonStyle(.bordered)
        .buttonBorderShape(.circle)
        .font(.title2.weight(.bold))
        #else
        .buttonStyle(.plain)
        #endif
        .overlay(alignment: .topTrailing) {
            Text("\(appModel.inAppPurchaseService.solutionCredits)")
                .font(.caption2.weight(.bold))
                .foregroundStyle(.white)
                .padding(.horizontal, 5)
                .padding(.vertical, 1)
                .background(bulbColor, in: Capsule())
                .offset(x: 8, y: -8)
        }
        .disabled(isDisabled)
        .opacity(isDisabled ? 0.4 : 1)
        .accessibilityLabel(appModel.isPlayingSolution ? "Stop solution" : "Play solution. \(appModel.inAppPurchaseService.solutionCredits) credits remaining.")
        .accessibilityHint(!isLevelReady ? "Level is loading" : isLevelCompleted ? "Level already solved" : "Shows solution for current level")
    }
}
