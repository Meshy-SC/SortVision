// ImmersiveGameView+Viewpoint.swift
#if os(visionOS)
// Viewpoint tracking via WorldTrackingProvider for D-Pad direction mapping.

import SwiftUI
import RealityKit
import ARKit

extension ImmersiveGameView {

    // MARK: - Viewpoint Loop

    /// Polls head position and computes the viewing angle relative to the board center.
    /// Maps to a SquareAzimuth so the D-Pad directions feel natural from any angle.
    func runViewpointLoop() async {
        while !Task.isCancelled {
            if appModel.gamePhase == .playing {
                updateViewpoint()
            }
            try? await Task.sleep(for: .milliseconds(100))
        }
    }

    // MARK: - Viewpoint Computation

    private func updateViewpoint() {
        guard let trackingProvider = appModel.worldTrackingProvider,
              let deviceAnchor = trackingProvider.queryDeviceAnchor(atTimestamp: CACurrentMediaTime()) else {
            return
        }

        let headTransform = deviceAnchor.originFromAnchorTransform
        let headPosition = SIMD3<Float>(headTransform.columns.3.x, headTransform.columns.3.y, headTransform.columns.3.z)

        // Board center in world space (matches LevelBuilder centering: (cols-1)/2, (rows-1)/2)
        let cellSize = GameLayout.cellSize
        let localCenter = SIMD3<Float>(
            Float(appModel.levelWidth - 1) * cellSize / 2,
            0,
            Float(appModel.levelDepth - 1) * cellSize / 2
        )
        let worldCenter = gameAnchorEntity.convert(position: localCenter, to: nil)

        // Vector from board center to user (horizontal only)
        let dx = headPosition.x - worldCenter.x
        let dz = headPosition.z - worldCenter.z

        // Compute angle in world space
        let worldAngle = atan2(dx, dz)

        // Account for the board's Y rotation to get a board-relative angle
        let boardRotation = gameAnchorEntity.transform.rotation
        // Extract Y-axis rotation angle from quaternion
        let boardForward = boardRotation.act(SIMD3<Float>(0, 0, 1))
        let boardAngle = atan2(boardForward.x, boardForward.z)
        var relativeAngle = worldAngle - boardAngle

        // Normalize to [-π, π]
        relativeAngle = relativeAngle.remainder(dividingBy: 2 * .pi)

        // Map to azimuth quadrants
        let azimuth: SquareAzimuth
        if relativeAngle >= -.pi / 4 && relativeAngle < .pi / 4 {
            azimuth = .front
        } else if relativeAngle >= .pi / 4 && relativeAngle < 3 * .pi / 4 {
            azimuth = .right
        } else if relativeAngle >= -3 * .pi / 4 && relativeAngle < -.pi / 4 {
            azimuth = .left
        } else {
            azimuth = .back
        }

        if appModel.currentViewpoint != azimuth {
            appModel.currentViewpoint = azimuth
        }
    }
}
#endif
