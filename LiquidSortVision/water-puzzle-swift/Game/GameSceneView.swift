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
                // Background tap target for deselection (full area, unscaled)
                Color.clear
                    .contentShape(Rectangle())
                    .onTapGesture {
                        engine.handleBackgroundTap()
                    }

                // Scaled tube content + stream overlay
                ZStack {
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

                    // Liquid stream overlay during pour
                    if let anim = engine.pourAnimation, anim.isStreaming {
                        liquidStreamOverlay(anim: anim)
                    }
                }
                // Give content the unscaled natural size so tubes don't overflow
                .frame(
                    width: geometry.size.width / layout.scale,
                    height: geometry.size.height / layout.scale
                )
                .coordinateSpace(name: sceneSpace)
                .onPreferenceChange(TubeFramePreferenceKey.self) { frames in
                    tubeFrames = frames
                    engine.tubeFrames = frames
                }
                .scaleEffect(layout.scale)
                // Constrain layout frame to actual available size
                .frame(width: geometry.size.width, height: geometry.size.height)
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
                // Capture base frame BEFORE animation transforms
                .background(
                    GeometryReader { geo in
                        Color.clear
                            .preference(
                                key: TubeFramePreferenceKey.self,
                                value: [tube.index: geo.frame(in: .named(sceneSpace))]
                            )
                    }
                )
                // Animation transforms applied externally for base-frame capture
                .offset(y: tube.isPending && !tube.isAnimating ? -TubeView.pendingLift : 0)
                .rotationEffect(.radians(tube.tiltAngle), anchor: .center)
                .offset(x: tube.animationOffsetX, y: tube.animationOffsetY)
                .animation(
                    tube.isAnimating ? nil : .spring(response: 0.25, dampingFraction: 0.7),
                    value: tube.isPending
                )
                .zIndex(tube.isAnimating ? 10 : 0)
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

        // With .center anchor, the rotation pivot is at the center of the tube.
        // The mouth (neck opening) is tubeHeight/2 - capHeight above center.
        let mouthDist = TubeView.tubeHeight / 2 - TubeView.capHeight

        // Mouth position relative to center (anchor point)
        let localX: CGFloat = 0
        let localY: CGFloat = -mouthDist

        // Rotate around the center anchor
        let cosA = cos(tiltAngle)
        let sinA = sin(tiltAngle)
        let rotatedX = localX * cosA - localY * sinA
        let rotatedY = localX * sinA + localY * cosA

        // Center of tube in scene coords (with animation offsets)
        let anchorPoint = CGPoint(
            x: sourceFrame.midX + offsetX,
            y: sourceFrame.midY + offsetY
        )
        let sourceLip = CGPoint(
            x: anchorPoint.x + rotatedX,
            y: anchorPoint.y + rotatedY
        )

        // Target opening: into the body of the target tube for a visible stream
        let targetOpening = CGPoint(
            x: targetFrame.midX,
            y: targetFrame.minY + TubeView.capHeight + TubeView.neckHeight + 20
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
        let scale: CGFloat
    }

    private func calculateLayout(tubeCount: Int, availableSize: CGSize) -> LayoutInfo {
        let isTwoRows = tubeCount > maxPerRow

        let rowCount: Int
        if isTwoRows {
            rowCount = Int(ceil(Double(tubeCount) / 2.0))
        } else {
            rowCount = tubeCount
        }

        let tubeSpacing: CGFloat = 10
        let rowSpacing: CGFloat = isTwoRows ? 40 : 0

        // Natural content size at 1x scale
        let contentWidth = CGFloat(rowCount) * TubeView.tubeWidth
            + CGFloat(max(rowCount - 1, 0)) * tubeSpacing
        let numberOfRows = CGFloat(isTwoRows ? 2 : 1)
        let contentHeight = numberOfRows * TubeView.tubeHeight + rowSpacing

        // Scale to fit within available space (with small margin)
        let margin: CGFloat = 16
        let horizontalScale = availableSize.width / (contentWidth + margin)
        let verticalScale = availableSize.height / (contentHeight + margin)
        let scale = min(min(horizontalScale, verticalScale), 1.0)

        return LayoutInfo(
            isTwoRows: isTwoRows,
            tubeSpacing: tubeSpacing,
            rowSpacing: rowSpacing,
            scale: scale
        )
    }
}
