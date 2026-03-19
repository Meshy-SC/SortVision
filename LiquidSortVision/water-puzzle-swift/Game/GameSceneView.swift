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
                VStack(spacing: layout.rowSpacing * layout.scale) {
                    if layout.isTwoRows {
                        let topCount = Int(ceil(Double(tubeCount) / 2.0))
                        let bottomCount = tubeCount - topCount

                        tubeRow(
                            tubes: Array(engine.tubes.prefix(topCount)),
                            spacing: layout.tubeSpacing * layout.scale,
                            tubeScale: layout.scale
                        )

                        tubeRow(
                            tubes: Array(engine.tubes.suffix(bottomCount)),
                            spacing: layout.tubeSpacing * layout.scale,
                            tubeScale: layout.scale
                        )
                    } else {
                        tubeRow(
                            tubes: engine.tubes,
                            spacing: layout.tubeSpacing * layout.scale,
                            tubeScale: layout.scale
                        )
                    }
                }

                // Liquid stream overlay during pour
                if let anim = engine.pourAnimation, anim.isStreaming {
                    liquidStreamOverlay(anim: anim, tubeScale: layout.scale)
                }
            }
            .coordinateSpace(name: sceneSpace)
            .onPreferenceChange(TubeFramePreferenceKey.self) { frames in
                tubeFrames = frames
                engine.tubeFrames = frames
                engine.viewScale = layout.scale
            }
        }
    }

    // MARK: - Tube Row

    private func tubeRow(tubes: [TubeState], spacing: CGFloat, tubeScale: CGFloat) -> some View {
        let scaledWidth = TubeView.tubeWidth * tubeScale
        let scaledHeight = TubeView.tubeHeight * tubeScale

        return HStack(spacing: spacing) {
            ForEach(tubes) { tube in
                TubeView(tube: tube) {
                    engine.handleTubeTap(tube)
                }
                // Scale tube visual, then set layout frame to scaled size
                .scaleEffect(tubeScale)
                .frame(width: scaledWidth, height: scaledHeight)
                // Capture base frame AFTER scale — positions are in screen space
                .background(
                    GeometryReader { geo in
                        Color.clear
                            .preference(
                                key: TubeFramePreferenceKey.self,
                                value: [tube.index: geo.frame(in: .named(sceneSpace))]
                            )
                    }
                )
                // Animation transforms in screen space
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

    private func liquidStreamOverlay(anim: GameEngine.PourAnimation, tubeScale: CGFloat) -> some View {
        let sourceFrame = tubeFrames[anim.sourceIndex] ?? .zero
        let targetFrame = tubeFrames[anim.targetIndex] ?? .zero
        let sourceTube = engine.tubes.first(where: { $0.index == anim.sourceIndex })
        let tiltSign: CGFloat = targetFrame.midX >= sourceFrame.midX ? 1.0 : -1.0
        let sourceLip = TubeView.transformedPoint(
            in: sourceFrame,
            localOffset: TubeView.pourLipOffset(toward: tiltSign, scale: tubeScale),
            angle: sourceTube?.tiltAngle ?? 0,
            translationX: sourceTube?.animationOffsetX ?? 0,
            translationY: sourceTube?.animationOffsetY ?? 0
        )
        let targetLip = TubeView.lipPoint(in: targetFrame, scale: tubeScale)

        let streamFrom = sourceLip
        let streamTo = targetLip

        let streamColor = ColorPalette.color(for: anim.colorGroupId)

        return LiquidStreamView(
            from: streamFrom,
            to: streamTo,
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
