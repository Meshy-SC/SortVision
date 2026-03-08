import SwiftUI

/// Main menu — clean, native Apple aesthetic.
///
/// Uses the system background, large navigation title, and standard
/// SwiftUI button styles. No custom backgrounds or forced colors.
struct MainMenuView: View {
    @Environment(GameManager.self) private var gameManager
    @Binding var path: NavigationPath

    var body: some View {
        VStack(spacing: 0) {
            Spacer()

            // App icon / branding area
            Image(systemName: "drop.fill")
                .font(.system(size: 80))
                .foregroundStyle(.tint)
                .symbolEffect(.pulse, options: .repeating)
                .accessibilityHidden(true)
                .padding(.bottom, 8)

            Text("Water Sort Puzzle")
                .font(.largeTitle.bold())
                .accessibilityAddTraits(.isHeader)

            Text("Sort the colors!")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .padding(.top, 2)

            Spacer()

            // Primary action
            Button {
                path.append(AppScreen.difficultySelect)
            } label: {
                Text("Play")
                    .font(.title3.weight(.semibold))
                    .frame(maxWidth: 280)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.extraLarge)
            .accessibilityHint("Opens difficulty selection")
            .keyboardShortcut(.defaultAction)

            // Sound toggle
            Button {
                gameManager.soundEnabled.toggle()
            } label: {
                Label(
                    gameManager.soundEnabled ? "Sound On" : "Sound Off",
                    systemImage: gameManager.soundEnabled
                        ? "speaker.wave.2.fill" : "speaker.slash.fill"
                )
            }
            .buttonStyle(.bordered)
            .controlSize(.regular)
            .padding(.top, 16)
            .accessibilityHint("Double tap to toggle sound effects")
            #if os(iOS)
            .sensoryFeedback(.selection, trigger: gameManager.soundEnabled)
            #endif

            Spacer()
                .frame(height: 60)
        }
        .frame(maxWidth: .infinity)
        .navigationTitle("Water Sort Puzzle")
        #if os(iOS)
        .toolbarVisibility(.hidden, for: .navigationBar)
        #endif
        .navigationBarBackButtonHidden(true)
    }
}
