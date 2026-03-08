import SwiftUI

/// App settings presented as a native sheet.
///
/// Currently offers a sound toggle. Designed to be extended
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
                        Label("Sound Effects", systemImage: "speaker.wave.2")
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
                    LabeledContent("Version") {
                        Text(Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0")
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
