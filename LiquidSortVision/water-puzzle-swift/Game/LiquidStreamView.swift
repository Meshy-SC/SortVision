import SwiftUI

/// A view that draws an animated liquid stream between two points.
///
/// The stream is a thick colored line with a natural gravity-affected curve
/// from the source tube's lip down to the target tube's opening.
/// Includes a glow effect and drip blob for realism.
struct LiquidStreamView: View {
    /// Start point in the coordinate space (source tube lip).
    let from: CGPoint
    /// End point in the coordinate space (target tube opening).
    let to: CGPoint
    /// The color of the liquid being poured.
    let color: Color
    /// Pour progress 0…1 (controls stream thickness/opacity).
    let progress: CGFloat

    /// Width of the liquid stream.
    private let streamWidth: CGFloat = 8

    var body: some View {
        Canvas { context, size in
            guard streamThickness > 0.01 else { return }

            let path = streamPath()

            // Draw a wider, semi-transparent outer glow
            context.stroke(
                path,
                with: .color(color.opacity(0.25)),
                style: StrokeStyle(
                    lineWidth: (streamWidth + 6) * streamThickness,
                    lineCap: .round,
                    lineJoin: .round
                )
            )

            // Draw the main stream
            context.stroke(
                path,
                with: .color(color),
                style: StrokeStyle(
                    lineWidth: streamWidth * streamThickness,
                    lineCap: .round,
                    lineJoin: .round
                )
            )

            // Inner highlight for liquid sheen
            context.stroke(
                path,
                with: .color(.white.opacity(0.2)),
                style: StrokeStyle(
                    lineWidth: (streamWidth * 0.4) * streamThickness,
                    lineCap: .round,
                    lineJoin: .round
                )
            )

            // Draw drip blob at the end point
            let dripSize = 10.0 * streamThickness
            let dripRect = CGRect(
                x: to.x - dripSize / 2,
                y: to.y - dripSize / 2,
                width: dripSize,
                height: dripSize
            )
            context.fill(Ellipse().path(in: dripRect), with: .color(color))

            // Small splash effect at target
            let splashSize = 6.0 * streamThickness
            let splashRect = CGRect(
                x: to.x - splashSize / 2,
                y: to.y - splashSize,
                width: splashSize,
                height: splashSize
            )
            context.fill(Ellipse().path(in: splashRect), with: .color(color.opacity(0.4)))
        }
        .allowsHitTesting(false)
    }

    /// Stream thickness ramps up quickly and stays thick, then tapers.
    private var streamThickness: CGFloat {
        if progress < 0.08 {
            return progress / 0.08
        } else if progress > 0.88 {
            return (1.0 - progress) / 0.12
        }
        return 1.0
    }

    /// Creates a curved path from source down to target with a natural gravity droop.
    private func streamPath() -> Path {
        var path = Path()
        path.move(to: from)

        // Control points create a natural gravity-affected arc.
        // The stream drops straight down from the lip then curves to target.
        let cp1 = CGPoint(
            x: from.x,
            y: from.y + (to.y - from.y) * 0.5
        )
        let cp2 = CGPoint(
            x: to.x,
            y: from.y + (to.y - from.y) * 0.8
        )

        path.addCurve(to: to, control1: cp1, control2: cp2)
        return path
    }
}
