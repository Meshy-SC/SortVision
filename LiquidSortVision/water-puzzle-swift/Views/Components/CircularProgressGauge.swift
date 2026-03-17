import SwiftUI

/// A circular progress ring gauge with customizable size, color, and label.
///
/// Displays a circular track with a filled arc representing progress,
/// with an optional center label. Used in world cards and level grid headers.
///
/// ## Usage
/// ```swift
/// CircularProgressGauge(progress: 0.45, color: .blue, size: 60) {
///     Text("45%")
/// }
/// ```
struct CircularProgressGauge<Label: View>: View {
    let progress: Double
    let color: Color
    let size: CGFloat
    let lineWidth: CGFloat
    @ViewBuilder let label: () -> Label

    init(
        progress: Double,
        color: Color,
        size: CGFloat = 56,
        lineWidth: CGFloat = 5,
        @ViewBuilder label: @escaping () -> Label
    ) {
        self.progress = progress
        self.color = color
        self.size = size
        self.lineWidth = lineWidth
        self.label = label
    }

    var body: some View {
        ZStack {
            // Track
            Circle()
                .stroke(color.opacity(0.2), lineWidth: lineWidth)

            // Progress arc
            Circle()
                .trim(from: 0, to: min(max(progress, 0), 1))
                .stroke(
                    color,
                    style: StrokeStyle(lineWidth: lineWidth, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))
                .animation(.easeInOut(duration: 0.4), value: progress)

            // Center label
            label()
        }
        .frame(width: size, height: size)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Progress: \(Int(progress * 100)) percent")
    }
}

// MARK: - Convenience initializer without label

extension CircularProgressGauge where Label == EmptyView {
    init(
        progress: Double,
        color: Color,
        size: CGFloat = 56,
        lineWidth: CGFloat = 5
    ) {
        self.progress = progress
        self.color = color
        self.size = size
        self.lineWidth = lineWidth
        self.label = { EmptyView() }
    }
}
