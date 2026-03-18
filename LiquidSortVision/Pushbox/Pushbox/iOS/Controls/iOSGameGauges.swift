// iOSGameGauges.swift
// Unified progress, score, and pushes gauges for the iOS game scene.

#if os(iOS) || os(macOS) || os(tvOS)
import SwiftUI

/// All three top-bar gauges (Progress, Score, Pushes) in a single HStack
/// with consistent spacing. Single source of truth for gauge styling.
struct iOSGameGauges: View {

    @Environment(AppModel.self) private var appModel

    // MARK: - Layout constants

    @ScaledMetric(relativeTo: .caption2) private var labelSpacing: CGFloat = 8

    /// 1-based world number derived from `World.allWorlds` ordering.
    private var worldNumber: Int {
        let active = appModel.activeWorld ?? appModel.selectedWorld
        guard let active,
              let idx = World.allWorlds.firstIndex(where: { $0.worldName == active.worldName }) else {
            return 1
        }
        return idx + 1
    }

    /// 1-based level number.
    private var levelNumber: Int {
        (appModel.selectedLevelIndex ?? 0) + 1
    }

    var body: some View {
        // Group (not HStack) so each gauge becomes a direct child of the
        // parent HStack, inheriting the parent's uniform spacing.
        Group {
            // World
            gaugeItem(
                value: Double(worldNumber),
                maxValue: max(Double(World.allWorlds.count), 1),
                displayText: "\(worldNumber)",
                label: "World",
                tint: .indigo
            )

            // Level
            gaugeItem(
                value: Double(levelNumber),
                maxValue: max(Double(currentWorldLevelCount), 1),
                displayText: "\(levelNumber)",
                label: "Level",
                tint: .teal
            )

            // Pushes (hidden when no optimal data)
            if let optimalPushes = appModel.optimalPushes, optimalPushes > 0 {
                let current = Double(appModel.progressService.currentLevelPushes)
                let threshold = ceil(Double(optimalPushes) * 1.2)
                let tint: Color = if current <= Double(optimalPushes) {
                    .blue
                } else if current <= threshold {
                    .orange
                } else {
                    .red
                }

                gaugeItem(
                    value: current,
                    maxValue: threshold,
                    displayText: "\(Int(current))",
                    label: "Pushes",
                    tint: tint
                )
            }
        }
    }

    /// Total levels in the active world.
    private var currentWorldLevelCount: Int {
        let active = appModel.activeWorld ?? appModel.selectedWorld
        return active?.levelCount ?? 1
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
            #if os(tvOS)
            ZStack {
                Circle()
                    .stroke(tint.opacity(0.2), lineWidth: 3)
                Circle()
                    .trim(from: 0, to: maxValue > 0 ? value / maxValue : 0)
                    .stroke(tint, style: StrokeStyle(lineWidth: 3, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                Text(displayText)
                    .font(.body.weight(.bold))
                    .foregroundStyle(tint)
                    .lineLimit(1)
                    .minimumScaleFactor(0.5)
            }
            .frame(width: 64, height: 64)
            .animation(.spring(response: 0.6, dampingFraction: 1.0), value: value)
            #else
            Button {} label: {
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
                .contentShape(Circle())
            }
            .buttonStyle(.glass)
            .buttonBorderShape(.circle)
            .allowsHitTesting(false)
            .animation(.spring(response: 0.6, dampingFraction: 1.0), value: value)
            #endif

            Text(label)
                .font(.caption2.weight(.medium))
                .foregroundStyle(.white)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(label): \(displayText)")
    }
}
#endif
