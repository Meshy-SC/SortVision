import SwiftUI

/// A circular capacity gauge displaying a numeric value and label,
/// used for progress percentage, score, credit count, and push count.
///
/// Wraps SwiftUI's `Gauge` with `accessoryCircularCapacity` style,
/// spring animation on value changes, and Dynamic Type support.
/// On tvOS, where `Gauge` is unavailable, uses a `ProgressView` fallback.
struct CircularStatGauge: View {
    var title: String
    var value: Double
    var maxValue: Double
    var tintColor: Color
    
    #if os(tvOS)
    @ScaledMetric(relativeTo: .headline) private var gaugeSize: CGFloat = 100
    #elseif os(visionOS)
    @ScaledMetric(relativeTo: .headline) private var gaugeSize: CGFloat = 80
    #else
    @ScaledMetric(relativeTo: .headline) private var gaugeSize: CGFloat = 72
    #endif

    /// Stroke width scales with the gauge diameter.
    private var strokeWidth: CGFloat { gaugeSize * 0.08 }

    var body: some View {
        let safeMax = max(maxValue, 1)
        let clampedValue = min(max(value.isFinite ? value : 0, 0), safeMax)
        VStack(spacing: 8) {
            ZStack {
                Circle()
                    .stroke(tintColor.opacity(0.2), lineWidth: strokeWidth)
                Circle()
                    .trim(from: 0, to: safeMax > 0 ? clampedValue / safeMax : 0)
                    .stroke(tintColor, style: StrokeStyle(lineWidth: strokeWidth, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                Text(labelText)
                    .font(.system(size: gaugeSize * 0.25, weight: .bold))
                    .foregroundStyle(tintColor)
                    .lineLimit(1)
                    .minimumScaleFactor(0.5)
            }
            .frame(width: gaugeSize, height: gaugeSize)

            Text(title)
                .font(.subheadline)
        }
        .animation(.spring(response: 0.6, dampingFraction: 1.0), value: value)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(title): \(labelText)")
        .dynamicTypeSize(...DynamicTypeSize.accessibility2)
    }

    /// Formats the label, appending % for "Progress"
    private var labelText: String {
        let safeValue = value.isFinite ? Int(value) : 0
        if title == "Progress" {
            return "\(safeValue)%"
        } else {
            return "\(safeValue)"
        }
    }
}
