import SwiftUI

/// A view that draws an animated liquid stream between two points.
///
/// The stream is a thick colored line with a controlled downward curve
/// from the source tube opening to the target tube opening.
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

            // Keep the halo subtle so the stream reads as liquid inside glass,
            // not a neon line over the scene.
            context.stroke(
                path,
                with: .color(color.opacity(0.12)),
                style: StrokeStyle(
                    lineWidth: (streamWidth + 1) * streamThickness,
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

    /// Creates a restrained pour path that leaves and enters the necks cleanly.
    private func streamPath() -> Path {
        var path = Path()
        path.move(to: from)

        let dx = to.x - from.x
        let dy = to.y - from.y
        let initialDrop = min(max(dy * 0.24, 8), 18)
        let finalApproach = min(max(dy * 0.20, 8), 16)

        let cp1 = CGPoint(
            x: from.x + dx * 0.18,
            y: from.y + initialDrop
        )
        let cp2 = CGPoint(
            x: to.x - dx * 0.08,
            y: to.y - finalApproach
        )

        path.addCurve(to: to, control1: cp1, control2: cp2)
        return path
    }
}

struct LiquidNeckSegmentView: View {
    let from: CGPoint
    let to: CGPoint
    let color: Color
    let progress: CGFloat

    private let streamWidth: CGFloat = 5

    var body: some View {
        Canvas { context, size in
            guard thickness > 0.01 else { return }

            var path = Path()
            path.move(to: from)
            path.addLine(to: to)

            context.stroke(
                path,
                with: .color(color.opacity(0.12)),
                style: StrokeStyle(
                    lineWidth: (streamWidth + 1) * thickness,
                    lineCap: .round,
                    lineJoin: .round
                )
            )

            context.stroke(
                path,
                with: .color(color),
                style: StrokeStyle(
                    lineWidth: streamWidth * thickness,
                    lineCap: .round,
                    lineJoin: .round
                )
            )

            context.stroke(
                path,
                with: .color(.white.opacity(0.2)),
                style: StrokeStyle(
                    lineWidth: (streamWidth * 0.4) * thickness,
                    lineCap: .round,
                    lineJoin: .round
                )
            )
        }
        .allowsHitTesting(false)
    }

    private var thickness: CGFloat {
        if progress < 0.08 {
            return progress / 0.08
        } else if progress > 0.88 {
            return (1.0 - progress) / 0.12
        }
        return 1.0
    }
}
