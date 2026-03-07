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

                // Play button — uses built-in borderedProminent style
                // Automatic Liquid Glass on iOS 26+; platform-adaptive on macOS & visionOS
                Button("PLAY") {
                    path.append(AppScreen.difficultySelect)
                }
                .font(.system(size: 24, weight: .bold, design: .rounded))
                .buttonStyle(.borderedProminent)
                .tint(Color(red: 0.16, green: 0.50, blue: 0.73))
                .controlSize(.extraLarge)
                .buttonBorderShape(.roundedRectangle(radius: 16))

                // Sound toggle — uses built-in bordered circular button style
                Button {
                    gameManager.soundEnabled.toggle()
                } label: {
                    Image(
                        systemName: gameManager.soundEnabled
                            ? "speaker.wave.2.fill" : "speaker.slash.fill"
                    )
                }
                .buttonStyle(.bordered)
                .buttonBorderShape(.circle)
                .tint(.white)

                Spacer()
                    .frame(height: 60)
            }
        }
        .navigationBarBackButtonHidden(true)
    }
}
