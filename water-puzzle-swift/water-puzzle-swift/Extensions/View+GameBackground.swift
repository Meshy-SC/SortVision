import SwiftUI

/// Reusable dark gradient background matching the app's visual theme.
///
/// Applied consistently across menu screens (MainMenu, DifficultySelect, LevelGrid)
/// to ensure visual coherence and eliminate code duplication.
struct GameBackgroundModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
            .background {
                LinearGradient(
                    colors: [
                        Color(red: 0.10, green: 0.13, blue: 0.20),
                        Color(red: 0.16, green: 0.20, blue: 0.30),
                    ],
                    startPoint: .top, endPoint: .bottom
                )
                .ignoresSafeArea()
            }
    }
}

extension View {
    /// Applies the standard dark gradient background used across menu screens.
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
