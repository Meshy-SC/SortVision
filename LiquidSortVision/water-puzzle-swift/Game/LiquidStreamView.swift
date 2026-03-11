import SwiftUI

/// A view that draws an animated liquid stream between two points.
///
/// The stream is a thick colored line with a slight curve and animated
/// drip effect. It connects the source tube's lip to the target tube's opening.
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
    private let streamWidth: CGFloat = 6

    var body: some View {
        Canvas { context, _ in
            let path = streamPath()

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

            // Draw a slightly wider, semi-transparent glow
            context.stroke(
                path,
                with: .color(color.opacity(0.3)),
                style: StrokeStyle(
                    lineWidth: (streamWidth + 4) * streamThickness,
                    lineCap: .round,
                    lineJoin: .round
                )
            )

            // Draw drip blobs at the end point
            let dripSize = 8.0 * streamThickness
            let dripRect = CGRect(
                x: to.x - dripSize / 2,
                y: to.y - dripSize / 2,
                width: dripSize,
                height: dripSize
            )
            context.fill(Ellipse().path(in: dripRect), with: .color(color))
        }
        .allowsHitTesting(false)
    }

    /// Stream thickness ramps up quickly and stays thick, then tapers.
    private var streamThickness: CGFloat {
        if progress < 0.1 {
            return progress / 0.1
        } else if progress > 0.85 {
            return (1.0 - progress) / 0.15
        }
        return 1.0
    }

    /// Creates a curved path from source to target with a natural droop.
    private func streamPath() -> Path {
        var path = Path()
        path.move(to: from)

        // Control points create a natural gravity-affected arc
        let midX = (from.x + to.x) / 2.0
        let dropY = max(from.y, to.y) + 20 // droop below endpoints

        let cp1 = CGPoint(x: from.x + (midX - from.x) * 0.5, y: from.y + 10)
        let cp2 = CGPoint(x: to.x - (to.x - midX) * 0.5, y: dropY)

        path.addCurve(to: to, control1: cp1, control2: cp2)
        return path
    }
}
