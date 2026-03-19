import SwiftUI

// MARK: - Tube Position Tracking

/// Preference key to collect each tube's frame in the scene coordinate space.
struct TubeFramePreferenceKey: PreferenceKey {
    static var defaultValue: [Int: CGRect] = [:]

    /// Merges tube frames from child views, keeping the latest value for each index.
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

                tubeLayout(
                    layout: layout,
                    layer: .content,
                    capturesFrames: true
                )

                if let anim = engine.pourAnimation, anim.isStreaming {
                    liquidStreamOverlay(anim: anim, tubeScale: layout.scale)
                        .zIndex(15)
                }

                tubeLayout(
                    layout: layout,
                    layer: .front,
                    capturesFrames: false
                )

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

    private func tubeLayout(
        layout: LayoutInfo,
        layer: TubeView.RenderLayer,
        capturesFrames: Bool
    ) -> some View {
        let tubeCount = engine.tubes.count

        return VStack(spacing: layout.rowSpacing * layout.scale) {
            if layout.isTwoRows {
                let topCount = Int(ceil(Double(tubeCount) / 2.0))
                let bottomCount = tubeCount - topCount

                tubeRow(
                    tubes: Array(engine.tubes.prefix(topCount)),
                    spacing: layout.tubeSpacing * layout.scale,
                    tubeScale: layout.scale,
                    layer: layer,
                    capturesFrames: capturesFrames
                )

                tubeRow(
                    tubes: Array(engine.tubes.suffix(bottomCount)),
                    spacing: layout.tubeSpacing * layout.scale,
                    tubeScale: layout.scale,
                    layer: layer,
                    capturesFrames: capturesFrames
                )
            } else {
                tubeRow(
                    tubes: engine.tubes,
                    spacing: layout.tubeSpacing * layout.scale,
                    tubeScale: layout.scale,
                    layer: layer,
                    capturesFrames: capturesFrames
                )
            }
        }
        .allowsHitTesting(layer != .front)
    }

    private func tubeRow(
        tubes: [TubeState],
        spacing: CGFloat,
        tubeScale: CGFloat,
        layer: TubeView.RenderLayer,
        capturesFrames: Bool
    ) -> some View {
        let scaledWidth = TubeView.tubeWidth * tubeScale
        let scaledHeight = TubeView.tubeHeight * tubeScale

        return HStack(spacing: spacing) {
            ForEach(tubes) { tube in
                ZStack {
                    if capturesFrames {
                        GeometryReader { geo in
                            Color.clear
                                .allowsHitTesting(false)
                                .preference(
                                    key: TubeFramePreferenceKey.self,
                                    value: [tube.index: geo.frame(in: .named(sceneSpace))]
                                )
                        }
                    }

                    TubeView(tube: tube, onTap: {
                        engine.handleTubeTap(tube)
                    }, layer: layer)
                    // Scale tube visual, then set layout frame to scaled size
                    .scaleEffect(tubeScale)
                    .frame(width: scaledWidth, height: scaledHeight)
                    // Animation transforms happen inside the fixed layout slot so
                    // stream anchors can be computed from the stable wrapper frame.
                    .offset(y: tube.isPending && !tube.isAnimating ? -TubeView.pendingLift : 0)
                    .rotationEffect(.radians(tube.tiltAngle), anchor: .center)
                    .offset(x: tube.animationOffsetX, y: tube.animationOffsetY)
                    .animation(
                        tube.isAnimating ? nil : .spring(response: 0.25, dampingFraction: 0.7),
                        value: tube.isPending
                    )
                }
                .frame(width: scaledWidth, height: scaledHeight)
                .zIndex(tubeZIndex(for: tube, layer: layer))
            }
        }
    }

    private func tubeZIndex(for tube: TubeState, layer: TubeView.RenderLayer) -> Double {
        switch layer {
        case .content:
            return tube.isAnimating ? 10 : 0
        case .front:
            return tube.isAnimating ? 30 : 20
        }
    }

    // MARK: - Liquid Stream Overlay

    private func liquidStreamOverlay(anim: GameEngine.PourAnimation, tubeScale: CGFloat) -> some View {
        let sourceFrame = tubeFrames[anim.sourceIndex] ?? .zero
        let targetFrame = tubeFrames[anim.targetIndex] ?? .zero
        let sourceTube = engine.tubes.first(where: { $0.index == anim.sourceIndex })
        let tiltSign: CGFloat = targetFrame.midX >= sourceFrame.midX ? 1.0 : -1.0
        let sourceInside = TubeView.transformedPoint(
            in: sourceFrame,
            localOffset: TubeView.sourceStreamInnerOffset(scale: tubeScale),
            angle: sourceTube?.tiltAngle ?? 0,
            translationX: sourceTube?.animationOffsetX ?? 0,
            translationY: sourceTube?.animationOffsetY ?? 0
        )
        let sourceLip = TubeView.transformedPoint(
            in: sourceFrame,
            localOffset: TubeView.pourLipOffset(toward: tiltSign, scale: tubeScale),
            angle: sourceTube?.tiltAngle ?? 0,
            translationX: sourceTube?.animationOffsetX ?? 0,
            translationY: sourceTube?.animationOffsetY ?? 0
        )
        let targetLip = TubeView.lipPoint(in: targetFrame, scale: tubeScale)
        let targetEntry = TubeView.transformedPoint(
            in: targetFrame,
            localOffset: TubeView.streamEntryOffset(scale: tubeScale),
            angle: 0,
            translationX: 0,
            translationY: 0
        )

        let streamColor = ColorPalette.color(for: anim.colorGroupId)

        return ZStack {
            LiquidNeckSegmentView(
                from: sourceInside,
                to: sourceLip,
                color: streamColor,
                progress: anim.pourProgress
            )
            .mask(
                tubeMask(
                    frame: sourceFrame,
                    angle: sourceTube?.tiltAngle ?? 0,
                    translationX: sourceTube?.animationOffsetX ?? 0,
                    translationY: sourceTube?.animationOffsetY ?? 0,
                    scale: tubeScale
                )
            )

            LiquidStreamView(
                from: sourceLip,
                to: targetLip,
                color: streamColor,
                progress: anim.pourProgress
            )

            LiquidNeckSegmentView(
                from: targetLip,
                to: targetEntry,
                color: streamColor,
                progress: anim.pourProgress
            )
            .mask(
                tubeMask(
                    frame: targetFrame,
                    angle: 0,
                    translationX: 0,
                    translationY: 0,
                    scale: tubeScale
                )
            )
        }
        .allowsHitTesting(false)
    }

    private func tubeMask(
        frame: CGRect,
        angle: CGFloat,
        translationX: CGFloat,
        translationY: CGFloat,
        scale: CGFloat
    ) -> some View {
        BottleShape(
            bodyWidth: TubeView.tubeWidth,
            bodyHeight: TubeView.bodyHeight,
            neckWidth: TubeView.neckWidth,
            neckHeight: TubeView.neckHeight,
            capHeight: TubeView.capHeight,
            bottomRadius: TubeView.bottomRadius
        )
        .fill(.white)
        .scaleEffect(scale)
        .frame(
            width: TubeView.tubeWidth * scale,
            height: TubeView.tubeHeight * scale
        )
        .position(x: frame.midX, y: frame.midY)
        .rotationEffect(.radians(angle), anchor: .center)
        .offset(x: translationX, y: translationY)
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
