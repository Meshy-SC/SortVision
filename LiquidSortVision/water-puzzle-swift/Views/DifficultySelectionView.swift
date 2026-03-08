import SwiftUI

/// Difficulty selection — the app's root screen.
///
/// Presents each difficulty mode as a standard list row with
/// a progress indicator, matching Apple's native apps.
/// Includes a settings button in the toolbar.
struct DifficultySelectionView: View {
    @Environment(GameManager.self) private var gameManager
    @Binding var path: NavigationPath
    @State private var showSettings = false

    var body: some View {
        List {
            ForEach(GameMode.allCases) { mode in
                let completed = gameManager.completedLevel(for: mode)
                let total = gameManager.levels(for: mode).count

                Button {
                    path.append(AppScreen.levelGrid(mode))
                } label: {
                    HStack {
                        Label(mode.displayName, systemImage: iconName(for: mode))
                            .font(.body.weight(.medium))

                        Spacer()

                        Text("\(completed)/\(total)")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)

                        Image(systemName: "chevron.right")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.tertiary)
                    }
                    .padding(.vertical, 4)
                }
                .tint(.primary)
                .accessibilityLabel("\(mode.displayName), \(completed) of \(total) completed")
                .accessibilityHint("Double tap to view \(mode.displayName) levels")
            }
        }
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
}
