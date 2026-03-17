import SwiftUI

/// World selection — the app's root screen.
///
/// Presents each of the 10 worlds as a card with icon, name, subtitle,
/// a circular progress gauge, and completion counter. Worlds unlock
/// sequentially: complete all levels in a world to unlock the next.
/// Worlds without content show "Coming Soon".
struct StageSelectionView: View {
    @Environment(GameManager.self) private var gameManager
    @State private var showSettings = false

    /// Total levels completed across all worlds.
    private var totalCompleted: Int {
        Stage.allCases.reduce(0) { $0 + gameManager.completedCountInStage($1) }
    }

    /// Total levels available across all worlds.
    private var totalAvailable: Int {
        Stage.allCases.reduce(0) { $0 + gameManager.levels(for: $1).count }
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                // Overall progress header
                overallProgressCard

                // World cards
                ForEach(Stage.allCases) { stage in
                    let totalInStage = gameManager.levels(for: stage).count
                    let completedInStage = gameManager.completedCountInStage(stage)
                    let isAccessible = gameManager.isStageAccessible(stage)

                    if !stage.isAvailable {
                        WorldCardView(
                            stage: stage,
                            completed: 0,
                            total: Stage.levelsPerStage,
                            isAccessible: false,
                            isComingSoon: true
                        )
                    } else if isAccessible {
                        NavigationLink(value: AppScreen.levelGrid(stage)) {
                            WorldCardView(
                                stage: stage,
                                completed: completedInStage,
                                total: totalInStage,
                                isAccessible: true,
                                isComingSoon: false
                            )
                        }
                        .buttonStyle(.plain)
                    } else {
                        WorldCardView(
                            stage: stage,
                            completed: 0,
                            total: totalInStage,
                            isAccessible: false,
                            isComingSoon: false
                        )
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
        }
        .background(.background.secondary)
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

    // MARK: - Overall Progress Card

    private var overallProgressCard: some View {
        HStack(spacing: 16) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Overall Progress")
                    .font(.headline)
                    .foregroundStyle(.primary)

                Text("Complete all worlds to unlock the next.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            CircularProgressGauge(
                progress: totalAvailable > 0 ? Double(totalCompleted) / Double(totalAvailable) : 0,
                color: .accentColor,
                size: 52,
                lineWidth: 4
            ) {
                VStack(spacing: 0) {
                    Text("\(totalCompleted)")
                        .font(.system(.caption, design: .rounded, weight: .bold))
                        .foregroundStyle(.primary)
                    Text("/\(totalAvailable)")
                        .font(.system(.caption2, design: .rounded))
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(16)
        .background {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(.regularMaterial)
                .overlay {
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .strokeBorder(Color.accentColor.opacity(0.15), lineWidth: 1)
                }
        }
    }
}
