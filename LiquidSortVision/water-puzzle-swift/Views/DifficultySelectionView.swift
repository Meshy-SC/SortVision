import SwiftUI

/// Difficulty selection — the app's root screen.
///
/// Presents each difficulty mode as a native `NavigationLink` list row with
/// colored hierarchical SF Symbols and a progress indicator, matching Apple
/// Settings. Uses `Section` header and footer per HIG. `NavigationLink(value:)`
/// automatically manages the `NavigationStack` path and renders a system chevron.
struct DifficultySelectionView: View {
    @Environment(GameManager.self) private var gameManager
    @State private var showSettings = false

    var body: some View {
        List {
            Section {
                ForEach(GameMode.allCases) { mode in
                    let completed = gameManager.completedLevel(for: mode)
                    let total = gameManager.levels(for: mode).count

                    NavigationLink(value: AppScreen.levelGrid(mode)) {
                        HStack(spacing: 12) {
                            Image(systemName: iconName(for: mode))
                                .font(.title3)
                                .foregroundStyle(colorForMode(mode))
                                .symbolRenderingMode(.hierarchical)
                                .frame(width: 28)

                            Text(mode.displayName)
                                .font(.body)

                            Spacer()

                            Text("\(completed)/\(total)")
                                .font(.subheadline.monospacedDigit())
                                .foregroundStyle(.secondary)
                                .contentTransition(.numericText())
                        }
                        .padding(.vertical, 2)
                    }
                    .accessibilityLabel("\(mode.displayName), \(completed) of \(total) completed")
                    .accessibilityHint("Double tap to view \(mode.displayName) levels")
                }
            } header: {
                Text("Difficulty")
            } footer: {
                Text("Complete levels in order to unlock the next one.")
            }
        }
        #if os(macOS)
        .listStyle(.inset)
        #else
        .listStyle(.insetGrouped)
        #endif
        .navigationTitle("Water Sort")
        #if os(iOS)
        .navigationBarTitleDisplayMode(.large)
        #endif
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    showSettings = true
                } label: {
                    Label("Settings", systemImage: "gearshape")
                }
                .accessibilityHint("Opens app settings")
            }
        }
        .sheet(isPresented: $showSettings) {
            SettingsView()
                .environment(gameManager)
        }
    }

    private func iconName(for mode: GameMode) -> String {
        switch mode {
        case .easy:   "tortoise.fill"
        case .normal: "hare.fill"
        case .hard:   "flame.fill"
        case .expert: "bolt.fill"
        }
    }

    private func colorForMode(_ mode: GameMode) -> Color {
        switch mode {
        case .easy:   .green
        case .normal: .blue
        case .hard:   .orange
        case .expert: .red
        }
    }
}
