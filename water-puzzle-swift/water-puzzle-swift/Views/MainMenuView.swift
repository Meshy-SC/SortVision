import SwiftUI

/// Main menu screen. Mirrors Unity's MainMenu scene with MenuPanel.
struct MainMenuView: View {
    @Environment(GameManager.self) private var gameManager
    @Binding var path: NavigationPath

    var body: some View {
        ZStack {
            // Background gradient matching the dark theme
            LinearGradient(
                colors: [
                    Color(red: 0.10, green: 0.13, blue: 0.20),
                    Color(red: 0.16, green: 0.20, blue: 0.30),
                ],
                startPoint: .top, endPoint: .bottom
            )
            .ignoresSafeArea()

            VStack(spacing: 32) {
                Spacer()

                // Game title — mirrors the logo sprite
                VStack(spacing: 8) {
                    Text("Water Sort")
                        .font(.system(size: 48, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                    Text("Puzzle")
                        .font(.system(size: 36, weight: .medium, design: .rounded))
                        .foregroundStyle(.white.opacity(0.8))
                }

                Spacer()

                // Play button — mirrors Unity MenuPanel play button
                Button {
                    path.append(AppScreen.difficultySelect)
                } label: {
                    Text("PLAY")
                        .font(.system(size: 24, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                        .frame(width: 220, height: 64)
                        .background(
                            RoundedRectangle(cornerRadius: 16)
                                .fill(
                                    LinearGradient(
                                        colors: [
                                            Color(red: 0.16, green: 0.50, blue: 0.73),
                                            Color(red: 0.20, green: 0.60, blue: 0.86),
                                        ],
                                        startPoint: .top, endPoint: .bottom
                                    )
                                )
                        )
                        .shadow(color: .blue.opacity(0.3), radius: 8, y: 4)
                }

                // Sound toggle — mirrors Unity SoundButton
                Button {
                    gameManager.soundEnabled.toggle()
                } label: {
                    Image(
                        systemName: gameManager.soundEnabled
                            ? "speaker.wave.2.fill" : "speaker.slash.fill"
                    )
                    .font(.title2)
                    .foregroundStyle(.white.opacity(0.7))
                    .frame(width: 50, height: 50)
                    .background(Circle().fill(.white.opacity(0.1)))
                }

                Spacer()
                    .frame(height: 60)
            }
        }
        .navigationBarBackButtonHidden(true)
    }
}
