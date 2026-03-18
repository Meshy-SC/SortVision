import SwiftUI

/// A prominent header card displayed at the top of the level grid.
///
/// Shows the world's icon, name, subtitle, and stat gauges
/// for Progress and Stars, matching Pushbox's visual style.
struct WorldHeaderView: View {
    let stage: Stage
    let completed: Int
    let total: Int
    let totalStars: Int
    let maxStars: Int

    private var progress: Double {
        guard total > 0 else { return 0 }
        return Double(completed) / Double(total)
    }

    var body: some View {
        VStack(spacing: 16) {
            // World info row
            HStack(spacing: 16) {
                // World icon
                ZStack {
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [stage.themeColor, stage.secondaryColor],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 52, height: 52)

                    Image(systemName: stage.iconName)
                        .font(.title2.weight(.semibold))
                        .foregroundStyle(.white)
                        .symbolRenderingMode(.hierarchical)
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text("World \(stage.worldNumber)")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(stage.themeColor)
                        .textCase(.uppercase)
                        .tracking(0.5)

                    Text(stage.displayName)
                        .font(.title2.weight(.bold))
                        .foregroundStyle(.primary)

                    Text(stage.subtitle)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                Spacer()
            }

            // Stat gauges row
            HStack(spacing: 0) {
                Spacer()

                // Progress gauge
                CircularStatGauge(
                    value: completed,
                    maxValue: total,
                    title: "Progress",
                    tintColor: stage.themeColor
                )

                Spacer()

                // Stars gauge
                CircularStatGauge(
                    value: totalStars,
                    maxValue: maxStars,
                    title: "Stars",
                    tintColor: .yellow
                )

                Spacer()
            }
        }
        .padding(20)
        .background {
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(.regularMaterial)
                .overlay {
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .fill(stage.themeColor.opacity(0.06))
                }
                .overlay {
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .strokeBorder(stage.themeColor.opacity(0.15), lineWidth: 1)
                }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(
            "World \(stage.worldNumber), \(stage.displayName), \(completed) of \(total) completed, \(totalStars) of \(maxStars) stars"
        )
    }
}

// MARK: - CircularStatGauge

/// A circular gauge showing value/max with a title label, matching Pushbox's design.
struct CircularStatGauge: View {
    let value: Int
    let maxValue: Int
    let title: String
    let tintColor: Color

    private var progress: Double {
        guard maxValue > 0 else { return 0 }
        return min(Double(value) / Double(maxValue), 1.0)
    }

    var body: some View {
        VStack(spacing: 6) {
            ZStack {
                // Background track
                Circle()
                    .strokeBorder(tintColor.opacity(0.15), lineWidth: 5)
                    .frame(width: 56, height: 56)

                // Progress arc
                Circle()
                    .trim(from: 0, to: progress)
                    .stroke(
                        tintColor,
                        style: StrokeStyle(lineWidth: 5, lineCap: .round)
                    )
                    .rotationEffect(.degrees(-90))
                    .frame(width: 56, height: 56)
                    .animation(.spring(response: 0.6), value: progress)

                // Value display
                VStack(spacing: 0) {
                    Text("\(value)")
                        .font(.system(.callout, design: .rounded, weight: .bold))
                        .foregroundStyle(.primary)
                        .contentTransition(.numericText())
                    Text("/\(maxValue)")
                        .font(.system(.caption2, design: .rounded))
                        .foregroundStyle(.secondary)
                }
            }

            Text(title)
                .font(.caption2.weight(.medium))
                .foregroundStyle(.secondary)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(title): \(value) of \(maxValue)")
    }
}
