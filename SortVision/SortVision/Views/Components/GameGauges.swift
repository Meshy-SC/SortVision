import SwiftUI

// MARK: - GameGauges

/// Top-bar circular gauges for the game scene — shows World, Level,
/// and Moves progress. Mirrors ParkVision's GameGauges.
///
/// The Moves gauge changes colour based on performance vs optimal:
/// blue (at/below optimal), orange (within 50%), red (above).
struct GameGauges: View {

    let worldNumber: Int
    let totalWorlds: Int
    let levelNumber: Int
    let totalLevels: Int
    let moveCount: Int
    let optimalMoveCount: Int?
    @ScaledMetric(relativeTo: .caption2) private var labelSpacing: CGFloat = 8

    var body: some View {
        Group {
            // World
            gaugeItem(
                value: Double(worldNumber),
                maxValue: max(Double(totalWorlds), 1),
                displayText: "\(worldNumber)",
                label: "World",
                tint: .indigo
            )

            // Level
            gaugeItem(
                value: Double(levelNumber),
                maxValue: max(Double(totalLevels), 1),
                displayText: "\(levelNumber)",
                label: "Level",
                tint: .teal
            )

            // Moves (hidden when no optimal data)
            if let optimal = optimalMoveCount, optimal > 0 {
                let current = Double(moveCount)
                let threshold = ceil(Double(optimal) * 1.5)
                let tint: Color = if current <= Double(optimal) {
                    .blue
                } else if current <= threshold {
                    .orange
                } else {
                    .red
                }

                gaugeItem(
                    value: current,
                    maxValue: threshold,
                    displayText: "\(moveCount)",
                    label: "Moves",
                    tint: tint
                )
            }

        }
    }

    // MARK: - Reusable gauge

    private func gaugeItem(
        value: Double,
        maxValue: Double,
        displayText: String,
        label: String,
        tint: Color
    ) -> some View {
        VStack(spacing: labelSpacing) {
            Gauge(value: value, in: 0...maxValue) {
            } currentValueLabel: {
                Text(displayText)
                    .font(.caption.weight(.bold))
                    .foregroundStyle(tint)
                    .lineLimit(1)
                    .minimumScaleFactor(0.5)
            }
            .gaugeStyle(.accessoryCircularCapacity)
            .tint(tint)
            .frame(width: 44, height: 44)
            .animation(.spring(response: 0.6, dampingFraction: 1.0), value: value)

            Text(label)
                .font(.caption2.weight(.medium))
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(label): \(displayText)")
    }
}
