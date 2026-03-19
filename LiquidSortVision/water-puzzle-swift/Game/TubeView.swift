import SwiftUI

/// A tube (glass bottle) view that displays liquid segments.
///
/// Draws a tall glass bottle matching the competition's visual style:
/// - Wide rounded body with translucent cyan-blue glass
/// - Visible glass reflections and edge highlights
/// - Narrow neck with small dark cap
/// - Vibrant liquid segments with rounded liquid surface
///
/// Note: Animation transforms (rotation, offset, pending lift) are applied
/// externally by GameSceneView to allow base-frame capture for pour alignment.
struct TubeView: View {

    enum RenderLayer {
        case content
        case front
    }

    // MARK: - Constants

    /// Total width of the bottle body.
    static let tubeWidth: CGFloat = 52

    /// Height of the main body (below the neck).
    static let bodyHeight: CGFloat = 150

    /// Height of the neck taper section.
    static let neckHeight: CGFloat = 14

    /// Width of the neck opening.
    static let neckWidth: CGFloat = 22

    /// Height of the cap/stopper.
    static let capHeight: CGFloat = 12

    /// Half-width of the visible top rim/cap silhouette.
    static let rimHalfWidth: CGFloat = (neckWidth + 10) / 2

    /// Full height including body + neck + cap.
    static let tubeHeight: CGFloat = bodyHeight + neckHeight + capHeight

    /// Corner radius for the bottle bottom.
    static let bottomRadius: CGFloat = 22

    /// Glass wall stroke width.
    static let wallThickness: CGFloat = 2.5

    /// Vertical offset when the tube is selected.
    static let pendingLift: CGFloat = 20

    /// Height per liquid unit within the body.
    static let unitHeight: CGFloat = (bodyHeight - wallThickness * 2) / CGFloat(TubeState.maxValue)

    /// Inset for the liquid area inside the glass walls.
    static let liquidInset: CGFloat = wallThickness + 1.5

    /// Visible gap between the pouring lip and the target tube while streaming.
    static let pourClearance: CGFloat = 36

    /// Offset from the tube center to the neck opening center in local coordinates.
    static func mouthCenterOffset(scale: CGFloat) -> CGPoint {
        CGPoint(
            x: 0,
            y: -(tubeHeight / 2 - capHeight) * scale
        )
    }

    /// Offset from the tube center to the visible top rim center.
    static func lipCenterOffset(scale: CGFloat) -> CGPoint {
        CGPoint(
            x: 0,
            y: -(tubeHeight / 2 - capHeight / 2) * scale
        )
    }

    /// Offset from the tube center to the visible pouring lip on the rim.
    static func pourLipOffset(toward tiltSign: CGFloat, scale: CGFloat) -> CGPoint {
        let lipCenter = lipCenterOffset(scale: scale)
        return CGPoint(
            x: tiltSign * rimHalfWidth * scale,
            y: lipCenter.y
        )
    }

    /// Offset from the tube center to a point just inside the upright tube neck.
    static func streamEntryOffset(scale: CGFloat) -> CGPoint {
        let mouthCenter = mouthCenterOffset(scale: scale)
        return CGPoint(
            x: 0,
            y: mouthCenter.y + wallThickness * 2.0 * scale
        )
    }

    /// Offset from the tube center to a point just inside the tilted source neck.
    static func sourceStreamInnerOffset(scale: CGFloat) -> CGPoint {
        let mouthCenter = mouthCenterOffset(scale: scale)
        return CGPoint(
            x: mouthCenter.x,
            y: mouthCenter.y + (neckHeight + wallThickness * 1.2) * scale
        )
    }

    /// Rotates a local point around the tube center into scene-space coordinates.
    static func rotate(offset: CGPoint, by angle: CGFloat) -> CGPoint {
        let sinAngle = sin(angle)
        let cosAngle = cos(angle)
        return CGPoint(
            x: offset.x * cosAngle - offset.y * sinAngle,
            y: offset.x * sinAngle + offset.y * cosAngle
        )
    }

    /// Scene-space point for a rotated tube feature after applying animation translation.
    static func transformedPoint(
        in frame: CGRect,
        localOffset: CGPoint,
        angle: CGFloat,
        translationX: CGFloat = 0,
        translationY: CGFloat = 0
    ) -> CGPoint {
        let rotatedOffset = rotate(offset: localOffset, by: angle)
        return CGPoint(
            x: frame.midX + translationX + rotatedOffset.x,
            y: frame.midY + translationY + rotatedOffset.y
        )
    }

    /// Scene-space point for the visible top rim center.
    static func lipPoint(in frame: CGRect, scale: CGFloat) -> CGPoint {
        let offset = lipCenterOffset(scale: scale)
        return CGPoint(
            x: frame.midX + offset.x,
            y: frame.midY + offset.y
        )
    }

    // MARK: - Properties

    let tube: TubeState
    let onTap: () -> Void
    let layer: RenderLayer

    var body: some View {
        ZStack(alignment: .bottom) {
            if layer != .front {
                // Glass bottle (behind liquid)
                glassBack

                // Liquid stack (inside the body area only)
                liquidStack
                    .padding(.horizontal, Self.liquidInset)
                    .padding(.bottom, Self.liquidInset)
            }

            if layer != .content {
                // Glass front (shine overlay, on top of liquid)
                glassFront
            }
        }
        .frame(width: Self.tubeWidth, height: Self.tubeHeight)
        .contentShape(Rectangle())
        .onTapGesture {
            if layer != .front {
                onTap()
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityHidden(layer == .front)
        .accessibilityLabel(accessibilityLabel)
        .accessibilityAddTraits(.isButton)
    }

    // MARK: - Glass Back (behind liquid)

    private var glassBack: some View {
        ZStack {
            // Glass body fill — translucent dark blue
            BottleShape(
                bodyWidth: Self.tubeWidth,
                bodyHeight: Self.bodyHeight,
                neckWidth: Self.neckWidth,
                neckHeight: Self.neckHeight,
                capHeight: Self.capHeight,
                bottomRadius: Self.bottomRadius
            )
            .fill(
                LinearGradient(
                    colors: [
                        Color(red: 0.10, green: 0.14, blue: 0.28).opacity(0.85),
                        Color(red: 0.09, green: 0.12, blue: 0.24).opacity(0.80),
                        Color(red: 0.07, green: 0.10, blue: 0.22).opacity(0.85),
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
            )

            // Glass outline — bright blue-cyan for visibility
            BottleShape(
                bodyWidth: Self.tubeWidth,
                bodyHeight: Self.bodyHeight,
                neckWidth: Self.neckWidth,
                neckHeight: Self.neckHeight,
                capHeight: Self.capHeight,
                bottomRadius: Self.bottomRadius
            )
            .stroke(
                LinearGradient(
                    colors: [
                        Color(red: 0.30, green: 0.60, blue: 0.90).opacity(0.65),
                        Color(red: 0.25, green: 0.52, blue: 0.82).opacity(0.45),
                        Color(red: 0.22, green: 0.48, blue: 0.78).opacity(0.55),
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                ),
                lineWidth: Self.wallThickness
            )
        }
    }

    // MARK: - Glass Front (on top of liquid — highlights)

    private var glassFront: some View {
        ZStack {
            // Left edge highlight — vertical glass reflection line
            RoundedRectangle(cornerRadius: Self.bottomRadius - 4)
                .fill(
                    LinearGradient(
                        colors: [
                            .white.opacity(0.0),
                            .white.opacity(0.22),
                            .white.opacity(0.10),
                            .white.opacity(0.0),
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .frame(width: 5)
                .padding(.leading, 6)
                .padding(.trailing, Self.tubeWidth - 11)
                .padding(.vertical, Self.neckHeight + Self.capHeight + 4)

            // Right edge subtle reflection
            RoundedRectangle(cornerRadius: Self.bottomRadius - 4)
                .fill(
                    LinearGradient(
                        colors: [
                            .white.opacity(0.0),
                            .white.opacity(0.10),
                            .white.opacity(0.04),
                            .white.opacity(0.0),
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .frame(width: 3)
                .padding(.leading, Self.tubeWidth - 10)
                .padding(.trailing, 7)
                .padding(.vertical, Self.neckHeight + Self.capHeight + 8)

            // Top curved highlight for glass curvature
            Ellipse()
                .fill(.white.opacity(0.06))
                .frame(width: Self.tubeWidth - 12, height: 20)
                .offset(y: -(Self.tubeHeight / 2) + Self.neckHeight + Self.capHeight + 14)
        }
        .allowsHitTesting(false)
    }

    // MARK: - Liquid Stack

    private var liquidStack: some View {
        VStack(spacing: 0) {
            Spacer(minLength: 0)

            let liquidWidth = Self.tubeWidth - Self.liquidInset * 2

            // Liquids are bottom-to-top; VStack top-to-bottom so reverse.
            ForEach(Array(tube.liquids.enumerated().reversed()), id: \.element.id) { index, liquid in
                let isTopSegment = (index == tube.liquids.count - 1)
                let segmentHeight = Self.unitHeight * liquid.value
                let color = ColorPalette.color(for: liquid.groupId)

                ZStack(alignment: .top) {
                    // Main liquid body with subtle gradient for depth
                    LinearGradient(
                        colors: [color.opacity(0.92), color],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                    .frame(height: segmentHeight)

                    // Liquid highlight — left side shine through liquid
                    HStack(spacing: 0) {
                        color.opacity(0.0)
                            .frame(width: 1)
                        LinearGradient(
                            colors: [
                                .white.opacity(0.22),
                                .white.opacity(0.06),
                                .clear,
                            ],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                        .frame(width: liquidWidth * 0.3)
                        Spacer(minLength: 0)
                    }
                    .frame(height: segmentHeight)

                    // Rounded top surface for the topmost liquid segment
                    if isTopSegment && liquid.value > 0.3 {
                        Ellipse()
                            .fill(color.opacity(0.5))
                            .frame(width: liquidWidth, height: 10)
                            .offset(y: -5)
                        Ellipse()
                            .fill(
                                LinearGradient(
                                    colors: [.white.opacity(0.25), .white.opacity(0.05)],
                                    startPoint: .top,
                                    endPoint: .bottom
                                )
                            )
                            .frame(width: liquidWidth * 0.65, height: 5)
                            .offset(y: -4)
                    }
                }
            }
        }
        .frame(height: Self.bodyHeight - Self.liquidInset * 2)
        .clipShape(
            UnevenRoundedRectangle(
                topLeadingRadius: 2,
                bottomLeadingRadius: Self.bottomRadius - Self.liquidInset,
                bottomTrailingRadius: Self.bottomRadius - Self.liquidInset,
                topTrailingRadius: 2
            )
        )
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

/// Custom path for a glass bottle with body, tapering neck, and cap/stopper.
struct BottleShape: Shape {
    let bodyWidth: CGFloat
    let bodyHeight: CGFloat
    let neckWidth: CGFloat
    let neckHeight: CGFloat
    let capHeight: CGFloat
    let bottomRadius: CGFloat

    func path(in rect: CGRect) -> Path {
        var path = Path()

        let centerX = rect.midX
        let bottom = rect.maxY
        let bodyTop = bottom - bodyHeight
        let neckTop = bodyTop - neckHeight
        let capTop = neckTop - capHeight

        let halfBody = bodyWidth / 2
        let halfNeck = neckWidth / 2
        let halfCap = (neckWidth + 10) / 2  // cap wider than neck
        let cr = min(bottomRadius, halfBody)

        // --- Cap (dark stopper) ---
        let capCR: CGFloat = 5
        path.move(to: CGPoint(x: centerX - halfCap, y: neckTop))
        path.addLine(to: CGPoint(x: centerX - halfCap, y: capTop + capCR))
        path.addArc(
            center: CGPoint(x: centerX - halfCap + capCR, y: capTop + capCR),
            radius: capCR,
            startAngle: .degrees(180),
            endAngle: .degrees(270),
            clockwise: false
        )
        path.addLine(to: CGPoint(x: centerX + halfCap - capCR, y: capTop))
        path.addArc(
            center: CGPoint(x: centerX + halfCap - capCR, y: capTop + capCR),
            radius: capCR,
            startAngle: .degrees(270),
            endAngle: .degrees(0),
            clockwise: false
        )
        path.addLine(to: CGPoint(x: centerX + halfCap, y: neckTop))

        // --- Body outline: right neck → body → bottom → body → left neck ---
        path.move(to: CGPoint(x: centerX + halfNeck, y: neckTop))

        // Smooth neck-to-body transition (right side) — wider shoulder
        path.addCurve(
            to: CGPoint(x: centerX + halfBody, y: bodyTop + 18),
            control1: CGPoint(x: centerX + halfNeck + 4, y: bodyTop - 2),
            control2: CGPoint(x: centerX + halfBody, y: bodyTop + 4)
        )

        // Right body side down
        path.addLine(to: CGPoint(x: centerX + halfBody, y: bottom - cr))

        // Bottom-right corner
        path.addArc(
            center: CGPoint(x: centerX + halfBody - cr, y: bottom - cr),
            radius: cr,
            startAngle: .degrees(0),
            endAngle: .degrees(90),
            clockwise: false
        )

        // Bottom edge
        path.addLine(to: CGPoint(x: centerX - halfBody + cr, y: bottom))

        // Bottom-left corner
        path.addArc(
            center: CGPoint(x: centerX - halfBody + cr, y: bottom - cr),
            radius: cr,
            startAngle: .degrees(90),
            endAngle: .degrees(180),
            clockwise: false
        )

        // Left body side up
        path.addLine(to: CGPoint(x: centerX - halfBody, y: bodyTop + 18))

        // Smooth body-to-neck transition (left side) — wider shoulder
        path.addCurve(
            to: CGPoint(x: centerX - halfNeck, y: neckTop),
            control1: CGPoint(x: centerX - halfBody, y: bodyTop + 4),
            control2: CGPoint(x: centerX - halfNeck - 4, y: bodyTop - 2)
        )

        return path
    }
}
