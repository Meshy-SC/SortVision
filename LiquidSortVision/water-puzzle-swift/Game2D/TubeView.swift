import SwiftUI

/// A 2D tube (bottle) that displays liquid segments as stacked colored rectangles.
///
/// The tube is drawn with a rounded-rectangle glass outline and filled
/// liquid segments that stack from bottom to top. When selected (pending),
/// the tube lifts upward with a spring animation.
struct TubeView: View {

    // MARK: - Constants

    /// Width of the tube body.
    static let tubeWidth: CGFloat = 44

    /// Height of the tube body.
    static let tubeHeight: CGFloat = 160

    /// Corner radius for the bottle shape.
    static let cornerRadius: CGFloat = 12

    /// Glass wall stroke width.
    static let wallThickness: CGFloat = 2.5

    /// Vertical offset when the tube is selected.
    static let pendingLift: CGFloat = 16

    /// Height per liquid unit.
    static let unitHeight: CGFloat = tubeHeight / CGFloat(TubeState.maxValue)

    // MARK: - Properties

    let tube: TubeState
    let onTap: () -> Void

    var body: some View {
        ZStack(alignment: .bottom) {
            // Glass outline
            glassOutline

            // Liquid stack
            liquidStack
                .clipShape(
                    UnevenRoundedRectangle(
                        topLeadingRadius: 4,
                        bottomLeadingRadius: Self.cornerRadius - 2,
                        bottomTrailingRadius: Self.cornerRadius - 2,
                        topTrailingRadius: 4
                    )
                )
                .padding(.horizontal, Self.wallThickness)
                .padding(.bottom, Self.wallThickness)
        }
        .frame(width: Self.tubeWidth, height: Self.tubeHeight)
        .offset(y: tube.isPending ? -Self.pendingLift : 0)
        .animation(.spring(response: 0.25, dampingFraction: 0.7), value: tube.isPending)
        .onTapGesture {
            onTap()
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityLabel)
        .accessibilityAddTraits(.isButton)
    }

    // MARK: - Glass Outline

    private var glassOutline: some View {
        // Bottle shape: open top, rounded bottom
        BottleShape(cornerRadius: Self.cornerRadius)
            .stroke(
                Color.primary.opacity(0.3),
                lineWidth: Self.wallThickness
            )
            .background(
                BottleShape(cornerRadius: Self.cornerRadius)
                    .fill(Color.primary.opacity(0.04))
            )
    }

    // MARK: - Liquid Stack

    private var liquidStack: some View {
        VStack(spacing: 0) {
            Spacer(minLength: 0)

            ForEach(tube.liquids) { liquid in
                ColorPalette.color(for: liquid.groupId)
                    .frame(height: Self.unitHeight * liquid.value)
            }
        }
    }

    // MARK: - Accessibility

    private var accessibilityLabel: String {
        if tube.isEmpty {
            return "Empty tube"
        }
        let contents = tube.liquids.map { liquid in
            let colorName = colorName(for: liquid.groupId)
            let units = Int(liquid.value.rounded())
            return "\(units) \(colorName)"
        }.joined(separator: ", ")
        return "Tube with \(contents)\(tube.isPending ? ", selected" : "")"
    }

    private func colorName(for groupId: Int) -> String {
        let names = [
            "red", "blue", "yellow", "green", "purple", "orange",
            "cyan", "pink", "mint", "indigo", "brown", "teal"
        ]
        guard groupId >= 0, groupId < names.count else { return "unknown" }
        return names[groupId]
    }
}

// MARK: - Bottle Shape

/// Custom shape for the tube — open at top, rounded at bottom, straight sides.
struct BottleShape: Shape {
    let cornerRadius: CGFloat

    func path(in rect: CGRect) -> Path {
        var path = Path()

        let left = rect.minX
        let right = rect.maxX
        let top = rect.minY
        let bottom = rect.maxY
        let cr = min(cornerRadius, rect.width / 2)

        // Start at top-left (open top)
        path.move(to: CGPoint(x: left, y: top))

        // Left side down
        path.addLine(to: CGPoint(x: left, y: bottom - cr))

        // Bottom-left corner
        path.addArc(
            center: CGPoint(x: left + cr, y: bottom - cr),
            radius: cr,
            startAngle: .degrees(180),
            endAngle: .degrees(90),
            clockwise: true
        )

        // Bottom edge
        path.addLine(to: CGPoint(x: right - cr, y: bottom))

        // Bottom-right corner
        path.addArc(
            center: CGPoint(x: right - cr, y: bottom - cr),
            radius: cr,
            startAngle: .degrees(90),
            endAngle: .degrees(0),
            clockwise: true
        )

        // Right side up
        path.addLine(to: CGPoint(x: right, y: top))

        return path
    }
}
