// DirectionalPadOrnament.swift
#if os(visionOS)
// Directional control pad for player movement.

import SwiftUI

/// Directional control pad ornament for moving the player in the puzzle.
/// Transforms button directions based on current viewpoint orientation.
struct DirectionalPadOrnament: View {
    
    /// Current camera viewpoint for direction transformation.
    var currentViewpoint: SquareAzimuth
    
    /// Called when the user taps a direction button.
    /// - Parameters:
    ///   - columnDelta: Horizontal movement (-1 left, +1 right).
    ///   - rowDelta: Vertical movement (-1 up, +1 down).
    var onMove: (_ columnDelta: Int, _ rowDelta: Int) -> Void
    
    @ScaledMetric(relativeTo: .title) private var buttonSize: CGFloat = 80
    
    /// Transforms logical direction to world direction based on viewpoint.
    private func transformedDirection(forColumnDelta columnDelta: Int, rowDelta: Int) -> (Int, Int) {
        switch currentViewpoint {
        case .front: return (columnDelta, rowDelta)
        case .right: return (rowDelta, -columnDelta)
        case .back:  return (-columnDelta, -rowDelta)
        case .left:  return (-rowDelta, columnDelta)
        }
    }
    
    var body: some View {
        VStack(spacing: 30) {
            Button(action: {
                let (newColumnDelta, newRowDelta) = transformedDirection(forColumnDelta: 0, rowDelta: -1)
                onMove(newColumnDelta, newRowDelta)
            }) {
                Image(systemName: "chevron.up")
                    .frame(width: buttonSize, height: buttonSize)
            }
            .hoverEffect(.highlight)
            .accessibilityLabel("Move Up")
            .accessibilityHint("Moves the player one tile upward")

            HStack(spacing: 30) {
                Button(action: {
                    let (newColumnDelta, newRowDelta) = transformedDirection(forColumnDelta: -1, rowDelta: 0)
                    onMove(newColumnDelta, newRowDelta)
                }) {
                    Image(systemName: "chevron.left")
                        .frame(width: buttonSize, height: buttonSize)
                }
                .hoverEffect(.highlight)
                .accessibilityLabel("Move Left")
                .accessibilityHint("Moves the player one tile to the left")

                Button(action: {
                    let (newColumnDelta, newRowDelta) = transformedDirection(forColumnDelta: 1, rowDelta: 0)
                    onMove(newColumnDelta, newRowDelta)
                }) {
                    Image(systemName: "chevron.right")
                        .frame(width: buttonSize, height: buttonSize)
                }
                .hoverEffect(.highlight)
                .accessibilityLabel("Move Right")
                .accessibilityHint("Moves the player one tile to the right")
            }

            Button(action: {
                let (newColumnDelta, newRowDelta) = transformedDirection(forColumnDelta: 0, rowDelta: 1)
                onMove(newColumnDelta, newRowDelta)
            }) {
                Image(systemName: "chevron.down")
                    .frame(width: buttonSize, height: buttonSize)
            }
            .hoverEffect(.highlight)
            .accessibilityLabel("Move Down")
            .accessibilityHint("Moves the player one tile downward")
        }
        .buttonStyle(.bordered)
        .buttonBorderShape(.circle)
        .controlSize(.large)
        .font(.largeTitle.weight(.bold))
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Directional pad")
        .dynamicTypeSize(...DynamicTypeSize.accessibility2)
    }
}
#endif
