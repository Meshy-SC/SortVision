import SwiftUI

/// Custom path for a glass bottle with body, tapering neck, and cap/stopper.
///
/// Draws the bottle outline used by `TubeView` for both the filled glass
/// background and the stroke outline. Also used as a clipping mask
/// by `GameSceneView` for the liquid stream overlay.
///
/// ## Geometry
/// ```
///     ┌─cap──┐        ← capHeight
///     │ neck │        ← neckHeight (tapers from neck to body width)
///  ┌──┘      └──┐
///  │   body     │     ← bodyHeight
///  │            │
///  └────────────┘     ← bottomRadius rounded corners
/// ```
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
        let effectiveCornerRadius = min(bottomRadius, halfBody)

        // --- Cap (dark stopper) ---
        let capCornerRadius: CGFloat = 5
        path.move(to: CGPoint(x: centerX - halfCap, y: neckTop))
        path.addLine(to: CGPoint(x: centerX - halfCap, y: capTop + capCornerRadius))
        path.addArc(
            center: CGPoint(x: centerX - halfCap + capCornerRadius, y: capTop + capCornerRadius),
            radius: capCornerRadius,
            startAngle: .degrees(180),
            endAngle: .degrees(270),
            clockwise: false
        )
        path.addLine(to: CGPoint(x: centerX + halfCap - capCornerRadius, y: capTop))
        path.addArc(
            center: CGPoint(x: centerX + halfCap - capCornerRadius, y: capTop + capCornerRadius),
            radius: capCornerRadius,
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
        path.addLine(to: CGPoint(x: centerX + halfBody, y: bottom - effectiveCornerRadius))

        // Bottom-right corner
        path.addArc(
            center: CGPoint(x: centerX + halfBody - effectiveCornerRadius, y: bottom - effectiveCornerRadius),
            radius: effectiveCornerRadius,
            startAngle: .degrees(0),
            endAngle: .degrees(90),
            clockwise: false
        )

        // Bottom edge
        path.addLine(to: CGPoint(x: centerX - halfBody + effectiveCornerRadius, y: bottom))

        // Bottom-left corner
        path.addArc(
            center: CGPoint(x: centerX - halfBody + effectiveCornerRadius, y: bottom - effectiveCornerRadius),
            radius: effectiveCornerRadius,
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
