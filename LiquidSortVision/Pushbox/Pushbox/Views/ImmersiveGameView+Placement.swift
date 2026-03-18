// ImmersiveGameView+Placement.swift
#if os(visionOS)
// Placement logic for positioning the game board in the user's environment.

import SwiftUI
import RealityKit
import ARKit

extension ImmersiveGameView {

    // MARK: - Placement Loop

    /// Continuously updates placeholder position during the placing phase.
    func runPlacementLoop() async {
        while !Task.isCancelled {
            if appModel.gamePhase == .placing {
                updatePlaceholderPosition()
            }
            try? await Task.sleep(for: .milliseconds(50))
        }
    }

    // MARK: - Placeholder Positioning

    /// Updates the placeholder position to follow the user's gaze on the floor.
    func updatePlaceholderPosition() {
        guard let placeholder = placeholderEntity,
              let trackingProvider = appModel.worldTrackingProvider,
              let deviceAnchor = trackingProvider.queryDeviceAnchor(atTimestamp: CACurrentMediaTime()) else {
            return
        }

        let headTransform = deviceAnchor.originFromAnchorTransform
        let headPosition = SIMD3<Float>(headTransform.columns.3.x, headTransform.columns.3.y, headTransform.columns.3.z)
        let forward = -SIMD3<Float>(headTransform.columns.2.x, headTransform.columns.2.y, headTransform.columns.2.z)

        let floorY: Float = 0.0
        let minDistance: Float = 1.0
        let maxDistance: Float = 5.0

        // Always use the horizontal gaze direction for consistent floor placement
        let flatForward = safeNormalize(SIMD3<Float>(forward.x, 0, forward.z))

        // Compute horizontal distance to floor intersection
        var horizontalDistance: Float = maxDistance

        if forward.y < -0.01 {
            // User looking downward: find where gaze hits the floor
            let t = (floorY - headPosition.y) / forward.y
            let intersection = headPosition + forward * t
            let offset = SIMD3<Float>(intersection.x - headPosition.x, 0, intersection.z - headPosition.z)
            horizontalDistance = simd_length(offset)
        }

        horizontalDistance = min(max(horizontalDistance, minDistance), maxDistance)

        var targetPosition = headPosition + flatForward * horizontalDistance
        targetPosition.y = floorY

        let currentPosition = placeholder.position
        let distance = simd_length(targetPosition - currentPosition)
        let baseSmoothFactor: Float = 0.15
        let adaptiveFactor = min(baseSmoothFactor + distance * 0.05, 0.35)

        placeholder.position = currentPosition + (targetPosition - currentPosition) * adaptiveFactor

        // Calculate rotation to face the user (Y-axis rotation only)
        let toUser = safeNormalize(SIMD3<Float>(headPosition.x - placeholder.position.x, 0, headPosition.z - placeholder.position.z))
        let angle = atan2(toUser.x, toUser.z)
        placeholder.orientation = simd_quatf(angle: angle, axis: SIMD3<Float>(0, 1, 0))
    }

    // MARK: - Placement Confirmation

    /// Captures the placeholder transform, positions the game anchor, and transitions to playing.
    func confirmPlacement() {
        guard let placeholder = placeholderEntity else { return }

        // Capture the full world transform (position + rotation)
        let worldTransform = placeholder.transformMatrix(relativeTo: nil)
        let anchorTransform = Transform(matrix: worldTransform)

        // Position the game anchor at the placement location
        gameAnchorEntity.transform = anchorTransform

        // Save session anchor transform for reuse across levels
        appModel.saveSessionAnchor(transform: anchorTransform)

        // Hide placeholder
        placeholder.isEnabled = false

        // Transition to playing phase
        appModel.confirmLevelPlacement()
    }

    // MARK: - Helpers

    /// Normalizes a vector, returning forward if input is near-zero.
    func safeNormalize(_ vector: SIMD3<Float>) -> SIMD3<Float> {
        simd_length(vector) > 0.0001 ? simd_normalize(vector) : [0, 0, -1]
    }
}
#endif
