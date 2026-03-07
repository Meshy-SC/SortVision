import SwiftUI

/// Heads-Up Display overlay for the gameplay screen.
///
/// Displays navigation controls and level information in a top-aligned bar:
/// - **Home button**: Returns to main menu (left)
/// - **Level indicator**: Shows current level number (center)
/// - **Restart button**: Resets the current level (right)
///
/// Mirrors Unity's `Game/UIManager` HUD layout.
struct GameHUDView: View {
    let levelNumber: Int
    let onHome: () -> Void
    let onRestart: () -> Void

    var body: some View {
        VStack {
            HStack(spacing: 16) {
                // Home button — returns to main menu
                Button(action: onHome) {
                    Image(systemName: "house.fill")
                }
                .buttonStyle(.bordered)
                .buttonBorderShape(.circle)
                .tint(.white)

                Spacer()

                // Level indicator
                Text("Level \(levelNumber)")
                    .font(.system(size: 20, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)

                Spacer()

                // Restart button
                Button(action: onRestart) {
                    Image(systemName: "arrow.counterclockwise")
                }
                .buttonStyle(.bordered)
                .buttonBorderShape(.circle)
                .tint(.white)
            }
            .padding(.horizontal, 20)
            .padding(.top, 12)

            Spacer()
        }
    }
}
