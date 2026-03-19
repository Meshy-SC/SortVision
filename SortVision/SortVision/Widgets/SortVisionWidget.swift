import SwiftUI
import WidgetKit

// MARK: - Widget Timeline

/// Timeline provider for the SortVision widget.
///
/// Generates a single entry showing the player's progress in their current stage.
/// Refreshes on a 1-hour cadence — actual updates are triggered by
/// `WidgetCenter.shared.reloadAllTimelines()` when levels are completed.
struct SortVisionTimelineProvider: TimelineProvider {

    func placeholder(in context: Context) -> SortVisionWidgetEntry {
        SortVisionWidgetEntry(
            date: .now,
            progress: WidgetDataProvider.GameProgress(
                completedCount: 0,
                currentStage: .iron,
                nextLevel: 1
            )
        )
    }

    func getSnapshot(in context: Context, completion: @escaping (SortVisionWidgetEntry) -> Void) {
        completion(createEntry())
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<SortVisionWidgetEntry>) -> Void) {
        let entry = createEntry()
        // Refresh in 1 hour; actual updates happen via WidgetCenter reload
        let nextUpdate = Calendar.current.date(byAdding: .hour, value: 1, to: .now)!
        let timeline = Timeline(entries: [entry], policy: .after(nextUpdate))
        completion(timeline)
    }

    private func createEntry() -> SortVisionWidgetEntry {
        SortVisionWidgetEntry(
            date: .now,
            progress: WidgetDataProvider.progress()
        )
    }
}

// MARK: - Widget Entry

/// A single timeline entry containing the player's current progress.
struct SortVisionWidgetEntry: TimelineEntry {
    let date: Date
    let progress: WidgetDataProvider.GameProgress
}

// MARK: - Widget View

/// The widget's SwiftUI view, showing the current stage and next level.
///
/// Displays the player's current stage with a progress ring and
/// "Continue" prompt. If all available levels are complete, shows
/// a congratulations state.
struct SortVisionWidgetView: View {
    let entry: SortVisionWidgetEntry

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
                Image(systemName: progress.currentStage.iconName)
                    .foregroundStyle(progress.currentStage.themeColor)
                Text("World \(progress.currentStage.worldNumber)")
                    .font(.system(.caption, design: .rounded, weight: .bold))
                    .foregroundStyle(.primary)
                Spacer()
            }

            Spacer()

            // Progress gauge — uses the same Gauge style as the main app
            let localLevel = Stage.localLevelNumber(for: progress.nextLevel)
            Gauge(value: progress.stageProgress, in: 0...1) {
                // Label intentionally empty — title shown below.
            } currentValueLabel: {
                VStack(spacing: 0) {
                    Text("\(localLevel)")
                        .font(.system(size: 18, weight: .bold, design: .rounded))
                        .foregroundStyle(.primary)
                        .contentTransition(.numericText())
                    Text(progress.currentStage.displayName)
                        .font(.system(size: 8, weight: .regular, design: .rounded))
                        .foregroundStyle(.secondary)
                }
                .minimumScaleFactor(0.5)
            }
            .gaugeStyle(.accessoryCircularCapacity)
            .tint(progress.currentStage.themeColor)
            .frame(width: 60, height: 60)

            Spacer()

            Text("Continue →")
                .font(.system(.caption, design: .rounded, weight: .medium))
                .foregroundStyle(progress.currentStage.themeColor)
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
        guard let url = URL(string: "flowvision://play?level=\(level)") else {
            return URL(string: "flowvision://play")!
        }
        return url
    }
}

// MARK: - Widget Declaration

/// Home Screen / StandBy / Lock Screen widget for SortVision.
///
/// Shows the player's current stage and next playable level with a progress ring.
/// Tapping opens the app directly to that level.
///
/// ## Setup Required
/// To use this widget, add a Widget Extension target in Xcode:
/// File → New → Target → Widget Extension.
/// Then move this file into that target and add `Stage`,
/// `WidgetDataProvider`, and the data models to the shared framework.
struct SortVisionWidget: Widget {
    let kind: String = "SortVisionWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: SortVisionTimelineProvider()) { entry in
            SortVisionWidgetView(entry: entry)
        }
        .configurationDisplayName("SortVision")
        .description("See your next level and continue playing.")
        .supportedFamilies([.systemSmall])
    }
}
