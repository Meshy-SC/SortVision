// FocusedGameActions.swift
// Type-safe focused value for propagating game actions to macOS menu commands.

#if os(macOS)
import SwiftUI

// MARK: - Game Actions

/// Encapsulates game action closures for propagation via `@FocusedValue`.
/// Replaces NotificationCenter-based command dispatch with type-safe closures
/// that automatically disable menu items when no game view is focused.
///
/// All closures are `@MainActor @Sendable` because they capture and mutate
/// game state that is `@MainActor`-isolated.
@MainActor
struct GameActions: Sendable {
    var undoMove: @MainActor @Sendable () -> Void
    var previousLevel: @MainActor @Sendable () -> Void
    var nextLevel: @MainActor @Sendable () -> Void
}

// MARK: - Focused Value Key

private struct FocusedGameActionsKey: FocusedValueKey {
    typealias Value = GameActions
}

extension FocusedValues {
    var gameActions: GameActions? {
        get { self[FocusedGameActionsKey.self] }
        set { self[FocusedGameActionsKey.self] = newValue }
    }
}

// MARK: - Game Commands

/// Menu commands that use `@FocusedValue` to invoke game actions.
/// Menu items automatically disable when no game view is focused.
struct GameCommands: Commands {
    @FocusedValue(\.gameActions) private var gameActions

    var body: some Commands {
        CommandMenu("Game") {
            Button("Undo Move") { gameActions?.undoMove() }
                .keyboardShortcut("z", modifiers: .command)
                .disabled(gameActions == nil)

            Divider()

            Button("Previous Level") { gameActions?.previousLevel() }
                .keyboardShortcut(.leftArrow, modifiers: .command)
                .disabled(gameActions == nil)

            Button("Next Level") { gameActions?.nextLevel() }
                .keyboardShortcut(.rightArrow, modifiers: .command)
                .disabled(gameActions == nil)
        }
    }
}
#endif
