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

    /// Creates a curved path from source down to target with a natural gravity droop.
    private func streamPath() -> Path {
        var path = Path()
        path.move(to: from)

        let dx = to.x - from.x
        let dy = to.y - from.y
        let downwardLead = max(dy * 0.22, 8)
        let settleLift = min(max(abs(dy) * 0.12, 4), 10)

        // Keep the stream close to the direct pour path so it reads as a controlled flow,
        // not a spray or scattering arc.
        let cp1 = CGPoint(
            x: from.x + dx * 0.15,
            y: from.y + downwardLead
        )
        let cp2 = CGPoint(
            x: from.x + dx * 0.8,
            y: to.y - settleLift
        )

        path.addCurve(to: to, control1: cp1, control2: cp2)
        return path
    }
}
