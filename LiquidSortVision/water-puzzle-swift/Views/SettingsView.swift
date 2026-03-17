import SwiftUI

/// App settings presented as a sheet with world-themed styling.
///
/// Offers sound toggle and app info. Designed to be extended
/// with additional settings in the future (e.g., haptics,
/// colour-blind mode, reset progress).
struct SettingsView: View {
    @Environment(GameManager.self) private var gameManager
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Toggle(isOn: Bindable(gameManager).soundEnabled) {
                        Label("Sound Effects", systemImage: "speaker.wave.2.fill")
                    }
                    #if os(iOS)
                    .sensoryFeedback(.selection, trigger: gameManager.soundEnabled)
                    #endif
                } header: {
                    Text("Audio")
                } footer: {
                    Text("Plays sound effects during gameplay.")
                }

                Section {
                    LabeledContent {
                        Text(Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0")
                    } label: {
                        Label("Version", systemImage: "info.circle")
                    }

                    LabeledContent {
                        Text("10 Worlds × 100 Levels")
                    } label: {
                        Label("Total Levels", systemImage: "square.grid.3x3")
                    }
                } header: {
                    Text("About")
                }
            }
            .navigationTitle("Settings")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
        .presentationDetents([.medium])
        .presentationDragIndicator(.visible)
    }
}
