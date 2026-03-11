import SwiftUI

/// Navigation route identifiers for the app's screen flow.
///
/// Defines the complete navigation graph:
/// ```
/// StageSelection (root) → LevelGrid → Gameplay
/// ```
///
/// Used with `NavigationStack(path:)` in `RootNavigationView` for
/// declarative, type-safe navigation throughout the app.
enum AppScreen: Hashable, Sendable {
    /// Level selection grid for a specific stage.
    case levelGrid(Stage)

    /// Active gameplay for a specific level within a stage.
    case gameplay(Stage, Level)
}
