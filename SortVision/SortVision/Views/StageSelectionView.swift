import SwiftUI

/// World selection — the app's root screen.
///
/// Presents worlds in a `List` with a stats section at top showing
/// circular gauges for Progress and Stars. Worlds unlock sequentially.
/// Mirrors ParkVision's `GameModeBrowserView` pattern.
struct StageSelectionView: View {
    @Environment(GameManager.self) private var gameManager

    /// Message shown in the locked-world alert.
    @State private var lockedStageAlertMessage: String?

    var body: some View {
        List {
            // MARK: Stats
            Section {
                HStack(spacing: 30) {
                    CircularStatGauge(
                        title: "Progress",
                        value: overallCompletionPercentage,
                        maxValue: 100,
                        tintColor: .green
                    )
                    CircularStatGauge(
                        title: "Stars",
                        value: Double(gameManager.totalStars),
                        maxValue: Double(gameManager.maxStars),
                        tintColor: .yellow
                    )
                }
                .frame(maxWidth: .infinity, alignment: .center)
            }
            .listRowBackground(Color.clear)

            // MARK: Worlds
            Section {
                ForEach(Stage.allCases) { stage in
                    let totalInStage = gameManager.levels(for: stage).count
                    let completedInStage = gameManager.completedCountInStage(stage)
                    let isAccessible = gameManager.isStageAccessible(stage)

                    if !stage.isAvailable {
                        stageRow(stage: stage, completed: 0, total: Stage.levelsPerStage, isUnlocked: false, isComingSoon: true)
                    } else if isAccessible {
                        NavigationLink(value: AppScreen.levelGrid(stage)) {
                            stageRow(stage: stage, completed: completedInStage, total: totalInStage, isUnlocked: true, isComingSoon: false)
                        }
                        .accessibilityLabel(stageAccessibilityLabel(stage: stage, completed: completedInStage, total: totalInStage))
                    } else {
                        Button {
                            lockedStageAlertMessage = "Complete all levels in the previous world to unlock \(stage.displayName)."
                        } label: {
                            stageRow(stage: stage, completed: 0, total: totalInStage, isUnlocked: false, isComingSoon: false)
                        }
                        .accessibilityLabel("World \(stage.worldNumber), \(stage.displayName), locked")
                    }
                }
            } header: {
                Text("Worlds")
            }
        }
        #if os(iOS)
        .listStyle(.insetGrouped)
        #elseif os(macOS)
        .listStyle(.sidebar)
        #endif
        .navigationTitle("SortVision")
        #if os(iOS)
        .navigationBarTitleDisplayMode(.large)
        #endif
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                NavigationLink {
                    SettingsView()
                } label: {
                    Label("Settings", systemImage: "gearshape")
                }
                .accessibilityHint("Opens app settings")
            }
        }
        .alert("World Locked", isPresented: Binding(
            get: { lockedStageAlertMessage != nil },
            set: { if !$0 { lockedStageAlertMessage = nil } }
        )) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(lockedStageAlertMessage ?? "")
        }
    }

    // MARK: - Overall Progress

    private var overallCompletionPercentage: Double {
        let totalLevels = Stage.allCases.reduce(0) { $0 + gameManager.levels(for: $1).count }
        guard totalLevels > 0 else { return 0 }
        let totalCompleted = Stage.allCases.reduce(0) { $0 + gameManager.completedCountInStage($1) }
        return Double(totalCompleted) / Double(totalLevels) * 100
    }

    // MARK: - World Row

    private func stageRow(stage: Stage, completed: Int, total: Int, isUnlocked: Bool, isComingSoon: Bool) -> some View {
        HStack {
            Image(systemName: isUnlocked ? stage.iconName : (isComingSoon ? "clock" : "lock.fill"))
                .font(.title2)
                .foregroundStyle(isUnlocked ? stage.themeColor : .secondary)
                .frame(width: 36, height: 36)

            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(stage.displayName)
                        .font(.headline)

                    if isComingSoon {
                        Text("Coming Soon")
                            .font(.caption2.weight(.medium))
                            .foregroundStyle(.white.opacity(0.7))
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Capsule().fill(.secondary.opacity(0.3)))
                    }
                }

                Text(stage.subtitle)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            if isUnlocked {
                HStack(spacing: 4) {
                    Text("\(completed)/\(total)")
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(.secondary)
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
            }
        }
        .opacity(isUnlocked ? 1.0 : 0.6)
    }

    // MARK: - Accessibility

    private func stageAccessibilityLabel(stage: Stage, completed: Int, total: Int) -> String {
        "\(stage.displayName), \(completed) of \(total) levels completed"
    }
}
