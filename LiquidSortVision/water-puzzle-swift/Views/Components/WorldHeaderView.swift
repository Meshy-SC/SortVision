import SwiftUI

/// A prominent header card displayed at the top of the level grid.
///
/// Shows the world's icon, name, subtitle, and a large circular
/// progress gauge with completion stats. Provides a visual anchor
/// for the level selection screen.
struct WorldHeaderView: View {
    let stage: Stage
    let completed: Int
    let total: Int

    private var progress: Double {
        guard total > 0 else { return 0 }
        return Double(completed) / Double(total)
    }

    var body: some View {
        HStack(spacing: 20) {
            // Left: World info
            VStack(alignment: .leading, spacing: 6) {
                Text("World \(stage.worldNumber)")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(stage.themeColor)
                    .textCase(.uppercase)
                    .tracking(0.5)

                Text(stage.displayName)
                    .font(.title.weight(.bold))
                    .foregroundStyle(.primary)

                Text(stage.subtitle)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                // Horizontal progress bar
                VStack(alignment: .leading, spacing: 4) {
                    ProgressView(value: Double(completed), total: Double(max(total, 1)))
                        .tint(stage.themeColor)

                    Text("\(completed) of \(total) completed")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .padding(.top, 4)
            }

            Spacer()

            // Right: Circular gauge
            CircularProgressGauge(
                progress: progress,
                color: stage.themeColor,
                size: 72,
                lineWidth: 6
            ) {
                VStack(spacing: 1) {
                    Text("\(Int(progress * 100))%")
                        .font(.system(.callout, design: .rounded, weight: .bold))
                        .foregroundStyle(.primary)
                        .contentTransition(.numericText())
                }
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
            "World \(stage.worldNumber), \(stage.displayName), \(stage.subtitle), \(completed) of \(total) completed"
        )
    }
}
