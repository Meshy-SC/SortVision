import Foundation
import Observation

/// Manages deep link navigation requests from App Intents, Shortcuts, and Widgets.
///
/// When an App Intent or Widget sets `pendingLevel`, the `RootNavigationView`
/// picks up the request and navigates to the appropriate gameplay screen.
///
/// ## Flow
/// ```
/// AppIntent/Widget → DeepLinkManager.pendingLevel → RootNavigationView → GameplayView
/// ```
@MainActor @Observable
final class DeepLinkManager {
    static let shared = DeepLinkManager()

    /// A pending navigation request from an App Intent or Widget.
    ///
    /// Set by intents/widgets, consumed by `RootNavigationView` on appearance.
    /// Automatically cleared after navigation is performed.
    var pendingLevel: (mode: GameMode, number: Int)?

    private init() {}
}
