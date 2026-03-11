import SwiftUI

/// The main game scene view that lays out tubes in a grid.
///
/// Displays all tubes in one or two rows depending on count
/// and handles background taps for deselection.
struct GameSceneView: View {
    let engine: GameEngine

    /// Maximum tubes in a single row before splitting into two rows.
    private let maxPerRow = 7

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
                        // Two-row layout
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
                        // Single-row layout
                        tubeRow(
                            tubes: engine.tubes,
                            spacing: layout.tubeSpacing
                        )
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
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
            }
        }
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

        // Calculate spacing to fit tubes within available width
        let totalTubeWidth = CGFloat(rowCount) * TubeView.tubeWidth
        let availableSpacing = availableSize.width - totalTubeWidth - 32 // 16pt padding each side
        let maxSpacing: CGFloat = 16
        let tubeSpacing = max(4, min(maxSpacing, availableSpacing / CGFloat(max(rowCount - 1, 1))))

        let rowSpacing: CGFloat = isTwoRows ? 24 : 0

        return LayoutInfo(
            isTwoRows: isTwoRows,
            tubeSpacing: tubeSpacing,
            rowSpacing: rowSpacing
        )
    }
}
