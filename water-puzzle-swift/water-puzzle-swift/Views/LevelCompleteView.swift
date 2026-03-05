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
                    // Continue button — mirrors Unity LevelCompletePanel continue
                    if gameManager.hasNextLevel(mode: gameMode, after: levelNumber) {
                        Button {
                            if let nextLevel = gameManager.level(
                                for: gameMode, number: levelNumber + 1)
                            {
                                path.removeLast()
                                path.append(AppScreen.gameplay(gameMode, nextLevel))
                            }
                        } label: {
                            Text("Continue")
                                .font(.system(size: 20, weight: .bold, design: .rounded))
                                .foregroundStyle(.white)
                                .frame(width: 200, height: 55)
                                .background(
                                    RoundedRectangle(cornerRadius: 14)
                                        .fill(Color.green.opacity(0.85))
                                )
                                .shadow(color: .green.opacity(0.3), radius: 6, y: 3)
                        }
                    }

                    // Main Menu button — mirrors Unity LevelCompletePanel menu
                    Button {
                        path.removeLast(path.count)
                    } label: {
                        Text("Main Menu")
                            .font(.system(size: 20, weight: .bold, design: .rounded))
                            .foregroundStyle(.white)
                            .frame(width: 200, height: 55)
                            .background(
                                RoundedRectangle(cornerRadius: 14)
                                    .fill(Color.gray.opacity(0.5))
                            )
                    }
                }
            }
            .padding(40)
            .background(
                RoundedRectangle(cornerRadius: 24)
                    .fill(Color(red: 0.14, green: 0.17, blue: 0.24))
                    .shadow(color: .black.opacity(0.4), radius: 20)
            )
        }
        .onAppear {
            displayedMessage = toastMessages.randomElement() ?? "Great!"
        }
    }
}
