import SwiftUI

/// A circular capacity gauge displaying a numeric value and label,
/// used for progress percentage, score, and move count display.
///
/// Uses the built-in `Gauge` with `.accessoryCircularCapacity`
/// style for automatic platform adaptation.
/// Mirrors ParkVision's `CircularStatGauge`.
struct CircularStatGauge: View {
    var title: String
    var value: Double
    var maxValue: Double
    var tintColor: Color

    #if os(visionOS)
    @ScaledMetric(relativeTo: .headline) private var gaugeSize: CGFloat = 80
    #else
    @ScaledMetric(relativeTo: .headline) private var gaugeSize: CGFloat = 72
    #endif

    var body: some View {
        let safeMax = max(maxValue, 1)
        let clampedValue = min(max(value.isFinite ? value : 0, 0), safeMax)
        VStack(spacing: 8) {
            Gauge(value: clampedValue, in: 0...safeMax) {
                // Label intentionally empty — title shown below.
            } currentValueLabel: {
                Text(labelText)
                    .font(.system(size: gaugeSize * 0.25, weight: .bold))
                    .foregroundStyle(tintColor)
                    .lineLimit(1)
                    .minimumScaleFactor(0.5)
            }
            .gaugeStyle(.accessoryCircularCapacity)
            .tint(tintColor)
            .frame(width: gaugeSize, height: gaugeSize)

            Text(title)
                .font(.subheadline)
        }
        .animation(.spring(response: 0.6, dampingFraction: 1.0), value: value)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(title): \(labelText)")
        .dynamicTypeSize(...DynamicTypeSize.accessibility2)
    }

    private var labelText: String {
        let safeValue = value.isFinite ? Int(value) : 0
        if title == "Progress" {
            return "\(safeValue)%"
        } else {
            return "\(safeValue)"
        }
    }
}
