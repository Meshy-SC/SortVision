import SwiftUI
import WidgetKit

// MARK: - Widget Timeline

/// Timeline provider for the Water Puzzle widget.
///
/// Generates a single entry showing the player's progress across all difficulties.
/// Refreshes on a 1-hour cadence — actual updates are triggered by
/// `WidgetCenter.shared.reloadAllTimelines()` when levels are completed.
struct WaterPuzzleTimelineProvider: TimelineProvider {
    /// Known total level counts per difficulty.
    /// These must match the actual level JSON files in the main app bundle.
    private static let totalLevels: [GameMode: Int] = [
        .easy: 100,
        .normal: 200,
        .hard: 200,
        .expert: 300,
    ]

    func placeholder(in context: Context) -> WaterPuzzleWidgetEntry {
        WaterPuzzleWidgetEntry(
            date: .now,
            progressByMode: GameMode.allCases.map { mode in
                WidgetDataProvider.DifficultyProgress(
                    mode: mode,
                    completedCount: 0,
                    nextLevel: 1,
                    totalLevels: Self.totalLevels[mode] ?? 100
                )
            }
        )
    }

    func getSnapshot(in context: Context, completion: @escaping (WaterPuzzleWidgetEntry) -> Void) {
        completion(createEntry())
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<WaterPuzzleWidgetEntry>) -> Void) {
        let entry = createEntry()
        // Refresh in 1 hour; actual updates happen via WidgetCenter reload
        let nextUpdate = Calendar.current.date(byAdding: .hour, value: 1, to: .now)!
        let timeline = Timeline(entries: [entry], policy: .after(nextUpdate))
        completion(timeline)
    }

    private func createEntry() -> WaterPuzzleWidgetEntry {
        WaterPuzzleWidgetEntry(
            date: .now,
            progressByMode: GameMode.allCases.map { mode in
                WidgetDataProvider.progress(
                    for: mode,
                    totalLevels: Self.totalLevels[mode] ?? 100
                )
            }
        )
    }
}

// MARK: - Widget Entry

/// A single timeline entry containing progress data for all difficulties.
struct WaterPuzzleWidgetEntry: TimelineEntry {
    let date: Date
    let progressByMode: [WidgetDataProvider.DifficultyProgress]
}

// MARK: - Widget View

/// The widget's SwiftUI view, showing the best difficulty to resume.
///
/// Displays the first non-completed difficulty with a "Continue" prompt
/// and a progress ring. If all are complete, shows a congratulations state.
struct WaterPuzzleWidgetView: View {
    let entry: WaterPuzzleWidgetEntry

    @Environment(\.widgetFamily) private var family

    /// The first difficulty that still has unsolved levels.
    private var activeDifficulty: WidgetDataProvider.DifficultyProgress? {
        entry.progressByMode.first { !$0.isAllComplete }
    }

    var body: some View {
        Group {
            if let active = activeDifficulty {
                activeView(active)
            } else {
                allCompleteView
            }
        }
        .containerBackground(for: .widget) {
            LinearGradient(
                colors: [
                    Color(red: 0.10, green: 0.13, blue: 0.20),
                    Color(red: 0.16, green: 0.20, blue: 0.30),
                ],
                startPoint: .top, endPoint: .bottom
            )
        }
    }

    // MARK: - Active Game View

    private func activeView(_ progress: WidgetDataProvider.DifficultyProgress) -> some View {
        VStack(spacing: 6) {
            HStack {
                Image(systemName: "drop.fill")
                    .foregroundStyle(colorForMode(progress.mode))
                Text("Water Sort")
                    .font(.system(.caption, design: .rounded, weight: .bold))
                    .foregroundStyle(.white)
                Spacer()
            }

            Spacer()

            // Progress ring
            ZStack {
                Circle()
                    .stroke(.white.opacity(0.15), lineWidth: 4)
                Circle()
                    .trim(from: 0, to: progress.progress)
                    .stroke(
                        colorForMode(progress.mode),
                        style: StrokeStyle(lineWidth: 4, lineCap: .round)
                    )
                    .rotationEffect(.degrees(-90))

                VStack(spacing: 0) {
                    Text("\(progress.nextLevel)")
                        .font(.system(.title2, design: .rounded, weight: .bold))
                        .foregroundStyle(.white)
                    Text(progress.mode.displayName)
                        .font(.system(.caption2, design: .rounded))
                        .foregroundStyle(.white.opacity(0.7))
                }
            }
            .frame(width: 60, height: 60)

            Spacer()

            Text("Continue →")
                .font(.system(.caption, design: .rounded, weight: .medium))
                .foregroundStyle(.white.opacity(0.8))
        }
        .padding()
        .widgetURL(deepLinkURL(mode: progress.mode, level: progress.nextLevel))
    }

    // MARK: - All Complete View

    private var allCompleteView: some View {
        VStack(spacing: 8) {
            Image(systemName: "trophy.fill")
                .font(.title)
                .foregroundStyle(.yellow)
            Text("All Complete!")
                .font(.system(.caption, design: .rounded, weight: .bold))
                .foregroundStyle(.white)
        }
        .padding()
    }

    // MARK: - Helpers

    private func colorForMode(_ mode: GameMode) -> Color {
        switch mode {
        case .easy: .green
        case .normal: .blue
        case .hard: .orange
        case .expert: .red
        }
    }

    private func deepLinkURL(mode: GameMode, level: Int) -> URL {
        // Values are developer-controlled integers, but avoid force-unwrap as defensive practice
        guard let url = URL(string: "waterpuzzle://play?mode=\(mode.rawValue)&level=\(level)") else {
            return URL(string: "waterpuzzle://play")!
        }
        return url
    }
}

// MARK: - Widget Declaration

/// Home Screen / StandBy / Lock Screen widget for Water Sort Puzzle.
///
/// Shows the player's next playable level with a progress ring.
/// Tapping opens the app directly to that level.
///
/// ## Setup Required
/// To use this widget, add a Widget Extension target in Xcode:
/// File → New → Target → Widget Extension.
/// Then move this file into that target and add `GameMode`,
/// `WidgetDataProvider`, and the data models to the shared framework.
struct WaterPuzzleWidget: Widget {
    let kind: String = "WaterPuzzleWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: WaterPuzzleTimelineProvider()) { entry in
            WaterPuzzleWidgetView(entry: entry)
        }
        .configurationDisplayName("Water Sort Puzzle")
        .description("See your next level and continue playing.")
        .supportedFamilies([.systemSmall])
    }
}
