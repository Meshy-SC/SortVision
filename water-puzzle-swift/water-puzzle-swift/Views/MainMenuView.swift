import SwiftUI

/// Main menu screen. Mirrors Unity's MainMenu scene with MenuPanel.
struct MainMenuView: View {
    @Environment(GameManager.self) private var gameManager
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Binding var path: NavigationPath

    var body: some View {
        ZStack {
            // Background applied via reusable modifier
            Color.clear
                .gameBackground()

            VStack(spacing: 32) {
                Spacer()

                // Game title — mirrors the logo sprite
                VStack(spacing: 8) {
                    Text("Water Sort")
                        .font(.system(.largeTitle, design: .rounded, weight: .bold))
                        .foregroundStyle(.white)
                    Text("Puzzle")
                        .font(.system(.title, design: .rounded, weight: .medium))
                        .foregroundStyle(.white.opacity(0.8))
                }
                .accessibilityElement(children: .combine)
                .accessibilityAddTraits(.isHeader)
                .accessibilityLabel("Water Sort Puzzle")

                Spacer()

                // Play button — uses built-in borderedProminent style
                // Automatic Liquid Glass on iOS 26+; platform-adaptive on macOS & visionOS
                Button("PLAY") {
                    path.append(AppScreen.difficultySelect)
                }
                .font(.system(.title2, design: .rounded, weight: .bold))
                .buttonStyle(.borderedProminent)
                .tint(Color(red: 0.16, green: 0.50, blue: 0.73))
                .controlSize(.extraLarge)
                .buttonBorderShape(.roundedRectangle(radius: 16))
                .accessibilityHint("Opens difficulty selection")
                .keyboardShortcut(.defaultAction)

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
                .accessibilityLabel(gameManager.soundEnabled ? "Sound on" : "Sound off")
                .accessibilityHint("Double tap to toggle sound effects")
                #if os(iOS)
                .sensoryFeedback(.selection, trigger: gameManager.soundEnabled)
                #endif

                Spacer()
                    .frame(height: 60)
            }
        }
        .navigationTitle("Water Sort Puzzle")
        #if os(iOS)
        .toolbarVisibility(.hidden, for: .navigationBar)
        #endif
        .navigationBarBackButtonHidden(true)
    }
}
