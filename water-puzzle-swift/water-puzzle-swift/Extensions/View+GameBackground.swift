import SwiftUI

/// Reusable dark gradient background matching the app's visual theme.
///
/// Applied consistently across menu screens (MainMenu, DifficultySelect, LevelGrid)
/// to ensure visual coherence and eliminate code duplication.
///
/// On visionOS, uses the system glass background effect instead of the opaque gradient,
/// following Apple's HIG recommendation for spatial computing environments.
struct GameBackgroundModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
            .background {
                #if os(visionOS)
                Color.clear
                    .ignoresSafeArea()
                #else
                LinearGradient(
                    colors: [
                        Color(red: 0.10, green: 0.13, blue: 0.20),
                        Color(red: 0.16, green: 0.20, blue: 0.30),
                    ],
                    startPoint: .top, endPoint: .bottom
                )
                .ignoresSafeArea()
                #endif
            }
    }
}

extension View {
    /// Applies the standard dark gradient background used across menu screens.
    ///
    /// Uses platform-adaptive rendering:
    /// - **iOS/macOS**: Dark gradient for immersive game feel
    /// - **visionOS**: Glass background effect for spatial computing integration
    ///
    /// Usage:
    /// ```swift
    /// VStack { ... }
    ///     .gameBackground()
    /// ```
    func gameBackground() -> some View {
        modifier(GameBackgroundModifier())
    }
}
