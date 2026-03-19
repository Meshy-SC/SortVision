import SwiftUI

/// Audio settings sub-page — toggle for sound effects.
///
/// Accessed from the main Settings view. Uses `GameManager`
/// from the environment to read/write the sound preference.
struct AudioSettingsView: View {

    @Environment(GameManager.self) private var gameManager

    var body: some View {
        @Bindable var gameManager = gameManager
        List {
            Section("Sound Effects") {
                Toggle(isOn: $gameManager.soundEnabled) {
                    Label(
                        "All Sound Effects",
                        systemImage: gameManager.soundEnabled
                            ? "speaker.wave.2.fill"
                            : "speaker.slash.fill"
                    )
                }
            }
        }
        .navigationTitle("Audio")
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
    }
}
