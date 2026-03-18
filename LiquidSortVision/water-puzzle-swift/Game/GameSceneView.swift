import SwiftUI

// MARK: - Tube Position Tracking

/// Preference key to collect each tube's frame in the scene coordinate space.
struct TubeFramePreferenceKey: PreferenceKey {
    static var defaultValue: [Int: CGRect] = [:]

    static func reduce(value: inout [Int: CGRect], nextValue: () -> [Int: CGRect]) {
        value.merge(nextValue()) { $1 }
    }
}

/// The main game scene view that lays out tubes in a grid.
///
/// Displays all tubes in one or two rows depending on count,
/// handles background taps for deselection, and overlays a
/// liquid stream animation during pours.
struct GameSceneView: View {
    let engine: GameEngine

    /// Maximum tubes in a single row before splitting into two rows.
    private let maxPerRow = 7

    /// Collected tube frames in the scene coordinate space.
    @State private var tubeFrames: [Int: CGRect] = [:]

    /// Named coordinate space for position tracking.
    private let sceneSpace = "GameScene"

    var body: some View {
        GeometryReader { geometry in
            let tubeCount = engine.tubes.count
            let layout = calculateLayout(
                tubeCount: tubeCount,
                availableSize: geometry.size
            )

            ZStack {
                // Background tap target for deselection
                Color.clear
                    .contentShape(Rectangle())
                    .onTapGesture {
                        engine.handleBackgroundTap()
                    }

                // Tube layout
                VStack(spacing: layout.rowSpacing) {
                    if layout.isTwoRows {
                        let topCount = Int(ceil(Double(tubeCount) / 2.0))
                        let bottomCount = tubeCount - topCount

                        tubeRow(
                            tubes: Array(engine.tubes.prefix(topCount)),
                            spacing: layout.tubeSpacing
                        )

                        tubeRow(
                            tubes: Array(engine.tubes.suffix(bottomCount)),
                            spacing: layout.tubeSpacing
                        )
                    } else {
                        tubeRow(
                            tubes: engine.tubes,
                            spacing: layout.tubeSpacing
                        )
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)

                // Liquid stream overlay during pour
                if let anim = engine.pourAnimation, anim.isStreaming {
                    liquidStreamOverlay(anim: anim)
                }
            }
            .coordinateSpace(name: sceneSpace)
            .onPreferenceChange(TubeFramePreferenceKey.self) { frames in
                tubeFrames = frames
            }
        }
    }

    // MARK: - Tube Row

    private func tubeRow(tubes: [TubeState], spacing: CGFloat) -> some View {
        HStack(spacing: spacing) {
            ForEach(tubes) { tube in
                TubeView(tube: tube) {
                    engine.handleTubeTap(tube)
                }
                .background(
                    GeometryReader { geo in
                        Color.clear
                            .preference(
                                key: TubeFramePreferenceKey.self,
                                value: [tube.index: geo.frame(in: .named(sceneSpace))]
                            )
                    }
                )
            }
        }
    }

    // MARK: - Liquid Stream Overlay

    private func liquidStreamOverlay(anim: GameEngine.PourAnimation) -> some View {
        let sourceFrame = tubeFrames[anim.sourceIndex] ?? .zero
        let targetFrame = tubeFrames[anim.targetIndex] ?? .zero

        // Source tube animation state
        let sourceTube = engine.tubes.first { $0.index == anim.sourceIndex }
        let tiltAngle = sourceTube?.tiltAngle ?? 0
        let offsetX = sourceTube?.animationOffsetX ?? 0
        let offsetY = sourceTube?.animationOffsetY ?? 0

        // With .bottom anchor, the rotation pivot is at the bottom-center.
        // The mouth/lip is at the top of the tube (tubeHeight above the anchor).
        let tubeHeight = sourceFrame.height

        // Top-centre relative to bottom-centre (anchor point)
        let localX: CGFloat = 0
        let localY: CGFloat = -tubeHeight

        // Rotate around the bottom-centre anchor
        let cosA = cos(tiltAngle)
        let sinA = sin(tiltAngle)
        let rotatedX = localX * cosA - localY * sinA
        let rotatedY = localX * sinA + localY * cosA

        // Bottom-center of tube in scene coords (with animation offsets)
        let anchorPoint = CGPoint(
            x: sourceFrame.midX + offsetX,
            y: sourceFrame.maxY + offsetY
        )
        let sourceLip = CGPoint(
            x: anchorPoint.x + rotatedX,
            y: anchorPoint.y + rotatedY
        )

        // Target opening: top-centre of the target tube
        let targetOpening = CGPoint(
            x: targetFrame.midX,
            y: targetFrame.minY
        )

        let streamColor = ColorPalette.color(for: anim.colorGroupId)

        return LiquidStreamView(
            from: sourceLip,
            to: targetOpening,
            color: streamColor,
            progress: anim.pourProgress
        )
        .allowsHitTesting(false)
    }

    // MARK: - Layout Calculation

    private struct LayoutInfo {
        let isTwoRows: Bool
        let tubeSpacing: CGFloat
        let rowSpacing: CGFloat
    }

    private func calculateLayout(tubeCount: Int, availableSize: CGSize) -> LayoutInfo {
        let isTwoRows = tubeCount > maxPerRow

        let rowCount: Int
        if isTwoRows {
            rowCount = Int(ceil(Double(tubeCount) / 2.0))
        } else {
            rowCount = tubeCount
        }

        let totalTubeWidth = CGFloat(rowCount) * TubeView.tubeWidth
        let availableSpacing = availableSize.width - totalTubeWidth - 32
        let maxSpacing: CGFloat = 14
        let tubeSpacing = max(4, min(maxSpacing, availableSpacing / CGFloat(max(rowCount - 1, 1))))

        // More row spacing for taller bottles
        let rowSpacing: CGFloat = isTwoRows ? 40 : 0

        return LayoutInfo(
            isTwoRows: isTwoRows,
            tubeSpacing: tubeSpacing,
            rowSpacing: rowSpacing
        )
    }
}
