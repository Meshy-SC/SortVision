import SwiftUI

/// A view that draws an animated liquid stream between two points.
///
/// The stream is a thick colored line with a controlled downward curve
/// from the source tube lip to the target tube lip.
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
    private let streamWidth: CGFloat = 5

    var body: some View {
        Canvas { context, size in
            guard streamThickness > 0.01 else { return }

            let path = streamPath()

            // Draw a wider, semi-transparent outer glow
            context.stroke(
                path,
                with: .color(color.opacity(0.25)),
                style: StrokeStyle(
                    lineWidth: (streamWidth + 2) * streamThickness,
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

    /// Creates a restrained pour path with a vertical start and finish so the
    /// liquid reads as a controlled flow instead of a spray arc.
    private func streamPath() -> Path {
        var path = Path()
        path.move(to: from)

        let dy = to.y - from.y
        let initialDrop = min(max(dy * 0.35, 12), 26)
        let finalApproach = min(max(dy * 0.22, 8), 18)

        let cp1 = CGPoint(
            x: from.x,
            y: from.y + initialDrop
        )
        let cp2 = CGPoint(
            x: to.x,
            y: to.y - finalApproach
        )

        path.addCurve(to: to, control1: cp1, control2: cp2)
        return path
    }
}
