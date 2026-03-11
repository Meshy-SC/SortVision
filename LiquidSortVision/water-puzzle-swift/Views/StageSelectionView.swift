import SwiftUI

/// Stage selection — the app's root screen.
///
/// Presents each of the 10 metal/material-themed stages as a list row
/// with colored SF Symbols, a progress bar, and a completion counter.
/// Stages are unlocked sequentially: complete all levels in a stage
/// to unlock the next. Stages without content show "Coming Soon".
struct StageSelectionView: View {
    @Environment(GameManager.self) private var gameManager
    @State private var showSettings = false

    var body: some View {
        List {
            Section {
                ForEach(Stage.allCases) { stage in
                    let totalInStage = gameManager.levels(for: stage).count
                    let completedInStage = gameManager.completedCountInStage(stage)
                    let isAccessible = gameManager.isStageAccessible(stage)

                    if !stage.isAvailable {
                        comingSoonRow(stage: stage)
                    } else if isAccessible {
                        NavigationLink(value: AppScreen.levelGrid(stage)) {
                            stageRow(
                                stage: stage,
                                completed: completedInStage,
                                total: totalInStage
                            )
                        }
                        .accessibilityLabel(
                            "\(stage.displayName), \(completedInStage) of \(totalInStage) completed"
                        )
                        .accessibilityHint("Double tap to view \(stage.displayName) levels")
                    } else {
                        lockedRow(stage: stage, total: totalInStage)
                    }
                }
            } header: {
                Text("Stages")
            } footer: {
                Text("Complete all levels in a stage to unlock the next one.")
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

    // MARK: - Row Views

    private func stageRow(stage: Stage, completed: Int, total: Int) -> some View {
        HStack(spacing: 12) {
            Image(systemName: stage.iconName)
                .font(.title3)
                .foregroundStyle(stage.themeColor)
                .symbolRenderingMode(.hierarchical)
                .frame(width: 28)

            VStack(alignment: .leading, spacing: 4) {
                Text(stage.displayName)
                    .font(.body)

                if total > 0 {
                    ProgressView(value: Double(completed), total: Double(total))
                        .tint(stage.themeColor)
                }
            }

            Spacer()

            Text("\(completed)/\(total)")
                .font(.subheadline.monospacedDigit())
                .foregroundStyle(.secondary)
                .contentTransition(.numericText())
        }
        .padding(.vertical, 2)
    }

    private func lockedRow(stage: Stage, total: Int) -> some View {
        HStack(spacing: 12) {
            Image(systemName: "lock.fill")
                .font(.title3)
                .foregroundStyle(.secondary)
                .frame(width: 28)

            VStack(alignment: .leading, spacing: 4) {
                Text(stage.displayName)
                    .font(.body)
                    .foregroundStyle(.secondary)

                ProgressView(value: 0, total: Double(max(total, 1)))
                    .tint(.secondary)
            }

            Spacer()

            Text("0/\(total)")
                .font(.subheadline.monospacedDigit())
                .foregroundStyle(.tertiary)
        }
        .padding(.vertical, 2)
        .accessibilityLabel("\(stage.displayName), locked")
        .accessibilityHint("Complete the previous stage to unlock")
    }

    private func comingSoonRow(stage: Stage) -> some View {
        HStack(spacing: 12) {
            Image(systemName: stage.iconName)
                .font(.title3)
                .foregroundStyle(stage.themeColor.opacity(0.5))
                .symbolRenderingMode(.hierarchical)
                .frame(width: 28)

            Text(stage.displayName)
                .font(.body)
                .foregroundStyle(.secondary)

            Spacer()

            Text("Coming Soon")
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
        .padding(.vertical, 2)
        .accessibilityLabel("\(stage.displayName), coming soon")
    }
}
