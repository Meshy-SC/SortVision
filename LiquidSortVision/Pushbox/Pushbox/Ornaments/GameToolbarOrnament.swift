// GameToolbarOrnament.swift
#if os(visionOS)
// Bottom toolbar with game controls: grid toggle, solution, undo, and level navigation.

import SwiftUI

// MARK: - GameToolbarOrnament

/// Bottom toolbar providing the main game action buttons.
///
/// Used in two contexts:
/// - **Standalone** (`isStandalone = true`): Rendered directly as an ornament when the control panel
///   is closed. Wraps buttons in an HStack with glass background.
/// - **Toolbar item** (`isStandalone = false`): Rendered inside a `ToolbarItemGroup(placement:
///   .bottomOrnament)` when the control panel is open. Buttons are laid out by the toolbar system.
struct GameToolbarOrnament: View {
    
    // MARK: - Environment
    
    @Environment(AppModel.self) private var appModel

    // MARK: - Properties
    
    /// Action to execute when the undo button is tapped.
    let undoAction: () -> Void
    
    /// Action to execute when the previous level button is tapped.
    let previousLevelAction: () -> Void
    
    /// Action to execute when the next level button is tapped.
    let nextLevelAction: () -> Void
    
    /// Action to execute when the solution button is tapped.
    let solutionAction: () -> Void
    
    /// Whether the level is fully loaded and ready.
    let isLevelReady: Bool

    /// Whether the undo button should be disabled.
    let isUndoDisabled: Bool

    /// When `true`, wraps buttons in an HStack with glass background for standalone ornament use.
    /// When `false`, renders bare buttons for use inside a `ToolbarItemGroup`.
    var isStandalone: Bool = true

    // MARK: - State

    private static let scaleSteps: [Double] = [0.5, 1.0, 2.0, 3.0]

    /// Whether the locked-level alert is presented for the next level.
    @State private var showLockedAlert = false

    // MARK: - Body
    
    var body: some View {
        Group {
            if isStandalone {
                HStack {
                    buttons
                }
                .padding()
                .glassBackgroundEffect()
            } else {
                buttons
            }
        }
        .dynamicTypeSize(...DynamicTypeSize.accessibility2)
    }

    // MARK: - Shared Buttons

    @ViewBuilder
    private var buttons: some View {
        // Grid toggle
        Toggle(isOn: Binding(
            get: { appModel.isControlPanelOpen },
            set: { appModel.isControlPanelOpen = $0 }
        )) {
            Image(systemName: "square.grid.3x3")
        }
        .toggleStyle(.button)
        .keyboardShortcut("l", modifiers: .command)
        .disabled(appModel.isPlayingSolution)
        .accessibilityLabel(appModel.isControlPanelOpen ? "Hide level selection" : "Show level selection")

        if isStandalone { Spacer() }

        // Scale — cycles through 0.5x → 1x → 2x on each tap
        Button {
            let steps = Self.scaleSteps
            let currentIndex = steps.firstIndex(of: appModel.boardScale) ?? 1
            appModel.boardScale = steps[(currentIndex + 1) % steps.count]
        } label: {
            Text(boardScaleLabel)
        }
        .buttonStyle(.bordered)
        .buttonBorderShape(.capsule)
        .accessibilityLabel("Board scale \(boardScaleLabel)")

        if isStandalone { Spacer() }

        // Solution bulb — shared component
        SolutionButton(action: solutionAction, isLevelReady: isLevelReady)
            .environment(appModel)

        // Solution credits purchase
        Button {
            appModel.inAppPurchaseService.isStoreSheetPresented = true
        } label: {
            Image(systemName: "cart.fill")
        }
        .buttonStyle(.bordered)
        .buttonBorderShape(.circle)
        .accessibilityLabel("Buy solution credits")

        if isStandalone { Spacer() }

        // Undo
        Button(action: undoAction) {
            Image(systemName: "arrow.uturn.backward")
        }
        .buttonStyle(.bordered)
        .buttonBorderShape(.circle)
        .keyboardShortcut("z", modifiers: .command)
        .disabled(isUndoDisabled || appModel.isPlayingSolution)
        .accessibilityLabel("Undo last move")

        if isStandalone { Spacer() }

        // Previous level
        Button(action: previousLevelAction) {
            Image(systemName: "arrow.left")
        }
        .buttonStyle(.bordered)
        .buttonBorderShape(.circle)
        .keyboardShortcut(.leftArrow, modifiers: .command)
        .disabled(appModel.isPlayingSolution || !appModel.canGoToPreviousLevel)
        .accessibilityLabel("Previous level")

        if isStandalone { Spacer() }

        // Next level
        Button {
            if appModel.isNextLevelLocked {
                showLockedAlert = true
            } else {
                nextLevelAction()
            }
        } label: {
            Image(systemName: "arrow.right")
        }
        .buttonStyle(.bordered)
        .buttonBorderShape(.circle)
        .keyboardShortcut(.rightArrow, modifiers: .command)
        .disabled(appModel.isPlayingSolution || !appModel.hasNextLevel)
        .opacity(appModel.isNextLevelLocked ? 0.5 : 1)
        .accessibilityLabel("Next level")
        .accessibilityHint(appModel.isNextLevelLocked ? "Level is locked" : "")
        .alert("Level Locked", isPresented: $showLockedAlert) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(appModel.nextLevelLockMessage ?? "Complete more levels to unlock the next level.")
        }

    }

    // MARK: - Helpers

    private var boardScaleLabel: String {
        let s = appModel.boardScale
        if s == 1.0 { return "1x" }
        if s < 1.0  { return "0.5x" }
        if s == 3.0 { return "3x" }
        return "2x"
    }
}
#endif
