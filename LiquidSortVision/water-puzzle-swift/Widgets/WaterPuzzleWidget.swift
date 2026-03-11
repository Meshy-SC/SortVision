import SwiftUI
import WidgetKit

// MARK: - Widget Timeline

/// Timeline provider for the Water Puzzle widget.
///
/// Generates a single entry showing the player's progress in their current stage.
/// Refreshes on a 1-hour cadence — actual updates are triggered by
/// `WidgetCenter.shared.reloadAllTimelines()` when levels are completed.
struct WaterPuzzleTimelineProvider: TimelineProvider {

    func placeholder(in context: Context) -> WaterPuzzleWidgetEntry {
        WaterPuzzleWidgetEntry(
            date: .now,
            progress: WidgetDataProvider.GameProgress(
                completedCount: 0,
                currentStage: .iron,
                nextLevel: 1
            )
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
            progress: WidgetDataProvider.progress()
        )
    }
}

// MARK: - Widget Entry

/// A single timeline entry containing the player's current progress.
struct WaterPuzzleWidgetEntry: TimelineEntry {
    let date: Date
    let progress: WidgetDataProvider.GameProgress
}

// MARK: - Widget View

/// The widget's SwiftUI view, showing the current stage and next level.
///
/// Displays the player's current stage with a progress ring and
/// "Continue" prompt. If all available levels are complete, shows
/// a congratulations state.
struct WaterPuzzleWidgetView: View {
    let entry: WaterPuzzleWidgetEntry

    @Environment(\.widgetFamily) private var family

    var body: some View {
        Group {
            if entry.progress.isAllComplete {
                allCompleteView
            } else {
                activeView(entry.progress)
            }
        }
        .containerBackground(.background, for: .widget)
    }

    // MARK: - Active Game View

    private func activeView(_ progress: WidgetDataProvider.GameProgress) -> some View {
        VStack(spacing: 6) {
            HStack {
                Image(systemName: "drop.fill")
                    .foregroundStyle(progress.currentStage.themeColor)
                Text("Water Sort")
                    .font(.system(.caption, design: .rounded, weight: .bold))
                    .foregroundStyle(.primary)
                Spacer()
            }

            Spacer()

            // Progress ring
            ZStack {
                Circle()
                    .stroke(.secondary.opacity(0.3), lineWidth: 4)
                Circle()
                    .trim(from: 0, to: progress.stageProgress)
                    .stroke(
                        progress.currentStage.themeColor,
                        style: StrokeStyle(lineWidth: 4, lineCap: .round)
                    )
                    .rotationEffect(.degrees(-90))

                VStack(spacing: 0) {
                    let localLevel = Stage.localLevelNumber(for: progress.nextLevel)
                    Text("\(localLevel)")
                        .font(.system(.title2, design: .rounded, weight: .bold))
                        .foregroundStyle(.primary)
                        .contentTransition(.numericText())
                    Text(progress.currentStage.displayName)
                        .font(.system(.caption2, design: .rounded))
                        .foregroundStyle(.secondary)
                }
            }
            .frame(width: 60, height: 60)

            Spacer()

            Text("Continue →")
                .font(.system(.caption, design: .rounded, weight: .medium))
                .foregroundStyle(.secondary)
        }
        .padding()
        .widgetURL(deepLinkURL(level: progress.nextLevel))
    }

    // MARK: - All Complete View

    private var allCompleteView: some View {
        VStack(spacing: 8) {
            Image(systemName: "trophy.fill")
                .font(.title)
                .foregroundStyle(.yellow)
            Text("All Complete!")
                .font(.system(.caption, design: .rounded, weight: .bold))
                .foregroundStyle(.primary)
        }
        .padding()
    }

    // MARK: - Helpers

    private func deepLinkURL(level: Int) -> URL {
        guard let url = URL(string: "waterpuzzle://play?level=\(level)") else {
            return URL(string: "waterpuzzle://play")!
        }
        return url
    }
}

// MARK: - Widget Declaration

/// Home Screen / StandBy / Lock Screen widget for Water Sort Puzzle.
///
/// Shows the player's current stage and next playable level with a progress ring.
/// Tapping opens the app directly to that level.
///
/// ## Setup Required
/// To use this widget, add a Widget Extension target in Xcode:
/// File → New → Target → Widget Extension.
/// Then move this file into that target and add `Stage`,
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
