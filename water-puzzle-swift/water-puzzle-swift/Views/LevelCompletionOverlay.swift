import SwiftUI

/// Level completion overlay. Mirrors Unity's LevelCompletePanel:
/// - Random toast message ("Great!", "Awesome!", etc.)
/// - Continue button → loads next level
/// - Main Menu button → returns to root
struct LevelCompletionOverlay: View {
    let gameMode: GameMode
    let levelNumber: Int
    @Binding var path: NavigationPath
    @Environment(GameManager.self) private var gameManager
    @AccessibilityFocusState private var isOverlayFocused: Bool

    /// Random congratulation messages matching the Unity ToastMessage pool.
    private let toastMessages = [
        "Great!", "Awesome!", "Well Done!", "Amazing!",
        "Perfect!", "Brilliant!", "Fantastic!", "Excellent!",
    ]

    @State private var displayedMessage: String = "Great!"

    var body: some View {
        ZStack {
            // Dimmed background
            Color.black.opacity(0.5)
                .ignoresSafeArea()
                .onTapGesture {} // Absorb taps

            VStack(spacing: 24) {
                // Toast message
                Text(displayedMessage)
                    .font(.system(.title, design: .rounded, weight: .bold))
                    .foregroundStyle(.yellow)
                    .accessibilityFocused($isOverlayFocused)

                Text("Level \(levelNumber) Complete!")
                    .font(.system(.title3, design: .rounded, weight: .medium))
                    .foregroundStyle(.white)

                VStack(spacing: 16) {
                    // Continue button — uses built-in borderedProminent style
                    if gameManager.hasNextLevel(mode: gameMode, after: levelNumber) {
                        Button("Continue") {
                            if let nextLevel = gameManager.level(
                                for: gameMode, number: levelNumber + 1)
                            {
                                path.removeLast()
                                path.append(AppScreen.gameplay(gameMode, nextLevel))
                            }
                        }
                        .font(.system(.title3, design: .rounded, weight: .bold))
                        .buttonStyle(.borderedProminent)
                        .tint(.green)
                        .controlSize(.large)
                        .buttonBorderShape(.roundedRectangle(radius: 14))
                        .accessibilityHint("Advances to level \(levelNumber + 1)")
                        .keyboardShortcut(.defaultAction)
                    }

                    // Main Menu button — uses built-in borderedProminent style
                    Button("Main Menu") {
                        path.removeLast(path.count)
                    }
                    .font(.system(.title3, design: .rounded, weight: .bold))
                    .buttonStyle(.borderedProminent)
                    .tint(.gray)
                    .controlSize(.large)
                    .buttonBorderShape(.roundedRectangle(radius: 14))
                    .accessibilityHint("Returns to the main menu")
                    .keyboardShortcut(.cancelAction)
                }
            }
            .padding(40)
            .background(.ultraThickMaterial, in: RoundedRectangle(cornerRadius: 24))
            .shadow(radius: 20)
            .accessibilityElement(children: .contain)
            .accessibilityAddTraits(.isModal)
        }
        .onAppear {
            displayedMessage = toastMessages.randomElement() ?? "Great!"
            // Move VoiceOver focus to the overlay after a brief delay
            Task {
                try? await Task.sleep(for: .milliseconds(500))
                isOverlayFocused = true
            }
        }
    }
}
