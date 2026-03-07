import SwiftUI

/// Level completion overlay. Mirrors Unity's LevelCompletePanel:
/// - Random toast message ("Great!", "Awesome!", etc.)
/// - Continue button → loads next level
/// - Main Menu button → returns to root
struct LevelCompleteView: View {
    let gameMode: GameMode
    let levelNumber: Int
    @Binding var path: NavigationPath
    @Environment(GameManager.self) private var gameManager

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
                    .font(.system(size: 38, weight: .bold, design: .rounded))
                    .foregroundStyle(.yellow)

                Text("Level \(levelNumber) Complete!")
                    .font(.system(size: 22, weight: .medium, design: .rounded))
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
                        .font(.system(size: 20, weight: .bold, design: .rounded))
                        .buttonStyle(.borderedProminent)
                        .tint(.green)
                        .controlSize(.large)
                        .buttonBorderShape(.roundedRectangle(radius: 14))
                    }

                    // Main Menu button — uses built-in borderedProminent style
                    Button("Main Menu") {
                        path.removeLast(path.count)
                    }
                    .font(.system(size: 20, weight: .bold, design: .rounded))
                    .buttonStyle(.borderedProminent)
                    .tint(.gray)
                    .controlSize(.large)
                    .buttonBorderShape(.roundedRectangle(radius: 14))
                }
            }
            .padding(40)
            .background(.ultraThickMaterial, in: RoundedRectangle(cornerRadius: 24))
            .shadow(radius: 20)
        }
        .onAppear {
            displayedMessage = toastMessages.randomElement() ?? "Great!"
        }
    }
}
